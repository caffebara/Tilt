# Privacy Policy for Tilt

Last updated: 2026-09-15

**Tilt collects no personal data, and it has no network code of any kind.** Nothing it reads leaves
your Mac, because there is nothing in the app that could send it anywhere.

## What Tilt reads

**The lid angle.** Tilt reads the angle of your MacBook's lid from the built-in sensor, through
the system's IOKit interface. It is a number in degrees and nothing else. It is used to draw the
screen in perspective and is never stored.

**The screen.** While the effect is on, Tilt captures the desktop through macOS's own
ScreenCaptureKit, which is why macOS asks you for the Screen Recording permission the first time.
It takes a still of the wallpaper and a live stream of the windows so it can tilt the windows away
from the wallpaper behind them.

## What happens to the capture

It is drawn on your screen and discarded. Tilt holds one frame in memory so the picture does not
flicker while the next frame arrives, releases it as soon as that frame lands, and releases it
entirely when the effect ends.

The capture is never written to disk. It is never transmitted. It is never shown to anyone but
you, on the machine it came from.

## What Tilt stores

Six settings, and only settings. They are kept by macOS in Tilt's own sandbox container on your
Mac:

- whether the effect is switched on
- the lid angle at which it engages
- the strength of the glass treatment
- your viewing distance in centimetres
- whether the angle appears in the menu bar
- whether you have already seen the first-run hint

No usage data, no identifiers, no analytics, no crash reporting, and no third-party services of any
kind. Tilt has no account, no sign-in, and no server.

**One thing is kept outside that container, by macOS rather than by Tilt.** If you switch on "Open
at login", macOS records that choice in its own background task database, which is where every
login item on your Mac lives. It holds the fact that you asked for Tilt to start, and nothing
about you. You can see it and switch it off at any time in System Settings, under General and then
Login Items, and Tilt's own menu reads that setting back from the system rather than keeping a
copy of its own.

**Deleting Tilt does not remove that entry**, which is worth knowing because it is not what most
people expect. Measured on 2026-09-15: with the application bundle deleted, the entry was still
recorded and still switched on. If you remove Tilt and want the entry gone too, switch it off in
Login Items. That is the only copy of it, and it is the system's rather than ours.

## Permissions

**Screen Recording** is required, because drawing your desktop in perspective means reading it
first. macOS asks for it, and you can revoke it at any time in System Settings under Privacy and
Security. Without it, Tilt simply does not draw the effect.

**The lid angle sensor** is reached through the `com.apple.security.device.usb` entitlement, which
is what macOS requires for access to that class of device from inside the app sandbox. Tilt uses
it for the hinge sensor and for nothing else. It reads no external, removable, or connected
device.

**Input Monitoring** is never requested. macOS may offer the prompt anyway, because Tilt's overlay
covers the screen and the system asks about any window in that position. You can deny it and lose
nothing: Tilt does not read your keystrokes and does not need the permission.

## Children

Tilt is not directed at children and collects nothing from anyone, of any age.

## Changes

If this policy ever changes, the new version replaces this page and the date at the top changes
with it.

## Contact

<!-- Fill this in before publishing the page. Apple expects a working contact route. -->
Questions about this policy: `<contact address>`
