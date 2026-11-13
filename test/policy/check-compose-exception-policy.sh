#!/bin/sh

#
# Copyright 2025-2026 Scott Gigawatt
#
# SPDX-License-Identifier: Apache-2.0
#
# check-compose-exception-policy.sh: Keep the temporary Compose exception bound
#                                   to its reviewed artifact and exact scope.
#
# Usage: test/policy/check-compose-exception-policy.sh [repository-root]
#

#
# Resolve the checkout or an isolated fixture without depending on its name.
#
set -eu
repository_root=${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)}
cd "${repository_root}"
reviewed_tag='v5.7.1@sha256:6a6704a7ccbc45eb4cc7e5b71dba685e9bc23705c580430f15034b2b5e46ec2b'

#
# Require a new reachability review when the donor changes. Module versions
# alone cannot establish that a vulnerable package is absent from a new binary.
#
if ! grep -F -x 'FROM docker/compose-bin:v5.7.1@sha256:6a6704a7ccbc45eb4cc7e5b71dba685e9bc23705c580430f15034b2b5e46ec2b AS compose' 'test/Dockerfile' >/dev/null; then
    echo 'Compose donor changed; remove the exception or review its binary evidence again.' >&2
    exit 1
fi

#
# Accept one canonical YAML entry only, with no additional paths, identifiers,
# aliases, categories, or expiry extension. The folded statement stays readable.
#
awk -v expected_path='usr/local/lib/docker/cli-plugins/docker-compose' -v reviewed_tag="${reviewed_tag}" '
    /^[[:space:]]*#/ || /^[[:space:]]*$/ { next }
    state == 0 && $0 == "vulnerabilities:" { state++; next }
    state == 1 && $0 == "  - id: CVE-2026-78661" { state++; next }
    state == 2 && $0 == "    paths:" { state++; next }
    state == 3 && $0 == "      - " expected_path { state++; next }
    state == 4 && $0 == "    expired_at: 2026-11-22" { state++; next }
    state == 5 && $0 == "    statement: >-" { state++; next }
    state == 6 && /^      [^[:space:]]/ { statement = statement substr($0, 7) " "; next }
    { invalid = 1 }
    END {
        if (invalid || state != 6 || !index(statement, "Owner: scottgigawatt.") || !index(statement, reviewed_tag)) {
            print "Compose exception scope changed; retain its single reviewed ID, path, owner, pin, and expiry." > "/dev/stderr"
            exit 1
        }
    }
' .trivyignore.yaml
printf '%s\n' 'Compose exception scope and reviewed donor match.'
