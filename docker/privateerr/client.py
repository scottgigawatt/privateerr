#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# client.py: Make bounded HTTP requests without logging credentials or VPN settings.
#

"""Make bounded HTTP requests without logging credentials or VPN settings."""

import json
import signal
from contextlib import contextmanager
from http.client import HTTPException
from urllib.error import HTTPError, URLError
from urllib.request import HTTPRedirectHandler, ProxyHandler, Request, build_opener

from .config import Config


class APIUnavailable(Exception):
    """Represent transport, authorization, and malformed-response failures uniformly."""


class NoRedirects(HTTPRedirectHandler):
    """Keep authentication headers on the configured server."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


@contextmanager
def deadline(seconds: float):
    """Bound DNS, connection setup, and body reads in the single-threaded Linux supervisor."""

    def expired(signum, frame):
        raise TimeoutError("HTTP deadline exceeded")

    previous = signal.signal(signal.SIGALRM, expired)
    signal.setitimer(signal.ITIMER_REAL, seconds)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous)


class Client:
    """Use Gluetun's existing API and health listener; expose no additional server."""

    def __init__(self, config: Config):
        self.config = config
        self.opener = build_opener(ProxyHandler({}), NoRedirects())

    def request(self, url: str, *, timeout: int, method: str = "GET", body=None, key="") -> bytes:
        headers = {}
        if key:
            headers["X-API-Key"] = key
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body).encode()
        request = Request(url, data=data, headers=headers, method=method)
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
            error.close()
            raise APIUnavailable from None
        except (OSError, URLError, HTTPException, ValueError) as error:
            raise APIUnavailable from error

    def get(self, route: str) -> dict:
        try:
            result = json.loads(
                self.request(self.config.api_url + route, timeout=30, key=self.config.api_key)
            )
            if not isinstance(result, dict):
                raise ValueError
            return result
        except (ValueError, UnicodeError) as error:
            raise APIUnavailable from error

    def apply(self, settings: dict) -> None:
        self.request(
            self.config.api_url + "/v1/vpn/settings",
            timeout=30,
            method="PUT",
            body=settings,
            key=self.config.api_key,
        )

    def healthy(self) -> bool:
        try:
            self.request(self.config.health_url, timeout=10)
            return True
        except APIUnavailable:
            return False

    def catalog(self) -> dict:
        try:
            result = json.loads(self.request(self.config.catalog_url, timeout=20).splitlines()[0])
            if not isinstance(result, dict) or not isinstance(result.get("regions"), list):
                raise ValueError
            return result
        except (ValueError, IndexError, UnicodeError) as error:
            raise APIUnavailable from error
