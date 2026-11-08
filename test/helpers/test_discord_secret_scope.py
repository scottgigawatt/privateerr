#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test_discord_secret_scope.py: Keep notification credentials explicit and
#                              isolated across optional Discord destinations.
#

"""Reject broad secret access and cross-server fallback in notification jobs."""

import re
import unittest
from collections.abc import Mapping
from pathlib import Path

REPOSITORY_ROOT = Path(__file__).resolve().parents[2]

# This deliberately limited grammar accepts only two named, guarded webhooks.
# Captured routes and names are tested independently with synthetic values.
GUARDED_WEBHOOKS = re.compile(
    r"matrix\.profile\s*==\s*'([^']+)'\s*&&\s*secrets\.([A-Z_]+)\s*\|\|\s*"
    r"matrix\.profile\s*==\s*'([^']+)'\s*&&\s*secrets\.([A-Z_]+)\s*\|\|\s*''"
)
EXPECTED_KEYS = {"DISCORD_WEBHOOK_URL", "DISCORD_HADES_HOOK_URL"}


def select_synthetic_webhook(expression: str, profile: str, values: Mapping[str, str]) -> str:
    """Evaluate the restricted route expression without executing workflow text."""
    match = GUARDED_WEBHOOKS.fullmatch(expression.strip())

    if match is None:
        raise ValueError("Notification secrets must use two literal, guarded references.")

    routes = ((match[1], match[2]), (match[3], match[4]))

    if {key for _, key in routes} != EXPECTED_KEYS:
        raise ValueError("Notification jobs may reference only the two expected webhook names.")

    for route, key in routes:
        if profile == route and values.get(key, ""):
            return values[key]

    return ""


def notification_bindings() -> dict[str, str]:
    """Read the actual inline bindings from both image notification jobs."""
    workflow = REPOSITORY_ROOT / ".github/workflows/build-and-push.yml"
    job = ""
    bindings: dict[str, str] = {}

    for line in workflow.read_text().splitlines():
        job_match = re.fullmatch(r"  ([a-z-]+):", line)

        if job_match:
            job = job_match[1]

        if job in {"notify-start", "notify-result"} and "DISCORD_WEBHOOK_URL:" in line:
            binding = re.fullmatch(r"\s+DISCORD_WEBHOOK_URL:\s*\$\{\{\s*(.*?)\s*}}", line)

            if binding is None or job in bindings:
                raise ValueError("Each notification job needs one explicit webhook binding.")

            bindings[job] = binding[1]

    return bindings


class NotificationSecretScopeTests(unittest.TestCase):
    """Check real workflow bindings and rejected credential-routing regressions."""

    def test_routes_with_missing_optional_webhooks(self) -> None:
        """Empty or invalid routes must never select the other server's webhook."""
        bindings = notification_bindings()
        self.assertEqual(set(bindings), {"notify-start", "notify-result"})

        # Cover both, either, and neither optional destination being configured.
        for primary, secondary in (("asteres", "hades"), ("", "hades"), ("asteres", ""), ("", "")):
            values = {"DISCORD_WEBHOOK_URL": primary, "DISCORD_HADES_HOOK_URL": secondary}

            for profile in ("image-primary", "image-secondary", "invalid-route"):
                expected = {"image-primary": primary, "image-secondary": secondary}.get(profile, "")

                for job, expression in bindings.items():
                    with self.subTest(job=job, profile=profile, values=values):
                        self.assertEqual(
                            select_synthetic_webhook(expression, profile, values), expected
                        )

    def test_reject_broad_or_unguarded_secret_access(self) -> None:
        """The original dynamic lookup and unguarded fallback must be rejected."""
        unsafe = (
            "secrets[matrix.webhook]",
            "toJSON(secrets)",
            "secrets.*",
            "secrets",
            "matrix.profile == 'image-primary' && secrets.DISCORD_WEBHOOK_URL || secrets.DISCORD_HADES_HOOK_URL",
            "matrix.profile == 'image-primary' && secrets.UNRELATED_TOKEN || matrix.profile == 'image-secondary' && secrets.DISCORD_HADES_HOOK_URL || ''",
        )

        for expression in unsafe:
            with self.subTest(expression=expression), self.assertRaises(ValueError):
                select_synthetic_webhook(expression, "image-primary", {})


if __name__ == "__main__":
    unittest.main()
