#!/usr/bin/env bash

#
# Copyright 2025-2026 Scott Gigawatt
#
# Licensed under the Apache License, Version 2.0.
#
# test-generation.sh: Exercise generation and process lifecycle inside the Privateerr image.
#
# The script:
#   - Replaces upstream setup with an isolated example generator.
#   - Checks default region selection, readiness, and token redaction.
#   - Verifies that failures and timeouts preserve the last saved configuration.
#   - Confirms that keepalive exits promptly on a termination signal.
#
# Usage: docker run --rm --network none -v "$PWD:/src:ro" --entrypoint bash privateerr:recovery-review /src/test/runtime/test-generation.sh
#

#
# Fail on command errors, unset variables, and failed assertions in pipelines.
#
set -euo pipefail

#
# Keep test files in an isolated temporary directory.
#
fixture_root="$(mktemp -d)"
trap 'rm -rf "${fixture_root}"' EXIT
mkdir -p "${fixture_root}/pia" "${fixture_root}/wireguard"
export PIA_BIN_HOME="${fixture_root}/pia"
export PIA_CONF_PATH="${fixture_root}/wireguard/wg0.conf"
export PRIVATEERR_METADATA_PATH="${fixture_root}/wireguard/privateerr.env"
export PRIVATEERR_LOG_PATH="${fixture_root}/privateerr.log"
export PRIVATEERR_HEALTHCHECK_MARKER="${fixture_root}/ready"
export PRIVATEERR_KEEPALIVE=false
export PRIVATEERR_SERVERLIST_URL="file://${fixture_root}/catalog"
printf '{"regions":[]}\n' > "${fixture_root}/catalog"

#
# Supply an upstream stand-in that can succeed, fail, or exceed the generation deadline.
#
cat > "${PIA_BIN_HOME}/run_setup.sh" <<'SETUP'
#!/usr/bin/env bash

#
# Fail the example generator on errors or missing variables.
#
set -eu
[[ "${PREFERRED_REGION}" == ca ]]

#
# Simulate upstream failure after an incomplete file has been written.
#
if [[ "${TEST_GENERATION_FAIL:-false}" == true ]]; then
    printf 'broken' > "${PIA_CONF_PATH}"
    exit 1
fi

#
# Simulate an upstream command that exceeds the generation deadline.
#
if [[ "${TEST_GENERATION_HANG:-false}" == true ]]; then
    sleep 30
fi

key="$(printf '%032d' 1 | base64 | tr -d '\n')"
cat > "${PIA_CONF_PATH}" <<CONFIG
[Interface]
PrivateKey = ${key}
Address = 10.0.0.2
[Peer]
PublicKey = ${key}
Endpoint = 198.51.100.10:1337
CONFIG
printf 'WG_HOSTNAME=example-one\nPIA_TOKEN=test-token-redact\n'  # pragma: allowlist secret
SETUP
chmod +x "${PIA_BIN_HOME}/run_setup.sh"
bash /privateerr/privateerr-entrypoint.sh > "${fixture_root}/output"
[[ -s "${PIA_CONF_PATH}" && -s "${PRIVATEERR_METADATA_PATH}" && -f "${PRIVATEERR_HEALTHCHECK_MARKER}" ]]

#
# Fail if an upstream token reaches the retained log without redaction.
#
if grep -q test-token-redact "${PRIVATEERR_LOG_PATH}"; then
    echo 'FAIL: upstream token appeared in logs' >&2
    exit 1
fi

#
# Keep the successful pair for comparison after each simulated generation failure.
#
cp "${PIA_CONF_PATH}" "${fixture_root}/previous.conf"
cp "${PRIVATEERR_METADATA_PATH}" "${fixture_root}/previous.env"
export TEST_GENERATION_FAIL=true

#
# Require the entrypoint to fail when upstream generation cannot finish successfully.
#
if bash /privateerr/privateerr-entrypoint.sh >> "${fixture_root}/output" 2>&1; then
    echo 'FAIL: unsuccessful generation was accepted' >&2
    exit 1
fi

cmp "${PIA_CONF_PATH}" "${fixture_root}/previous.conf"
cmp "${PRIVATEERR_METADATA_PATH}" "${fixture_root}/previous.env"
[[ ! -e "${PRIVATEERR_HEALTHCHECK_MARKER}" ]]
unset TEST_GENERATION_FAIL

#
# Shorten the deadline to verify that a hung upstream process is terminated.
#
export TEST_GENERATION_HANG=true
export PRIVATEERR_GENERATION_TIMEOUT_SECONDS=1
started=${SECONDS}

#
# Require the entrypoint to fail when upstream generation cannot finish successfully.
#
if bash /privateerr/privateerr-entrypoint.sh >> "${fixture_root}/output" 2>&1; then
    echo 'FAIL: generation deadline was not enforced' >&2
    exit 1
fi

(( SECONDS - started < 10 ))
cmp "${PIA_CONF_PATH}" "${fixture_root}/previous.conf"
unset TEST_GENERATION_HANG

#
# Run keepalive in the background so shutdown behavior can be exercised.
#
export PRIVATEERR_KEEPALIVE=true
bash /privateerr/privateerr-entrypoint.sh >> "${fixture_root}/output" 2>&1 &
entrypoint_pid=$!

#
# Wait for generation readiness before sending the keepalive process a termination signal.
#
for _ in $(seq 1 50); do
    [[ ! -f "${PRIVATEERR_HEALTHCHECK_MARKER}" ]] || break
    sleep 0.1
done

[[ -f "${PRIVATEERR_HEALTHCHECK_MARKER}" ]]
kill -TERM "${entrypoint_pid}"
wait "${entrypoint_pid}"
printf 'Generation tests passed: default region, one-shot readiness, redaction, failure preservation, deadline and shutdown.\n'
