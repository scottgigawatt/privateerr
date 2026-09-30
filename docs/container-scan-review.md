# Container scan review

Reviewed on September 30, 2026 with Trivy 0.74.0 (database updated at 07:10 UTC), plus Docker Scout 1.24.0. The review covers immutable `edge` and `latest` digests for all three supported platforms, plus the rebuilt Buccaneerr image with the dependency replacements below. Scanner databases change, so these findings apply to the scanned artifacts rather than every future image with the same tag.

## Dependency fixes

Buccaneerr uses Docker CLI 29.8.1 and Compose 5.5.1 from digest-pinned official images. It replaces Alpine's bootstrap npm with npm 12.1.0. Pre-commit 4.6.2 installs Node hooks without the obsolete `--ignore-prepublish` option rejected by npm 12. BusyBox supplies AWK and core utilities, avoiding unnecessary GNU packages.

The tool manifest additionally locks brace-expansion 5.0.12, ip-address 10.7.2, and undici 6.29.0; the image removes npm's older bundled copies so Node resolves these integrity-checked replacements. The ip-address and undici replacements fix CVE-2026-101910, CVE-2026-101911, CVE-2026-101912, CVE-2026-101913, CVE-2026-85024, CVE-2026-18540, and CVE-2026-19534 in the completed image. The brace-expansion replacement fixes [CVE-2026-102276](https://github.com/advisories/GHSA-6j4f-fj2g-mc7p), [CVE-2026-102278](https://github.com/advisories/GHSA-qhr7-859c-m2p7), and [CVE-2026-102277](https://github.com/advisories/GHSA-q2hr-2g5m-vwhr). npm 12.1.0 still bundles affected versions, so keep the replacements until upstream fixes its distribution. The committed npm lockfile records integrity hashes for the complete tool dependency graph; `npm ci` checks them during builds.

Ten GitHub dependency alerts still identify the vulnerable bundled entries in `test/package-lock.json`. A standalone `npm ci` restores those copies; the complete Docker build applies the replacements. Keep these source alerts visible until npm ships patched dependencies. Renovate uses npm 11 to generate the compatible lockfile because its package-manager bootstrap does not yet support npm 12's restrictions on remote tarballs; this does not select the npm version installed in Buccaneerr.

The image installs fixed nghttp2 1.70.0 or newer and setuptools 83.0.0 or newer from Alpine's edge repository until those fixes reach stable. It also takes pre-commit 4.6.2 or newer from edge/community because stable still supplies 4.6.0. These are narrow package exceptions; the base and remaining tools stay on stable Alpine. Privateerr already uses the same nghttp2 fix, and its scanned runtime had no reported findings.

## Remaining package-level alerts

After replacing the npm dependencies, eight package-level alerts remain in Docker Scout for Buccaneerr. Trivy reports only the two containerd advisories and the OpenPGP warning. None is hidden by a new scanner exclusion. Review the affected code and platform as well as the package name:

- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery and is fixed in CLI 29.2.0 and Compose 5.1.0. These Linux images contain newer versions.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion in `golang.org/x/sys/windows`. Buccaneerr runs the Linux actionlint binary.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package, not every package in `golang.org/x/crypto`. Binary analysis of Compose 5.5.1 found no compiled OpenPGP package.
- **CVE-2026-53493:** The containerd [advisory](https://github.com/containerd/containerd/security/advisories/GHSA-pg57-6jwg-q645) concerns resource exhaustion while pulling malicious image descriptor graphs. Compose 5.5.1 includes an affected containerd module version and remains the newest official Compose donor. Buccaneerr contains clients, not a containerd daemon; assess the separate host runtime and avoid untrusted image sources while awaiting the upstream update.
- **CVE-2026-53495:** The containerd [advisory](https://github.com/containerd/containerd/security/advisories/GHSA-7jxh-36q5-gcqv) affects the daemon's CRI execution implementation. Compose includes containerd client libraries, but no CRI implementation or containerd daemon. This does not assess the separate Docker host's daemon.
- **CVE-2026-89157, CVE-2026-89160, and CVE-2026-89162:** PCRE2 [10.48 release notes](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.48) include the pattern-conversion, invalid UTF matching, and serialization fixes. The image already contains Alpine's PCRE2 10.48 package; Scout currently reports it as unfixed.

Maraudarr uses the same Compose 5.5.1 donor and Scout reports the four Compose-related alerts above. Updating to an older or custom-built Compose solely to remove scanner metadata would not improve the affected runtime behavior.

## Stable image refresh

The published v2.1.2 Privateerr runtime images have no findings in either scanner across all three platforms. The v2.1.2 Privateerr, Buccaneerr, and Maraudarr artifacts contain fixed libexpat 2.8.5-r0; CVE-2026-93990 from their previous stable images is absent. New brace-expansion advisories now affect the v2.1.2 Buccaneerr artifact: Trivy reports two high and one medium finding for its bundled 5.0.9. The rebuilt image with 5.0.12 removes those findings and retains only the documented Compose findings in Trivy. A rebuilt stable release is needed to deliver this fix to `latest`; merging the source update alone only refreshes `edge`.

Alpine 3.24 stable still provides nghttp2 1.69.0-r0 and setuptools 82.0.1-r1 on all three platforms. Keep the narrow edge-package exceptions until stable supplies the fixed versions. The PCRE2, Windows-only, and OpenPGP explanations remain relevant because Scout still reports those alerts; a clean Trivy result does not mean Scout agrees.

## Repeat the review

Scan an immutable published digest and specify its platform so results can be compared reliably:

```sh
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE_DIGEST --platform linux/amd64
```

Replace `IMAGE_DIGEST` with the published digest. Repeat for every supported platform and retain the scanner version, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot, not a guarantee that no vulnerabilities exist.
