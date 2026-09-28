# Working on Tilt

A menu bar app that renders the desktop in 3D perspective from the MacBook lid angle. One Swift
file, two build paths, and a handful of constraints that reading the code does not reveal.

This file is the source of truth for every agent working here, Claude and Codex alike. An agent
reviewing `main.swift` cannot run the app or read the lid sensor, so nothing below is confirmable
from the code; treat it as given and verify behaviour on hardware.

## Build, and never install

`./build.sh` writes `Tilt.app` beside itself. Leave it there. Song installs it, so do not copy it
to `/Applications`, and do not launch it as a side effect of a build.

`build.sh` is the loop and the distribution both, per 006: there is no download, so building is
how anyone runs this. It signs with a certificate it creates itself, and that is the only reason
the screen recording permission survives a rebuild, since an ad-hoc signature pins the grant to
the binary's hash. `Tilt.xcodeproj` was the submission path and now builds the same app a second
way. Both read one `Resources/Info.plist`, one `Resources/Tilt.entitlements` and one
`makeicns.sh`. Change a bundle setting in those, never in one build path.

## Traps that have already cost a day

**`IOHIDManager` has to be a stored property.** As a local in `init()` ARC releases it after its
last use and the devices die before the first read. It reproduces only at `-O`, so `-Onone` will
tell you the bug is fixed when it is not.

**`SCShareableContent.excludingDesktopWindows(true, ...)` needs the `true`.** With `false` the
wallpaper window joins the list, so excluding every window leaves nothing, the wallpaper capture
returns nil, and it shows up as a black surround when the picture tilts rather than as an error.

**The built-in display only.** The illusion is a plane held fixed while the lid turns in front of
it, and an external display does not turn. `engage()` checks the screen itself rather than the
suppression flag, because `nsScreen` outlives the screen it names and several paths clear that
flag.

**The test hook must not reach a normal build.** The fake angle at `/tmp/tilt-fake-lid` is behind
`#if TILT_TEST_HOOK`, which only `build.sh --test` sets. It shipped once, and any local process
could then drive the overlay. That build goes to `$TMPDIR` because built beside the real app it
appeared in launchers with the same name, icon and bundle id.

**The two build paths differ on architecture, and that is not a bug.** `build.sh` builds arm64 and
the Xcode archive builds universal, because the project sets no `ARCHS`. Both slices read the
sensor and pass `--check`, run on the Xcode product rather than on `Tilt.app`, which is arm64 by
design:

```sh
arch -arm64  "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
arch -x86_64 "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
```

It reads like a slice nobody has run, and pinning the project to arm64 to make the paths agree cuts
a platform for nothing.

**The privacy policy URL is compiled in, so the GitHub account name is load-bearing.**
`main.swift` ships `https://caffebara.github.io/tilt-privacy/` as a string in the binary, and the
menu opens it. Renaming the account, renaming or deleting `caffebara/tilt-privacy`, or switching
its Pages off points every copy already built at a 404, and that repository is the only place the
policy exists. This one has cost nothing yet, unlike the rest of this section; it is here because
the price of springing it is paid by whoever is running a build that can no longer be changed. A
domain of one's own would end it, and was judged not worth buying.

**An Xcode build registers its product with Launch Services.** `xcodebuild` runs
`lsregister -f -R -trusted` on the built `.app`, so every Release build puts another Tilt in
Spotlight and Open With under the same name, icon and bundle id as the installed one. That is the
mechanism behind the duplicate the test build hit, and it is not confined to a bundle built beside
the real app: nine had accumulated by 2026-09-22, four of them from that day. Deleting the build
directory does not remove the record, measured on two that pointed at nothing. Unregister first:

```sh
L=/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister
"$L" -u <path-to-Tilt.app>          # before deleting the directory
"$L" -dump | grep -i 'path:.*Tilt\.app'   # what it still knows
```

**`com.apple.security.device.usb` is what reads the sensor**, not a USB device. Measured against a
bundle id with no permission grants: sandbox alone fails `0xE00002CD`, sandbox with that
entitlement succeeds. Removing it looks harmless and silently kills the app.

## Conventions

Menu rows use stock AppKit controls. Hand-drawn substitutes were tried and rejected: they lose the
accent colour and the accessibility roles.

Verify against the real sensor or a real build, not against the test hook alone. Every regression
in this app's history was found by measuring, and reported fixed by something that only looked
right.
