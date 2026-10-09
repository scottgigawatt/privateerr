# Container scan review

Reviewed on October 9, 2026 with Trivy 0.75.0 and Docker Scout 1.25.0. The review covers immutable `edge` and `latest` digests on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Scanner databases change, so these findings apply to the recorded artifacts rather than every future image with the same tag.

## Current security status

Production Privateerr reports no Docker Scout findings on the reviewed platforms. The zlib, Expat, KaTeX, and smol-toml findings from the earlier review are resolved in the published v2.1.5 images. Their old artifact digests and pending-release guidance have been removed.

The reviewed stable Buccaneerr v2.1.5 images still include Go 1.26.8 in Docker CLI, Compose, and actionlint. The fixes ship in Go 1.26.9 or 1.27.2 and `golang.org/x/net` 0.60.0. The Docker CLI update uses upstream 29.9.0. Compose 5.6.0 and actionlint 1.7.12 are rebuilt from their checksum-verified upstream Go modules using the digest-pinned patched Go builder and fixed networking dependencies. Actionlint also requires `golang.org/x/sys` 0.48.0 or newer. Renovate tracks these source versions, dependency floors, and the builder image. Build tools remain outside the published test image and production Privateerr.

Both images retain the zlib 1.3.2-r1 minimum. Alpine 3.24 still supplies Expat 2.8.5, so the narrow Expat 2.9.0 edge exception remains necessary. Buccaneerr retains its setuptools edge exception until stable supplies version 83 or later. No general edge upgrade is performed.

## Retained security controls

Buccaneerr uses digest-pinned Docker CLI and the rebuilt Compose 5.6.0 binary. Compose includes fixed containerd 2.4.1. BusyBox supplies AWK and core utilities; npm is installed only during the build and removed in the same layer. Pre-commit runs Markdownlint through the same test-image helper as other checks.

Pre-commit 4.6.2 and virtualenv 21.14.6 install into `/opt/precommit` from the complete exact, SHA-256-verified `test/requirements-tools.txt` lockfile. Bootstrap pip is removed after installation. Virtualenv retains the exact upstream pip 26.2.1 and setuptools 84.0.0 seed wheels for Python 3.14 with their SHA-256 verification; unused Python 3.9 seed archives are removed. No production Python dependencies, customized pip distribution, scanner exclusions, or rewritten upstream package inventory are introduced.

## Published artifact findings

The reviewed production Privateerr images report zero Scout identifiers. The recorded pre-rebuild Buccaneerr artifacts report thirty-six Scout identifiers on every platform. The recorded immutable digests retain that baseline. Merged fixes refresh `edge`; refreshing stable `latest` requires a new stable release.

The remaining package-level reports require the following context. No scanner exclusion hides them.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) still has no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. These Linux tools use CLI 29.9.0 and Compose 5.6.0, newer than the patched releases. Scout still reports the Docker CLI module.

## Bundled installer findings

Virtualenv needs its integrity-checked pip seed wheel to create fresh Python hook environments. The current published pip release, 26.2.1, still vendors the dependencies below. Installing their standalone fixed releases does not replace code inside that wheel. The [upstream vendoring policy](https://pip.pypa.io/en/latest/development/vendoring-policy/) does not support partially removing bundled libraries. Updating their vendored versions would require maintaining and validating a custom pip distribution, so this image preserves the upstream wheel. There is no published pip release containing these dependency fixes as of this review. These findings remain visible in Scout and require an upstream pip update. They affect the test-only Buccaneerr seed installer; production Privateerr contains neither virtualenv nor pip.

| Bundled dependency | Reported advisory | Standalone fixed version |
| --- | --- | --- |
| msgpack 1.1.2 | [CVE-2026-57585](https://github.com/advisories/GHSA-6v7p-g79w-8964) | 1.2.1 |
| urllib3 2.7.0 | [CVE-2026-97687](https://www.cve.org/CVERecord?id=CVE-2026-97687), [CVE-2026-97688](https://www.cve.org/CVERecord?id=CVE-2026-97688), [CVE-2026-97689](https://www.cve.org/CVERecord?id=CVE-2026-97689) | 2.8.0 |
| setuptools 70.3.0, limited to pip's vendored `pkg_resources` | [CVE-2025-47273](https://www.cve.org/CVERecord?id=CVE-2025-47273), [CVE-2026-59890](https://www.cve.org/CVERecord?id=CVE-2026-59890) | 78.1.1 and 83.0.0, respectively |

The unused pip 26.0.1 and setuptools 82.0.1 seed wheels target Python 3.9, which this image does not provide. Removing those assets removes their vulnerable code without changing the active Python 3.14 seed wheels. Scout still reports the removed assets from virtualenv's original package SBOM at `virtualenv-*.dist-info/sboms/virtualenv.cdx.json`; that upstream inventory describes the unmodified distributed wheel, not the image after pruning. Keep this distinction visible when reviewing the scan. A fresh pre-commit Python hook environment verifies that environment creation and package installation still work.

A successful workflow scan rejects fixed high or critical findings; it does not mean either scanner reports zero findings. CI uses `ignore-unfixed: true` and scans its local build. Use the full artifact scans when evaluating other severities, unfixed dependencies, platforms, and published stable images.

## Reviewed image indices

The scanned `latest` images select v2.1.5. These immutable index digests record the October 9 artifact snapshot:

| Image | Tag | Index digest |
| --- | --- | --- |
| Privateerr | `edge` | `sha256:3ced883fe6c341aca614da3066c64f623759eae8300d8699f4851e7e8b9ce78d` |
| Privateerr | `latest` | `sha256:d7a09207dd74eb0d24bd81fa85302ca064b5351490178b72ee0e759c9a2a0c81` |
| Buccaneerr | `edge` | `sha256:50cd191ed008ef3d9ae32807c71a3592be44dc28c30a8fa7bdc1f77f177a4cb3` |
| Buccaneerr | `latest` | `sha256:7f0336c01b6965f02643f9d61d33fa3f11f51dbf680e033a8bf353acbe249dc8` |

## Repeat the review

Scan immutable published digests, including findings with no fix and every severity:

```sh
trivy image --image-src remote --scanners vuln ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST --platform linux/amd64
```

Replace `IMAGE-DIGEST` with the published manifest digest for the platform being reviewed. Repeat for every supported platform and retain scanner versions, database date, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot.
