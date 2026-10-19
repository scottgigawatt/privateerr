# Container scan review

Reviewed on October 19, 2026 with Trivy 0.75.0 in comprehensive mode. The vulnerability database was updated at 13:35 UTC that day. Docker Scout 1.26.0 requires Docker Hub sign-in, so a fresh Scout comparison was blocked during this review; the older Scout counts below are not current scan results. The review covers immutable `edge` and `latest` digests on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Scanner databases change, so these findings apply to the recorded artifacts rather than every future image with the same tag.

## Current security status

The recorded published production images report 48 Trivy findings covering 24 identifiers on every platform, all from curl and libcurl 8.22.0. CVE-2026-92392 is HIGH severity; the other reports are MEDIUM or LOW. Official curl 8.23.0 fixes all 24 identifiers. Source builds now require that version from a narrowly tagged Alpine edge repository because stable Alpine 3.24 still supplies 8.22.0. This source fix reaches `edge` after a successful main publication; the recorded `latest` images remain v2.1.6 until a new release. Do not treat a source merge as a fix to an existing immutable image.

Buccaneerr uses the digest-pinned official Compose 5.6.0 image and Alpine's actionlint package. Docker CLI remains digest-pinned, and the repaired smol-toml 1.9.1 lockfile remains intact. The project-specific Go builds and dependency overrides have been removed to avoid maintaining a separate tool dependency graph and cross-compilation pipeline. These tools remain outside production Privateerr.

The official Compose and packaged actionlint binaries can still report Go vulnerabilities. The latest upstream releases remain Compose 5.6.0, actionlint 1.7.12, and pip 26.2.1 as of October 19; no successor release removes these recorded tool or bundled-installer findings. CI temporarily excludes CVE-2026-78667 and CVE-2026-97031 at their exact Compose and actionlint binary paths until October 23, 2026. Those advisories concern HTTP file-serving and TLS-server denial of service; the supported CLI validation and test-container management commands do not expose those server paths. Buccaneerr runtime tests can use networking inside the VPN namespace, so this rationale does not depend on every test being offline. It is an invocation-boundary assessment, not proof about every dependency or unsupported command.

The October 10 PR scan also reports [CVE-2026-78669](https://pkg.go.dev/vuln/GO-2026-6611) in official Compose's Go standard library and `golang.org/x/net`. This HTTP/2 SETTINGS-frame denial of service affects clients and servers; a CLI alone is not an exemption. The additional exception applies only to `usr/local/lib/docker/cli-plugins/docker-compose`, with the same October 23 expiry. Supported repository checks use trusted checked-in fixtures; `scripts/compose/test.sh` requires a local Unix Docker socket for runtime, live, smoke, and pre-commit suites, rejects remote Docker contexts, and does not forward `DOCKER_HOST` into Buccaneerr. Other suites run without networking. Network-enabled tests remain supported, and Compose used against untrusted HTTP/2 peers outside this wrapper boundary retains risk. This assessment does not prove every Compose command or dependency safe.

The existing fixed HIGH/CRITICAL gate remains active for all other findings and paths, including Docker CLI. Braces and the OpenPGP module warning are not excluded. Full artifact reviews remain unfiltered. Review or remove the exceptions before their expiry, and remove them once compatible official tools on all three supported platforms include the Go fixes. Any extension requires a separate review of the expiry, exact paths, and affected package identifiers; a blanket exclusion is not an acceptable substitute.

Both images retain the zlib 1.3.2-r1 and libexpat 2.9.0-r0 minimums. Stable Alpine now supplies fixed libexpat 2.9.0 on all three architectures, so the Expat edge exception has been removed. Only curl needs the production edge repository; Buccaneerr also retains its setuptools edge exception until stable supplies version 83 or later. No general edge upgrade is performed.

## Retained security controls

Buccaneerr uses digest-pinned Docker CLI and the official Compose 5.6.0 binary. Compose includes fixed containerd 2.4.1. BusyBox supplies AWK and core utilities; npm is installed only during the build and removed in the same layer. Pre-commit runs Markdownlint through the same test-image helper as other checks.

Pre-commit 4.6.2 and virtualenv 21.14.6 install into `/opt/precommit` from the complete exact, SHA-256-verified `test/requirements-tools.txt` lockfile. Bootstrap pip is removed after installation. Virtualenv retains the exact upstream pip 26.2.1 and setuptools 84.0.0 seed wheels for Python 3.14 with their SHA-256 verification; unused Python 3.9 seed archives are removed. No production Python dependencies, customized pip distribution, or rewritten upstream package inventory are introduced.

## Published artifact findings

The recorded Buccaneerr images report 82 comprehensive Trivy findings covering 40 identifiers on every platform: the 48 curl/libcurl findings above plus 34 findings covering 16 identifiers in the official Go tools and braces. Comprehensive mode includes upstream Go-library analysis for Alpine-owned actionlint; the default precise mode can omit those Go findings while still identifying the installed APK. These are unfiltered all-severity results, distinct from CI's narrower fixed HIGH/CRITICAL gate. The October 11 Scout review reported 36 identifiers in Buccaneerr, including upstream installer metadata; that historical count has not been refreshed because sign-in is required.

The following package-level reports remain visible and require context.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) still has no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. These Linux tools use separately pinned Docker CLI and Compose 5.6.0 releases newer than the patched versions. Scout still reports the Docker CLI module.

## Bundled installer findings

Virtualenv needs its integrity-checked pip seed wheel to create fresh Python hook environments. The current published pip release, 26.2.1, still vendors the dependencies below. Installing their standalone fixed releases does not replace code inside that wheel. The [upstream vendoring policy](https://pip.pypa.io/en/latest/development/vendoring-policy/) does not support partially removing bundled libraries. Updating their vendored versions would require maintaining and validating a custom pip distribution, so this image preserves the upstream wheel. There is no published pip release containing these dependency fixes as of this review. These findings remain visible in Scout and require an upstream pip update. They affect the test-only Buccaneerr seed installer; production Privateerr contains neither virtualenv nor pip.

| Bundled dependency | Reported advisory | Standalone fixed version |
| --- | --- | --- |
| msgpack 1.1.2 | [CVE-2026-57585](https://github.com/advisories/GHSA-6v7p-g79w-8964) | 1.2.1 |
| urllib3 2.7.0 | [CVE-2026-97687](https://www.cve.org/CVERecord?id=CVE-2026-97687), [CVE-2026-97688](https://www.cve.org/CVERecord?id=CVE-2026-97688), [CVE-2026-97689](https://www.cve.org/CVERecord?id=CVE-2026-97689) | 2.8.0 |
| setuptools 70.3.0, limited to pip's vendored `pkg_resources` | [CVE-2025-47273](https://www.cve.org/CVERecord?id=CVE-2025-47273), [CVE-2026-59890](https://www.cve.org/CVERecord?id=CVE-2026-59890) | 78.1.1 and 83.0.0, respectively |

The unused pip 26.0.1 and setuptools 82.0.1 seed wheels target Python 3.9, which this image does not provide. Removing those assets removes their vulnerable code without changing the active Python 3.14 seed wheels. Scout still reports the removed assets from virtualenv's original package SBOM at `virtualenv-*.dist-info/sboms/virtualenv.cdx.json`; that upstream inventory describes the unmodified distributed wheel, not the image after pruning. Keep this distinction visible when reviewing the scan. A fresh pre-commit Python hook environment verifies that environment creation and package installation still work.

A successful workflow scan rejects fixed high or critical findings; it does not mean either scanner reports zero findings. CI uses `ignore-unfixed: true`, applies the expiring binary-path exceptions above, and scans its local build. Use the full artifact scans when evaluating other severities, unfixed dependencies, platforms, and published stable images.

## Reviewed image indices

The scanned `latest` images select v2.1.6. These immutable index digests record the October 19 snapshot before the curl security fix; subsequent `edge` publications select new artifacts:

| Image | Tag | Index digest |
| --- | --- | --- |
| Privateerr | `edge` | `sha256:80110206589a48ffd52fa87ffa846c81bdaed1cad6853355a6c4fb7e82a49557` |
| Privateerr | `latest` | `sha256:9ea437871a84581b8945323485eea0d953bfe3a61e24c08c57cd53baf9db0cb6` |
| Buccaneerr | `edge` | `sha256:17166043a53d9a66d140e2b3df0df87ddc93f9ea9b4526c50a064b821b52469d` |
| Buccaneerr | `latest` | `sha256:38061fda9f5ca23eaf1ec2eaa6bad6b973336ee399673ec5e4fc07147b55af70` |

## Repeat the review

Scan immutable published digests, including findings with no fix and every severity:

```sh
trivy image --image-src remote --scanners vuln --detection-priority comprehensive --ignorefile /dev/null ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST --platform linux/amd64
```

For Trivy, replace `IMAGE-DIGEST` with the published runtime manifest digest for the platform being reviewed. For Scout, use the image index digest with `--platform` so it can locate the matching published SPDX attestation. Repeat for every supported platform and retain scanner versions, database date, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot.
