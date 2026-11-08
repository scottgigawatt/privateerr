# Container security review

The historical review below checks local Privateerr and Buccaneerr update candidates on October 28, 2026 (UTC). Every image was examined on `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. These candidates are review artifacts; changing source does not publish an image or advance `latest`.

## November 8, 2026 temporary Compose exception

This section is for maintainers reviewing the temporary CI exception for Buccaneerr. Trivy now classifies [CVE-2026-78661 / GO-2026-6860](https://pkg.go.dev/vuln/GO-2026-6860) as HIGH in Compose's `golang.org/x/net v0.60.0` module. The affected HTML parser is fixed upstream in x/net 0.62.0. At this check, the latest [official Compose release](https://github.com/docker/compose/releases/tag/v5.7.0) remained 5.7.0; no newer official donor containing that module fix was available. The exception is justified by absent affected code in the reviewed binary, not by an absence of an upstream module fix. The November 4 UNKNOWN and November 8 HIGH classifications come from dated scanner/database results for the same immutable donor; the earlier counts remain historical evidence.

The [temporary exception](https://github.com/scottgigawatt/privateerr/blob/main/.trivyignore.yaml) excludes only `CVE-2026-78661` at `usr/local/lib/docker/cli-plugins/docker-compose`. Its owner is `scottgigawatt`. Trivy stops applying it on **November 22, 2026 at 00:00 UTC**. It applies only to the Buccaneerr scan in pull-request and publication workflows. Production Privateerr scans have no exception. Every other finding remains subject to the existing scan policy. Affected CI scans enable `TRIVY_SHOW_SUPPRESSED`, so the ignored finding and its justification remain visible. Raw audits continue to use `--ignorefile /dev/null`.

### Verify the reviewed binary

The reviewed donor is `docker/compose-bin:v5.7.0@sha256:a4de4851b16f18634f74de66f126d5de65f7c5cb5a9502d67ab83e9a96041a70`. A fresh read-only registry extraction verified the SHA-256 of its index, selected manifests, configurations, and layers before extracting `/docker-compose` with its original executable mode `0755`. Configuration architecture matched each requested Linux platform. No extracted binary was executed.

| Platform | Donor runtime manifest | Extracted binary SHA-256 |
| --- | --- | --- |
| `linux/amd64` | `sha256:c34e6c54a19b3ac03edc915dd6115880c491a36fce89e0679962e5db6f36e81a` | `7758048ad38e580f22559603312874fec8bb638d021a9e64182385fc17cc12a2` |
| `linux/arm64` | `sha256:631696b7b690e6009ad3155d78a9b998e7db8cf407b987aefa4ab159e2d25dca` | `15861535d14e26555736b49376c95e14bfd94285366c8446bfac7156a972e76f` |
| `linux/arm/v7` | `sha256:1f08c4d07dd5f18fdf6be60c71bc3067e8cab0020e39f33a8678e610b89f5f44` | `d18e5c549fd3595b36846fe00d01e2af5a37d4baec7945c557a0abda9af63c91` |

Go 1.27.3 and `govulncheck v1.9.0` inspected the binaries, which were built with Go 1.26.10. `go version -m` confirmed x/net 0.60.0. Both `go tool nm` and `govulncheck -mode=extract` recovered symbols successfully; neither found the affected `golang.org/x/net/html` package or its nested packages. Nonzero x/net symbol counts provide a positive control against an empty or failed extraction.

| Platform | Recovered Go symbols | x/net symbols | HTML package symbols |
| --- | --- | --- | --- |
| `linux/amd64` | 37,364 | 396 | 0 |
| `linux/arm64` | 37,311 | 395 | 0 |
| `linux/arm/v7` | 37,648 | 396 | 0 |

To repeat this check, use Go 1.27.3, `govulncheck v1.9.0`, and `jq`. Extract the binary from a manifest above into a disposable directory, verify its SHA-256, and set `COMPOSE_BINARY` to that local path. These commands inspect the binary without executing it:

```sh
go version -m "${COMPOSE_BINARY}"
go tool nm "${COMPOSE_BINARY}" > compose-symbols.txt
govulncheck -mode=extract "${COMPOSE_BINARY}" > compose-symbols.jsonl
govulncheck -mode=binary -scan=symbol -json "${COMPOSE_BINARY}" > compose-vulnerabilities.json
jq -s -e '.[1].pkgSymbols as $symbols | ($symbols | length > 0) and any($symbols[]; (.pkg // "") | startswith("golang.org/x/net/")) and all($symbols[]; (.pkg != "golang.org/x/net/html") and ((.pkg // "") | startswith("golang.org/x/net/html/") | not))' compose-symbols.jsonl
```

The final command must succeed. Retain the module-level reports: binary-mode govulncheck still reports GO-2026-6860 against x/net 0.60.0, but without an affected package or symbol trace. This review does not declare Compose vulnerability-free or establish that unrelated findings are harmless.

### Check filtering and expiry

The exact CI engine, Trivy 0.70.0, was tested locally using its checksum-verified official macOS ARM64 release archive (SHA-256 `68e543c51dcc96e1c344053a4fde9660cf602c25565d9f09dc17dd41e13b838a`). Its fresh database was updated at `2026-11-08 00:37:11 UTC` and held constant. Image-style `trivy rootfs` scans using both the CI default precise detection and comprehensive detection inspected the verified amd64 binary in an isolated filesystem at the reviewed path; the package and symbol review above covers all three platforms. A plain `trivy filesystem` scan does not provide equivalent compiled-binary coverage.

| Actual Trivy 0.70.0 check | Result |
| --- | --- |
| HIGH/CRITICAL gate with an empty ignore file | Exit 1; the HIGH finding remains |
| Same gate with the active exact-path exception | Exit 0; the finding is recorded as ignored |
| Same gate with an expired copy of the exception | Exit 1; the finding returns |
| Same CVE in a second binary at another path | Exit 1; the second binary remains affected by the gate |
| All-severity, unfixed-inclusive raw and filtered reports | Only CVE-2026-78661 is excluded from active findings; CVE-2026-97045 and GO-2026-5932 remain visible |

The JSON reports used `--show-suppressed`; the excluded finding appears in `ExperimentalModifiedFindings` with status `ignored`, its source file, and its statement. A passing filtered gate is not an unfiltered clean scan.

### Remove or reassess the exception

The [scope guard](https://github.com/scottgigawatt/privateerr/blob/main/test/policy/check-compose-exception-policy.sh) and [rejection fixtures](https://github.com/scottgigawatt/privateerr/blob/main/test/helpers/test-compose-exception-policy.sh) run through pre-commit and `make test-workflows`. They reject a changed donor declaration, another path or advisory, a second exception, or an extended expiry. Trivy enforces the UTC expiry; the guard checks the reviewed policy values rather than the current clock.

1. Before the expiry, check for an official donor containing x/net 0.62.0 or later. Review its binary contents and run unfiltered scans on every supported platform before accepting a pin update.
2. Remove this exception sooner if the donor changes, affected HTML code becomes present, or the upstream fix can be adopted. A changed donor requires a new code-path assessment; the current exception cannot be carried forward automatically.
3. When removing the exception, remove `.trivyignore.yaml`, its `trivyignores` and `TRIVY_SHOW_SUPPRESSED` workflow settings, the dedicated guard and fixture scripts, their calls in `test-workflow-helpers.sh`, and the dedicated pre-commit hook. Update the build path filter and this dated decision together.
4. Run `make test-workflows`, the repository hooks, and strict documentation checks. Confirm the unfiltered image gate passes before merging a fix. Do not extend the exception solely to obtain a green build.

The older CVE-2026-78669 exception remains removed. This decision neither restores that exception nor suppresses CVE-2026-97045 or other Compose advisories.

## November 4, 2026 official Compose update

Buccaneerr now copies Docker's published [Compose 5.7.0 binary](https://github.com/docker/compose/releases/tag/v5.7.0) from the immutable donor index `sha256:a4de4851b16f18634f74de66f126d5de65f7c5cb5a9502d67ab83e9a96041a70`. The index supplies `linux/amd64`, `linux/arm64`, and `linux/arm/v7`. It includes `golang.org/x/net v0.60.0`, which fixes CVE-2026-78669 and four additional x/net advisories present in the previous donor. No project-specific Go build is introduced.

Trivy 0.76.1 compared both immutable donor indexes on all three platforms using comprehensive detection, every severity, unfixed findings, and an explicit empty ignore file. The same database, updated at `2026-11-03 19:16:30 UTC`, was held constant for all six scans. Reported image architectures matched the requested platforms. Findings fell from eight to three on each platform: CVE-2026-78669, CVE-2026-78659, CVE-2026-78660, CVE-2026-78663, and CVE-2026-97032 are absent from 5.7.0. GO-2026-5932, CVE-2026-78661, and CVE-2026-97045 remain visible at UNKNOWN severity; this update does not claim a vulnerability-free binary.

These donor-image results are separate from the published-image recheck below. The earlier candidate identities and counts remain historical evidence.

## Subsequent Markdown-tooling fix

Pull-request CI later detected [CVE-2026-116795](https://github.com/le0pard/re2js/security/advisories/GHSA-gg6h-894w-4m9c) in Buccaneerr's re2js 2.8.6 dependency. Upstream fixes its repeated lookbehind matching in [2.8.7](https://github.com/le0pard/re2js/releases/tag/2.8.7). Markdownlint 0.42.0 still pins 2.8.6, so the test-tool manifest overrides only markdownlint's re2js to a patched release and locks its published integrity hash. Remove that override when a compatible Markdownlint release includes the fix. No scan exception is added.

The candidate identities and totals below predate this follow-up and the actionlint rebuild described below. They do not describe rebuilt images containing those fixes.

## Scan scope and results

Trivy 0.76.1 used comprehensive detection with all severities, unfixed findings, and an explicit empty ignore file. Its database was updated at `2026-10-28 01:21:08 UTC` and held constant for all six scans. Local OCI builds were inspected one runtime manifest at a time; their exact configuration and layer contents were preserved when preparing Docker archives. Each Trivy report's architecture was checked against its selected manifest. Docker Scout 1.27.0 also ran without severity or fix-status filters on the same six platform archives. Its report instances and distinct advisory identifiers are counted separately because aliases can describe the same issue.

The counts below are identical on all three platforms:

| Image | Artifact | Trivy findings | Scout instances | Scout identifiers |
| --- | --- | --- | --- | --- |
| Privateerr | Local stable-Python candidate | 0 | 1 | 1 |
| Buccaneerr | Local stable-Python candidate | 10 | 38 | 34 |

Whole-image scanner totals do not establish coverage of every embedded archive. Python's retained `ensurepip` bootstrap wheel requires the separate inspection described below. Buccaneerr retains upstream tool findings; this review does not declare either image free of vulnerabilities. The normal CI gate is narrower than this audit: it rejects other fixed HIGH/CRITICAL findings and uses precise detection by default. The November 4 removal concerned CVE-2026-78669; the [November 8 decision](#november-8-2026-temporary-compose-exception) documents the new CVE-2026-78661-only exception.

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
| Compose CVE-2026-78669 exception | Removed on November 4 after the official fix and unfiltered published-image scans confirmed clearance on every platform; see the next section. |
| Date compatibility shim | Retained. Current upstream PIA still calls `date --date='1 day'`; BusyBox rejects that syntax, while the shim translates it and delegates to BusyBox. No GNU coreutils package is introduced. |
| Hadolint DL3018 package-version exception | Retained for APK installation. Stable package refreshes deliberately accept current security revisions rather than pinning each APK forever; immutable image pins and scans identify the built result. Removing the existing lint flag still produces DL3018. |
| Hadolint DL3064 path exceptions | Retained. Current Hadolint 2.15.1 still flags the non-secret Privateerr install-path argument and environment names when these targeted comments are removed. |

The PIA submodule and reviewed Docker CLI 29.9.2, Compose 5.6.1, ShellCheck 0.11.0, Hadolint 2.15.1, actionlint 1.7.12, and direct npm tool pins are unchanged. The October 29 package check found a new signed edge actionlint `1.7.12-r3` rebuild using Go 1.27.3 on all three platforms. The test image fetches only that APK from a command-line-only edge source and installs it locally; dependencies and configured repositories remain on stable, with no retained repository tag. Execution and package-closure checks on all three target architectures confirm compatibility without upgrading musl or other stable libraries. No project-specific Go rebuild or customized pip distribution is added.

## Removed Compose exception

The exact-path exception for [CVE-2026-78669](https://pkg.go.dev/vuln/GO-2026-6611) is removed, together with the unused ignore file and workflow references. Official Compose 5.7.0 contains the fix from x/net 0.60.0 on every supported platform. That November 4 change retained the fixed HIGH/CRITICAL gate and added no exception. The separate November 8 decision above concerns only CVE-2026-78661.

On November 4, Trivy 0.76.1 scanned all three runtime manifests from published Buccaneerr index `sha256:c723041fad63f778985e6a31f3406b856e89c4e0851b389ba6b10c2789973c97`, built from source `28ab2a6f8598d92377df059c9d41191cdcfebca5`. The database updated at `2026-11-04 13:16:53 UTC` was held constant. Comprehensive detection included every severity and unfixed findings with an explicit empty ignore file. Each reported architecture matched the selected manifest.

| Platform | Published runtime manifest digest |
| --- | --- |
| `linux/amd64` | `sha256:2fba0cecebadedfdbbc9c2e6242fdf84dec17f364f2b1a9359470fe314744b7e` |
| `linux/arm64` | `sha256:482f95726a00af6d33b96ccc029a33ffa1dd6a291ad89337c4c8157f81162250` |
| `linux/arm/v7` | `sha256:8e02ea36d41fa87af35c0c0bae2bc9ef54e3e1c63b6d4baa34ebc823aaabc3b3` |

CVE-2026-78669 is absent from every report. Each platform retains four UNKNOWN findings: actionlint's CVE-2026-39824 and Compose's GO-2026-5932, CVE-2026-78661, and CVE-2026-97045. There are no HIGH or CRITICAL findings in these reports. This result does not establish coverage of nested archives or claim vulnerability-free images. The current database now identifies an upstream fix for GO-2026-5932; Compose 5.7.0 still contains the older module.

Removing the exception does not update previously released images. Buccaneerr from the existing Privateerr v2.4.0 stable release still contains Compose 5.6.1; the verified fix is available in the published edge image above. No stable release is created by this cleanup.

## Interpret remaining findings

### Stable musl backport

Alpine's [stable recipe](https://github.com/alpinelinux/aports/blob/3.24-stable/main/musl/APKBUILD) and [stable security database](https://secdb.alpinelinux.org/v3.24/main.json) record CVE-2026-107891 fixed in musl `1.2.6-r3`. Every candidate retains that stable backport. With only stable repositories configured, Trivy no longer selects the edge `r6` threshold and reports no musl finding. Scout still compares the stable package with the edge `r6` threshold and reports one advisory. Stable and edge package revision numbers are not interchangeable; no musl suppression is added.

### Official Go tools

The local candidates above use stable actionlint `1.7.12-r3` with Go 1.26.9 and report CVE-2026-111943. The [new official edge rebuild](https://pkgs.alpinelinux.org/package/edge/community/aarch64/actionlint) retains the same actionlint version but uses Go 1.27.3, fixing that standard-library finding. Its native binaries were checked on all three supported architectures. The Windows-specific x/sys advisory [CVE-2026-39824](https://pkg.go.dev/vuln/GO-2026-5024) remains visible in the unfiltered module inventory; no actionlint exception is added.

Compose retains the HTTP/2 finding, four MEDIUM x/net reports, and the [OpenPGP module advisory](https://pkg.go.dev/vuln/GO-2026-5932). The fresh database also reports two UNKNOWN HTML-package advisories, [CVE-2026-78661](https://pkg.go.dev/vuln/GO-2026-6860) and [CVE-2026-97045](https://pkg.go.dev/vuln/GO-2026-6866), fixed in x/net 0.62.0. The affected `golang.org/x/net/html` package is absent from the compiled Compose binary on all three platforms. Scout also reports the Windows plugin-discovery advisory [CVE-2025-15558](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p). These module-level reports remain visible in unfiltered audits. The November 8 decision above changes only CI handling of CVE-2026-78661 at the reviewed binary path. Module metadata does not establish that every affected package is invoked by supported commands, and this review does not claim all tool behavior is non-exploitable.

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
