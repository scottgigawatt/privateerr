#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# client.py: Make bounded HTTP requests without logging credentials or VPN settings.
#

"""Call Gluetun and fetch PIA endpoints without exposing connection secrets.

Control requests carry the shared API key; health probes and catalog downloads
do not. Every request has a total deadline and a response-size limit so a slow
or malformed server cannot hold the recovery loop indefinitely.
"""

import json
import signal
from collections.abc import Generator, Mapping
from contextlib import contextmanager
from email.message import Message
from http.client import HTTPException
from types import FrameType
from typing import IO
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener

from .config import Config
from .data import object_fields


class APIUnavailable(Exception):
    """Represent transport, authorization, and malformed-response failures uniformly."""


class NoRedirects(HTTPRedirectHandler):
    """Keep authentication headers on the configured server."""

    def redirect_request(
        self, req: Request, fp: IO[bytes], code: int, msg: str, headers: Message, newurl: str
    ) -> None:
        """Reject redirects rather than forwarding a control API key to another destination."""
        return None


@contextmanager
def deadline(seconds: float) -> Generator[None]:
    """Bound DNS, connection setup, and body reads in the single-threaded Linux supervisor."""

    def expired(signum: int, frame: FrameType | None) -> None:
        """Interrupt blocking network operations when the total request time expires."""
        raise TimeoutError("HTTP deadline exceeded")

    # A socket timeout alone does not bound DNS lookup or a body arriving a few bytes at a time.
    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, seconds)

    try:
        yield
    finally:
        # Cancel this request's alarm before later work can receive it.
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


class Client:
    """Use Gluetun's existing API and health listener; expose no additional server."""

    def __init__(self, config: Config):
        self.config = config

        # Contact configured servers directly, ignoring inherited proxy environment variables.
        self.opener = build_opener(ProxyHandler({}), NoRedirects())

    def request(
        self,
        url: str,
        *,
        timeout: float,
        method: str = "GET",
        body: Mapping[str, object] | None = None,
        key: str = "",
    ) -> bytes:
        """Send one bounded request and return its body without logging request contents."""
        headers: dict[str, str] = {}

        # Callers must explicitly supply authentication; health and catalog calls omit it.
        if key:
            headers["X-API-Key"] = key

        data = None

        # Serialize settings only for calls that submit a body.
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()

        request = Request(url, data=data, headers=headers, method=method)

        # The socket timeout bounds individual waits; the outer deadline bounds the whole call.
        try:
            with deadline(timeout), self.opener.open(request, timeout=5) as response:
                if response.status != 200:
                    raise APIUnavailable

                # Bound retained data even if a server sends an unexpectedly large response.
                payload = response.read(4 * 1024 * 1024 + 1)

                if len(payload) > 4 * 1024 * 1024:
                    raise APIUnavailable

                return payload
        except HTTPError as error:
            # Release the error response without including its potentially sensitive body.
            error.close()
            raise APIUnavailable from None
        except (OSError, URLError, HTTPException, ValueError) as error:
            raise APIUnavailable from error

    def get(self, route: str) -> dict[str, object]:
        """Read a control API object, rejecting responses the supervisor cannot interpret."""
        try:
            result = json.loads(
                self.request(self.config.api_url + route, timeout=30, key=self.config.api_key)
            )

            return object_fields(result)
        except (ValueError, UnicodeError) as error:
            raise APIUnavailable from error

    def apply(self, settings: Mapping[str, object]) -> None:
        """Submit connection fields; the supervisor separately verifies settings and health."""
        self.request(
            self.config.api_url + "/v1/vpn/settings",
            timeout=30,
            method="PUT",
            body=settings,
            key=self.config.api_key,
        )

    def healthy(self) -> bool:
        """Probe the separate health listener without sending the control API key."""
        try:
            self.request(self.config.health_url, timeout=10)
            return True
        except APIUnavailable:
            return False

    def catalog(self) -> dict[str, object]:
        """Read PIA's advertised regions and WireGuard servers for endpoint selection."""

        # PIA serves JSON on the first line followed by signature data outside that JSON document.
        try:
            result = json.loads(self.request(self.config.catalog_url, timeout=20).splitlines()[0])

            result = object_fields(result)

            if not isinstance(result.get("regions"), list):
                raise ValueError

            return result
        except (ValueError, IndexError, UnicodeError) as error:
            raise APIUnavailable from error
