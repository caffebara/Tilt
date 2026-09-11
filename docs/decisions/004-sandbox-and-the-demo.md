---
status: accepted
date: 2026-09-11
---

# 004. Target the App Store under the sandbox, and ship a demo for hardware with no lid

## Context

The store requires the app sandbox, and it is widely written that the lid angle sensor cannot be
read inside one. Measured against a bundle id holding no permission grants, so nothing else could
account for the result:

| signed with | sensor read |
| --- | --- |
| sandbox alone | fails, `0xE00002CD` |
| sandbox and `com.apple.security.device.usb` | succeeds |

Separately, App Review runs on hardware that may have no lid angle sensor and no built-in display
at all. There the app is correctly inert, which is indistinguishable from broken.

## Decision

Ship sandboxed with `com.apple.security.device.usb`, and add a demo that sweeps the angle through
one close and open so the effect can be seen without a hinge. The demo borrows a screen when
there is no built-in one.

## Consequences

That entitlement looks removable and is not: without it the app silently does nothing.

Borrowing a screen is the one hole in 001, so the rule had to move from the suppression flag into
`engage()` before the demo could exist. Verified: sensor below the threshold on an external
display does not engage, before or after a demo.

No lid angle app is on the Mac App Store today, so there is no precedent that this passes review.
