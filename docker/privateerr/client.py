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
    """Keep retry semantics while carrying a safe failure category and HTTP status.

    Args:
        reason: Internal category; unrecognized values are never included in diagnostics.
        status: HTTP response status when the server rejected the request.
    """

    def __init__(self, reason: str = "request failed", status: int | None = None) -> None:
        super().__init__("API request failed")
        self.reason = reason
        self.status = status

    def diagnostic(self) -> str:
        """Report only approved categories, never URLs, headers, bodies, or raw exceptions."""

        allowed = {
            "request failed",
            "HTTP response rejected",
            "request timed out",
            "connection failed",
            "invalid response",
            "response too large",
        }
        reason = self.reason if self.reason in allowed else "request failed"
        suffix = f" (HTTP {self.status})" if self.status is not None else ""
        return reason + suffix


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
        """Send one bounded request and return its body without logging request contents.

        Args:
            url: Complete destination; redirects and inherited proxies are not followed.
            timeout: Maximum total seconds for connection setup and response reads.
            method: HTTP method used for this request.
            body: Optional object to encode as JSON for a settings update.
            key: Optional API credential; omit it for health and catalog requests.

        Returns:
            The response body, limited to four MiB.

        Raises:
            APIUnavailable: If transport, status, size, or deadline checks fail.
        """
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
                    raise APIUnavailable("HTTP response rejected", response.status)

                # Bound retained data even if a server sends an unexpectedly large response.
                payload = response.read(4 * 1024 * 1024 + 1)

                if len(payload) > 4 * 1024 * 1024:
                    raise APIUnavailable("response too large")

                return payload
        except HTTPError as error:
            # Release the error response without including its potentially sensitive body.
            error.close()
            raise APIUnavailable("HTTP response rejected", error.code) from None
        except TimeoutError:
            raise APIUnavailable("request timed out") from None
        except URLError as error:
            # urllib wraps connection-stage timeouts, unlike timeouts while reading a response.
            reason = (
                "request timed out"
                if isinstance(error.reason, TimeoutError)
                else "connection failed"
            )
            raise APIUnavailable(reason) from None
        except OSError:
            raise APIUnavailable("connection failed") from None
        except HTTPException, ValueError:
            raise APIUnavailable("invalid response") from None

    def get(self, route: str) -> dict[str, object]:
        """Read a control API object, rejecting responses the supervisor cannot interpret."""
        try:
            result = json.loads(
                self.request(self.config.api_url + route, timeout=30, key=self.config.api_key)
            )

            return object_fields(result)
        except (ValueError, UnicodeError) as error:
            raise APIUnavailable("invalid response") from error

    def apply(self, settings: Mapping[str, object]) -> None:
        """Submit connection fields; the supervisor separately verifies settings and health.

        Args:
            settings: Minimal connection update; unrelated Gluetun settings are omitted.

        Raises:
            APIUnavailable: If the response cannot confirm the request. The update may
                still have succeeded, so callers must reconcile it before retrying.
        """
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

    def catalog(self, *, timeout: float = 20) -> dict[str, object]:
        """Read PIA's advertised regions and WireGuard servers without API credentials.

        Args:
            timeout: Maximum total request seconds; generation can supply its
                remaining budget instead of starting another full request window.

        Returns:
            Catalog object with a regions list. Nested fields remain untrusted
                and must be validated by the endpoint selector or metadata generator.

        Raises:
            APIUnavailable: If retrieval fails or the first response line is not
                a JSON object containing a regions list.

        Note:
            Only the first line is parsed; trailing catalog signature data is not
            verified by this method. Transport uses the configured catalog URL.
        """

        # PIA serves JSON on the first line followed by signature data outside that JSON document.
        try:
            result = json.loads(
                self.request(self.config.catalog_url, timeout=timeout).splitlines()[0]
            )

            result = object_fields(result)

            if not isinstance(result.get("regions"), list):
                raise ValueError

            return result
        except (ValueError, IndexError, UnicodeError) as error:
            raise APIUnavailable("invalid response") from error
