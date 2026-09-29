---
status: superseded by 007
date: 2026-09-11
---

# 003. build.sh and the Xcode project both stay

## Context

Submitting to the Mac App Store needs an archive, and an archive needs an Xcode project. The
obvious tidy-up is to migrate and delete `build.sh`.

`build.sh` signs with a certificate it creates on first run. That is the only reason the screen
recording permission survives a rebuild: an ad-hoc signature pins the designated requirement to
the binary's hash, so every rebuild would look like a different app and ask again.

## Decision

Keep both. `build.sh` is the local loop, `Tilt.xcodeproj` is the submission path.

The alternative considered was extending `build.sh` with distribution signing and skipping the
project. It was rejected because none of that shell can be run until there is a developer
account, whereas the project's build and archive are verified now and the account-gated part is
filled in by Apple's own tooling.

## Consequences

Two build paths can drift, so they read one `Resources/Info.plist`, one
`Resources/Tilt.entitlements` and one `makeicns.sh`. A bundle setting changed in one path only is
a bug.
