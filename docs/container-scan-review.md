# Container scan review

Buccaneerr was reviewed on October 20, 2026 with Trivy 0.75.0 in comprehensive mode and Docker Scout 1.26.0. Trivy's database was updated at 01:19:53 UTC on October 21, or 21:19:53 EDT on October 20. Both scanners examined the immutable `edge` image built from main commit `f8b07cb65487645974a56c37e9bece9578704281` on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. All three platforms have matching advisory sets. Scanner databases change, so these findings apply to the recorded artifacts rather than every future image with the same tag. The production-image snapshot below remains historical evidence from October 19; production and `latest` images were not scanned again during this Buccaneerr review.

## Review the October 21 tool update

Source commit `8c2f14c48568fe47a0d142c89e7cf48aba107f36` updates the official Docker CLI donor to 29.9.2 and the official Compose donor to 5.6.1. Their verified image indices are `sha256:2a146f3eb1ee1015c482756624bbff3a94a1b0531cad6fca03be55943373cf95` and `sha256:2aeaeedd4f2d8e2dcb399b2b9723bfaeb6714140cb0657897f5865960f1624ae`, respectively. The [official Docker inventory](https://github.com/docker-library/repo-info/blob/master/repos/docker/remote/29.9.2-cli.md) records its published platforms; the [Compose release](https://github.com/docker/compose/releases/tag/v5.6.1) identifies the Go 1.26.10 security fix. No project-specific Go rebuild or dependency override is introduced.

Complete Buccaneerr images were built locally for all three supported platforms and exported as OCI layouts. The immutable runtime manifests and configuration digests below identify the actual scanned artifacts; these are local review artifacts, not published registry images. They do not establish that `edge`, `latest`, or an installed image has received the update. Production Privateerr was not rebuilt or scanned again in this local review.

| Platform | Local runtime manifest digest | Image configuration digest |
| --- | --- | --- |
| linux/amd64 | `sha256:b57c9331866fcdf4b82415d4481274f72789da2e24fddee9553ab8ffe4df8db7` | `sha256:bd044ad9bb90bb0f6acbee592fe734349f821450057d8e45b0877a4e3f9c2b9e` |
| linux/arm64 | `sha256:b90022e6cd90cc291074651f9f9a4e541855c4768e9944f4b637d5731ea6dddd` | `sha256:e407d2636373d035e42f633740e462472a225b45cc3e57633d3e9252b8635e8d` |
| linux/arm/v7 | `sha256:6a2ce2e5f5b2e822dab71364134a7884157989b9bf32930a3730b2f79b527fbd` | `sha256:b8816f5fd5d9812dc6195908a8c57d55c92a46aa073c1ae65dd7b4bfda6a4a15` |

Trivy 0.75.0 scanned these layouts on October 21 with the vulnerability database updated at 13:15:34 UTC that day. The database was freshly downloaded, then held constant across the three scans. Comprehensive detection, every severity, unfixed findings, and an empty ignore file were used. Each platform reports the same nine findings covering nine identifiers: three HIGH, four MEDIUM, and two UNKNOWN. Docker CLI and Compose both embed Go 1.26.10, and neither binary reports CVE-2026-111943. The two existing Compose standard-library exception identifiers, CVE-2026-78667 and CVE-2026-97031, are also absent from all three unfiltered scans.

The complete image still reports CVE-2026-111943 in Alpine actionlint 1.7.12-r3, which embeds Go 1.26.9. The default precise scan can omit upstream Go findings for an Alpine-owned binary, so passing the normal CI gate does not establish that this finding is fixed. The actionlint `golang.org/x/sys` finding and the unfixed braces finding remain visible as well. No new exception covers actionlint.

Compose still embeds `golang.org/x/net v0.58.0`, including HIGH CVE-2026-78669 and four MEDIUM findings fixed in v0.60.0. Its unmaintained OpenPGP finding also remains. The existing exact-path CVE-2026-78669 exception expires on October 23, 2026; this update neither resolves that advisory nor extends its expiry. The policy scans also pass on all three artifacts after removing only the obsolete CVE-2026-78667 and CVE-2026-97031 entries. The CVE-2026-78669 entry, including its comments, exact path, statement, and October 23 expiry, is unchanged. No exclusion is added, extended, or broadened.

Only Trivy was rerun for these local artifacts. The published-image and Scout evidence in the following sections retains its original dates and digests; it is not a scan of this source update.

## Security status at the recorded review

The October 19 published production images reported 48 Trivy findings covering 24 identifiers on every platform, all from curl and libcurl 8.22.0. CVE-2026-92392 is HIGH severity; the other reports are MEDIUM or LOW. Official curl 8.23.0 fixes all 24 identifiers. Source builds now require that version from a narrowly tagged Alpine edge repository because stable Alpine 3.24 still supplies 8.22.0. The historical indices below predate that fix and selected v2.1.6 for `latest`; they do not establish the current state of either tag. Do not treat a source merge as a fix to an existing immutable image.

At the October 20 review, Buccaneerr used the digest-pinned official Compose 5.6.0 image and Alpine's actionlint package, with a minimum of 1.7.12-r3. Docker CLI remains digest-pinned, and the repaired smol-toml 1.9.1 lockfile remains intact. The project-specific Go builds and dependency overrides have been removed to avoid maintaining a separate tool dependency graph and cross-compilation pipeline. These tools remain outside production Privateerr.

The official Compose and packaged actionlint binaries can still report Go vulnerabilities. As of October 20, the latest upstream releases remain Compose 5.6.0 and actionlint 1.7.12. Pip 26.2.2 is available, but its bundled dependencies still have the six installer CVEs listed below. There is no verified drop-in upstream release that removes the remaining Compose or bundled-installer findings. Alpine has rebuilt actionlint 1.7.12-r3 with Go 1.26.9 on all three platforms, fixing its former Go standard-library findings without a project-specific build. The `golang.org/x/sys` version finding remains visible. At that review, CI temporarily excluded CVE-2026-78667 and CVE-2026-97031 only at the exact Compose binary path until October 23, 2026. The obsolete actionlint paths have been removed from those exceptions. Those advisories concern HTTP file-serving and TLS-server denial of service; the supported CLI validation and test-container management commands do not expose those server paths. Buccaneerr runtime tests can use networking inside the VPN namespace, so this rationale does not depend on every test being offline. It is an invocation-boundary assessment, not proof about every dependency or unsupported command.

The October 10 PR scan also reports [CVE-2026-78669](https://pkg.go.dev/vuln/GO-2026-6611) in official Compose's Go standard library and `golang.org/x/net`. This HTTP/2 SETTINGS-frame denial of service affects clients and servers; a CLI alone is not an exemption. The additional exception applies only to `usr/local/lib/docker/cli-plugins/docker-compose`, with the same October 23 expiry. Supported repository checks use trusted checked-in fixtures; `scripts/compose/test.sh` requires a local Unix Docker socket for runtime, live, smoke, and pre-commit suites, rejects remote Docker contexts, and does not forward `DOCKER_HOST` into Buccaneerr. Other suites run without networking. Network-enabled tests remain supported, and Compose used against untrusted HTTP/2 peers outside this wrapper boundary retains risk. This assessment does not prove every Compose command or dependency safe.

The October 20 review retains the same three exact-path Compose exceptions and their October 23 expiry. The official release is still affected; this review does not extend the exceptions or establish that other Compose advisories are unreachable.

The existing fixed HIGH/CRITICAL gate remains active for all other findings and paths, including Docker CLI. Braces and the OpenPGP module warning are not excluded. Full artifact reviews remain unfiltered. Review or remove the exceptions before their expiry, and remove them once compatible official tools on all three supported platforms include the Go fixes. Any extension requires a separate review of the expiry, exact paths, and affected package identifiers; a blanket exclusion is not an acceptable substitute.

Both images retain the zlib 1.3.2-r1 and libexpat 2.9.0-r0 minimums. Stable Alpine now supplies fixed libexpat 2.9.0 on all three architectures, so the Expat edge exception has been removed. Only curl needs the production edge repository; Buccaneerr also retains its setuptools edge exception until stable supplies version 83 or later. No general edge upgrade is performed.

## Retained security controls

The October 20 reviewed Buccaneerr image used digest-pinned Docker CLI and the official Compose 5.6.0 binary. Compose includes fixed containerd 2.4.1. BusyBox supplies AWK and core utilities; npm is installed only during the build and removed in the same layer. Pre-commit runs Markdownlint through the same test-image helper as other checks.

Pre-commit 4.7.0 and virtualenv 21.14.11 install into `/opt/precommit` from the complete exact, SHA-256-verified `test/requirements-tools.txt` lockfile. Bootstrap pip is removed after installation. Virtualenv retains the exact upstream pip 26.2.1 and setuptools 84.0.0 seed wheels for Python 3.14 with their SHA-256 verification; unused Python 3.9 seed archives are removed. No production Python dependencies, customized pip distribution, or rewritten upstream package inventory are introduced.

## Published artifact findings

The October 20 Buccaneerr image reports 23 comprehensive Trivy findings covering 18 identifiers on every platform: six HIGH, 13 MEDIUM, two LOW, and two UNKNOWN package findings. Alpine packages and the standalone Docker CLI have no findings in this scan. Comprehensive mode includes upstream Go-library analysis for Alpine-owned actionlint; the default precise mode can omit those Go findings while still identifying the installed APK. These are unfiltered all-severity results, distinct from CI's narrower fixed HIGH/CRITICAL gate.

Scout reports 36 advisory identifiers across 15 package versions on each platform. Its report includes virtualenv's upstream software bill of materials (SBOM), which still lists removed seed wheels. Scout reports the same msgpack issue as both CVE-2026-57585 and GHSA-6v7p-g79w-8964; count those aliases once when comparing issues. Scout has not yet reported the two new Markdown parser advisories found by Trivy. Combining both reports and deduplicating that alias gives 37 issues, classified below. Severity assignments differ between the scanners; a Scout CRITICAL label alone does not establish Linux applicability.

| Finding group | Issues | Assessment and next step |
| --- | --- | --- |
| Markdown parser | 2 | Update the existing markdown-it override from 15.0.2 to 15.0.3 and regenerate the lockfile. |
| Removed or older seed-wheel inventory only | 12 | Record the installed-file evidence below; these vulnerable versions are absent from the retained wheels. |
| Windows-only code | 3 | Record the Linux applicability assessment below. |
| Remaining Compose advisories | 13 | Await compatible official updates or assess affected code paths individually. |
| Dependencies in the active pip seed wheel | 6 | Await an upstream pip update; standalone package upgrades do not replace vendored code. |
| Braces | 1 | Keep the unpatched dependency finding visible. |

The source lockfile now selects markdown-it 15.0.3, fixing [CVE-2026-111758](https://github.com/advisories/GHSA-gfr2-rv44-r23c) and [CVE-2026-111766](https://github.com/advisories/GHSA-vfgh-jcmw-g37q). Both denial-of-service advisories were published on October 20 after the earlier Markdown parser fix. This is a source fix; the reviewed immutable image still contains 15.0.2. The inventory and platform assessments do not remove vulnerable code or guarantee a lower scanner count. Keep unfiltered reports and do not rewrite upstream inventory to hide findings.

The following package-level reports remain visible and require context.

- **CVE-2026-93687:** [braces 3.0.3](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) still has no published patched version. Markdownlint CLI2 depends on it through micromatch. Keep the GitHub dependency alert visible and use repository-controlled file patterns for checks.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package. Compose's module metadata includes `golang.org/x/crypto`; the advisory does not apply to every package in that module.
- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery. Scout reports the Docker CLI module embedded in Compose; the affected Windows behavior does not apply to these Linux images.
- **CVE-2026-56857:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-6604) affects Windows junction handling in the standard library. Scout reports it as CRITICAL in Compose, but the affected Windows behavior does not apply to these Linux images.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects `golang.org/x/sys/windows.NewNTUnicodeString`. The actionlint module inventory reports an older x/sys version, but that Windows package does not apply to these Linux images.

## Bundled installer findings

Virtualenv needs its integrity-checked pip seed wheel to create fresh Python hook environments. The retained pip 26.2.1 wheel and the newer upstream [pip 26.2.2 inventory](https://github.com/pypa/pip/blob/26.2.2/src/pip/_vendor/vendor.txt) still vendor the dependencies below. Installing their standalone fixed releases does not replace code inside that wheel. The [upstream vendoring policy](https://pip.pypa.io/en/latest/development/vendoring-policy/) does not support partially removing bundled libraries. Updating their vendored versions would require maintaining and validating a custom pip distribution, so this image preserves the upstream wheel. There is no published pip release containing these dependency fixes as of this review. These findings remain visible in Scout and require an upstream pip update. They affect the test-only Buccaneerr seed installer; production Privateerr contains neither virtualenv nor pip.

| Bundled dependency | Reported advisory | Standalone fixed version |
| --- | --- | --- |
| msgpack 1.1.2 | [CVE-2026-57585](https://github.com/advisories/GHSA-6v7p-g79w-8964) | 1.2.1 |
| urllib3 2.7.0 | [CVE-2026-97687](https://www.cve.org/CVERecord?id=CVE-2026-97687), [CVE-2026-97688](https://www.cve.org/CVERecord?id=CVE-2026-97688), [CVE-2026-97689](https://www.cve.org/CVERecord?id=CVE-2026-97689) | 2.8.0 |
| setuptools 70.3.0, limited to pip's vendored `pkg_resources` | [CVE-2025-47273](https://www.cve.org/CVERecord?id=CVE-2025-47273), [CVE-2026-59890](https://www.cve.org/CVERecord?id=CVE-2026-59890) | 78.1.1 and 83.0.0, respectively |

A read-only inspection of the published arm64 image found exactly two seed wheels: pip 26.2.1 and setuptools 84.0.0, matching virtualenv's active Python 3.14 mapping. The unused pip 26.0.1 and setuptools 82.0.1 seed wheels target Python 3.9, which this image does not provide. Those archives are absent. Pip's retained `pip/_vendor/vendor.txt` records requests 2.34.2, idna 3.18, Pygments 2.20.0, and urllib3 2.7.0. This distinguishes the 12 inventory-only CVEs below from the six CVEs still affecting the active pip wheel.

| Older version reported by Scout | Inventory-only CVEs | Retained code |
| --- | --- | --- |
| pip 26.0.1 | CVE-2026-8643, CVE-2026-3219, CVE-2026-6357, CVE-2026-13346 | pip 26.2.1 |
| requests 2.32.5 | CVE-2026-25645 | requests 2.34.2 inside pip |
| idna 3.11 | CVE-2026-45409 | idna 3.18 inside pip |
| Pygments 2.19.2 | CVE-2026-4539 | Pygments 2.20.0 inside pip |
| urllib3 1.26.20 | CVE-2025-50181, CVE-2025-66418, CVE-2025-66471, CVE-2026-21441, CVE-2026-44431 | urllib3 2.7.0 inside pip; its three newer CVEs remain visible above |

Scout reads these entries from `virtualenv-21.14.11.dist-info/sboms/virtualenv.cdx.json`. That upstream inventory describes the distributed virtualenv wheel before pruning. Reports for setuptools 82.0.1, msgpack, and newer urllib3 advisories overlap findings in retained pip code, so they are not counted among the 12 inventory-only issues. Preserve the upstream SBOM and describe this boundary rather than deleting metadata. A fresh pre-commit Python hook environment verifies that environment creation and package installation still work.

A successful workflow scan rejects fixed high or critical findings; it does not mean either scanner reports zero findings. CI uses `ignore-unfixed: true`, applies the expiring binary-path exceptions above, and scans its local build. Use the full artifact scans when evaluating other severities, unfixed dependencies, platforms, and published stable images.

## Reviewed image indices

The October 20 Buccaneerr index is `sha256:1c56754fb640dcbe120b33f022a274cceb446f8327fae83301fe3687a32e4bd4`. The successful [main publication](https://github.com/scottgigawatt/privateerr/actions/runs/39526870674) and image revision labels identify commit `f8b07cb65487645974a56c37e9bece9578704281`.

| Platform | Runtime manifest digest |
| --- | --- |
| linux/amd64 | `sha256:0b20ab2d4d39cc0413d3290bf19da51425db52811a4de7e1f552d001b9d982d9` |
| linux/arm64 | `sha256:8d4f9710a3d0bc2c4cafb9e1f11cb1ed016090108f77304d92a8cbe17ee6735d` |
| linux/arm/v7 | `sha256:f037ea747f2c60a98d23c21324563d9cc35acbd0b5a053e355e71b54ad32d925` |

The following indices retain the historical October 19 snapshot before the curl security fix. They do not describe the current `edge` or `latest` tags:

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
