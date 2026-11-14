#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test_compose.py: Verify published runtime and explicit local build/test Compose layers.
#

"""Validate real Compose interpolation without starting deployment containers."""

import json
import os
import re
import subprocess
import tempfile
import unittest
from pathlib import Path
from typing import cast

ROOT = Path(__file__).resolve().parents[2]
RUNTIME_SERVICES = {"privateerr", "gluetun", "qbittorrent"}
LAYERS = ((False, False), (True, False), (False, True), (True, True))
type JSONValue = str | int | float | bool | None | list[JSONValue] | dict[str, JSONValue]


def _json_value(value: object) -> JSONValue:
    """Validate decoded JSON before using the dynamic Compose model in assertions."""

    if value is None or isinstance(value, (str, int, float, bool)):
        return value

    if isinstance(value, list):
        return [_json_value(item) for item in cast(list[object], value)]

    if isinstance(value, dict):
        result: dict[str, JSONValue] = {}

        for key, item in cast(dict[object, object], value).items():
            if not isinstance(key, str):
                raise AssertionError("Compose returned a JSON object with a non-string key")

            result[key] = _json_value(item)

        return result

    raise AssertionError("Compose returned an unsupported JSON value")


def _mapping(value: JSONValue) -> dict[str, JSONValue]:
    """Require a JSON object at the model boundary being inspected."""

    if not isinstance(value, dict):
        raise AssertionError("Expected a Compose JSON object")

    return value


def _sequence(value: JSONValue) -> list[JSONValue]:
    """Require a JSON array at the model boundary being inspected."""

    if not isinstance(value, list):
        raise AssertionError("Expected a Compose JSON array")

    return value


class ComposeTests(unittest.TestCase):
    """Check each opt-in layer without exposing operator settings or contacting a daemon."""

    @staticmethod
    def model(
        *, overrides: str = "", build_overlay: bool = False, test_overlay: bool = False
    ) -> dict[str, JSONValue]:
        """Resolve only public example settings through the real Compose config command."""

        content = (ROOT / "example.env").read_text()

        # Edit assignments as operators do, so dependent variables resolve from their choices.
        for override in overrides.splitlines():
            name, _ = override.split("=", 1)
            pattern = rf"^{re.escape(name)}=.*$"

            if re.search(pattern, content, flags=re.MULTILINE) is None:
                raise AssertionError(f"Example setting is missing: {name}")

            content = re.sub(
                pattern, lambda _, replacement=override: replacement, content, flags=re.MULTILINE
            )

        with tempfile.TemporaryDirectory() as temporary:
            environment = Path(temporary) / "example.env"
            environment.write_text(content)
            command = [
                "docker",
                "compose",
                "--project-directory",
                str(ROOT),
                "--env-file",
                str(environment),
                "--file",
                str(ROOT / "docker-compose.yml"),
            ]

            if build_overlay:
                command.extend(["--file", str(ROOT / "docker-compose.build.yml")])

            if test_overlay:
                command.extend(["--file", str(ROOT / "docker-compose.test.yml")])

            # Exclude shell overrides and private .env contents from the public-model fixtures.
            subprocess.run(
                [*command, "config", "--quiet"],
                env={"PATH": os.environ["PATH"]},
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            )
            result = subprocess.run(
                [*command, "config", "--format", "json"],
                env={"PATH": os.environ["PATH"]},
                capture_output=True,
                text=True,
                check=True,
                timeout=30,
            )
            decoded: object = json.loads(result.stdout)
            return _mapping(_json_value(decoded))

    @staticmethod
    def services(model: dict[str, JSONValue]) -> dict[str, dict[str, JSONValue]]:
        """Require named service objects before checking their runtime settings."""

        return {name: _mapping(value) for name, value in _mapping(model["services"]).items()}

    def test_example_enables_complete_recovery_stack(self) -> None:
        """Keep the single-file published deployment hardened and free of build/test behavior."""

        model = self.model()
        services = self.services(model)
        self.assertEqual(set(services), RUNTIME_SERVICES)
        self.assertNotIn("buccaneerr", json.dumps(model))

        for service in services.values():
            self.assertNotIn("build", service)
            self.assertNotIn("profiles", service)
            self.assertNotIn("buccaneerr", _mapping(service.get("depends_on", {})))

        privateerr = services["privateerr"]
        self.assertEqual(privateerr["image"], "ghcr.io/scottgigawatt/privateerr:latest")
        self.assertFalse(privateerr.get("privileged", False))
        self.assertEqual(privateerr["cap_drop"], ["ALL"])
        self.assertIn("no-new-privileges:true", _sequence(privateerr["security_opt"]))
        self.assertEqual(
            privateerr["sysctls"],
            {
                "net.ipv6.conf.all.disable_ipv6": "1",
                "net.ipv6.conf.default.disable_ipv6": "1",
            },
        )
        self.assertEqual(_mapping(privateerr["environment"])["PRIVATEERR_AUTO_RECOVER"], "true")
        gluetun = services["gluetun"]
        self.assertEqual(_mapping(gluetun["environment"])["PRIVATEERR_AUTO_RECOVER"], "true")
        self.assertEqual(_mapping(gluetun["environment"])["QBITTORRENT_PORT_SYNC"], "true")
        self.assertEqual(_mapping(_sequence(gluetun["ports"])[0])["published"], "8080")
        self.assertEqual(
            gluetun["entrypoint"], ["/bin/sh", "/gluetun/scripts/gluetun-entrypoint-wrapper.sh"]
        )
        self.assertEqual(len(_sequence(gluetun["volumes"])), 2)
        self.assertEqual(
            _mapping(_mapping(gluetun["depends_on"])["privateerr"])["condition"], "service_healthy"
        )

    def test_layers_select_only_their_owned_build_and_validator(self) -> None:
        """Exercise all four real models and keep test selection explicit through file inclusion."""

        baseline = self.model()
        runtime = self.services(baseline)

        for build_overlay, test_overlay in LAYERS:
            with self.subTest(build=build_overlay, test=test_overlay):
                model = self.model(build_overlay=build_overlay, test_overlay=test_overlay)
                services = self.services(model)
                expected = RUNTIME_SERVICES | ({"buccaneerr"} if test_overlay else set[str]())
                self.assertEqual(set(services), expected)
                self.assertEqual(model["name"], baseline["name"])
                self.assertEqual(model["networks"], baseline["networks"])

                for name in RUNTIME_SERVICES:
                    service = dict(services[name])
                    self.assertNotIn("profiles", service)

                    if name == "privateerr" and build_overlay:
                        self.assertEqual(service.pop("image"), "privateerr:local")
                        self.assertEqual(service.pop("pull_policy"), "build")
                        build = _mapping(service.pop("build"))
                        self.assertEqual(build["context"], str(ROOT / "docker"))
                        self.assertEqual(build["dockerfile"], "Dockerfile")
                        self.assertEqual(
                            set(_mapping(build["args"])),
                            {
                                "ALPINE_TAG",
                                "PIA_BIN_HOME",
                                "PRIVATEERR_BIN_HOME",
                                "IMAGE_CREATED",
                                "IMAGE_REVISION",
                                "IMAGE_VERSION",
                            },
                        )
                        service["image"] = runtime[name]["image"]

                    # The overlay may select an image build; all runtime fields stay identical.
                    self.assertEqual(service, runtime[name])

                if test_overlay:
                    validator = services["buccaneerr"]
                    self.assertNotIn("profiles", validator)
                    self.assertEqual(validator["image"], "buccaneerr:local")
                    self.assertEqual(validator["pull_policy"], "build")
                    self.assertEqual(validator["network_mode"], "service:gluetun")
                    self.assertEqual(validator["cap_add"], ["NET_ADMIN"])
                    self.assertEqual(
                        _mapping(validator["environment"])["BUCCANEERR_TEST_RECOVERY"], "true"
                    )
                    self.assertIn("qbittorrent", _mapping(validator["depends_on"]))
                    build = _mapping(validator["build"])
                    self.assertEqual(build["context"], str(ROOT))
                    self.assertEqual(build["dockerfile"], "test/Dockerfile")
                    self.assertEqual(
                        set(_mapping(build["args"])),
                        {
                            "ALPINE_TAG",
                            "BUCCANEERR_BIN_HOME",
                            "IMAGE_CREATED",
                            "IMAGE_REVISION",
                            "IMAGE_VERSION",
                        },
                    )

    def test_environment_owns_defaults_and_operator_overrides(self) -> None:
        """Keep project identity, ports, hooks, and probes consistent across every layer choice."""

        for filename in (
            "docker-compose.yml",
            "docker-compose.build.yml",
            "docker-compose.test.yml",
        ):
            self.assertIsNone(re.search(r"\$\{[^}]+:-", (ROOT / filename).read_text()))

        for build_overlay, test_overlay in LAYERS:
            with self.subTest(build=build_overlay, test=test_overlay):
                model = self.model(
                    overrides="COMPOSE_PROJECT_NAME=example\n"
                    "PRIVATEERR_AUTO_RECOVER=false\n"
                    "QBITTORRENT_WEBUI_PORT=8090\n"
                    "GLUETUN_ENTRYPOINT_WRAPPER=/gluetun/scripts/custom-wrapper.sh\n",
                    build_overlay=build_overlay,
                    test_overlay=test_overlay,
                )
                self.assertEqual(model["name"], "example")
                services = self.services(model)

                for service in services.values():
                    self.assertTrue(str(service["container_name"]).startswith("example-"))

                self.assertEqual(
                    _mapping(services["privateerr"]["environment"])["PRIVATEERR_AUTO_RECOVER"],
                    "false",
                )
                gluetun = services["gluetun"]
                self.assertEqual(
                    gluetun["entrypoint"], ["/bin/sh", "/gluetun/scripts/custom-wrapper.sh"]
                )
                port = _mapping(_sequence(gluetun["ports"])[0])
                self.assertEqual(port["published"], "8090")
                self.assertEqual(port["target"], 8090)
                application = services["qbittorrent"]
                self.assertEqual(_mapping(application["environment"])["WEBUI_PORT"], "8090")

                for service_name in ("gluetun", "buccaneerr") if test_overlay else ("gluetun",):
                    self.assertEqual(
                        _mapping(services[service_name]["environment"])["QBITTORRENT_API_URL"],
                        "http://127.0.0.1:8090",
                    )

                self.assertIn(
                    "http://127.0.0.1:8090/",
                    _sequence(_mapping(application["healthcheck"])["test"]),
                )
                environment = _mapping(gluetun["environment"])
                self.assertEqual(
                    environment["VPN_PORT_FORWARDING_UP_COMMAND"],
                    '/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh up {{PORT}} {{VPN_INTERFACE}}"',
                )
                self.assertEqual(
                    environment["VPN_PORT_FORWARDING_DOWN_COMMAND"],
                    '/bin/sh -c "/gluetun/scripts/qbittorrent-port-forwarding.sh down"',
                )

    def test_selected_application_uses_shared_network_and_persistent_storage(self) -> None:
        """Keep application traffic in Gluetun with persistent state and a healthy dependency."""

        application = self.services(self.model())["qbittorrent"]
        self.assertEqual(application["network_mode"], "service:gluetun")
        self.assertNotIn("ports", application)
        dependency = _mapping(_mapping(application["depends_on"])["gluetun"])
        self.assertTrue(dependency["restart"])
        self.assertEqual(dependency["condition"], "service_healthy")
        self.assertEqual(len(_sequence(application["volumes"])), 2)
