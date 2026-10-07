# Container scan review

Reviewed on October 7, 2026 with Trivy 0.75.0 and Docker Scout 1.25.0 (Trivy database updated at 07:38 UTC). The review covers immutable `edge` and `latest` digests on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. Scanner databases change, so these findings apply to the recorded artifacts rather than every future image with the same tag.

## New dependency fixes

Privateerr and Buccaneerr both report zlib 1.3.2-r0 [CVE-2026-85091](https://www.cve.org/CVERecord?id=CVE-2026-85091). Alpine 3.24 stable supplies the fixed 1.3.2-r1 revision on all three platforms. Both Dockerfiles require that minimum version so cached base packages cannot retain the vulnerable revision.

Docker Scout also reports Expat 2.8.5-r0 [CVE-2026-102633](https://github.com/libexpat/libexpat/pull/1392) and [CVE-2026-77214](https://github.com/libexpat/libexpat/pull/1393), which the current Trivy database does not enumerate. The [Expat 2.9.0 release](https://github.com/libexpat/libexpat/releases/tag/R_2_9_0) fixes both; the first concerns 32-bit builds. Stable still supplies 2.8.5-r0, so both images install only `libexpat` 2.9.0-r0 or newer from edge. The test image also retains its existing setuptools edge exception because stable supplies 82.0.1-r1. Remove each narrow exception once stable provides its fixed package. No general edge upgrade is performed.

Buccaneerr's tool manifest overrides two vulnerable transitive dependencies until their parents allow the fixed releases: KaTeX 0.18.2 fixes [CVE-2026-103923](https://github.com/KaTeX/KaTeX/security/advisories/GHSA-238p-pmpm-9mq7), and smol-toml 1.9.0 fixes [the quadratic TOML parser advisory](https://github.com/squirrelchat/smol-toml/security/advisories/GHSA-r4xh-jqrq-34v2). The integrity-locked dependency tree contains those fixed versions. Compatibility checks exercise the actual math extension, the inherited rendering-trust boundary, and valid flat TOML input. These tools remain outside production Privateerr.

## Retained security controls

Buccaneerr uses digest-pinned Docker CLI 29.8.2 and Compose 5.6.0. Compose includes fixed containerd 2.4.1. BusyBox supplies AWK and core utilities; npm is installed only during the build and removed in the same layer. Pre-commit runs Markdownlint through the same test-image helper as other checks.

Pre-commit 4.6.2 and virtualenv 21.14.5 install into `/opt/precommit` from the complete exact, SHA-256-verified `test/requirements-tools.txt` lockfile. Bootstrap pip is removed after installation. Virtualenv retains the exact upstream pip 26.2.1 and setuptools 84.0.0 seed wheels for Python 3.14 with their SHA-256 verification; unused Python 3.9 seed archives are removed. No production Python dependencies, customized pip distribution, scanner exclusions, or rewritten upstream package inventory are introduced.

## Published artifact findings

Before these fixes, both `edge` and stable `latest` Privateerr images have one unique Trivy finding and three Scout identifiers on every platform. Buccaneerr has five unique Trivy findings and twenty-eight Scout identifiers on every platform. The five newly addressed advisories are zlib, the two Expat findings, KaTeX, and smol-toml. The baseline digests below retain that review evidence; source fixes refresh `edge`, and a new stable release is needed to refresh `latest`.

The remaining package-level reports require the following context. No scanner exclusion hides them.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) still has no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. These Linux images use CLI 29.8.2 and Compose 5.6.0, newer than the patched releases. Scout still reports the Docker CLI module.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion. Buccaneerr runs the Linux actionlint binary, whose module metadata still includes the older version.

Scout no longer reports the earlier gRPC CVE-2026-84445 finding. The current [upstream advisory](https://github.com/grpc/grpc-go/security/advisories/GHSA-2v4p-qf9q-27wj) lists the installed 1.84.0 version as patched.

## Bundled installer findings

Virtualenv needs its integrity-checked pip seed wheel to create fresh Python hook environments. The current published pip release, 26.2.1, still vendors the dependencies below. Installing their standalone fixed releases does not replace code inside that wheel. The [upstream vendoring policy](https://pip.pypa.io/en/latest/development/vendoring-policy/) does not support partially removing bundled libraries. Updating their vendored versions would require maintaining and validating a custom pip distribution, so this image preserves the upstream wheel. There is no published pip release containing these dependency fixes as of this review. These findings remain visible in Scout and require an upstream pip update. They affect the test-only Buccaneerr seed installer; production Privateerr contains neither virtualenv nor pip.

| Bundled dependency | Reported advisory | Standalone fixed version |
| --- | --- | --- |
| msgpack 1.1.2 | [CVE-2026-57585](https://github.com/advisories/GHSA-6v7p-g79w-8964) | 1.2.1 |
| urllib3 2.7.0 | [CVE-2026-97687](https://www.cve.org/CVERecord?id=CVE-2026-97687), [CVE-2026-97688](https://www.cve.org/CVERecord?id=CVE-2026-97688), [CVE-2026-97689](https://www.cve.org/CVERecord?id=CVE-2026-97689) | 2.8.0 |
| setuptools 70.3.0, limited to pip's vendored `pkg_resources` | [CVE-2025-47273](https://www.cve.org/CVERecord?id=CVE-2025-47273), [CVE-2026-59890](https://www.cve.org/CVERecord?id=CVE-2026-59890) | 78.1.1 and 83.0.0, respectively |

The unused pip 26.0.1 and setuptools 82.0.1 seed wheels target Python 3.9, which this image does not provide. Removing those assets removes their vulnerable code without changing the active Python 3.14 seed wheels. Scout still reports the removed assets from virtualenv's original package SBOM at `virtualenv-21.14.5.dist-info/sboms/virtualenv.cdx.json`; that upstream inventory describes the unmodified distributed wheel, not the image after pruning. Keep this distinction visible when reviewing the scan. A fresh pre-commit Python hook environment verifies that environment creation and package installation still work.

A successful workflow scan rejects fixed high or critical findings; it does not mean either scanner reports zero findings. CI uses `ignore-unfixed: true` and scans its local build. Use the full artifact scans when evaluating other severities, unfixed dependencies, platforms, and published stable images.

## Reviewed image indices

The scanned `latest` images select v2.1.3. These immutable index digests record the pre-fix artifact snapshot:

| Image | Tag | Index digest |
| --- | --- | --- |
| Privateerr | `edge` | `sha256:c2b04b16b11f62c5ee625f840ff203e7590b313542ec9b9be92497120eb3361f` |
| Privateerr | `latest` | `sha256:6c20dd59581dd25a2c64b97ef661abddc6a9561047924ce82d6681bdf7adefca` |
| Buccaneerr | `edge` | `sha256:df79b870f584aeb65aff522e223315678cd1f8847171e8673945af2108499813` |
| Buccaneerr | `latest` | `sha256:b89b35f1396e44ffbbe06c83222d9278cce95e88c4fe916185f6613ac35cf9bb` |

## Repeat the review

Scan immutable published digests, including findings with no fix and every severity:

```sh
trivy image --image-src remote --scanners vuln ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE-DIGEST --platform linux/amd64
```

Replace `IMAGE-DIGEST` with the published manifest digest for the platform being reviewed. Repeat for every supported platform and retain scanner versions, database date, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot.
