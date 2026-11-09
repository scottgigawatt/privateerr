# Container security review

Use this page to assess current published image findings, retained security controls, and the conditions for removing the temporary Compose exception. Privateerr's application uses only the Python standard library; validation and documentation tools belong to the test-only Buccaneerr image.

## November 9, 2026 published image audit

Trivy 0.76.2 used comprehensive detection, every severity, unfixed findings, and an explicit empty ignore file. Its database was updated at `2026-11-09 06:57:06 UTC` and held constant. Registry indexes, runtime manifests, configurations, and complete layer contents were verified by SHA-256 and size. Each scan used a single-runtime OCI layout, and the reported architecture and ARM variant matched its selected manifest.

Each row covers `linux/amd64`, `linux/arm64`, and `linux/arm/v7`:

| Published image | Whole-image findings per platform |
| --- | --- |
| Privateerr `edge` | 0 |
| Privateerr `latest` | 1 MEDIUM |
| Buccaneerr `edge` | 1 HIGH, 1 MEDIUM, 2 UNKNOWN |
| Buccaneerr `latest` | 1 HIGH, 2 MEDIUM, 2 UNKNOWN |

Both `latest` images retain zlib 1.3.2-r1 with CVE-2026-4738; their newer `edge` images include the fix in zlib 1.4-r0. Buccaneerr retains the four [Go-tool findings](#remaining-go-tool-findings) in both channels.

These totals do not cover every nested archive. The separate [Python bootstrap-wheel assessment](#python-bootstrap-wheel) still reports version-level findings; zero whole-image findings do not establish vulnerability-free images.

Both reviewed `edge` images were built from source `5472e54a6e45763cea93da85c52fea43aa4a237e`; both `latest` images were built from `108a42bf25593d97d469eb57096fdedaf0d13a2d`. Their immutable index digests are:

- Privateerr `edge`: `sha256:580b60343c353ff087b7217eb83e4c49b37bf939829fb11778ea20ef1f9b9993`
- Privateerr `latest`: `sha256:3b274ca1e99ce00420deb733e90cd7d7c36e6bb65a54fb342f77f7d78dee6036`
- Buccaneerr `edge`: `sha256:e875d3a06bbbfc8ec4c4ba0e91500b80b4ad92d1cef855b7d7fbb5f6ef82a4aa`
- Buccaneerr `latest`: `sha256:50795d35453c59375f591841bd2da8cfaef0f065bd7dfd91fd9678bcf3eceec0`

Privateerr's Docker Hub indexes match GHCR for these channels. Buccaneerr is published only to GHCR. An `edge` fix does not advance `latest`; a separately authorized stable release is required to deliver the newer packages through that channel.

## Remaining Go-tool findings

Buccaneerr retains four unfiltered module-level findings: actionlint's Windows-specific [CVE-2026-39824](https://pkg.go.dev/vuln/GO-2026-5024), and Compose's [GO-2026-5932](https://pkg.go.dev/vuln/GO-2026-5932), [CVE-2026-78661](https://pkg.go.dev/vuln/GO-2026-6860), and [CVE-2026-97045](https://pkg.go.dev/vuln/GO-2026-6866). They are classified as two UNKNOWN, one HIGH, and one MEDIUM finding respectively. Upstream module fixes exist, but the latest official Compose donor remains 5.7.0. Do not rebuild its dependency graph locally or carry the exception onto a changed donor without a new assessment.

Module metadata does not establish that every affected package is included or invoked by supported commands. The reviewed Compose binary omits the affected HTML parser package, as documented below. No actionlint exception is added, and these raw counts do not hide the Compose finding excluded from the narrower CI gate.

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

## Retained controls

| Control | Current reason to retain it |
| --- | --- |
| KaTeX override at 0.19.1 | The math extension still requires `^0.16.0`; removing the override restores the older range affected by [CVE-2026-103923](https://github.com/advisories/GHSA-238p-pmpm-9mq7). |
| Markdownlint's re2js override at 2.9.1 | Markdownlint still pins 2.8.6, affected by [CVE-2026-116795](https://github.com/le0pard/re2js/security/advisories/GHSA-gg6h-894w-4m9c). Remove the override when a compatible upstream dependency includes its fix. |
| Active virtualenv seed-wheel cleanup | Keep complete upstream wheels selected for Python 3.14, their integrity checks, and the unchanged upstream SBOM. Remove only inactive wheel archives. |
| Date compatibility shim | The unmodified PIA token script still calls `date --date='1 day'`; the wrapper translates that syntax for BusyBox. |
| Targeted Hadolint exceptions | DL3018 permits stable APK security refreshes. The two DL3064 comments cover non-secret Privateerr install-path names. |

Both Dockerfiles refresh stable Alpine packages rather than carrying historical library floors or a persistent edge repository. Buccaneerr fetches only Alpine's signed actionlint APK from a command-specific edge source; its dependencies and configured repositories remain on stable. Temporary pip and npm build packages are removed with their dependency groups. These controls keep test tooling out of production without altering upstream Python assets or inventory to reduce scanner counts.

## Installer dependency boundaries

[Pip 26.3](https://github.com/pypa/pip/blob/26.3/NEWS.rst) was released on November 2. The [virtualenv 21.15.6 seed manifest](https://github.com/pypa/virtualenv/blob/21.15.6/src/virtualenv/seed/wheels/embed/__init__.py) selects its complete upstream wheel for Python 3.14; virtualenv 21.15.5 already selected the same wheel.

Direct inspection of published Buccaneerr confirms that the active pip 26.3 wheel vendors msgpack 1.2.4 and urllib3 2.8.0, including their upstream fixes. Its SHA-256 is `f3b60b20ffaadd4415ed7957212a38ac63fa4c5fa375bd0f4a797777940fad13`. It still includes the `pkg_resources` subset recorded as setuptools 70.3.0. A version-level advisory against the complete setuptools distribution does not prove that all affected modules exist in that subset.

Keep the upstream SBOM unchanged and distinguish inactive inventory entries from the installed files. Standalone package upgrades do not replace code vendored inside a wheel.

### Python bootstrap wheel

The reviewed production images retain Alpine Python's separate `/usr/lib/python3.14/ensurepip/_bundled/pip-26.2.2-py3-none-any.whl`. Its SHA-256 is `fd7f4dfa8190e014013b9f08f3e973f4e4c26ffd179a204895533a7254813a70` on every architecture of both Privateerr channels. The archive includes msgpack 1.1.2, urllib3 2.7.0, and `pkg_resources` recorded as setuptools 70.3.0. Privateerr does not invoke `python3 -m ensurepip`, but the upstream archive remains available to that command.

A metadata-guided scan of the wheel's unchanged `pip/_vendor/vendor.txt` with the same November 9 database reports eight version-level entries: five HIGH, two MEDIUM, and one LOW. These entries are outside the whole-image counts and require code-path assessment, especially for the partial setuptools inventory.

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
