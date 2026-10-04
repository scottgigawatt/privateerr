# Container scan review

Reviewed on October 4, 2026 with Trivy 0.74.0 for published artifacts, Trivy 0.75.0 for the rebuilt ARM64 image, and Docker Scout 1.24.0 (Trivy database updated at 14:28 UTC). The review covers immutable `edge` and `latest` digests on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Scanner databases change, so these findings apply to the scanned artifacts rather than every future image with the same tag.

## Dependency fixes

Buccaneerr uses Docker CLI 29.8.2 and Compose 5.6.0 from digest-pinned official images. Compose includes containerd 2.4.1, fixing [CVE-2026-53493](https://github.com/containerd/containerd/security/advisories/GHSA-pg57-6jwg-q645) and [CVE-2026-53495](https://github.com/containerd/containerd/security/advisories/GHSA-7jxh-36q5-gcqv). BusyBox supplies AWK and core utilities, avoiding unnecessary GNU packages.

The tool manifest locks CSpell, Pyright, and Markdownlint CLI2. Alpine's npm installs these checkers during the image build and is removed in the same layer, keeping its bundled dependencies out of the completed image. Pre-commit runs Markdownlint through the same Buccaneerr helper used for Python checks, so it does not install a separate Node environment. Removing npm also eliminates the bundled brace-expansion and http-cache-semantics vulnerabilities, including CVE-2026-102276, CVE-2026-102277, CVE-2026-102278, and CVE-2026-93748. Renovate maintains the checker lockfile using npm 11.

Pre-commit 4.6.2 and virtualenv 21.7.13 now install into `/opt/precommit` from `test/requirements-tools.txt`. Every dependency has an exact version and SHA-256 hashes, enforced with pip's `--require-hashes` mode. The bootstrap pip is removed after installation, keeping its older bundled libraries out of the completed image. This isolated test environment replaces Alpine's virtualenv 21.3.3, including four advisories reported by Scout: [CVE-2026-102925](https://github.com/advisories/GHSA-p58f-9548-mpm2), [CVE-2026-102930](https://github.com/advisories/GHSA-94p9-xgh2-xp45), [CVE-2026-102937](https://github.com/advisories/GHSA-x78j-v8h9-3j2q), and [CVE-2026-102938](https://github.com/advisories/GHSA-9h9j-4vrj-gf7g). These packages remain outside the production Privateerr image.

Current `edge` images contain Python 3.14.8-r0; Buccaneerr also contains PCRE2 10.49-r0. These fix the Python and PCRE2 findings listed below. Both images still install nghttp2 1.70.0 or newer from Alpine's edge repository, and Buccaneerr installs setuptools 83.0.0 or newer from edge. Keep these narrow package exceptions until stable supplies the fixed versions.

## Remaining package-level alerts

Privateerr `edge` has no findings in either scanner across all three platforms. Before the virtualenv update, Buccaneerr `edge` has two unique Trivy findings and nine unique Scout findings; the four virtualenv findings have published fixes and are addressed by this change. The rebuilt ARM64 image has two unique Trivy findings and five unique Scout findings, with all four virtualenv advisories removed. The remaining package-level reports require the following context. No scanner exclusion hides them.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) has a stack-exhaustion issue in deeply nested patterns and no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. These Linux images use CLI 29.8.2 and Compose 5.6.0, newer than the patched releases. Scout still reports the Docker CLI module.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion in `golang.org/x/sys/windows`. Buccaneerr runs the Linux actionlint binary, whose module metadata still includes the older version.
- **CVE-2026-84445:** The gRPC [advisory](https://github.com/grpc/grpc-go/security/advisories/GHSA-2v4p-qf9q-27wj) affects servers configured with `xds.NewGRPCServer()`. Scout reports gRPC 1.84.0 in the Docker client, but the current upstream advisory lists 1.84.0 as patched. Buccaneerr also starts no xDS server; review the separate Docker host independently.

A successful workflow scan rejects fixed high or critical findings; it does not mean either scanner reports zero findings. CI uses `ignore-unfixed: true` and scans its local build. Use the full artifact scans above when evaluating other severities, unfixed dependencies, platforms, and published stable images.

## Stable image refresh

The scanned `latest` images still select v2.1.2. Privateerr has seven unique Python advisories in both scanners: CVE-2026-19553, CVE-2026-82049, CVE-2026-15806, CVE-2026-17084, CVE-2026-19672, CVE-2026-15310, and CVE-2026-19445. Python 3.14.8-r0 fixes all seven; the `edge` artifacts already contain it.

Buccaneerr v2.1.2 has 15 unique Trivy findings and 21 unique Scout findings. In addition to the Python advisories, it contains fixed PCRE2 CVE-2026-103111, the old npm dependency findings, the old containerd module findings, and the four virtualenv advisories. Fixed findings require rebuilding stable images from the corrected source. Merging source changes refreshes `edge`; a stable release is required to deliver those fixes through `latest`.

The reviewed image index digests are:

| Image | Tag | Index digest |
| --- | --- | --- |
| Privateerr | `edge` | `sha256:46c7c388908894225ccc63020c185e0bee77e67df8916efae1f2156bddb78f22` |
| Privateerr | `latest` | `sha256:04db2616bb7198917c4b316db5b34ae62cac6032084047549d768b8de1421f7b` |
| Buccaneerr | `edge` | `sha256:a98ac7f7919463334554cc486d37649b930b0a5eeefb3e69f26a2c69890c65f8` |
| Buccaneerr | `latest` | `sha256:a2255599b6a9905275e5ffe714190fa1beea8293a0428267605199daa3061052` |

## Repeat the review

Scan immutable published digests, including findings with no fix and every severity:

```sh
trivy image --image-src remote --scanners vuln ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST --platform linux/amd64
```

Replace `IMAGE-DIGEST` with the published manifest digest for the platform being reviewed. Repeat for every supported platform and retain the scanner version, database date, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot.
