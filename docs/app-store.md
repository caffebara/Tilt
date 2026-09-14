# Submitting Tilt to the Mac App Store

The app is built and signed for it. What is left needs an Apple Developer account.

`build.sh` stays the local loop: it signs with a certificate it creates itself, which is what
keeps the screen recording permission across rebuilds. `Tilt.xcodeproj` is the submission path,
and both read the same `Resources/Info.plist`, `Resources/Tilt.entitlements` and `makeicns.sh`.

## What the sandbox needed

The store requires the app sandbox, and the lid angle sensor stops answering inside it. Measured
with a bundle id holding no permission grants at all, so nothing else could account for it:

| signed with | sensor read |
| --- | --- |
| sandbox alone | fails, 0xE00002CD |
| sandbox and `com.apple.security.device.usb` | succeeds |

That entitlement is the one grant the sensor needs. ScreenCaptureKit needs no entitlement, only
the screen recording permission.

## Steps that need the account

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
> what draws the desktop as the tilting plane. The first time the overlay appears macOS also asks
> for input monitoring: the overlay covers the screen at the shielding window level and takes key
> focus so that escape dismisses it, and the system treats a window in that position as able to
> see keystrokes meant for other apps. Tilt installs a local monitor that passes every key through
> untouched except escape, and denying the permission costs only that shortcut, since a click
> dismisses the overlay too. On a Mac with no lid angle sensor or no built-in display, choose Run
> Demo from the menu bar item to see the effect.

## Known risks

No lid angle app is on the Mac App Store today, so there is no precedent either way. Three things
a reviewer may ask about: a USB entitlement on an app that touches no removable device, a sensor
whose HID usage Apple has not documented, although it is read through public IOKit calls rather
than a private API, and a keystroke prompt on an app that does not type. That last one arrives
with no explanation of its own, unlike screen recording, which this app introduces with a panel
of its own before macOS asks. Measured on 2026-09-14: launching does not raise it, the first
engagement does, so a reviewer who never gets the overlay on screen will never see it.

The name is worth checking early, since several apps beginning with Tilt are already there.
