---
status: accepted
date: 2026-09-11
---

# 001. The effect runs on the built-in display only

## Context

The app renders the desktop as a plane that stays fixed in space while the lid turns in front of
it. That illusion is a statement about a physical panel rotating around a hinge.

An external display does not rotate. Rendering the effect there produces motion with nothing
causing it, and the geometry has no eye position that makes sense.

## Decision

`engage()` refuses any screen that is not the built-in panel.

The check reads the screen itself rather than a suppression flag. `nsScreen` outlives the screen
it names: when the built-in panel goes away the app stands down but keeps the reference, and
several paths clear the flag independently, so a flag could not carry the rule.

## Consequences

In clamshell on an external display the app is inert, and says so in the menu. That is the same
state a review machine is in, which is why the demo in 004 can borrow a screen: a demo is not
claiming the panel is turning.
