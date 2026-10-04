# Container scan review

Reviewed on October 4, 2026 with Trivy 0.74.0 for published artifacts, Trivy 0.75.0 for the rebuilt ARM64 image, and Docker Scout 1.24.0 (Trivy database updated at 14:28 UTC). The review covers immutable `edge` and `latest` digests on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Scanner databases change, so these findings apply to the scanned artifacts rather than every future image with the same tag.

## Dependency fixes

Buccaneerr uses Docker CLI 29.8.2 and Compose 5.6.0 from digest-pinned official images. Compose includes containerd 2.4.1, fixing [CVE-2026-53493](https://github.com/containerd/containerd/security/advisories/GHSA-pg57-6jwg-q645) and [CVE-2026-53495](https://github.com/containerd/containerd/security/advisories/GHSA-7jxh-36q5-gcqv). BusyBox supplies AWK and core utilities, avoiding unnecessary GNU packages.

The tool manifest locks CSpell, Pyright, and Markdownlint CLI2. Alpine's npm installs these checkers during the image build and is removed in the same layer, keeping its bundled dependencies out of the completed image. Pre-commit runs Markdownlint through the same Buccaneerr helper used for Python checks, so it does not install a separate Node environment. Removing npm also eliminates the bundled brace-expansion and http-cache-semantics vulnerabilities, including CVE-2026-102276, CVE-2026-102277, CVE-2026-102278, and CVE-2026-93748. Renovate maintains the checker lockfile using npm 11.

Pre-commit 4.6.2 and virtualenv 21.14.5 now install into `/opt/precommit` from `test/requirements-tools.txt`. Every dependency has an exact version and SHA-256 hashes, enforced with pip's `--require-hashes` mode. The bootstrap pip is removed after installation. The image also removes virtualenv's unused Python 3.9 seed wheels, retaining the exact upstream pip 26.2.1 and setuptools 84.0.0 wheels for the installed Python 3.14 and their SHA-256 verification. This isolated test environment replaces Alpine's virtualenv 21.3.3, including four advisories reported by Scout: [CVE-2026-102925](https://github.com/advisories/GHSA-p58f-9548-mpm2), [CVE-2026-102930](https://github.com/advisories/GHSA-94p9-xgh2-xp45), [CVE-2026-102937](https://github.com/advisories/GHSA-x78j-v8h9-3j2q), and [CVE-2026-102938](https://github.com/advisories/GHSA-9h9j-4vrj-gf7g). These packages remain outside the production Privateerr image.

Current `edge` images contain Python 3.14.8-r0; Buccaneerr also contains PCRE2 10.49-r0. These fix the Python and PCRE2 findings listed below. Alpine 3.24 stable now supplies nghttp2 1.70.0-r0 on all three platforms, so both images remove the old edge-package override. Buccaneerr still installs setuptools 83.0.0 or newer from edge because stable supplies 82.0.1-r1. Keep that remaining narrow exception until stable supplies the fixed version.

## Remaining package-level alerts

Privateerr `edge` has no findings in either scanner across all three platforms. Before the virtualenv update, Buccaneerr `edge` has two unique Trivy findings and nine unique Scout findings; the four virtualenv findings have published fixes and are addressed by this change. The rebuilt image has two unique Trivy findings and twenty-four unique Scout identifiers, with all four virtualenv advisories removed. Virtualenv 21.14.5 adds an upstream package SBOM describing every original seed wheel, so Scout now reports bundled dependencies that the earlier review did not enumerate. Twelve identifiers concern retained packages or their metadata; twelve additional identifiers describe removed Python 3.9 seed assets in that upstream build inventory. The inventory remains unchanged and the removed files are verified absent from the completed image. The remaining package-level reports require the following context. No scanner exclusion hides them.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) has a stack-exhaustion issue in deeply nested patterns and no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. These Linux images use CLI 29.8.2 and Compose 5.6.0, newer than the patched releases. Scout still reports the Docker CLI module.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion in `golang.org/x/sys/windows`. Buccaneerr runs the Linux actionlint binary, whose module metadata still includes the older version.
- **CVE-2026-84445:** The gRPC [advisory](https://github.com/grpc/grpc-go/security/advisories/GHSA-2v4p-qf9q-27wj) affects servers configured with `xds.NewGRPCServer()`. Scout reports gRPC 1.84.0 in the Docker client, but the current upstream advisory lists 1.84.0 as patched. Buccaneerr also starts no xDS server; review the separate Docker host independently.

## Bundled installer findings

Virtualenv needs its integrity-checked pip seed wheel to create fresh Python hook environments. The current published pip release, 26.2.1, still vendors the dependencies below. Installing their standalone fixed releases does not replace code inside that wheel. The [upstream vendoring policy](https://pip.pypa.io/en/latest/development/vendoring-policy/) does not support replacing individual bundled libraries; this image preserves the upstream wheel rather than maintaining a custom pip distribution. There is no published pip release containing these dependency fixes as of this review. These findings remain visible in Scout and require an upstream pip update. They affect the test-only Buccaneerr seed installer; production Privateerr contains neither virtualenv nor pip.

| Bundled dependency | Reported advisory | Standalone fixed version |
| --- | --- | --- |
| msgpack 1.1.2 | [CVE-2026-57585](https://github.com/advisories/GHSA-6v7p-g79w-8964) | 1.2.1 |
| urllib3 2.7.0 | [CVE-2026-97687](https://www.cve.org/CVERecord?id=CVE-2026-97687), [CVE-2026-97688](https://www.cve.org/CVERecord?id=CVE-2026-97688), [CVE-2026-97689](https://www.cve.org/CVERecord?id=CVE-2026-97689) | 2.8.0 |
| setuptools 70.3.0, limited to pip's vendored `pkg_resources` | [CVE-2025-47273](https://www.cve.org/CVERecord?id=CVE-2025-47273), [CVE-2026-59890](https://www.cve.org/CVERecord?id=CVE-2026-59890) | 78.1.1 and 83.0.0, respectively |

The unused pip 26.0.1 and setuptools 82.0.1 seed wheels target Python 3.9, which this image does not provide. Removing those assets removes their vulnerable code without changing the active Python 3.14 seed wheels. Scout still reports the removed assets from virtualenv's original package SBOM at `virtualenv-21.14.5.dist-info/sboms/virtualenv.cdx.json`; that upstream inventory describes the unmodified distributed wheel, not the image after pruning. Keep this distinction visible when reviewing the scan. A fresh pre-commit Python hook environment verifies that environment creation and package installation still work.

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
