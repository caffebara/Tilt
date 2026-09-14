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
> for input monitoring. Tilt does not need it and does not request it: the overlay covers the
> screen at the shielding window level and takes key focus, and the system asks about any window
> in that position. The only key handling is a local monitor, which sees nothing but events
> already dispatched to Tilt and passes every one of them through untouched except escape.
> Measured with the permission switched off: escape still dismisses the overlay, and so does a
> click. The prompt can be denied and nothing is lost.
>
> On a Mac with no lid angle sensor, or with the lid shut and an external display, Tilt does
> nothing at all, and its menu says which of the two it is: "No lid angle sensor on this Mac" or
> "Waiting for the built-in display". That is the app working correctly rather than failing. It
> reads a MacBook hinge, so hardware without one has nothing for it to read. Decision 005 in the
> repository records why there is no demo mode to show the effect instead.

## Before the upload

Ordered, and the first one gates the rest: App Store Connect will not reserve a name somebody else
holds, so there is no point filling in a listing under a name that turns out to be taken.

1. **Reserve the name.** Several apps beginning with Tilt are already on the store.
2. ~~`PrivacyInfo.xcprivacy`~~ **Done.** `Resources/PrivacyInfo.xcprivacy` declares no tracking, no
   collected data, and the one required-reason API this app touches: `UserDefaults`, reason CA92.1
   (ITMS-91053). It is wired into **both** build paths, the `PBXResourcesBuildPhase` in
   `Tilt.xcodeproj` and a `cp` in `build.sh`, because one path only is exactly the bug 003 names.
   Verified by building both: the file lands in both bundles and the two copies are identical.

   The one thing left open is `CACurrentMediaTime()` at `main.swift:534`, the only other
   required-reason candidate in the code. It schedules a `CAAnimation.beginTime` rather than
   reading boot time, and nothing else in the file touches file timestamps, disk space or the
   active keyboard. Check it against Apple's current required-reason list when the account exists,
   since that list is versioned and is not readable from here.
3. **Verify the rendering change on hardware.** `074a2cb..5689ec1` has not been seen on a real lid.
4. ~~`ITSAppUsesNonExemptEncryption`~~ **Done.** `false`, in `Resources/Info.plist`, which removes
   the export compliance question App Store Connect otherwise asks on every single upload. The key
   is real: Xcode's `CoreBuildSystem.xcspec` carries it as
   `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`. Verified present in both built bundles.
5. Screenshots, a privacy policy URL, and the App Privacy questionnaire, whose answer is that no
   data is collected.

Two things to check on the exported archive rather than before it:

**`get-task-allow` must not be in it.** `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` is `YES`, so a locally
signed build carries it. Measured with ad-hoc signing on 2026-09-14: the product's entitlements are
`app-sandbox`, `device.usb` and `get-task-allow`. Distribute App is supposed to strip the last one,
and an archive that keeps it is rejected automatically. Worth one `codesign -d --entitlements :-`
on the exported bundle.

**The icon may need `CFBundleIconName` and an asset catalog.** `AppIcon.icns` is well formed, all
ten sizes from 16 through 512@2x, and that is not the same as the store accepting it. Measured on
this machine: all 15 installed Mac App Store apps carry both `Assets.car` and `CFBundleIconName`,
and none ships a bare `CFBundleIconFile`. This bundle ships a bare `CFBundleIconFile`. No macOS
validation rule was found either way, so the first upload is what decides it.

## Known risks

No lid angle app is on the Mac App Store today, so there is no precedent either way. Three things
a reviewer may ask about: a USB entitlement on an app that touches no removable device, a sensor
whose HID usage Apple has not documented, although it is read through public IOKit calls rather
than a private API, and a keystroke prompt on an app that does not type. That last one arrives
with no explanation of its own, unlike screen recording, which this app introduces with a panel
of its own before macOS asks. Measured on 2026-09-14: launching does not raise it, the first
engagement does, so a reviewer who never gets the overlay on screen will never see it. Denying it
changes nothing, which is the part worth saying out loud, and the app never appears in the Input
Monitoring list at all, because it never asks: the prompt is the window server's, not Tilt's.

The name is worth checking early, since several apps beginning with Tilt are already there. It is
step 1 above because it gates the upload rather than the review.

A fourth risk that no reviewer will ask about, because nothing reports it at all. `angle(from:)`
returns the raw feature report value with no range check, and the `0...180` guard lives only in
`--check`. A Mac whose sensor reports on another scale would sit permanently below the threshold,
inert, with a menu saying nothing is wrong. That is the failure 005 accepted, arriving from the
decode rather than from the hardware being absent, and it would look identical to a reviewer.

## Checked, and not a problem

Both of these were raised as blockers by a submission review on 2026-09-14, and both were wrong.
The commands that settled them are written down because the reasoning that produced them is easy to
repeat: each one looks right from the code alone.

**The two build paths differ on architecture, and that is fine.** `build.sh` passes
`-target arm64-apple-macos14.0`, while the project sets no `ARCHS` and inherits `arm64 x86_64`, so
the archive is universal. That reads as a slice nobody has ever run. Run it. On the Xcode product,
not on `Tilt.app`, which is arm64 by design:

```sh
arch -arm64  "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
arch -x86_64 "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
```

Both read the real sensor and print identical output. Pinning `ARCHS = arm64` to make the two paths
agree would cut a platform off the listing, which is the one change in this area that cannot be
walked back, in exchange for nothing measured.

**The two IOKit error codes in this repository are both correct.** `0xE00002CD` is
`kIOReturnNotOpen` and `0xE00002E2` is `kIOReturnNotPermitted` (`IOReturn.h:115` and `:138`), and
they are one failure seen at two call sites: `main.swift:41` discards what `IOHIDManagerOpen`
returns, so the code the app can actually surface is the `kIOReturnNotOpen` that
`IOHIDDeviceGetReport` returns afterwards. Reconciling them to a single value deletes the record
that this is a permission failure, and a reader left holding "device not open" fixes it by opening
the device and drops `com.apple.security.device.usb`. `AGENTS.md` says what that costs.
