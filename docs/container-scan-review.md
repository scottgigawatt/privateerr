# Container security review

This review checks published Privateerr and Buccaneerr artifacts and local update candidates on October 27, 2026. Every image was examined on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. The local candidates are review artifacts; changing source does not update an existing image or advance `latest`.

## Scan scope and results

Trivy 0.76.1 used comprehensive detection with all severities, unfixed findings, and no ignore file. Its freshly downloaded database was updated at `2026-10-27 01:25:30 UTC`; the same database was held constant for all comparisons. Docker Scout 1.27.0 also ran without severity or fix-status filters. Published scans used immutable runtime manifests or their matching published index and platform. Local OCI builds were inspected one runtime manifest at a time; their exact configuration and layer contents were preserved when preparing Docker archives for Scout. Each Trivy report's architecture was checked against its selected manifest.

The counts below are the same on all three platforms. Trivy counts package findings; Scout counts report instances and distinct advisory identifiers separately. Aliases can describe the same issue, so these columns are not interchangeable. In particular, Scout reports the msgpack issue as both CVE-2026-57585 and GHSA-6v7p-g79w-8964.

| Image | Artifact | Trivy findings | Scout instances | Scout identifiers |
| --- | --- | --- | --- | --- |
| Privateerr | `latest` | 2 | 4 | 4 |
| Privateerr | `edge` | 2 | 4 | 4 |
| Privateerr | `candidate` | 2 | 1 | 1 |
| Buccaneerr | `latest` | 21 | 49 | 44 |
| Buccaneerr | `edge` | 11 | 39 | 34 |
| Buccaneerr | `candidate` | 10 | 35 | 31 |

These totals describe whole-image scanner reports; they do not establish coverage of every embedded archive. Python's retained `ensurepip` bootstrap wheel requires the separate inspection described below.

The production candidate removes the three Python advisories reported by Scout against both published production tags. Its remaining musl report is a stable-versus-edge revision mismatch described below. Buccaneerr still has real upstream tool and installer dependency findings; this review does not declare it free of vulnerabilities. The normal CI gate is narrower than this audit: it rejects fixed HIGH/CRITICAL findings, uses precise detection by default, and applies the one exact-path Compose exception.

## Production runtime updates

Both candidates install Python `3.14.10-r0`, including the [October 26 upstream security fixes](https://discuss.python.org/t/python-3-15-2-3-14-10-3-13-18-3-12-16-and-3-11-18-are-out/109678) for CVE-2026-12345, CVE-2026-114583, and CVE-2026-115557. These cover temporary-directory cleanup, archive filtering, and blocking compromised certificate keys. The certificate denylist is a security backstop; it does not replace a maintained trust store.

Alpine 3.24 stable still supplies Python `3.14.8-r0`. A tagged `@pythonfix` edge repository supplies only Python and its matching bytecode package family, with a `3.14.10-r0` minimum. Installed APK databases on all six candidate platforms confirm that every other package version matches the stable repository indexes. Remove this targeted repository exception when stable supplies the fixed Python release; do not perform a general edge upgrade.

The pinned Alpine 3.24 image already resolves to 3.24.3 and remains current. Builds refresh its stable packages rather than carrying separate historical OpenSSL, musl, zlib, or Expat floors. The candidates retain stable musl `1.2.6-r3`, OpenSSL libraries `3.5.9-r0`, zlib `1.3.2-r1`, libexpat `2.9.0-r0`, and curl/libcurl `8.23.0-r0` on every platform. Privateerr application code uses only the Python standard library. Separately installed lint, installer, and documentation toolchains stay in Buccaneerr; Alpine's Python package also retains its bundled [`ensurepip` bootstrap wheel](https://docs.python.org/3.14/library/ensurepip.html) in both images.

## Workaround decisions

| Control or workaround | Decision and evidence |
| --- | --- |
| Curl edge repository and version floor | Removed. [Stable curl 8.23.0](https://pkgs.alpinelinux.org/package/v3.24/main/aarch64/curl) and matching libcurl are available in all three stable indexes. |
| Separate OpenSSL upgrade and musl/zlib/Expat floors | Replaced by a stable-package refresh. The pinned base and stable packages already contain those fixes; actual installed versions were checked on every architecture. |
| System setuptools edge install | Removed. Pip is a temporary build dependency, removed with its dependency group. No separately installed system pip or setuptools distribution remains in ordinary Buccaneerr; Python's bootstrap wheel is retained, and virtualenv's active setuptools seed wheel is 84.2.1. |
| Python security floor | Required as a narrow `@pythonfix` exception until stable includes Python 3.14.10. Its interpreter and bytecode packages are the only installed versions outside stable. |
| markdown-it and smol-toml npm overrides | Removed. markdownlint-cli2 0.24.0 already requires the same fixed versions, 15.0.3 and 1.9.1. Regenerating the lockfile preserves its resolved graph. |
| KaTeX npm override | Retained at 0.19.1. Removing it resolves the math extension's `^0.16.0` dependency to 0.16.47 and restores [CVE-2026-103923](https://github.com/advisories/GHSA-238p-pmpm-9mq7). The final npm audit reports zero findings. |
| Ruff packaging | Updated to 0.17.3 in the hash-verified tool and documentation locks. Official wheels cover all three Linux targets; Alpine's older Ruff package is unnecessary. |
| Inactive virtualenv seed-wheel cleanup | Retained. Only virtualenv's active upstream pip 26.2.2 and setuptools 84.2.1 wheels are retained for Python 3.14; upstream wheel integrity checks remain intact. |
| Compose CVE exception | Retained at its existing path and expiry; see the next section. No exception is added or broadened. |
| Date compatibility shim | Retained. Current upstream PIA still calls `date --date='1 day'`; BusyBox rejects that syntax, while the shim translates it and delegates to BusyBox. No GNU coreutils package is introduced. |
| Hadolint DL3018 package-version exception | Retained for APK installation. Stable package refreshes deliberately accept current security revisions rather than pinning each APK forever; immutable image pins and scans identify the built result. Removing the existing lint flag still produces DL3018. |
| Hadolint DL3064 path exceptions | Retained. Current Hadolint 2.15.1 still flags the non-secret Privateerr install-path argument and environment names when these targeted comments are removed. |

The PIA submodule, Docker CLI 29.9.2, Compose 5.6.1, ShellCheck 0.11.0, Hadolint 2.15.1, actionlint 1.7.12, and direct npm tools are already at their latest upstream releases checked during this review. Stable actionlint's `1.7.12-r3` package is newer than edge's `r2`; switching it to edge would regress its embedded Go runtime. No project-specific Go rebuild or customized pip distribution is added.

## Current Compose exception

The latest official Compose 5.6.1 binary still embeds `golang.org/x/net v0.58.0`; [CVE-2026-78669](https://pkg.go.dev/vuln/GO-2026-6611) requires its fix from x/net 0.60.0. The existing exception covers only `usr/local/lib/docker/cli-plugins/docker-compose` and still expires November 6, 2026. Its scope, expiry, and risk statement are unchanged. A fixed library release does not make the official binary fixed until that binary incorporates it.

This HTTP/2 issue affects clients and servers; being a CLI is not an exemption. Supported checks use trusted fixtures and the wrapper's local Unix Docker socket. The wrapper rejects remote Docker contexts and does not forward `DOCKER_HOST`. Network-enabled runtime tests remain supported, and untrusted HTTP/2 peers outside this boundary retain risk. Remove the exception after compatible official binaries on every supported platform include the fix, or review the remaining risk before the existing expiry. Keep full unfiltered scans regardless of the gate.

## Interpret remaining findings

### Stable musl backport

Both scanners compare installed musl `1.2.6-r3` with an edge `r6` threshold for CVE-2026-107891. Alpine's [stable recipe](https://github.com/alpinelinux/aports/blob/3.24-stable/main/musl/APKBUILD) and [stable security database](https://secdb.alpinelinux.org/v3.24/main.json) record that fix in `1.2.6-r3`. The stable and edge package revision numbers are not interchangeable. The candidate still installs the stable backport; it does not move the C library to edge or suppress this finding. Trivy reports the package twice for musl and musl-utils, while Scout reports one advisory.

### Official Go tools

Alpine actionlint `1.7.12-r3` embeds Go 1.26.9 and still reports CVE-2026-111943. It also reports the Windows-specific x/sys advisory [CVE-2026-39824](https://pkg.go.dev/vuln/GO-2026-5024). The latest official upstream release and the current edge package do not provide a better compatible binary. Keep the finding visible while awaiting an official package update; no actionlint exception is added.

Compose retains the HTTP/2 finding, four MEDIUM x/net reports, and the [OpenPGP module advisory](https://pkg.go.dev/vuln/GO-2026-5932). Scout additionally reports the Windows plugin-discovery advisory [CVE-2025-15558](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p). Module metadata does not prove that every affected package is invoked by supported commands. This review preserves those reports and does not claim all tool behavior is non-exploitable.

### Python bootstrap wheel

The candidates retain `/usr/lib/python3.14/ensurepip/_bundled/pip-26.2.2-py3-none-any.whl` from Alpine's Python package. There is no separately installed system pip or setuptools distribution, but this archive contains actual installer modules, including pip-vendored msgpack 1.1.2, urllib3 2.7.0, and `pkg_resources` recorded as setuptools 70.3.0. The wheel is available to `python3 -m ensurepip`; Privateerr does not invoke it.

The retained wheel is byte-identical across all three production candidate architectures (SHA-256 `fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70`). The production whole-image reports do not inventory its nested modules. Even after expanding the wheel, an unfiltered Trivy 0.76.1 filesystem scan with the same database detected no Python package manifests; its zero findings do not establish vendored-component coverage.

A separate metadata-guided Trivy 0.76.1 scan of the wheel's unchanged `pip/_vendor/vendor.txt`, using an explicit parser selection, reports seven version-level advisory entries for msgpack, urllib3, and the setuptools label used for bundled `pkg_resources`. These are additional dependency-version findings, outside the whole-image totals. They do not establish that every advisory affects the included code or Privateerr's supported execution path; in particular, `pkg_resources` is only part of setuptools. Preserve the upstream Python assets and SBOM, track complete upstream pip fixes, and assess relevant code paths separately.

### Installer code and upstream inventory

Scout also reads `virtualenv-21.14.13.dist-info/sboms/virtualenv.cdx.json`. That upstream inventory still lists older wheels and vendored versions after inactive wheel archives are removed. Direct inspection confirms that the retained pip 26.2.2 wheel vendors requests 2.34.2, certifi 2026.10.19, idna 3.18, and Pygments 2.20.0. Reports for older versions of those components, pip 26.0.1, and setuptools 82.0.1 describe inventory entries rather than the retained versions. In particular, the reported certifi 2026.1.4 trust-store advisory does not describe the retained certifi 2026.10.19 code.

The active pip wheel still vendors msgpack 1.1.2, urllib3 2.7.0, and the pkg_resources portion recorded as setuptools 70.3.0. Version-level findings for those components require separate code-path assessment; inventory for the complete setuptools distribution is not proof that all its modules exist inside pip. The latest upstream pip remains 26.2.2, so there is no newer complete upstream wheel to adopt. Standalone package upgrades do not replace vendored code. Keep the reports visible and the upstream SBOM intact; do not rewrite inventory or partially patch the wheel to reduce scanner counts.

The [braces advisory CVE-2026-93687](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) was withdrawn upstream on October 23. It is absent from the fresh reports and final npm audit; no project exception hides it.

## Reviewed artifact identities

These immutable published indices identify the `latest` and `edge` snapshots used above. They are not aliases for the local candidates.

| Image | Published tag | Index digest |
| --- | --- | --- |
| Privateerr | `latest` | `sha256:430e49888564838517ff073c48b5ece02ca44af385c6b73c8ad0121126d3331e` |
| Privateerr | `edge` | `sha256:cf132360969f87490de8e4bd77c89996067694b67ca75abf91788b75ed5478bd` |
| Buccaneerr | `latest` | `sha256:f4634ed5656950b18d6592ef11939160da35659c3ec2d2bef971f6a7c8f2e0d9` |
| Buccaneerr | `edge` | `sha256:78e13b2aaad73970889000957a6bc9a39cb6ac9b547c148e742ea4ee7a8a51ee` |

The local candidate runtime manifests below identify the exact built and scanned artifacts. All three platforms have the same reviewed runtime and tool versions and advisory sets described above. The checks verify Python 3.14.10, stable library versions, removed temporary pip/setuptools APK packages, and unchanged upstream seed-wheel contents. Published release images must be checked separately after their normal build and publication workflow.

| Candidate | Platform | Runtime manifest digest |
| --- | --- | --- |
| Privateerr | `linux/amd64` | `sha256:cc003125474ce7f6a519370137454464694e54c2af2c677c512d047989af24be` |
| Privateerr | `linux/arm64` | `sha256:d6faf0815569713731b42393775382e8318229705833de9cc0275b9caf571673` |
| Privateerr | `linux/arm/v7` | `sha256:1b1f88649d0a4e6375f1140ecd5e856da60d08cec995e5bb1b1a981f4a24ca6d` |
| Buccaneerr | `linux/amd64` | `sha256:2a5d4955c35cc1f6446cfef70e159af802874dab1fca6cf81f69a8b2e3ed4238` |
| Buccaneerr | `linux/arm64` | `sha256:53e6a708cb41239df28ba51b29afd7c3a0a32d75a471351a5b1a373da454ef8a` |
| Buccaneerr | `linux/arm/v7` | `sha256:8c53763caf48f67f44e066dd2ed01c8cc03a39e2036fac10267b94fef68bc4cb` |

## Repeat the review

Scan an immutable published runtime digest with every severity, unfixed findings, and no repository exceptions:

```sh
trivy image --image-src remote --scanners vuln --detection-priority comprehensive --ignorefile /dev/null ghcr.io/scottgigawatt/privateerr@sha256:IMAGE-DIGEST
```

Replace `IMAGE-DIGEST` with the runtime manifest digest for the platform being reviewed. Repeat for Buccaneerr. For Scout, use the published image index digest with an explicit platform so it can select the matching attestation:

```sh
docker scout cves registry://ghcr.io/scottgigawatt/privateerr@sha256:IMAGE-DIGEST --platform linux/amd64
```

Repeat for all supported platforms, retain scanner versions and database timestamps, and inspect the installed files behind remaining reports. A multi-platform OCI archive is not a Docker image archive: extract the layout and select one runtime manifest for Trivy, or prepare a Docker archive preserving that manifest's configuration and layers. Verify the reported architecture; a requested platform flag alone does not establish what was scanned.

To repeat the metadata-guided bootstrap dependency check, extract the retained wheel into a disposable directory. Replace `EXTRACTED-WHEEL-DIRECTORY` with that directory and `TRIVY-CACHE-DIRECTORY` with the cache containing the recorded database. The parser selection reads the existing vendoring manifest without changing it:

```sh
trivy fs --scanners vuln --detection-priority comprehensive \
    --ignorefile /dev/null --file-patterns 'pip:(^|/)vendor\.txt$' \
    --cache-dir "TRIVY-CACHE-DIRECTORY" --skip-db-update "EXTRACTED-WHEEL-DIRECTORY"
```
