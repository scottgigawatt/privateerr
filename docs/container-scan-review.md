# Container scan review

Reviewed on September 23, 2026. Scanner databases change; these findings apply to the package versions below, not every future image with the same tag.

## Dependency fixes

Buccaneerr uses Docker CLI 29.8.1 and Compose 5.5.1 from digest-pinned official images. It replaces Alpine's bootstrap npm with npm 11.20.0, including its patched bundled dependencies. The committed npm lockfile records integrity hashes for the complete tool dependency graph; `npm ci` checks them during builds. npm 11 retains installation flags required by pre-commit. BusyBox supplies AWK and core utilities, avoiding unnecessary GNU packages.

The image installs fixed nghttp2 1.70.0 or newer and setuptools 83.0.0 or newer from Alpine's edge repository until those fixes reach stable. These are narrow package exceptions; the base and remaining tools stay on stable Alpine. Privateerr already uses the same nghttp2 fix, and its scanned runtime had no reported findings.

## Remaining package-level alerts

Docker Scout still reports seven alerts in the rebuilt Buccaneerr image. None is hidden by a new scanner exclusion. Review the affected code and platform as well as the package name:

- **CVE-2025-15558:** Docker's [advisory](https://github.com/docker/cli/security/advisories/GHSA-p436-gjf2-799p) applies to Windows plugin discovery and is fixed in CLI 29.2.0 and Compose 5.1.0. These Linux images contain newer versions.
- **CVE-2026-39824:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5024) affects a Windows string conversion in `golang.org/x/sys/windows`. Buccaneerr runs the Linux actionlint binary.
- **GO-2026-5932:** The Go [advisory](https://pkg.go.dev/vuln/GO-2026-5932) concerns the unmaintained OpenPGP package, not every package in `golang.org/x/crypto`. Binary analysis of Compose 5.5.1 found no compiled OpenPGP package.
- **CVE-2026-53495:** The containerd [advisory](https://github.com/containerd/containerd/security/advisories/GHSA-7jxh-36q5-gcqv) affects the daemon's CRI execution implementation. Compose includes containerd client libraries, but no CRI implementation or containerd daemon. This does not assess the separate Docker host's daemon.
- **CVE-2026-89157, CVE-2026-89160, and CVE-2026-89162:** PCRE2 [10.48 release notes](https://github.com/PCRE2Project/pcre2/releases/tag/pcre2-10.48) include the pattern-conversion, invalid UTF matching, and serialization fixes. The image already contains Alpine's PCRE2 10.48 package; Scout currently reports it as unfixed.

Maraudarr uses the same Compose 5.5.1 donor and reports the three Compose-related alerts above. Updating to an older or custom-built Compose solely to remove scanner metadata would not improve the affected runtime behavior.

## Repeat the review

Scan an immutable published digest and specify its platform so results can be compared reliably:

```sh
docker scout cves registry://ghcr.io/scottgigawatt/buccaneerr@sha256:IMAGE_DIGEST --platform linux/amd64
```

Replace `IMAGE_DIGEST` with the published digest. Repeat for every supported platform and retain the scanner version, package versions, and scan date. A clean scan is evidence about that artifact and database snapshot, not a guarantee that no vulnerabilities exist.
