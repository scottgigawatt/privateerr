#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# checks.sh: Run repository checks using tools installed only in Buccaneerr.
#
# Usage: checks.sh all|python|helpers|workflows|lint|types|format|runtime|live|smoke|precommit|spellcheck
#

#
# Stop at the first failed check and reject missing variables.
#
set -eu

#
# Import production code from the checked-out source without writing bytecode there.
#
export PYTHONPATH="${PWD}/docker:${PWD}/test/runtime"
export PYTHONDONTWRITEBYTECODE=1
export RUFF_NO_CACHE=true

#
# Trust only the mounted checkout when its host owner differs from the container user.
#
git config --global --add safe.directory "${PWD}"

#
# Select an explicit suite so Make and workflows share the same container commands.
#
case "${1:-all}" in
    all)
        sh "$0" lint
        sh "$0" helpers
        sh "$0" workflows
        sh "$0" python
        ;;
    python)
        python3 -m unittest discover -s test/unit -v
        ;;
    helpers)
        test/helpers/test-make-helpers.sh
        test/helpers/test-dockerfile-base-images.sh
        test/helpers/test-compose-nuke.sh
        ;;
    workflows)
        test/helpers/test-workflow-helpers.sh
        test/policy/check-build-pin-policy.sh
        test/policy/check-image-tag-policy.sh
        test/helpers/test-policy-checks.sh
        actionlint
        ;;
    lint)
        ruff check docker test
        ruff format --check docker test
        pyright --warnings
        find docker config scripts test .github -path 'docker/pia-manual-connections' -prune -o \
            -type f -name '*.sh' -exec shellcheck {} +
        ;;
    types)
        pyright --warnings
        ;;
    python-lint)
        ruff check docker test
        ;;
    python-format)
        ruff format --check docker test
        ;;
    format)
        ruff check --fix docker test
        ruff format docker test
        ;;
    runtime)
        python3 test/runtime/test-recovery-api.py
        ;;
    live)
        python3 test/runtime/test-recovery-api.py --env-file "${PRIVATEERR_TEST_ENV_FILE:-.env}"
        ;;
    smoke)
        python3 test/runtime/test-recovery-api.py --env-file "${PRIVATEERR_TEST_ENV_FILE:-.env}" --smoke
        ;;
    precommit)
        pre-commit run --all-files
        ;;
    spellcheck)
        python3 test/policy/spellcheck.py
        ;;
    *)
        printf 'Unknown Buccaneerr check suite: %s\n' "$1" >&2
        exit 2
        ;;
esac
