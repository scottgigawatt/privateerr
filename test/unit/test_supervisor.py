#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_supervisor.py: Verify recovery decisions and persistence without PIA or Docker.
#

"""Verify recovery decisions and persistence without PIA or Docker."""

import base64
import copy
import tempfile
import unittest
from collections.abc import Generator, Mapping
from contextlib import contextmanager
from dataclasses import replace
from pathlib import Path
from unittest.mock import Mock, patch

from privateerr.client import APIUnavailable, Client
from privateerr.config import Config, ConfigurationError
from privateerr.settings import ConnectionSettings, InvalidSettings, Store, connection_settings
from privateerr.supervisor import (
    Endpoint,
    GenerationFailed,
    Pending,
    Shutdown,
    Supervisor,
    select_endpoint,
)


def fixture(
    directory: Path, endpoint: str = "198.51.100.10", name: str = "example-one"
) -> ConnectionSettings:
    """Write matching test-only connection files with syntactically valid keys."""

    directory.mkdir(parents=True, exist_ok=True)

    # Use deterministic test bytes that pass key validation without any real credentials.
    key = base64.b64encode(bytes(range(32))).decode()
    (directory / "wg0.conf").write_text(
        f"[Interface]\nPrivateKey = {key}\nAddress = 10.0.0.2\n"
        f"[Peer]\nPublicKey = {key}\nEndpoint = {endpoint}:1337\n"
    )
    (directory / "privateerr.env").write_text(
        f"PIA_WG_SERVER_NAME={name}\nPIA_WG_ENDPOINT_IP={endpoint}\n"
        "PIA_WG_ENDPOINT_PORT=1337\nPIA_REGION_ID=ca\n"
    )

    # Parse the fixture through production validation rather than returning a fabricated result.
    return connection_settings(directory / "wg0.conf", directory / "privateerr.env")


def catalog() -> dict[str, object]:
    """Provide pinned, alternate, and non-forwarding regions for endpoint selection tests."""

    return {
        "regions": [
            {
                "id": region,
                "port_forward": forwarding,
                "servers": {
                    "wg": [
                        {"ip": f"198.51.100.{number}", "cn": f"example-{number}"}
                        for number in numbers
                    ]
                },
            }
            for region, forwarding, numbers in (
                ("ca", True, (10, 11)),
                ("ca_toronto", True, (12,)),
                ("no_pf", False, (13,)),
            )
        ]
    }


class ConfigTests(unittest.TestCase):
    """Keep legacy startup compatible while validating explicitly enabled recovery."""

    def test_legacy_environment_needs_no_recovery_options(self):
        """Ignore unused recovery settings when automatic recovery has not been enabled."""

        config = Config.from_environment(
            {
                "PRIVATEERR_GLUETUN_API_KEY": "invalid",  # pragma: allowlist secret
                "PRIVATEERR_RECOVERY_INTERVAL_SECONDS": "bad",
            }
        )
        self.assertFalse(config.recover)
        self.assertTrue(config.keepalive)
        self.assertEqual(config.environment["PREFERRED_REGION"], "ca")

    def test_invalid_settings_are_rejected_without_values(self):
        """Reject invalid timing ranges and unsupported boolean spellings."""

        for variable, value in (
            ("PRIVATEERR_GENERATION_TIMEOUT_SECONDS", "0"),
            ("PRIVATEERR_GENERATION_TIMEOUT_SECONDS", "10000"),
            ("PRIVATEERR_AUTO_RECOVER", "yes"),
        ):
            with (
                self.subTest(variable=variable, value=value),
                self.assertRaises(ConfigurationError),
            ):
                Config.from_environment({variable: value})

    def test_recovery_requires_compatible_mode_and_valid_urls(self):
        """Validate recovery prerequisites and keep the API key out of configuration repr."""

        valid = {"PRIVATEERR_AUTO_RECOVER": "true", "PRIVATEERR_GLUETUN_API_KEY": "a" * 32}

        for override in (
            {"PRIVATEERR_KEEPALIVE": "false"},
            {"PIA_CONNECT": "true"},
            {"VPN_PROTOCOL": "openvpn"},
            {"PRIVATEERR_GLUETUN_API_KEY": "short"},  # pragma: allowlist secret
            {
                "PRIVATEERR_GLUETUN_URL": "http://user:password@host:8000",  # pragma: allowlist secret
            },
            {"PRIVATEERR_GLUETUN_URL": "http://host:99999"},
            {"PRIVATEERR_GLUETUN_HEALTH_URL": "http://host:9999/path"},
            {"PRIVATEERR_RECOVERY_INTERVAL_SECONDS": "-1"},
            {"PRIVATEERR_METADATA_PATH": "/elsewhere/privateerr.env"},
        ):
            with self.subTest(override=override), self.assertRaises(ConfigurationError):
                Config.from_environment(valid | override)

        self.assertNotIn("a" * 32, repr(Config.from_environment(valid)))


class RecoveryTests(unittest.TestCase):
    """Drive recovery decisions with controlled API state, files, and time."""

    def setUp(self):
        """Create distinct saved and candidate configurations with an initially unhealthy tunnel."""

        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = Config.from_environment(
            {
                "PIA_CONF_PATH": str(self.root / "saved/wg0.conf"),
                "PRIVATEERR_METADATA_PATH": str(self.root / "saved/privateerr.env"),
                "PRIVATEERR_HEALTHCHECK_MARKER": str(self.root / "ready"),
                "PRIVATEERR_AUTO_RECOVER": "true",
                "PRIVATEERR_GLUETUN_API_KEY": "a" * 32,
                "PRIVATEERR_RECOVERY_FAILURE_SECONDS": "2",
                "PRIVATEERR_RECOVERY_COOLDOWN_SECONDS": "5",
                "AUTOCONNECT": "false",
                "PIA_PF": "true",
            }
        )

        # Separate the published pair from the replacement so premature writes are observable.
        self.original = fixture(self.root / "saved")
        self.candidate = fixture(self.root / "candidate", "198.51.100.11", "example-two")
        self.store = Store(self.config)
        self.client = Mock(spec=Client)
        self.provider: dict[str, object] = {**self.original["provider"], "name": "custom"}

        # Model API readback separately from disk so tests can simulate an uncertain update.
        self.active: Mapping[str, object] = {
            **copy.deepcopy(self.original),
            "type": "wireguard",
            "provider": self.provider,
        }
        self.api_status = "running"

        def response(route: str) -> Mapping[str, object]:
            """Return the current simulated status or connection settings for each API probe."""

            return {"status": self.api_status} if route.endswith("status") else self.active

        self.client.get.side_effect = response
        self.client.healthy.return_value = False
        self.client.catalog.return_value = catalog()
        self.generator = Mock()

        @contextmanager
        def generate(endpoint: Endpoint | None = None) -> Generator[Path]:
            """Expose the prepared candidate through the production generator context contract."""

            yield self.root / "candidate"

        self.generator.generate.side_effect = generate

        # Advance an injected monotonic clock explicitly; recovery timing never needs real sleeps.
        self.now = 0
        self.supervisor = Supervisor(
            self.config, self.store, self.client, self.generator, clock=lambda: self.now
        )

    def test_duplicate_mismatched_and_invalid_fields(self):
        """Reject ambiguous fields, unsafe values, and disagreement between connection files."""

        for filename, text in (
            ("privateerr.env", "PIA_WG_ENDPOINT_PORT=1337\n"),
            ("wg0.conf", "PrivateKey=invalid\n"),
        ):
            fixture(self.root / "candidate")

            with (self.root / "candidate" / filename).open("a") as output:
                output.write(text)

            with self.assertRaises(InvalidSettings):
                self.store.candidate_settings(self.root / "candidate")

        # Reject malformed addresses and shell syntax as data before any candidate can be applied.
        for endpoint in ("999.1.1.1", "$(touch unsafe)"):
            with self.assertRaises(InvalidSettings):
                fixture(self.root / "invalid", endpoint)

        fixture(self.root / "candidate")

        # Individually valid files must still agree on the selected endpoint port.
        metadata = self.root / "candidate/privateerr.env"
        metadata.write_text(metadata.read_text().replace("1337", "1338"))

        with self.assertRaises(InvalidSettings):
            self.store.candidate_settings(self.root / "candidate")

    def test_partial_publication_finishes_after_restart(self):
        """Complete an interrupted pair replacement from retained source files on startup."""

        original_replace = Path.replace

        def interrupted(path: Path, target: Path) -> Path:
            """Fail metadata replacement after allowing the first file replacement to proceed."""

            if target == self.config.metadata_path:
                raise OSError("interrupted")

            return original_replace(path, target)

        with patch.object(Path, "replace", interrupted), self.assertRaises(OSError):
            self.store.publish(self.root / "candidate")

        self.assertTrue((self.store.journal / "ready").exists())

        # A new store must finish publication from the retained complete source copies.
        Store(self.config).resume()
        self.assertEqual(self.store.saved_settings(), self.candidate)
        self.assertFalse(self.store.journal.exists())

    def test_incomplete_copies_are_discarded(self):
        """Discard unfinished staging copies without changing the valid published pair."""

        for directory in (self.store.journal, self.store.pending):
            directory.mkdir()
            (directory / "wg0.conf").write_text("partial")

        self.store.resume()
        self.assertEqual(self.supervisor.resolve_pending(), Pending.RESOLVED)
        self.assertFalse(self.store.pending.exists())
        self.assertEqual(self.store.saved_settings(), self.original)

    def test_uncertain_update_waits_for_matching_settings_and_health(self):
        """Retain an uncertain candidate until both API readback and health confirm success."""

        self.store.retain(self.root / "candidate", self.store.pending)

        # An unreachable API cannot establish whether the submitted update took effect.
        self.client.get.side_effect = APIUnavailable
        self.assertEqual(self.supervisor.resolve_pending(), Pending.UNAVAILABLE)
        self.assertTrue(self.store.pending.exists())
        self.client.get.side_effect = None

        # Matching readback alone is insufficient while the tunnel remains unhealthy.
        self.client.get.return_value = self.candidate
        self.assertEqual(self.supervisor.resolve_pending(), Pending.UNHEALTHY)
        self.assertEqual(self.store.saved_settings(), self.original)
        self.client.healthy.return_value = True

        # Publish only after both the active connection and tunnel health confirm the candidate.
        self.assertEqual(self.supervisor.resolve_pending(), Pending.RESOLVED)
        self.assertEqual(self.store.saved_settings(), self.candidate)
        self.assertFalse(self.store.pending.exists())

    def test_rejected_candidate_keeps_saved_pair(self):
        """Discard an unapplied candidate when API readback still identifies the saved connection."""

        self.store.retain(self.root / "candidate", self.store.pending)
        self.assertEqual(self.supervisor.resolve_pending(), Pending.RESOLVED)
        self.assertFalse(self.store.pending.exists())
        self.assertEqual(self.store.saved_settings(), self.original)

    def test_only_sustained_outages_recover_with_exponential_backoff(self):
        """Distinguish a continuing outage from healthy, stopped, or unreachable control states."""

        for scenario in ("healthy", "transient", "stopped", "unavailable", "sustained", "cycling"):
            with self.subTest(scenario=scenario):
                self.supervisor = Supervisor(
                    self.config, self.store, self.client, self.generator, clock=lambda: self.now
                )
                attempts: list[int] = []
                self.supervisor.recover = lambda attempts=attempts: attempts.append(self.now)

                # Feed the same twenty-second timeline with stable, interrupted, and unavailable health signals.
                for self.now in range(20):
                    self.api_status = (
                        "stopped"
                        if scenario == "stopped" or (scenario == "cycling" and self.now % 3 == 0)
                        else "running"
                    )
                    self.client.healthy.return_value = scenario == "healthy" or (
                        scenario == "transient" and self.now >= 1
                    )

                    if scenario == "unavailable":
                        self.client.get.side_effect = APIUnavailable
                    else:
                        self.client.get.return_value = {"status": self.api_status}
                        self.client.get.side_effect = None

                    self.supervisor.step()

                if scenario == "sustained":
                    # The failure threshold is two seconds; successive retry delays are five and ten seconds.
                    self.assertEqual(attempts, [2, 7, 17])
                elif scenario == "cycling":
                    self.assertTrue(attempts)
                else:
                    self.assertEqual(attempts, [])

    def test_retry_delay_caps_and_health_resets_failure_state(self):
        """Bound repeated retry delays and reset outage tracking once the tunnel is healthy."""

        self.supervisor.recover = Mock(side_effect=GenerationFailed)
        self.supervisor.delay = 3500
        self.supervisor.step()
        self.now = 2
        self.supervisor.step()

        # Repeated failures cap the delay at one hour rather than increasing it without limit.
        self.assertEqual(self.supervisor.delay, 3600)
        self.client.healthy.return_value = True
        self.supervisor.step()

        # A healthy probe clears the outage and restores the configured initial retry delay.
        self.assertIsNone(self.supervisor.failed_since)
        self.assertEqual(self.supervisor.delay, 5)

    def test_region_and_forwarding_selection(self):
        """Honor pinning and forwarding restrictions while avoiding previously failed endpoints."""

        failed = {"198.51.100.10"}

        def choose(pinned: bool = True, forwarding: bool = True) -> str:
            """Select from the fixture catalog using the current failed-endpoint set."""

            return select_endpoint(
                catalog(), "ca", "198.51.100.10", failed, pinned=pinned, forwarding=forwarding
            ).ip

        # Pinned selection stays in the chosen region even after every local endpoint has failed.
        self.assertEqual(choose(), "198.51.100.11")
        failed.add("198.51.100.11")
        self.assertEqual(choose(), "198.51.100.10")

        # Automatic selection may cross regions but must still honor port-forwarding eligibility.
        self.assertEqual(choose(pinned=False), "198.51.100.12")
        failed.add("198.51.100.12")
        self.assertEqual(choose(pinned=False), "198.51.100.10")
        self.assertEqual(choose(pinned=False, forwarding=False), "198.51.100.13")

        with self.assertRaises(GenerationFailed):
            select_endpoint(
                catalog(), "missing", "198.51.100.10", failed, pinned=True, forwarding=True
            )

    def test_dedicated_ip_delegates_selection_to_upstream(self):
        """Leave dedicated-IP endpoint selection with the upstream PIA setup scripts."""

        self.config.environment["DIP_TOKEN"] = "dedicated-example"
        self.supervisor.recover()
        self.generator.generate.assert_called_once_with(None)
        self.client.catalog.assert_not_called()

    def test_timed_out_apply_retains_candidate_across_supervisor_restart(self):
        """Resolve an uncertain API update after a new supervisor reads the retained candidate."""

        self.client.apply.side_effect = APIUnavailable
        self.supervisor.recover()
        self.assertTrue((self.store.pending / "ready").is_file())
        self.assertEqual(self.store.saved_settings(), self.original)

        # Simulate a successful server-side update whose HTTP acknowledgement was lost.
        self.active = self.candidate
        self.client.healthy.return_value = True
        restarted = Supervisor(self.config, Store(self.config), self.client, self.generator)
        self.assertEqual(restarted.resolve_pending(), Pending.RESOLVED)
        self.assertEqual(self.store.saved_settings(), self.candidate)

    def test_generation_rechecks_operator_stop_and_recovered_tunnel(self):
        """Skip applying a replacement when tunnel state changes during generation."""

        for status, healthy in (("stopped", False), ("starting", False), ("running", True)):
            with self.subTest(status=status, healthy=healthy):
                self.api_status = status
                self.client.healthy.return_value = healthy

                # Generation may finish after an operator stop or a tunnel recovery; recheck before applying.
                self.supervisor.recover()
                self.client.apply.assert_not_called()
                self.assertFalse(self.store.pending.exists())

    def test_malformed_provider_waits_for_retry_without_generating(self):
        """Reject unexpected API shapes without crashing monitoring or replacing saved files."""

        # Supply two status probes followed by malformed settings when recovery becomes due.
        self.client.get.side_effect = [
            {"status": "running"},
            {"status": "running"},
            {"type": "wireguard", "provider": []},
        ]
        self.supervisor.step()
        self.now = self.config.failure_seconds
        self.supervisor.step()

        self.generator.generate.assert_not_called()
        self.assertEqual(self.store.saved_settings(), self.original)
        self.assertGreater(self.supervisor.next_attempt, self.now)

    def test_wrong_provider_never_generates(self):
        """Reject incompatible Gluetun providers before making another PIA registration."""

        self.provider["name"] = "other"

        with self.assertRaises(GenerationFailed):
            self.supervisor.recover()

        self.generator.generate.assert_not_called()

    def test_startup_reuses_saved_pair_and_reports_readiness_before_probing(self):
        """Make valid saved files ready for Gluetun before recovery monitoring begins."""

        def stop_after_grace(seconds: float) -> None:
            """Assert startup ordering and stop the otherwise persistent monitoring loop."""

            self.assertTrue(self.config.marker.exists())
            self.assertEqual(seconds, self.config.failure_seconds)
            raise Shutdown

        # Stop at the grace-period boundary to prove readiness precedes the first API probe.
        self.supervisor.wait = stop_after_grace

        with self.assertRaises(Shutdown):
            self.supervisor.run()

        self.generator.generate.assert_not_called()
        self.client.get.assert_not_called()

    def test_one_shot_regenerates_even_with_valid_saved_pair(self):
        """Preserve legacy one-shot behavior even when a valid configuration already exists."""

        config = replace(self.config, recover=False, keepalive=False)
        Supervisor(config, self.store, self.client, self.generator).run()
        self.generator.generate.assert_called_once_with()
        self.assertEqual(self.store.saved_settings(), self.candidate)
