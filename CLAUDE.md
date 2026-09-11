# Working on Tilt

A menu bar app that renders the desktop in 3D perspective from the MacBook lid angle. One Swift
file, two build paths, and a handful of constraints that reading the code does not reveal.

## Build, and never install

`./build.sh` writes `Tilt.app` beside itself. Leave it there. Song installs it, so do not copy it
to `/Applications`, and do not launch it as a side effect of a build.

`build.sh` is the local loop and `Tilt.xcodeproj` is the submission path. They are not
alternatives: `build.sh` signs with a certificate it creates itself, and that is the only reason
the screen recording permission survives a rebuild, since an ad-hoc signature pins the grant to
the binary's hash. Both read one `Resources/Info.plist`, one `Resources/Tilt.entitlements` and one
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

**`com.apple.security.device.usb` is what reads the sensor**, not a USB device. Measured against a
bundle id with no permission grants: sandbox alone fails `0xE00002CD`, sandbox with that
entitlement succeeds. Removing it looks harmless and silently kills the app.

## Conventions

Menu rows use stock AppKit controls. Hand-drawn substitutes were tried and rejected: they lose the
accent colour and the accessibility roles.

Verify against the real sensor or a real build, not against the test hook alone. Every regression
in this app's history was found by measuring, and reported fixed by something that only looked
right.
