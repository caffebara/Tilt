# App Store listing

Copy for App Store Connect, pasted in as it is. The limits in brackets are Apple's; the checker
in the store repo counts each block against them.

The store name is reserved: "Tilt" alone was already taken, so the App Store Connect record
(2026-10-06, bundle id com.cottonferry.tilt) is "Tilt: Lid Perspective". The app itself is still
called Tilt in the menu bar and in Finder. English, because the app's own interface is English.

## Name [30]

```
Tilt: Lid Perspective
```

## Subtitle [30]

```
Windows lift as the lid closes
```

## Promotional text [170]

```
Lower your MacBook's lid a little and your windows lean back while the desktop holds still. Lift it again and it's just your Mac.
```

## Keywords [100]

```
hinge,angle,desktop,parallax,wallpaper,illusion,depth,spatial,menu bar,screen,window,laptop,motion
```

## Description, Mac [4000]

```
Tilt is a small menu bar app that turns your MacBook's lid into a window onto your desktop.

Lower the lid a little and the desktop stays where it was. The wallpaper sits flat, your windows lean back from it, and as the screen keeps turning, the picture holds still behind the glass. Lift the lid again and everything is back to normal.

There's no camera and no head tracking. Your MacBook already knows its lid angle from a sensor in the hinge, and Tilt simply reads it. You tell Tilt roughly how far you sit from the screen, and it draws the perspective for that spot.

You choose the angle where it starts, how far away you sit, and how much the far edge softens as it leans away. Everything lives in the menu bar. There's no window and no Dock icon, and if you want the effect gone halfway through, press Esc.

What you need
An Apple silicon MacBook with a lid angle sensor, using its built-in display. An external display doesn't move with the lid, so Tilt leaves it alone.

Privacy
Tilt asks for Screen Recording because it has to see your desktop to redraw it. Each frame is drawn and then thrown away. Nothing is saved, nothing leaves your Mac, and the app has no network code at all.
```

## Category

Utilities (`public.app-category.utilities`), set in `Resources/Info.plist`.

## Support URL

```
https://tilt.cottonferry.com/support/
```

## Privacy policy URL

```
https://tilt.cottonferry.com/privacy/
```

## Copyright

```
2026 Myungkeun Song
```

## Review notes [4000]

```
Tilt draws the Mac's desktop in 3D perspective, driven by the MacBook lid angle. Close the lid partway and the windows tilt away from a flat wallpaper, held fixed in space while the screen turns.

PURPOSE AND AUDIENCE: a free menu bar utility for people with an Apple silicon MacBook. It turns the hinge angle into a sense of depth: a small, playful way to see the desktop, with settings for the angle it starts at, the viewing distance, and the strength of the effect.

HARDWARE: an Apple silicon MacBook with a lid angle sensor, using its built-in display. On a desktop Mac, or with only an external display, the menu says "No lid angle sensor on this Mac" or "Waiting for the built-in display" and nothing else happens. A screen recording from launch and a camera video of the same MacBook, showing the lid and the picture together, are attached to the App Review reply.

TO SEE IT:
1. Open Tilt. It has no window; it is the icon in the menu bar.
2. macOS asks for Screen Recording. Allow it, and let macOS quit and reopen Tilt.
3. With the lid fully open, bring it down slowly. Below 90° (the "Engage below" setting in the menu) the effect starts. Set "Engage below" to 120° to see it after only a small movement.
4. To leave: press Esc, or open the lid back past the threshold. After Esc the effect stays away until the lid has been opened past the threshold again, and the menu says so.

PERMISSIONS: Screen Recording only. Tilt captures the desktop with ScreenCaptureKit to draw it in perspective; nothing is stored or transmitted, and the app has no network code. If the permission is refused, the menu explains why it is needed and links to the Screen Recording pane in System Settings, and nothing is drawn.

ENTITLEMENTS: com.apple.security.device.usb. The lid angle sensor is an IOKit HID device (sensor usage page 0x20, orientation usage 0x8A), and inside the App Sandbox IOHIDManagerOpen is refused without this entitlement. Tilt opens that one sensor and no USB or other connected device.

The overlay is a full-screen window above other windows while the lid is lowered, because the whole desktop is what it redraws. While it is up, Tilt watches key presses only to recognise Esc; every other key passes through to the app underneath.

EXTERNAL SERVICES: none. Tilt has no network code and uses only Apple frameworks on the device: IOKit HID for the lid angle, ScreenCaptureKit for the desktop. No login, credentials or sample files are needed.

REGIONAL DIFFERENCES: none. The app works the same in every region where it is available.

THIRD-PARTY MATERIAL: the menu bar icon from Tabler Icons, MIT licensed, with its license notice in the app bundle. No regulated industry.

No account, no user-generated content, no purchases, no in-app purchase.
```
