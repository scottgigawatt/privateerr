# Container security review

This review checks local Privateerr and Buccaneerr update candidates on October 28, 2026 (UTC). Every image was examined on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. These candidates are review artifacts; changing source does not publish an image or advance `latest`.

## Subsequent Markdown-tooling fix

Pull-request CI later detected [CVE-2026-116795](https://github.com/le0pard/re2js/security/advisories/GHSA-gg6h-894w-4m9c) in Buccaneerr's re2js 2.8.6 dependency. Upstream fixes its repeated lookbehind matching in [2.8.7](https://github.com/le0pard/re2js/releases/tag/2.8.7). Markdownlint 0.42.0 still pins 2.8.6, so the test-tool manifest overrides only markdownlint's re2js to 2.8.7 and locks its published integrity hash. Remove that override when a compatible Markdownlint release includes the fix. No scan exception is added.

The candidate identities and totals below predate this follow-up and do not describe rebuilt images containing the override.

## Scan scope and results

Trivy 0.76.1 used comprehensive detection with all severities, unfixed findings, and an explicit empty ignore file. Its database was updated at `2026-10-28 01:21:08 UTC` and held constant for all six scans. Local OCI builds were inspected one runtime manifest at a time; their exact configuration and layer contents were preserved when preparing Docker archives. Each Trivy report's architecture was checked against its selected manifest. Docker Scout 1.27.0 also ran without severity or fix-status filters on the same six platform archives. Its report instances and distinct advisory identifiers are counted separately because aliases can describe the same issue.

The counts below are identical on all three platforms:

| Image | Artifact | Trivy findings | Scout instances | Scout identifiers |
| --- | --- | --- | --- | --- |
| Privateerr | Local stable-Python candidate | 0 | 1 | 1 |
| Buccaneerr | Local stable-Python candidate | 10 | 38 | 34 |

Whole-image scanner totals do not establish coverage of every embedded archive. Python's retained `ensurepip` bootstrap wheel requires the separate inspection described below. Buccaneerr retains upstream tool findings; this review does not declare either image free of vulnerabilities. The normal CI gate is narrower than this audit: it rejects fixed HIGH/CRITICAL findings, uses precise detection by default, and applies the one exact-path Compose exception.

## Production runtime updates

Both candidates install Python `3.14.10-r1`, including the [October 26 upstream security fixes](https://discuss.python.org/t/python-3-15-2-3-14-10-3-13-18-3-12-16-and-3-11-18-are-out/109678) for CVE-2026-12345, CVE-2026-114583, and CVE-2026-115557. These cover temporary-directory cleanup, archive filtering, and blocking compromised certificate keys. The certificate denylist is a security backstop; it does not replace a maintained trust store.

Alpine 3.24 stable supplies Python and its matching bytecode packages at `3.14.10-r1` on all three architectures. Both Dockerfiles install Python from stable before temporary bootstrap tools. The temporary tagged edge repository and Python version floor are unnecessary. Installed APK databases on all six candidate platforms confirm that every package version matches the stable repository indexes. The [r1 packaging revision](https://github.com/alpinelinux/aports/commit/831cfeb7301d5010c027905e42958312698f4e4a) requires Expat 2.9.0, which is already installed; the Python application interface is unchanged.

The pinned Alpine 3.24 image already resolves to 3.24.3 and remains current. Builds refresh its stable packages rather than carrying separate historical OpenSSL, musl, zlib, or Expat floors. The candidates retain stable musl `1.2.6-r3`, OpenSSL libraries `3.5.9-r0`, zlib `1.3.2-r1`, libexpat `2.9.0-r0`, and curl/libcurl `8.23.0-r0` on every platform. Privateerr application code uses only the Python standard library. Separately installed lint, installer, and documentation toolchains stay in Buccaneerr; Alpine's Python package also retains its bundled [`ensurepip` bootstrap wheel](https://docs.python.org/3.14/library/ensurepip.html) in both images.

## Workaround decisions

| Control or workaround | Decision and evidence |
| --- | --- |
| Curl edge repository and version floor | Removed. [Stable curl 8.23.0](https://pkgs.alpinelinux.org/package/v3.24/main/aarch64/curl) and matching libcurl are available in all three stable indexes. |
| Separate OpenSSL upgrade and musl/zlib/Expat floors | Replaced by a stable-package refresh. The pinned base and stable packages already contain those fixes; actual installed versions were checked on every architecture. |
| System setuptools edge install | Removed. Pip is a temporary build dependency, removed with its dependency group. No separately installed system pip or setuptools distribution remains in ordinary Buccaneerr; Python's bootstrap wheel is retained, and virtualenv's active setuptools seed wheel is 84.2.1. |
| Python edge repository and security floor | Removed. Stable supplies Python and its matching bytecode packages at 3.14.10-r1 on every supported architecture; no installed APK version comes from edge. |
| markdown-it and smol-toml npm overrides | Removed. markdownlint-cli2 0.24.0 already requires the same fixed versions, 15.0.3 and 1.9.1. Regenerating the lockfile preserves its resolved graph. |
| KaTeX npm override | Retained at 0.19.1. Removing it resolves the math extension's `^0.16.0` dependency to 0.16.47 and restores [CVE-2026-103923](https://github.com/advisories/GHSA-238p-pmpm-9mq7). The final npm audit reports zero findings. |
| Ruff packaging | Updated to 0.17.3 in the hash-verified tool and documentation locks. Official wheels cover all three Linux targets; Alpine's older Ruff package is unnecessary. |
| Inactive virtualenv seed-wheel cleanup | Retained. Only virtualenv's active upstream pip 26.2.2 and setuptools 84.2.1 wheels are retained for Python 3.14; upstream wheel integrity checks remain intact. |
| Compose CVE exception | Retained at its existing path and expiry; see the next section. No exception is added or broadened. |
| Date compatibility shim | Retained. Current upstream PIA still calls `date --date='1 day'`; BusyBox rejects that syntax, while the shim translates it and delegates to BusyBox. No GNU coreutils package is introduced. |
| Hadolint DL3018 package-version exception | Retained for APK installation. Stable package refreshes deliberately accept current security revisions rather than pinning each APK forever; immutable image pins and scans identify the built result. Removing the existing lint flag still produces DL3018. |
| Hadolint DL3064 path exceptions | Retained. Current Hadolint 2.15.1 still flags the non-secret Privateerr install-path argument and environment names when these targeted comments are removed. |

The PIA submodule and reviewed Docker CLI 29.9.2, Compose 5.6.1, ShellCheck 0.11.0, Hadolint 2.15.1, actionlint 1.7.12, and direct npm tool pins are unchanged. Stable actionlint's `1.7.12-r3` package is newer than edge's `r2`; switching it to edge would regress its embedded Go runtime. No project-specific Go rebuild or customized pip distribution is added.

## Current Compose exception

The latest official Compose 5.6.1 binary still embeds `golang.org/x/net v0.58.0`; [CVE-2026-78669](https://pkg.go.dev/vuln/GO-2026-6611) requires its fix from x/net 0.60.0. The existing exception covers only `usr/local/lib/docker/cli-plugins/docker-compose` and still expires November 6, 2026. Its scope, expiry, and risk statement are unchanged. A fixed library release does not make the official binary fixed until that binary incorporates it.

This HTTP/2 issue affects clients and servers; being a CLI is not an exemption. Supported checks use trusted fixtures and the wrapper's local Unix Docker socket. The wrapper rejects remote Docker contexts and does not forward `DOCKER_HOST`. Network-enabled runtime tests remain supported, and untrusted HTTP/2 peers outside this boundary retain risk. Remove the exception after compatible official binaries on every supported platform include the fix, or review the remaining risk before the existing expiry. Keep full unfiltered scans regardless of the gate.

## Interpret remaining findings

### Stable musl backport

Alpine's [stable recipe](https://github.com/alpinelinux/aports/blob/3.24-stable/main/musl/APKBUILD) and [stable security database](https://secdb.alpinelinux.org/v3.24/main.json) record CVE-2026-107891 fixed in musl `1.2.6-r3`. Every candidate retains that stable backport. With only stable repositories configured, Trivy no longer selects the edge `r6` threshold and reports no musl finding. Scout still compares the stable package with the edge `r6` threshold and reports one advisory. Stable and edge package revision numbers are not interchangeable; no musl suppression is added.

### Official Go tools

Alpine actionlint `1.7.12-r3` embeds Go 1.26.9 and still reports CVE-2026-111943. It also reports the Windows-specific x/sys advisory [CVE-2026-39824](https://pkg.go.dev/vuln/GO-2026-5024). The latest official upstream release and the current edge package do not provide a better compatible binary. Keep the finding visible while awaiting an official package update; no actionlint exception is added.

Compose retains the HTTP/2 finding, four MEDIUM x/net reports, and the [OpenPGP module advisory](https://pkg.go.dev/vuln/GO-2026-5932). The fresh database also reports two UNKNOWN HTML-package advisories, [CVE-2026-78661](https://pkg.go.dev/vuln/GO-2026-6860) and [CVE-2026-97045](https://pkg.go.dev/vuln/GO-2026-6866), fixed in x/net 0.62.0. The affected `golang.org/x/net/html` package is absent from the compiled Compose binary on all three platforms. Scout also reports the Windows plugin-discovery advisory [CVE-2025-15558](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p). These module-level reports remain visible without new exceptions. Module metadata does not establish that every affected package is invoked by supported commands, and this review does not claim all tool behavior is non-exploitable.

### Python bootstrap wheel

The candidates retain `/usr/lib/python3.14/ensurepip/_bundled/pip-26.2.2-py3-none-any.whl` from Alpine's Python package. There is no separately installed system pip or setuptools distribution, but this archive contains actual installer modules, including pip-vendored msgpack 1.1.2, urllib3 2.7.0, and `pkg_resources` recorded as setuptools 70.3.0. The wheel is available to `python3 -m ensurepip`; Privateerr does not invoke it.

The retained wheel is byte-identical across all six candidate artifacts (SHA-256 `fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70`). The production whole-image reports do not inventory its nested modules. A generic filesystem scan does not necessarily identify its nested vendored components; a zero whole-image total does not establish their coverage.

A separate metadata-guided Trivy 0.76.1 scan of the wheel's unchanged `pip/_vendor/vendor.txt`, using an explicit parser selection, reports eight version-level advisory entries for msgpack, urllib3, and the setuptools label used for bundled `pkg_resources`. These are additional dependency-version findings, outside the whole-image totals. They do not establish that every advisory affects the included code or Privateerr's supported execution path; in particular, `pkg_resources` is only part of setuptools. Preserve the upstream Python assets and SBOM, track complete upstream pip fixes, and assess relevant code paths separately.

### Installer code and upstream inventory

The upstream `virtualenv-21.14.13.dist-info/sboms/virtualenv.cdx.json` remains available to scanners. That upstream inventory still lists older wheels and vendored versions after inactive wheel archives are removed. Direct inspection confirms that the retained pip 26.2.2 wheel vendors requests 2.34.2, certifi 2026.10.19, idna 3.18, and Pygments 2.20.0. Reports for older versions of those components, pip 26.0.1, and setuptools 82.0.1 describe inventory entries rather than the retained versions. In particular, the reported certifi 2026.1.4 trust-store advisory does not describe the retained certifi 2026.10.19 code.

The active pip wheel still vendors msgpack 1.1.2, urllib3 2.7.0, and the pkg_resources portion recorded as setuptools 70.3.0. Version-level findings for those components require separate code-path assessment; inventory for the complete setuptools distribution is not proof that all its modules exist inside pip. The latest upstream pip remains 26.2.2, so there is no newer complete upstream wheel to adopt. Standalone package upgrades do not replace vendored code. Keep the reports visible and the upstream SBOM intact; do not rewrite inventory or partially patch the wheel to reduce scanner counts.

The [braces advisory CVE-2026-93687](https://github.com/advisories/GHSA-vfj7-8cjw-p6xm) was withdrawn upstream on October 23. It is absent from the fresh reports and final npm audit; no project exception hides it.

## Reviewed artifact identities

The runtime manifests below identify the exact local artifacts built and scanned for this review. All three platforms have the same reviewed runtime and tool versions and advisory sets. Checks verify the complete Python 3.14.10-r1 package family, stable repositories and library versions, removed temporary pip/setuptools APK packages, and unchanged upstream bootstrap-wheel contents. Published release images must be verified separately after their normal build and publication workflow.

| Candidate | Platform | Runtime manifest digest |
| --- | --- | --- |
| Privateerr | `linux/amd64` | `sha256:cc60f9c1dd56da19562d39b812dac283104b8f77e34ff8432b69119aa5bf6254` |
| Privateerr | `linux/arm64` | `sha256:c062919d10886e8c1054058b5bc366d8782d5a14789d6c8ea1da09b0e36b0104` |
| Privateerr | `linux/arm/v7` | `sha256:719beb0bac5d6d7e5f8eed081ec3077cc060ec9e1100e7f90583066e7da63b1d` |
| Buccaneerr | `linux/amd64` | `sha256:bc4b99a9d447c586a83d542e649255ae734cd6cf065874e0ad0732551e85e2a5` |
| Buccaneerr | `linux/arm64` | `sha256:45bbb9f0c6196ebe5fc6748e2a3075aa6e3f56ee0789620f1c056c74a1f4208f` |
| Buccaneerr | `linux/arm/v7` | `sha256:84b4d2753918f9a950638122968a4a71b2dcef71e94b8b82edd27d435a9e604a` |

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
