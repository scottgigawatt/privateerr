#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# generation.py: Invoke unmodified PIA scripts and prepare validated configuration candidates.
#

"""Prepare candidate VPN files through unmodified upstream PIA scripts.

The generator owns subprocess lifetimes, redacted invocation logs, IPv6 adaptation,
and metadata serialization. Candidates remain separate from the published pair;
callers decide when to publish or retain them through the configuration store.
Generation uses one monotonic deadline across upstream calls and catalog lookup.
"""

import ipaddress
import logging
import os
import re
import selectors
import signal
import subprocess
import tempfile
import time
from collections.abc import Generator as IteratorGenerator
from contextlib import contextmanager
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path

from .client import APIUnavailable, Client
from .config import Config
from .data import is_list, is_object
from .diagnostics import filesystem_operation
from .log import ANSI, redact
from .settings import InvalidSettings, Store, assignments

LOG = logging.getLogger("privateerr")

# Upstream writes this fixed token path independently of its installed script directory.
TOKEN_PATH = Path("/opt/piavpn-manual/token")

# Drop a whole oversized line so a credential cannot escape redaction in fragments.
MAX_LINE_BYTES = 65536


class GenerationFailed(Exception):
    """Report a Privateerr-authored failure without including upstream output or secrets."""


@dataclass(frozen=True)
class Endpoint:
    """Pair an advertised endpoint address with its matching PIA TLS server name.

    Attributes:
        ip: IPv4 address already selected and validated by the supervisor.
        name: Matching advertised server identity passed to upstream registration.
    """

    ip: str
    name: str


def reap_children() -> None:
    """Collect exited children, including descendants adopted as container PID 1.

    Live children are never waited on. Call only after the active direct child's
    status has been collected, so reaping cannot consume its subprocess status.
    """

    while True:
        try:
            pid, _ = os.waitpid(-1, os.WNOHANG)
        except ChildProcessError:
            return

        if pid == 0:
            return


def stop_group(process: subprocess.Popen[bytes]) -> None:
    """Terminate an upstream process group before staged secrets are removed.

    Args:
        process: Direct child started with its own session by the generator.

    Note:
        Allow the direct child up to five seconds after SIGTERM, then send
        SIGKILL to remaining group members even if that child has already exited.
        Collect the direct child's status before returning; adopted descendants
        are collected separately by `reap_children`.
    """

    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        pass

    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        pass
    finally:
        # The direct child can exit while another process still owns its stdout pipe.
        try:
            os.killpg(process.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass

        process.wait()


def prepare_ipv6(environment: dict[str, str], root: Path = Path("/proc/sys/net/ipv6/conf")) -> None:
    """Suppress redundant upstream IPv6 writes when Docker already disabled IPv6.

    Args:
        environment: Invocation environment, mutated in place only when a nonempty
            DISABLE_IPV6 request does not begin with n and both kernel flags are 1.
        root: Kernel IPv6 configuration directory; injectable for isolated tests.

    Note:
        Missing or unreadable flags preserve the request. This helper does not
        write kernel settings; otherwise upstream retains its existing behavior.
    """

    requested = environment.get("DISABLE_IPV6", "")

    if not requested or requested.lower().startswith("n"):
        return

    try:
        disabled = all(
            (root / interface / "disable_ipv6").read_text().strip() == "1"
            for interface in ("all", "default")
        )
    except OSError:
        return

    if disabled:
        LOG.info("IPv6 is already disabled in this container; PIA scripts will leave it unchanged.")
        environment["DISABLE_IPV6"] = "no"


def remaining(until: float) -> float:
    """Return the time budget left in a shared generation attempt.

    Args:
        until: Absolute deadline from the same monotonic clock used here.

    Returns:
        Positive seconds remaining for upstream work or catalog retrieval.

    Raises:
        GenerationFailed: If the shared deadline has been reached.
    """

    seconds = until - time.monotonic()

    if seconds <= 0:
        raise GenerationFailed("PIA generation exceeded its deadline.")

    return seconds


class Generator:
    """Generate validated candidates without publishing over saved configuration.

    Args:
        config: Validated paths, invocation environment, and generation timeout.
        store: Configuration store used to validate each complete candidate pair.

    Note:
        Use `generate` as a context manager. Its temporary files cease to exist
        when the context exits, so publish or retain a candidate inside the context.
    """

    def __init__(self, config: Config, store: Store):
        self.config = config
        self.store = store

    def run_script(self, name: str, environment: dict[str, str], until: float) -> str:
        """Stream one invocation with its source label, redaction, and a shared deadline.

        Args:
            name: Project-selected upstream script filename under PIA_BIN_HOME.
            environment: Complete child environment, including PIA_BIN_HOME and
                any credentials whose literal values should be redacted.
            until: Absolute monotonic deadline shared with the generation attempt.

        Returns:
            The last syntactically safe WG_HOSTNAME reported by this invocation,
                or an empty string if none was reported. This is a syntax check,
                not proof that the name belongs to the registered endpoint.

        Raises:
            GenerationFailed: If the script fails or the shared deadline expires.
            privateerr.diagnostics.FileOperationError: If the upstream process cannot be launched.
            OSError: If reading output, logging, or process cleanup fails.

        Note:
            Stdout and stderr share the PIA invocation label, including output
            from nested children. Redacted lines containing text use INFO; oversized
            lines are omitted entirely. Every exit path stops the process group
            and reaps exited children. Cleanup can extend beyond the work deadline.
        """

        logger = logging.getLogger("PIA/" + name)
        logger.info("Starting upstream PIA script.")
        hostname = ""

        def record(raw: bytes) -> None:
            """Extract a syntax-checked hostname and emit the redacted line only if it contains text."""

            nonlocal hostname
            line = ANSI.sub("", raw.decode("utf-8", errors="replace"))
            matches = re.findall(r"\bWG_HOSTNAME=([A-Za-z0-9][A-Za-z0-9.-]{0,252})(?=\s|$)", line)

            if matches:
                hostname = matches[-1]

            message = redact(line, environment)

            if message:
                logger.info("%s", message)

        with filesystem_operation("launch PIA script", Path(environment["PIA_BIN_HOME"]) / name):
            process = subprocess.Popen(
                ["bash", "./" + name],
                cwd=environment["PIA_BIN_HOME"],
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )

        try:
            assert process.stdout is not None

            # Read chunks rather than blocking on readline: silent or partial output must time out.
            with process.stdout, selectors.DefaultSelector() as selector:
                selector.register(process.stdout, selectors.EVENT_READ)
                buffer = b""
                dropping = False

                while True:
                    if not selector.select(min(0.25, remaining(until))):
                        continue

                    chunk = os.read(process.stdout.fileno(), 8192)

                    if not chunk:
                        if buffer and not dropping:
                            record(buffer)

                        break

                    # Progress output may end with carriage returns instead of newlines.
                    buffer += chunk.replace(b"\r", b"\n")

                    while b"\n" in buffer:
                        line, buffer = buffer.split(b"\n", 1)

                        if not dropping and len(line) <= MAX_LINE_BYTES:
                            record(line)
                        elif not dropping:
                            logger.warning("Omitted an oversized upstream log line.")

                        # Resume recording only after the discarded line's delimiter.
                        dropping = False

                    # Discard the whole oversized line rather than leaking a partially redacted token.
                    if len(buffer) > MAX_LINE_BYTES:
                        if not dropping:
                            logger.warning("Omitted an oversized upstream log line.")

                        buffer = b""
                        dropping = True

            try:
                code = process.wait(timeout=remaining(until))
            except subprocess.TimeoutExpired:
                raise GenerationFailed("PIA generation exceeded its deadline.") from None

            if code != 0:
                LOG.error("PIA script %s failed with exit status %s.", name, code)
                raise GenerationFailed("PIA generation failed; retained saved configuration.")
        finally:
            stop_group(process)
            reap_children()

        return hostname

    def write_metadata(self, stage: Path, hostname: str, until: float) -> None:
        """Write shell-safe metadata for the WireGuard file in one staging directory.

        Args:
            stage: Existing candidate directory containing wg0.conf; privateerr.env
                is written here without touching the published metadata file.
            hostname: Syntax-checked identity reported by this registration, used
                when no usable catalog identity matches the endpoint or hostname.
            until: Absolute monotonic deadline shared with upstream generation.

        Raises:
            InvalidSettings: If the endpoint, port, or final server name is invalid.
            GenerationFailed: If the generation deadline is reached.
            OSError: If candidate file access fails.

        Note:
            Catalog failure is optional: retain the registration identity and
            unknown region values, with PIA_PF as the forwarding fallback. Region
            labels are bounded and shell-escaped because Gluetun sources metadata;
            the Python store instead parses assignments as data. The caller must
            still validate the complete pair before publication.
        """

        try:
            endpoint, port = assignments(stage / "wg0.conf")["Endpoint"].split(":")
            ipaddress.IPv4Address(endpoint)

            if not port.isdigit() or not 1 <= int(port) <= 65535:
                raise ValueError
        except KeyError, ValueError:
            raise InvalidSettings("Generated WireGuard endpoint is invalid.") from None

        metadata = {
            "PIA_WG_SERVER_NAME": hostname,
            "PIA_WG_ENDPOINT_IP": endpoint,
            "PIA_WG_ENDPOINT_PORT": port,
            "PIA_REGION_ID": "unknown",
            "PIA_REGION_NAME": "unknown",
            "PIA_PORT_FORWARDING_SUPPORTED": (
                self.config.environment.get("PIA_PF", "unknown")
                if self.config.environment.get("PIA_PF") in ("true", "false")
                else "unknown"
            ),
            "PIA_GEOLOCATED_REGION": "unknown",
        }

        try:
            catalog = Client(self.config).catalog(timeout=min(20, remaining(until)))
        except APIUnavailable:
            LOG.warning(
                "PIA region details are unavailable; using the server name from registration."
            )
        else:
            enrich_metadata(metadata, catalog)

        if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", metadata["PIA_WG_SERVER_NAME"]):
            raise InvalidSettings("PIA registration did not identify its WireGuard server.")

        # Metadata is sourced by Gluetun's shell wrapper; quote expansion characters as literal data.
        name = metadata["PIA_REGION_NAME"]
        name = "".join(character for character in name if character >= " ")[:256]

        for character in ("\\", '"', "$", "`"):
            name = name.replace(character, "\\" + character)

        metadata["PIA_REGION_NAME"] = '"' + name + '"'
        timestamp = datetime.now(UTC).strftime("%Y-%m-%d %H:%M:%S UTC")
        header = (
            "#\n# Copyright 2025-2026 Scott Gigawatt\n#\n"
            "# Licensed under the Apache License, Version 2.0.\n#\n"
            f"# Generated by Privateerr on {timestamp}. Do not edit manually.\n#\n"
        )
        (stage / "privateerr.env").write_text(
            header + "".join(f"{key}={value}\n" for key, value in metadata.items())
        )
        remaining(until)

    @contextmanager
    def generate(self, endpoint: Endpoint | None = None) -> IteratorGenerator[Path]:
        """Yield a validated candidate pair and remove staging when the context exits.

        Args:
            endpoint: Selected recovery endpoint; omit it to let run_setup.sh
                perform normal upstream selection and registration.

        Yields:
            (Path): Private directory containing matching wg0.conf and privateerr.env.
                Its lifetime is limited to this context; callers own publication.

        Raises:
            GenerationFailed: If registration fails, its token is unusable, or
                the shared work deadline expires.
            InvalidSettings: If candidate files fail connection validation.
            privateerr.diagnostics.FileOperationError: If staging, process launch, or token access fails,
                or a filesystem error escapes the caller's context body.
            OSError: If other candidate access, output logging, or cleanup fails.

        Note:
            The invocation environment is copied before output paths are changed.
            Recovery reads upstream's fixed token-file handoff and removes that
            file after the read attempt, including decoding failures. This method
            never publishes files or applies settings to Gluetun.
        """

        until = time.monotonic() + self.config.generation_timeout

        with (
            filesystem_operation("generate replacement files", self.config.config_path.parent),
            tempfile.TemporaryDirectory(
                prefix=".privateerr-stage.", dir=self.config.config_path.parent
            ) as temporary,
        ):
            stage = Path(temporary)
            environment = self.config.environment.copy()
            environment.update(
                PIA_CONF_PATH=str(stage / "wg0.conf"),
                PRIVATEERR_METADATA_PATH=str(stage / "privateerr.env"),
            )
            prepare_ipv6(environment)

            if endpoint is None:
                hostname = self.run_script("run_setup.sh", environment, until)
            else:
                self.run_script("get_token.sh", environment, until)

                # Preserve the upstream token-file handoff without retaining it after registration.
                with filesystem_operation("read PIA registration token", TOKEN_PATH):
                    try:
                        lines = TOKEN_PATH.read_text().splitlines()
                    except UnicodeError:
                        raise GenerationFailed(
                            "PIA generation failed; retained saved configuration."
                        ) from None
                    finally:
                        TOKEN_PATH.unlink()

                if not lines or not lines[0] or lines[0] == "null":
                    raise GenerationFailed("PIA generation failed; retained saved configuration.")

                environment.update(
                    PIA_TOKEN=lines[0],
                    WG_SERVER_IP=endpoint.ip,
                    WG_HOSTNAME=endpoint.name,
                    DIP_TOKEN="",
                )
                self.run_script("connect_to_wireguard_with_token.sh", environment, until)
                hostname = endpoint.name

            self.write_metadata(stage, hostname, until)
            self.store.candidate_settings(stage)
            yield stage


def enrich_metadata(metadata: dict[str, str], catalog: dict[str, object]) -> None:
    """Enrich metadata in place from the first matching catalog WireGuard server.

    Args:
        metadata: Initialized metadata fields, including endpoint IP and the
            registration hostname used to match advertised servers.
        catalog: Decoded catalog object; nested collections and fields remain
            untrusted until checked here.

    Note:
        Match either endpoint IP or server name. Malformed structures and field
        types are ignored; unmatched or unusable fields retain their prior values.
        Server names and region IDs are syntax-checked here, while display-name
        bounding and shell quoting belong to `Generator.write_metadata`.
    """

    regions = catalog.get("regions")

    if not is_list(regions):
        return

    for region in regions:
        if not is_object(region):
            continue

        server_map = region.get("servers")

        if not is_object(server_map):
            continue

        servers = server_map.get("wg")

        if not is_list(servers):
            continue

        for server in servers:
            if not is_object(server):
                continue

            if (
                server.get("ip") != metadata["PIA_WG_ENDPOINT_IP"]
                and server.get("cn") != metadata["PIA_WG_SERVER_NAME"]
            ):
                continue

            hostname = server.get("cn")

            if isinstance(hostname, str) and re.fullmatch(
                r"[A-Za-z0-9][A-Za-z0-9.-]{0,252}", hostname
            ):
                metadata["PIA_WG_SERVER_NAME"] = hostname

            region_id = region.get("id")

            if isinstance(region_id, str) and re.fullmatch(r"[a-z][a-z0-9_-]{0,63}", region_id):
                metadata["PIA_REGION_ID"] = region_id

            name = region.get("name")

            if isinstance(name, str):
                metadata["PIA_REGION_NAME"] = name

            for field, key in (
                ("port_forward", "PIA_PORT_FORWARDING_SUPPORTED"),
                ("geo", "PIA_GEOLOCATED_REGION"),
            ):
                value = region.get(field)

                if isinstance(value, bool):
                    metadata[key] = str(value).lower()

            return
