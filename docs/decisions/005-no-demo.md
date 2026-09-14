---
status: accepted
date: 2026-09-14
supersedes: 004 (the demo half only)
---

# 005. Drop the demo

## Context

004 added a demo so that App Review, on hardware with no lid angle sensor and no
built-in display, could see the effect at all. There the app is correctly inert,
and inert is indistinguishable from broken.

It cost something, and 004 said so: the demo borrows a screen, which is the one
hole in 001's rule that the effect belongs to the built-in panel. `engage()` had
to carry an exemption for it.

## Decision

Remove it. The menu item, the sweep, and the exemption in `engage()`.

A Mac that cannot read a lid angle cannot run this app, and a demo does not change
that. It shows the owner of such a Mac a thing their machine will never do, and it
sits in the menu of every Mac that can, where it is one more row for a feature
nobody needs. The reviewer is the only reader it was ever for, and the review
notes can carry the explanation instead of the app carrying a mode.

## Consequences

001 tightens back to what it says: `engage()` now asks only whether the screen is
the built-in panel, with nothing else able to answer for it. The hole 004 opened
is closed rather than documented.

App Review on hardware with no lid sensor sees an app that does nothing, and
`docs/app-store.md` now says that in the review notes rather than pointing at a
menu item. That is the risk this decision accepts: a reviewer who does not read
the note has no way to tell inert from broken.
