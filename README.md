# Tilt

A menu bar app that renders your Mac's desktop in 3D perspective, driven by the MacBook lid angle.

Close the lid past a threshold and the windows lift off the desktop: the wallpaper stays flat where
it is, the windows tilt away from it, and the picture stays put in space while the panel turns in
front of it. Open the lid back past the threshold and everything goes away.

<img src="docs/demo.gif" alt="A MacBook lid closing: as it comes down, the Notes window on screen leans back while the wallpaper around it stays put" width="480">

| Lid open | Lid closing |
| --- | --- |
| ![The desktop with the lid open, a Notes window lying flat](docs/before.png) | ![The same desktop with the lid closing: the Notes window leans away while the wallpaper stays flat](docs/after.png) |

## Requirements

- An Apple silicon MacBook with a lid angle sensor
- macOS 14 or later
- Screen recording permission, which macOS asks for on first launch

It runs on the built-in display only. The illusion is that a plane stays fixed while the lid turns
in front of it, and an external display does not turn.

## Install

Download it, or build it from source. Either way it is the same app.

### Download

1. Download `Tilt-1.0.zip` from [Releases](https://github.com/caffebara/Tilt/releases/latest),
   open it, and drag `Tilt.app` into Applications in Finder before opening it. Opened where it
   was unzipped, macOS runs it from a temporary copy, and the "Open at login" switch does not
   appear.
2. Open it. The first time, macOS stops it with this:

   > **"Tilt.app" Not Opened**
   >
   > Apple could not verify "Tilt.app" is free of malware that may harm your Mac or compromise
   > your privacy.

   Choose **Done**, not Move to Trash, which deletes the app. macOS says this about any app not
   signed with a paid Apple Developer ID, whatever the app does, and the source it was built from
   is this repository. Then open System Settings, then Privacy & Security, scroll to the line
   about Tilt near the bottom and choose **Open Anyway**. macOS asks this once.

Each release lists the zip's SHA-256, so you can check the file you got is the one published:
`shasum -a 256 Tilt-1.0.zip`.

### Build from source

You need Xcode's command line tools, for `swiftc`.

```sh
git clone https://github.com/caffebara/Tilt
cd Tilt
./build.sh --install
```

That builds, quits a running Tilt, replaces `/Applications/Tilt.app` with the new build and opens
it. It refuses to replace an app of that name that is not Tilt. A plain `./build.sh` builds
`Tilt.app` beside the script and stops there, and it runs from there too.

**Every build asks for screen recording again, once.** `build.sh` signs ad hoc, so it never touches
your keychain, and macOS ties the permission to that exact build. A rebuild is a new app to it.
`--install` clears the old permission before it installs, so macOS asks cleanly. A plain
`./build.sh` does not, so after rebuilding in place run the `tccutil` line below: the old
permission stays recorded against the old build and does not apply to the new one.

### First launch

Nothing appears, because there is no window: Tilt is the icon in the menu bar. macOS asks for
screen recording, and until that is granted the app does nothing, since your desktop is the
picture it tilts. Let macOS quit and reopen Tilt when it offers, or the permission does not take
hold until the next launch. Keep it in `/Applications` if you want the "Open at login" switch.

## Uninstall

Reset the screen recording permission first, while Tilt is still installed. `tccutil` finds the
app through macOS's record of it, and with the app deleted it fails with "No such bundle
identifier".

```sh
tccutil reset ScreenCapture io.sxong.tilt
```

Then delete `Tilt.app`. The settings and the "Open at login" entry are removed as
[PRIVACY.md](PRIVACY.md) describes.

## Controls

Everything lives in the menu bar icon.

<img src="docs/menu.png" alt="The Tilt menu open under its menu bar icon, which shows the lid angle: Enabled, Engage below, You sit about, Glass effect, Show angle in menu bar, Open at login, Quit Tilt" width="420">

- **Enabled** switches the effect on and off.
- **Engage below** is the lid angle the effect starts under, from 40° to 120° in steps of 5. It
  goes away again two degrees above it. Under 20° Tilt gets out of the way whatever this says,
  because a lid that far down is usually on its way to sleep.
- **You sit about** is your distance from the screen, from 30 to 90 cm. The perspective is drawn
  for that distance, so this is the one to move if the effect looks too strong or too flat.
- **Glass effect** is how much the far edge blurs and darkens as it leans away: Off, Subtle,
  Medium or Strong.
- **Show angle in menu bar** puts the current lid angle beside the icon, which is the quickest way
  to see that the sensor is being read.
- **Open at login** appears only when Tilt runs from an Applications folder.

If nothing happens when the lid comes down, open the menu: it says why. Only the screen recording
note means the permission has not taken hold yet, so quit and reopen Tilt. "No lid angle sensor on
this Mac" means it cannot run here, and "Waiting for the built-in display" means only an external
display is in use. "Capture failed" names the cause and offers Try again. A full menu and still
nothing means Enabled is off, or Engage below is lower than where your lid stops.

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

## Development

```sh
./Tilt.app/Contents/MacOS/Tilt --check
```

Reads the sensor and asserts the smoothing filter still hides the quantisation without lagging a
fast close.

```sh
./build.sh --test
```

Builds `TiltTest.app` into `$TMPDIR` with the lid angle read from `/tmp/tilt-fake-lid`, so
transitions can be driven without a hand on the hinge. The hook is behind a compile flag and cannot
reach a normal build. It goes to `$TMPDIR` because built beside the real app it turned up in
launchers with the same name, icon and bundle id.

To use your own icon, replace `AppIcon.png` with a 1024x1024 one, delete `AppIcon.icns` and build
again. With no `AppIcon.png` at all, `makeicon.swift` draws a placeholder.

The app is sandboxed and carries `com.apple.security.device.usb`, which is what lets it read the
sensor at all rather than anything to do with USB devices. `AGENTS.md` says what removing it costs,
along with the rest of what this code does not reveal about itself.

## Privacy

No network code, nothing written to disk, and nothing but settings stored.
[PRIVACY.md](PRIVACY.md) says what is read, what is kept, and how to remove it.

## Licence

MIT, in [LICENSE](LICENSE). The menu bar glyph is somebody else's and carries its own notice; see
below.

## Credits

Menu bar glyph from [Tabler Icons](https://tabler.io/icons), MIT licensed. The notice ships
inside the app bundle; see [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).
