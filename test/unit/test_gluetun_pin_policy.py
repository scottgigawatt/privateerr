#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# test_gluetun_pin_policy.py: Reject deployment changes that leave Gluetun API tests behind.
#

"""Exercise the real pin checker against isolated, secret-free repository fixtures."""

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PIN = "v3.41.3@sha256:" + "a" * 64


class GluetunPinPolicyTests(unittest.TestCase):
    """Keep image-policy fixtures independent of the checkout and operator environment."""

    def setUp(self) -> None:
        """Copy only the checker and two public defaults into a disposable repository."""

        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        (self.root / "test/policy").mkdir(parents=True)
        (self.root / "test/runtime").mkdir()
        self.checker = self.root / "test/policy/check_gluetun_pin.py"
        shutil.copyfile(ROOT / "test/policy/check_gluetun_pin.py", self.checker)

    def run_policy(
        self, deployment: str = PIN, runtime: str = PIN
    ) -> subprocess.CompletedProcess[str]:
        """Run literal parsing with an unrelated shell override that must be ignored."""

        (self.root / "example.env").write_text('GLUETUN_TAG="${GLUETUN_TAG:-' + deployment + '}"\n')
        (self.root / "test/runtime/test-recovery-api.py").write_text(
            'import os\nGLUETUN = os.environ.get("GLUETUN_TEST_IMAGE", "qmcgaw/gluetun:'
            + runtime
            + '")\n'
        )
        return subprocess.run(
            [sys.executable, str(self.checker)],
            env={**os.environ, "GLUETUN_TAG": "latest", "GLUETUN_TEST_IMAGE": "unrelated"},
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )

    def test_matching_defaults_ignore_shell_overrides(self) -> None:
        """Policy checks the reviewed defaults even when operators select another image."""

        self.assertEqual(self.run_policy().returncode, 0)

    def test_mismatched_versions_and_digests_fail(self) -> None:
        """A deployment bump cannot leave the real API suite testing an older image."""

        for runtime in (PIN.replace("3.41.3", "3.41.4"), PIN.replace("a" * 64, "b" * 64)):
            with self.subTest(runtime=runtime):
                result = self.run_policy(runtime=runtime)
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("must match", result.stderr)

    def test_mutable_or_malformed_defaults_fail(self) -> None:
        """Require release identity and a complete digest on both repository surfaces."""

        for selector in ("latest", "v3.41.3", "v3.41.3@sha256:abc", "latest@sha256:" + "a" * 64):
            for deployment, runtime in ((selector, PIN), (PIN, selector)):
                with self.subTest(selector=selector, deployment=deployment):
                    self.assertNotEqual(self.run_policy(deployment, runtime).returncode, 0)

    def test_missing_or_computed_test_default_fails(self) -> None:
        """Never execute test source to discover a dynamically selected image."""

        self.run_policy()
        runtime = self.root / "test/runtime/test-recovery-api.py"

        for source in (
            runtime.read_text() + "GLUETUN = build_image()",
            "GLUETUN = build_image()",
            "GLUETUN = os.environ.get('GLUETUN_TEST_IMAGE')",
        ):
            runtime.write_text(source)
            result = subprocess.run(
                [sys.executable, str(self.checker)], capture_output=True, check=False, timeout=10
            )
            self.assertNotEqual(result.returncode, 0)

    def test_missing_or_duplicate_deployment_default_fails(self) -> None:
        """Reject ambiguous defaults rather than accepting the first matching assignment."""

        self.run_policy()
        environment = self.root / "example.env"
        assignment = environment.read_text()

        for source in ("", assignment + assignment, assignment + "GLUETUN_TAG=latest\n"):
            environment.write_text(source)
            result = subprocess.run(
                [sys.executable, str(self.checker)], capture_output=True, check=False, timeout=10
            )
            self.assertNotEqual(result.returncode, 0)
