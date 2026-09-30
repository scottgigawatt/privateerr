# Container scan review

Reviewed on September 30, 2026 with Trivy 0.74.0 (database updated at 07:10 UTC), plus Docker Scout 1.24.0. The review covers immutable `edge` and `latest` digests for all three supported platforms, plus the rebuilt Buccaneerr image with build-only npm. Scanner databases change, so these findings apply to the scanned artifacts rather than every future image with the same tag.

## Dependency fixes

Buccaneerr uses Docker CLI 29.8.1 and Compose 5.5.1 from digest-pinned official images. BusyBox supplies AWK and core utilities, avoiding unnecessary GNU packages.

The tool manifest locks CSpell, Pyright, and Markdownlint CLI2. Alpine's npm installs these checkers during the image build and is removed in the same layer, keeping its bundled dependencies out of the completed image. Pre-commit runs Markdownlint through the same Buccaneerr helper used for Python checks, so it does not install a separate Node environment or require npm when running hooks. Node.js remains available to run the installed checkers.

Removing npm from the manifest eliminates the vulnerable bundled entries behind the ten GitHub dependency alerts and the three replacement-package workarounds. GitHub must scan the merged lockfile again before alert closure can be confirmed. The committed lockfile retains exact versions and integrity hashes for every checker dependency; `npm ci` verifies them during builds. Renovate maintains the checkers through its npm manager, using npm 11 to generate a lockfile compatible with the build-only package manager.

The image installs fixed nghttp2 1.70.0 or newer and setuptools 83.0.0 or newer from Alpine's edge repository until those fixes reach stable. It also takes pre-commit 4.6.2 or newer from edge/community because stable still supplies 4.6.0. These are narrow package exceptions; the base and remaining tools stay on stable Alpine. Privateerr already uses the same nghttp2 fix, and its scanned runtime had no reported findings.

## Remaining package-level alerts

With npm removed, eight package-level alerts remain in Docker Scout for Buccaneerr. Trivy reports only the two containerd advisories and the OpenPGP warning. None is hidden by a new scanner exclusion. Review the affected code and platform as well as the package name:

- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery and is fixed in CLI 29.2.0 and Compose 5.1.0. These Linux images contain newer versions.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion in `golang.org/x/sys/windows`. Buccaneerr runs the Linux actionlint binary.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package, not every package in `golang.org/x/crypto`. Binary analysis of Compose 5.5.1 found no compiled OpenPGP package.
- **CVE-2026-53493:** The containerd [advisory](https://github.com/containerd/containerd/security/advisories/GHSA-pg57-6jwg-q645) concerns resource exhaustion while pulling malicious image descriptor graphs. Compose 5.5.1 includes an affected containerd module version and remains the newest official Compose donor. Buccaneerr contains clients, not a containerd daemon; assess the separate host runtime and avoid untrusted image sources while awaiting the upstream update.
- **CVE-2026-53495:** The containerd [advisory](https://github.com/containerd/containerd/security/advisories/GHSA-7jxh-36q5-gcqv) affects the daemon's CRI execution implementation. Compose includes containerd client libraries, but no CRI implementation or containerd daemon. This does not assess the separate Docker host's daemon.
- **CVE-2026-89157, CVE-2026-89160, and CVE-2026-89162:** PCRE2 [10.48 release notes](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.48) include the pattern-conversion, invalid UTF matching, and serialization fixes. The image already contains Alpine's PCRE2 10.48 package; Scout currently reports it as unfixed.

Maraudarr uses the same Compose 5.5.1 donor and Scout reports the four Compose-related alerts above. Updating to an older or custom-built Compose solely to remove scanner metadata would not improve the affected runtime behavior.

## Stable image refresh

The published v2.1.2 Privateerr runtime images have no findings in either scanner across all three platforms. The v2.1.2 Privateerr, Buccaneerr, and Maraudarr artifacts contain fixed libexpat 2.8.5-r0; CVE-2026-93990 from their previous stable images is absent. New brace-expansion advisories now affect the v2.1.2 Buccaneerr artifact: Trivy reports two high and one medium finding for its bundled 5.0.9. The rebuilt image without npm removes those findings and retains only the documented Compose findings in Trivy. A rebuilt stable release is needed to deliver this fix to `latest`; merging the source update alone only refreshes `edge`.

Alpine 3.24 stable still provides nghttp2 1.69.0-r0 and setuptools 82.0.1-r1 on all three platforms. Keep the narrow edge-package exceptions until stable supplies the fixed versions. The PCRE2, Windows-only, and OpenPGP explanations remain relevant because Scout still reports those alerts; a clean Trivy result does not mean Scout agrees.

## Repeat the review

Scan an immutable published digest and specify its platform so results can be compared reliably:

```sh
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE_DIGEST --platform linux/amd64
```

Replace `IMAGE_DIGEST` with the published digest. Repeat for every supported platform and retain the scanner version, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot, not a guarantee that no vulnerabilities exist.
