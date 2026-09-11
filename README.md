# Tilt

A menu bar app that renders your Mac's desktop in 3D perspective, driven by the MacBook lid angle.

Close the lid past a threshold and the windows lift off the desktop: the wallpaper stays flat where
it is, the windows tilt away from it, and the picture stays put in space while the panel turns in
front of it. Open the lid back past the threshold and everything goes away.

## Requirements

- A MacBook with a lid angle sensor (2019 and later)
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
sit from the screen, and how strong the glass treatment is.

While the overlay is up, escape dismisses it and so does a click. Either way it stays down until the
lid is opened back past the threshold.

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

## Mac App Store

The app is built and signed for it. What is left needs an Apple Developer account.

`build.sh` stays the local loop: it signs with a certificate it creates itself, which is what
keeps the screen recording permission across rebuilds. `Tilt.xcodeproj` is the submission path,
and both read the same `Resources/Info.plist`, `Resources/Tilt.entitlements` and `makeicns.sh`.

### What the sandbox needed

The store requires the app sandbox, and the lid angle sensor stops answering inside it. Measured
with a bundle id holding no permission grants at all, so nothing else could account for it:

| signed with | sensor read |
| --- | --- |
| sandbox alone | fails, 0xE00002CD |
| sandbox and `com.apple.security.device.usb` | succeeds |

That entitlement is the one grant the sensor needs. ScreenCaptureKit needs no entitlement, only
the screen recording permission.

### Steps that need the account

1. Enrol in the Apple Developer Program.
2. Register the app id `io.sxong.tilt`.
3. Create a Mac App Store provisioning profile for it.
4. Open `Tilt.xcodeproj`, set the team on the Tilt target, leave signing automatic.
5. Product, then Archive, then Distribute App to App Store Connect.
6. Fill in App Store Connect: name, description, screenshots, and a privacy policy URL, which
   every app needs. The policy has to say the screen capture never leaves the machine, because
   that is the question the capture raises.

Worth writing in the review notes, since the review machine may have no lid at all:

> Tilt reads the MacBook lid angle from the built-in HID sensor and renders the desktop in
> perspective as the lid closes. `com.apple.security.device.usb` is what grants IOKit access to
> that sensor and is used for nothing else, no external or removable device. Screen recording is
> what draws the desktop as the tilting plane. On a Mac with no lid angle sensor or no built-in
> display, choose Run Demo from the menu bar item to see the effect.

### Known risks

No lid angle app is on the Mac App Store today, so there is no precedent either way. Two things
a reviewer may ask about: a USB entitlement on an app that touches no removable device, and a
sensor whose HID usage Apple has not documented, although it is read through public IOKit calls
rather than a private API. The name is worth checking early, since several apps beginning with
Tilt are already there.

## Checks

```sh
./Tilt.app/Contents/MacOS/Tilt --check
```

Reads the sensor and asserts the smoothing filter still hides the quantisation without lagging a
fast close.

## Credits

Menu bar glyph from [Tabler Icons](https://tabler.io/icons), MIT licensed.
