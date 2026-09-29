---
status: accepted
date: 2026-09-29
supersedes: 003
---

# 007. build.sh is the only build

## Context

003 kept `Tilt.xcodeproj` beside `build.sh` for one reason: submitting to the Mac App Store needs an
archive, and an archive needs an Xcode project. 006 took the app off that path, so nothing
submits.

What the project still cost was two traps in `AGENTS.md`. Its universal build and `build.sh`'s arm64
build differed on architecture on purpose, and every `xcodebuild` registered another Tilt with
Launch Services under the installed one's name, icon and bundle id. It was also no use to a
stranger: it signs automatically with no development team set, so it asks for one before it
builds, and a signature from any team but the local certificate loses the screen recording grant
on every rebuild, which is what `build.sh` exists to avoid.

## Decision

Delete the project. `build.sh` is the only build.

## Consequences

No build in the repository produces an x86_64 slice. The README asks for Apple silicon, and
`build.sh` targets `arm64-apple-macos14.0`.

`Resources/Info.plist`, `Resources/Tilt.entitlements` and `makeicns.sh` stay where they are. They
were shared so the two paths could not drift, and now they are simply the build's inputs.
