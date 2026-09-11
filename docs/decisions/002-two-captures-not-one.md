---
status: accepted
date: 2026-09-11
---

# 002. The desktop is captured twice, and the wallpaper is not part of the tilt

## Context

The obvious implementation captures the whole screen and tilts the result. It puts the wallpaper
on screen twice at two different angles: once flat behind the overlay, once inside the tilted
picture. The overlap reads as a rendering fault rather than as depth.

## Decision

Two captures. A still of the wallpaper with every window excluded, drawn flat behind everything,
and a live ScreenCaptureKit stream of the windows alone on a transparent background, drawn in
front and turned. The windows lift off a wallpaper that stays where it is.

## Consequences

The wallpaper still is taken with `excludingDesktopWindows: true`. With `false` the wallpaper
window joins the list, so excluding every window leaves nothing and the capture returns nil. It
surfaces as a black surround when the picture tilts rather than as an error, which cost a full
debugging round.
