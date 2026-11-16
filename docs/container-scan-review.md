# Container security review

Use this page to assess published image findings, unreleased fixes, retained security controls, and the conditions for removing the temporary Compose exception. Privateerr uses only the Python standard library; validation and documentation tools belong to the test-only Buccaneerr image.

## November 16, 2026 published image audit

Trivy 0.76.2 used comprehensive detection, every severity, unfixed findings, and an explicit empty ignore file. Its database was updated at `2026-11-16 18:50:18 UTC` and held constant. Each scan selected an immutable runtime manifest and verified the reported architecture and ARM variant against that manifest. Each row covers `linux/amd64`, `linux/arm64`, and `linux/arm/v7`:

| Published image | Whole-image findings per platform |
| --- | --- |
| Privateerr `edge` | 0 |
| Privateerr `latest` (`2.4.4`) | 0 |
| Buccaneerr `edge` | 1 HIGH, 3 MEDIUM, 4 UNKNOWN |
| Buccaneerr `latest` (`2.4.4`) | 1 HIGH, 3 MEDIUM, 4 UNKNOWN |

The immutable index digests are:

- Privateerr `edge`: `sha256:025f5344df3cedb6930621b3a322b9a98dd6b89918b03619cbc4bd18095b2a91`
- Privateerr `latest`: `sha256:10817f1d091e591cf13dd8c9189341f88035ee777758313b9ee8107660ffba1c`
- Buccaneerr `edge`: `sha256:75c9d971d4f6c73fd0ba78b1ff1f90fe5bcfd94001226129cf63ebfcaf686737`
- Buccaneerr `latest`: `sha256:6d1531091964f63a6a02117d6ab5855a1a05f8cf4fdf26cce90a3a5c11b04fc4`

All twelve published runtime images pass the normal filtered gate, which uses precise detection and fixable HIGH/CRITICAL findings. Buccaneerr's one HIGH Compose finding is suppressed by the existing exact-path exception; the unfiltered counts above include it. No OS-package findings were reported. Successful main builds advance `edge`; a separately authorized stable release is required to advance `latest`.

These totals do not cover every nested archive. The separate [Python bootstrap-wheel assessment](#python-bootstrap-wheel) still requires review; zero whole-image findings do not establish vulnerability-free images.

## Docker CLI security fix

Buccaneerr copies the official [Docker CLI 29.10.0](https://docs.docker.com/engine/release-notes/29/#29100) from `docker:29.10.0-cli@sha256:34507eb5069d8be82c95dd3b6987d4250fd5fee49b82e2509b7d7a7030740d6d`. Its Go 1.27.4 runtime includes the fix for [CVE-2026-97054](https://pkg.go.dev/vuln/GO-2026-6859). Scans of the copied Docker binary in each supported donor platform report no findings. Other tools and packages in the donor are not copied into Buccaneerr.

A local Buccaneerr build combining this Docker update with CSpell 10.5.1 was scanned on all three supported platforms using the same database. Each runtime image reports one HIGH, three MEDIUM, and three UNKNOWN findings, including the unchanged Compose exception. The normal filtered gate passes on each platform. The copied Docker binary reports Go 1.27.4 and no findings; actionlint's separate occurrence of CVE-2026-97054 remains.

The published snapshots above still contain Docker CLI 29.9.3 and its CVE-2026-97054 finding. This source update requires a new image build to reach users.

## Remaining Go-tool findings

Official Compose 5.7.1 still embeds `golang.org/x/net v0.60.0` and `golang.org/x/crypto v0.57.0`. Raw scans of every supported donor platform retain HIGH [CVE-2026-78661](https://pkg.go.dev/vuln/GO-2026-6860), MEDIUM [CVE-2026-97045](https://pkg.go.dev/vuln/GO-2026-6866), and UNKNOWN [GO-2026-5932](https://pkg.go.dev/vuln/GO-2026-5932). Module fixes exist upstream, but the current official donor has not adopted them. Preserve the official binary rather than rebuilding its dependency graph locally.

Compose also reports MEDIUM [CVE-2026-128085](https://github.com/open-telemetry/opentelemetry-go/security/advisories/GHSA-q7gw-24fr-5p69) for both `go.opentelemetry.io/otel/sdk` and `go.opentelemetry.io/otel/trace` at 1.46.0. The upstream fix is 1.47.0; the current official Compose donor has not adopted it. This finding remains visible without an exception.

Alpine's signed actionlint package uses Go 1.27.3 and retains CVE-2026-97054. The current package has not adopted the patched runtime. Actionlint's [Windows-specific CVE-2026-39824](https://pkg.go.dev/vuln/GO-2026-5024) remains visible without an exception. Module metadata does not establish that every affected package is included or invoked by supported commands.

## November 13, 2026 temporary Compose exception

This section is for maintainers reviewing the temporary CI exception for Buccaneerr. The newer official Compose 5.7.1 donor fixes CVE-2026-97054 through Go 1.27.4, but retains the x/net 0.60.0 module affected by CVE-2026-78661. A new package and symbol assessment confirms the HTML parser remains absent on all supported platforms. The exception is justified by absent affected code, not an upstream module fix being unavailable.

The [temporary exception](https://github.com/scottgigawatt/privateerr/blob/main/.trivyignore.yaml) excludes only `CVE-2026-78661` at `usr/local/lib/docker/cli-plugins/docker-compose`. Its owner is `scottgigawatt`; the expiry remains **November 22, 2026 at 00:00 UTC**. It applies only to Buccaneerr scans, with suppressed findings visible. Production scans have no exception; every other finding remains subject to the existing gate. Raw audits use `--ignorefile /dev/null`.

### Verify the reviewed binary

The reviewed donor is `docker/compose-bin:v5.7.1@sha256:6a6704a7ccbc45eb4cc7e5b71dba685e9bc23705c580430f15034b2b5e46ec2b`. Docker Buildx extracted each Linux platform into a disposable directory without executing its binary. Go build metadata confirmed the architecture and ARMv7 variant.

| Platform | Donor runtime manifest | Binary SHA-256 |
| --- | --- | --- |
| `linux/amd64` | `sha256:7d12ba7faf83e8ed53e89b5142b664bedfa37ce141bc3dc0d44994dd3711fcf4` | `af426722a8af5de812fcee30cc1c39f0639f5f723cbadefb25e5d4db054064cf` |
| `linux/arm64` | `sha256:332b5f5e9fef2296eb23280b9b815457e6558d67b52faafc13d301cef238a80a` | `f2f49f903240895fa764c0dca3a14548b754ad9426f6b609ccaf55ec5a3aa2a5` |
| `linux/arm/v7` | `sha256:bea1e236427b5f44c28fd5a17da637ee5843235ff007e7496f195bca7469cc91` | `c03e0c93cf747f311d39f6920a33c461fd0f7a6246439aaf259766527caa28f5` |

Go 1.27.4 and `govulncheck v1.9.0` inspected binaries built with Go 1.27.4. Both `go tool nm` and `govulncheck -mode=extract` recovered symbols and found no `golang.org/x/net/html` package or nested packages. Nonzero x/net counts provide a positive control:

| Platform | Recovered Go symbols | x/net symbols | HTML package symbols |
| --- | --- | --- | --- |
| `linux/amd64` | 36,931 | 383 | 0 |
| `linux/arm64` | 36,865 | 382 | 0 |
| `linux/arm/v7` | 36,870 | 383 | 0 |

To repeat this check, use Go 1.27.4, `govulncheck v1.9.0`, and `jq`. Extract and hash-check a binary from the manifests above and set `COMPOSE_BINARY` to its local path. These commands inspect it without execution:

```sh
go version -m "${COMPOSE_BINARY}"
go tool nm "${COMPOSE_BINARY}" > compose-symbols.txt
govulncheck -mode=extract "${COMPOSE_BINARY}" > compose-symbols.jsonl
govulncheck -mode=binary -scan=symbol -json "${COMPOSE_BINARY}" > compose-vulnerabilities.json
jq -s -e '.[1].pkgSymbols as $symbols | ($symbols | length > 0) and any($symbols[]; (.pkg // "") | startswith("golang.org/x/net/")) and all($symbols[]; (.pkg != "golang.org/x/net/html") and ((.pkg // "") | startswith("golang.org/x/net/html/") | not))' compose-symbols.jsonl
```

The final command must succeed. Keep module-level reports: a missing package trace does not declare Compose vulnerability-free or establish that unrelated findings are harmless.

### Remove or reassess the exception

The [scope guard](https://github.com/scottgigawatt/privateerr/blob/main/test/policy/check-compose-exception-policy.sh) and [rejection fixtures](https://github.com/scottgigawatt/privateerr/blob/main/test/helpers/test-compose-exception-policy.sh) reject a changed donor, additional path or advisory, second exception, or extended expiry. Trivy enforces the UTC expiry.

1. Before expiry, check for an official donor containing x/net 0.62.0 or later. Inspect its binary contents and run unfiltered scans on every supported platform.
2. Remove the exception when the upstream fix can be adopted. If the donor changes while the finding remains, repeat the package and symbol assessment; never carry the exception forward automatically or extend it solely to obtain a passing build.
3. When removing it, remove `.trivyignore.yaml`, its workflow settings and build path filter, the dedicated guard and fixture scripts, their workflow-helper calls, and the pre-commit hook. Update this page and the security policy together.
4. Run `make test-workflows`, repository hooks, and strict documentation checks. Confirm the image gate passes and review the unfiltered report before merging.

## Retained controls

| Control | Current reason to retain it |
| --- | --- |
| KaTeX override at 0.19.1 | The math extension still requires `^0.16.0`; removing the override restores the older range affected by [CVE-2026-103923](https://github.com/advisories/GHSA-238p-pmpm-9mq7). |
| Active virtualenv seed-wheel cleanup | Keep complete upstream wheels selected for Python 3.14, their integrity checks, and the unchanged upstream SBOM. Remove only inactive wheel archives. |
| Date compatibility shim | The unmodified PIA token script still calls `date --date='1 day'`; the wrapper translates that syntax for BusyBox. |
| Targeted Hadolint exceptions | DL3018 permits stable APK security refreshes. The two DL3064 comments cover non-secret Privateerr install-path names. |

Both Dockerfiles refresh stable Alpine packages rather than carrying historical library floors or a persistent edge repository. Buccaneerr fetches only Alpine's signed actionlint APK from a command-specific edge source; its dependencies and configured repositories remain on stable. Temporary pip and npm build packages are removed with their dependency groups. These controls keep test tooling out of production without altering upstream Python assets or inventory to reduce scanner counts.

## Installer dependency boundaries

[Pip 26.3](https://github.com/pypa/pip/blob/26.3/NEWS.rst) was released on November 2. The [virtualenv 21.15.6 seed manifest](https://github.com/pypa/virtualenv/blob/21.15.6/src/virtualenv/seed/wheels/embed/__init__.py) selects its complete upstream wheel for Python 3.14; virtualenv 21.15.5 already selected the same wheel.

Direct inspection of published Buccaneerr confirms that the active pip 26.3 wheel vendors msgpack 1.2.4 and urllib3 2.8.0, including their upstream fixes. Its SHA-256 is `f3b60b20ffaadd4415ed7957212a38ac63fa4c5fa375bd0f4a797777940fad13`. It still includes the `pkg_resources` subset recorded as setuptools 70.3.0. A separate metadata-guided scan with the November 16 database reports three version-level entries against that subset: one HIGH, one MEDIUM, and one LOW. These are outside the whole-image totals. A version-level advisory against the complete setuptools distribution does not prove that all affected modules exist in that subset.

Keep the upstream SBOM unchanged and distinguish inactive inventory entries from the installed files. Standalone package upgrades do not replace code vendored inside a wheel.

### Python bootstrap wheel

The reviewed production images retain Alpine Python's separate `/usr/lib/python3.14/ensurepip/_bundled/pip-26.2.2-py3-none-any.whl`. Its SHA-256 is `fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70` on every architecture of both Privateerr channels. The archive includes msgpack 1.1.2, urllib3 2.7.0, and `pkg_resources` recorded as setuptools 70.3.0. Privateerr does not invoke `python3 -m ensurepip`, but the upstream archive remains available to that command.

A metadata-guided scan of the wheel's unchanged `pip/_vendor/vendor.txt` with the November 16 database reports eight version-level entries: five HIGH, two MEDIUM, and one LOW. These entries are outside the whole-image counts and require code-path assessment, especially for the partial setuptools inventory.

Updating virtualenv does not replace this package-owned bootstrap wheel. Alpine stable still supplies Python 3.14.10-r1 with that archive. Preserve upstream assets and SBOMs, and reassess when a complete maintained Python package updates it; do not partially patch or rename a wheel to manufacture lower counts.

## Repeat the review

Scan an immutable runtime manifest digest with every severity, unfixed findings, and no repository exceptions:

```sh
trivy image --image-src remote --scanners vuln --detection-priority comprehensive --ignorefile /dev/null ghcr.io/scottgigawatt/privateerr@sha256:IMAGE-DIGEST
```

Replace `IMAGE-DIGEST` with the runtime manifest digest for the platform being reviewed. Repeat for Buccaneerr and every supported architecture. Retain the image identities, scanner version, and database timestamp.

For an offline audit, download and verify all configuration and layer blobs, then prepare one runtime descriptor per OCI layout. A multi-platform archive or requested platform flag alone does not establish which architecture Trivy examined. Check the reported architecture, ARM variant, and source revision against the selected manifest.

To repeat the separate bootstrap metadata check, extract the retained wheel into a disposable directory without executing or modifying it. Replace `EXTRACTED-WHEEL-DIRECTORY` with that directory and `TRIVY-CACHE-DIRECTORY` with the cache containing the recorded database:

```sh
trivy fs --scanners vuln --detection-priority comprehensive \
    --ignorefile /dev/null --file-patterns 'pip:(^|/)vendor\.txt$' \
    --cache-dir "TRIVY-CACHE-DIRECTORY" --skip-db-update "EXTRACTED-WHEEL-DIRECTORY"
```
