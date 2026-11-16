#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# check_gluetun_pin.py: Require deployment and real API tests to select the same Gluetun image.
#

"""Check repository defaults without evaluating environment files or operator overrides."""

import ast
import re
import sys
from pathlib import Path

PIN = re.compile(r"v[0-9]+\.[0-9]+\.[0-9]+@sha256:[a-f0-9]{64}")


def deployment_pin(root: Path) -> str:
    """Read exactly one literal Gluetun default without sourcing shell expressions."""

    source = (root / "example.env").read_text()
    matches = re.findall(
        r'^GLUETUN_TAG="\$\{GLUETUN_TAG:-([^}]+)\}"$',
        source,
        flags=re.MULTILINE,
    )

    assignments = re.findall(r"^GLUETUN_TAG=", source, re.MULTILINE)

    if len(matches) != 1 or len(assignments) != 1:
        raise ValueError("Declare exactly one GLUETUN_TAG default in example.env.")

    return matches[0]


def test_pin(root: Path) -> str:
    """Inspect the API suite's literal image fallback without importing or running it."""

    tree = ast.parse((root / "test/runtime/test-recovery-api.py").read_text())
    assignments = [
        node
        for node in tree.body
        if isinstance(node, ast.Assign)
        and any(isinstance(target, ast.Name) and target.id == "GLUETUN" for target in node.targets)
    ]

    if len(assignments) != 1:
        raise ValueError("Declare exactly one literal Gluetun API test default.")

    call = assignments[0].value

    if (
        isinstance(call, ast.Call)
        and isinstance(call.func, ast.Attribute)
        and ast.unparse(call.func) == "os.environ.get"
        and len(call.args) == 2
        and isinstance(call.args[0], ast.Constant)
        and call.args[0].value == "GLUETUN_TEST_IMAGE"
        and isinstance(call.args[1], ast.Constant)
        and isinstance(call.args[1].value, str)
        and call.args[1].value.startswith("qmcgaw/gluetun:")
    ):
        return call.args[1].value.removeprefix("qmcgaw/gluetun:")

    raise ValueError("Declare exactly one literal Gluetun API test default.")


def check(root: Path) -> None:
    """Reject mutable, malformed, or mismatched checked-in defaults."""

    deployment, runtime = deployment_pin(root), test_pin(root)

    if not PIN.fullmatch(deployment) or not PIN.fullmatch(runtime):
        raise ValueError("Gluetun defaults require an exact release and full SHA-256 digest.")

    if deployment != runtime:
        raise ValueError("Deployment and API test Gluetun defaults must match.")


if __name__ == "__main__":
    try:
        check(Path(__file__).resolve().parents[2])
    except (OSError, SyntaxError, ValueError) as error:
        print(f"Gluetun pin policy: {error}", file=sys.stderr)
        raise SystemExit(1) from None

    print("Deployment and API test Gluetun pins match.")
