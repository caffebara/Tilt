# App Store listing

Copy for App Store Connect, pasted in as it is. The limits in brackets are Apple's; the checker
in the store repo counts each block against them.

**Draft, 2026-10-02.** Written before the name is reserved. If "Tilt" is taken, the Name, Subtitle
and Description change with it; the review notes do not. English, because the app's own interface
is English.

## Name [30]

```
Tilt
```

## Subtitle [30]

```
Your desktop, in perspective
```

## Promotional text [170]

```
Close your MacBook's lid partway and the windows lift off the desktop, held still in space while the screen turns in front of them.
```

## Keywords [100]

```
perspective,lid,hinge,angle,desktop,parallax,wallpaper,illusion,depth,menu bar,screen,window
```

## Description, Mac [4000]

```
Tilt turns the angle of your MacBook's lid into depth.

Bring the lid down past a threshold and the desktop changes: the wallpaper stays flat where it is, the windows tilt away from it, and the picture holds still in space while the panel turns in front of it. Open the lid back up and everything returns to normal.

It reads the lid angle from the sensor built into the hinge, so there is nothing to wear, track or calibrate. The perspective is drawn for how far you sit from the screen, which you set once.

■ Controls, all in the menu bar
• Enabled: switch the effect on and off.
• Engage below: the lid angle the effect starts under, from 40° to 120°.
• You sit about: your distance from the screen, from 30 to 90 cm.
• Glass effect: how much the far edge blurs and darkens as it leans away.
• Show angle in menu bar: the live lid angle beside the icon.
• Open at login.

While the effect is on screen, press Esc to dismiss it, or open the lid back past the threshold.

■ Requirements
An Apple silicon MacBook with a lid angle sensor, and the built-in display. An external display does not turn, so Tilt does nothing there.

■ Privacy
Tilt needs the Screen Recording permission, because drawing your desktop in perspective means reading it first. The picture is drawn on your screen and discarded: never saved, never sent. Tilt has no network code at all, and stores nothing but its own settings.
```

## Category

Utilities (`public.app-category.utilities`), set in `Resources/Info.plist`.

## Support URL

```
https://caffebara.github.io/Tilt/SUPPORT.html
```

## Privacy policy URL

```
https://caffebara.github.io/Tilt/PRIVACY.html
```

## Copyright

```
2026 Myungkeun Song
```

## Review notes [4000]

```
Tilt draws the Mac's desktop in 3D perspective, driven by the MacBook lid angle. Close the lid partway and the windows tilt away from a flat wallpaper, held fixed in space while the screen turns.

HARDWARE: an Apple silicon MacBook with a lid angle sensor, using its built-in display. On a desktop Mac, or with only an external display, the menu says "No lid angle sensor on this Mac" or "Waiting for the built-in display" and nothing else happens. A recording of the effect on a real MacBook: https://github.com/caffebara/Tilt/releases/download/v1.0/Tilt-real.mp4 . A 3D render of the same effect seen from the viewer's position, with the lid driven by a real recording: https://github.com/caffebara/Tilt/releases/download/v1.0/Tilt-render.mp4

TO SEE IT:
1. Open Tilt. It has no window; it is the icon in the menu bar.
2. macOS asks for Screen Recording. Allow it, and let macOS quit and reopen Tilt.
3. With the lid fully open, bring it down slowly. Below 90° (the "Engage below" setting in the menu) the effect starts. Set "Engage below" to 120° to see it after only a small movement.
4. To leave: press Esc, or open the lid back past the threshold. After Esc the effect stays away until the lid has been opened past the threshold again, and the menu says so.

PERMISSIONS: Screen Recording only. Tilt captures the desktop with ScreenCaptureKit to draw it in perspective; nothing is stored or transmitted, and the app has no network code. If the permission is refused, the menu explains why it is needed and links to the Screen Recording pane in System Settings, and nothing is drawn.

ENTITLEMENTS: com.apple.security.device.usb. The lid angle sensor is an IOKit HID device (sensor usage page 0x20, orientation usage 0x8A), and inside the App Sandbox IOHIDManagerOpen is refused without this entitlement. Tilt opens that one sensor and no USB or other connected device.

The overlay is a full-screen window above other windows while the lid is lowered, because the whole desktop is what it redraws. While it is up, Tilt watches key presses only to recognise Esc; every other key passes through to the app underneath.

No account, no purchases, no in-app purchase.
```
