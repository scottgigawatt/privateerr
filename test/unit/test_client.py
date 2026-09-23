#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test_client.py: Check authenticated HTTP, response validation, and whole-request deadlines.
#

"""Check authenticated HTTP, response validation, and whole-request deadlines."""

import json
import threading
import time
import unittest
from dataclasses import replace
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from privateerr.client import APIUnavailable, Client
from privateerr.config import Config


class ClientTests(unittest.TestCase):
    """Exercise the real HTTP client against controlled local server responses."""

    def setUp(self):
        """Start an isolated server that records authentication and simulates HTTP failures."""

        self.headers: list[str | None] = []
        self.bodies: list[object] = []

        # Let the nested HTTP handler record requests on this test instance.
        owner = self

        class Handler(BaseHTTPRequestHandler):
            """Return deterministic responses without requiring a running Gluetun instance."""

            def log_message(self, format: str, *args: object) -> None:
                """Suppress server access logs so expected failures do not clutter test output."""

                pass

            def do_GET(self):
                """Serve healthy, denied, redirected, truncated, and slow response scenarios."""

                owner.headers.append(self.headers.get("X-API-Key"))

                # A redirect must be rejected before credentials can reach another route.
                if self.path == "/redirect":
                    self.send_response(302)
                    self.send_header("Location", "/destination")
                    self.end_headers()
                    return

                # Advertise more bytes than arrive to exercise an incomplete response body.
                if self.path == "/truncated":
                    self.send_response(200)
                    self.send_header("Content-Length", "100")
                    self.end_headers()
                    self.wfile.write(b"{")
                    return

                # Keep the socket active to distinguish a total deadline from an idle timeout.
                if self.path == "/slow":
                    self.send_response(200)
                    self.end_headers()

                    try:
                        for _ in range(20):
                            self.wfile.write(b" ")
                            self.wfile.flush()
                            time.sleep(0.1)
                    except BrokenPipeError, ConnectionResetError:
                        # The client closes the connection when its request deadline expires.
                        pass

                    return

                self.send_response(401 if self.path == "/denied" else 200)
                self.end_headers()
                self.wfile.write(b"invalid" if self.path == "/invalid" else b'{"status":"running"}')

            def do_PUT(self):
                """Record the submitted JSON before acknowledging the update."""

                owner.headers.append(self.headers.get("X-API-Key"))
                owner.bodies.append(
                    json.loads(self.rfile.read(int(self.headers["Content-Length"])))
                )
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"running")

        # Use an ephemeral loopback port so tests never contact a deployed control API.
        self.server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        thread.start()

        # Cleanup runs in reverse order: stop serving before closing the listening socket.
        self.addCleanup(self.server.server_close)
        self.addCleanup(self.server.shutdown)
        url = f"http://127.0.0.1:{self.server.server_port}"
        self.client = Client(
            replace(
                Config.from_environment({}),
                api_url=url,
                health_url=url,
                api_key="test-only-key",  # pragma: allowlist secret
            )
        )

    def test_json_and_authentication_stay_on_control_requests(self):
        """Check JSON transport and keep API credentials off health requests."""

        self.assertEqual(self.client.get("/status"), {"status": "running"})
        self.client.apply({"test": "value"})
        self.assertTrue(self.client.healthy())

        # Control requests carry the key; the health probe must remain unauthenticated.
        self.assertEqual(self.headers, ["test-only-key", "test-only-key", None])
        self.assertEqual(self.bodies, [{"test": "value"}])

    def test_redirects_unauthorized_and_malformed_responses_fail(self):
        """Translate rejected or unusable responses into the supervisor retry signal."""

        for path in ("/redirect", "/denied", "/invalid", "/truncated"):
            with self.subTest(path=path), self.assertRaises(APIUnavailable):
                self.client.get(path)

        # Exactly four requests also proves that the redirect destination was never followed.
        self.assertEqual(len(self.headers), 4)

    def test_deadline_bounds_a_server_that_keeps_sending_bytes(self):
        """Bound the full request even while response bytes continue arriving."""

        started = time.monotonic()

        with self.assertRaises(APIUnavailable):
            self.client.request(self.client.config.api_url + "/slow", timeout=0.2)

        # The client must finish well before the server completes its two-second stream.
        self.assertLess(time.monotonic() - started, 1)
