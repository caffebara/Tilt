# Working on Tilt

A menu bar app that renders the desktop in 3D perspective from the MacBook lid angle. One Swift
file, one build script, and a handful of constraints that reading the code does not reveal.

This file is the source of truth for every agent working here, Claude and Codex alike. An agent
reviewing `main.swift` cannot run the app or read the lid sensor, so nothing below is confirmable
from the code; treat it as given and verify behaviour on hardware.

## Build, and never install

`./build.sh` writes `Tilt.app` beside itself. Leave it there. Whoever runs the build installs it,
so do not copy it to `/Applications`, and do not launch it as a side effect of a build.
`./build.sh --install` does both, and it is that person's command, never an agent's.

`build.sh` is the loop and the distribution both: there is no download, so building is how anyone
runs this. It signs ad hoc and never touches the keychain. That pins the screen recording grant to
the binary's hash, so every rebuild asks again; `--install` resets the old grant first. A
self-signed certificate avoided the re-ask and was removed on 2026-09-29, because its first build
stopped on a login keychain password prompt, and because any process could sign with its key and
inherit the grant.

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
bundle id with no permission grants, last on 2026-09-29: sandbox alone fails `IOHIDManagerOpen` with
`0xE00002E2` (not permitted), sandbox with that entitlement returns 0. Removing it looks harmless
and silently kills the app.

## Conventions

Menu rows use stock AppKit controls. Hand-drawn substitutes were tried and rejected: they lose the
accent colour and the accessibility roles.

Verify against the real sensor or a real build, not against the test hook alone. Every regression
in this app's history was found by measuring, and reported fixed by something that only looked
right.
