# Tilt

A menu bar app that renders your Mac's desktop in 3D perspective, driven by the MacBook lid angle.

Close the lid past a threshold and the windows lift off the desktop: the wallpaper stays flat where
it is, the windows tilt away from it, and the picture stays put in space while the panel turns in
front of it. Open the lid back past the threshold and everything goes away.

## Requirements

- An Apple silicon MacBook with a lid angle sensor
- macOS 14 or later
- Screen recording permission, which macOS asks for on first launch

It runs on the built-in display only. The illusion is that a plane stays fixed while the lid turns
in front of it, and an external display does not turn.

## Build

```sh
./build.sh
```

Writes `Tilt.app` next to the script, signed with a local certificate that `build.sh` creates on
first run. The certificate is what makes the screen recording permission survive a rebuild: an
ad-hoc signature pins the grant to the binary's hash, so every rebuild would ask again.

To use your own icon, drop a 1024x1024 `AppIcon.png` in this directory, delete `AppIcon.icns` and
build again. Without one, `makeicon.swift` draws a placeholder.

### Test build

```sh
./build.sh --test
```

Builds `TiltTest.app` into `$TMPDIR` with the lid angle read from `/tmp/tilt-fake-lid`, so
transitions can be driven without a hand on the hinge. The hook is behind a compile flag and cannot
reach a normal build. It goes to `$TMPDIR` because built beside the real app it turned up in
launchers with the same name, icon and bundle id.

## Controls

Everything lives in the menu bar: an on/off switch, the angle the effect engages below, how far you
sit from the screen, how strong the glass treatment is, whether the angle shows beside the menu bar
icon, and whether Tilt opens at login.

While the overlay is up, escape dismisses it. A click does not, and used to: dismissing on a click
fired while the lid was still moving, so a hand resting on the trackpad dropped the effect halfway
down. Once dismissed it stays down until the lid is opened back past the threshold, and the menu
says so while it is.

## How it works

The lid angle comes from a HID sensor on the sensor page (0x20) with an orientation usage (0x8A).
Feature report 1 is three bytes: report id, then the angle as a little-endian u16 of degrees.

The desktop is two captures rather than one. A still of the wallpaper, taken with every window
excluded, is drawn flat behind everything. A live ScreenCaptureKit stream of the windows alone, on a
transparent background, is drawn in front and turned. Capturing the whole screen instead put the
wallpaper on screen twice at two different angles.

"Fixed in space" needs more than rotating the image. In the lid's own frame a viewer sitting still
is also swinging around the hinge, so the eye travels with it: both the plane and the eye are
world-fixed, and both are expressed in the lid's rotating frame. That is why the viewing distance is
a setting and not a taste knob.

Rendering is driven by a display link rather than by captured frames, because ScreenCaptureKit only
delivers a frame when the screen changes and a still desktop would freeze the motion. A One Euro
filter fills in between the sensor's whole-degree readings.

## Distribution

Build it. There is no download, and that is a decision rather than a gap:
[006](docs/decisions/006-git-not-the-app-store.md) has why. A signed, notarized download needs a
Developer ID certificate and so the same paid membership a store listing would have, and
`build.sh`'s own certificate is what keeps the screen recording permission across rebuilds, which
a notarized update would not.

The app is still built and signed as though it were going to the store, because that is what
makes the sensor answer: `com.apple.security.device.usb` inside the sandbox. `AGENTS.md` says what
removing it costs.

## Checks

```sh
./Tilt.app/Contents/MacOS/Tilt --check
```

Reads the sensor and asserts the smoothing filter still hides the quantisation without lagging a
fast close.

## Licence

MIT, in [LICENSE](LICENSE). The menu bar glyph is somebody else's and carries its own notice; see
below.

## Credits

Menu bar glyph from [Tabler Icons](https://tabler.io/icons), MIT licensed. The notice ships
inside the app bundle; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
