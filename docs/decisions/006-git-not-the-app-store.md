---
status: accepted
date: 2026-09-28
---

# 006. Distribute from Git, not the App Store

## Context

The store path was built out rather than planned: the sandbox and the
`com.apple.security.device.usb` entitlement that makes the sensor answer inside it,
`PrivacyInfo.xcprivacy` in both build paths, a served privacy policy the app links,
a support page, the listing text, the capture transforms, and every review clause
this app would have pulled in, tabulated in `docs/app-store.md`. What was left
needed an Apple Developer account and nothing else.

On 2026-09-28 the iTunes Search API was asked what else reads the hinge. Four apps:
Lidio in April, hynthesizer in April, and then RepLid Duo on 2026-09-17 and Lid Up
on 2026-09-23, the last two folding or tilting the desktop as the lid closes. Both
are free and both are in the KR storefront.

That answered the review question, which had been the open one, and replaced it
with a different one. A sandboxed app reading the built-in hinge sensor ships. What
it no longer is, is novel or worth a thousand won against two free equivalents.

## Decision

MIT licence, public repository, and the source is the distribution. No listing.

## Consequences

**The paid membership does not disappear, it only stops buying anything.** Apple's
notarization documentation says "Before distributing your app directly to customers,
your Account Holder must sign the app with your Developer ID", and that "all software
built after June 1, 2019, and distributed with Developer ID must be notarized". Account
Holder is a role in the Developer Program, so a signed download off the store needs the
same $99 the store would have. What is free is source.

**So `./build.sh` is the distribution, and that is the better mechanism here rather
than the cheaper one.** `build.sh` signs with a certificate it creates, which is the
only reason the screen recording grant survives a rebuild: an ad-hoc signature pins the
grant to the binary's hash. A notarized download would hand every user an update that
asks for the permission again.

**If a binary is ever published anyway, Gatekeeper has moved.** Since macOS 15 a
control-click no longer overrides it; an unsigned download sends the user to System
Settings, Privacy & Security, to allow it there. Read from Apple's own note on runtime
protection in Sequoia, 2026-09-28.

**Nothing in the app changes.** The sandbox stays, and so does `device.usb`, which
`AGENTS.md` records as the one grant the sensor needs: removing it looks harmless and
silently kills the app. `PrivacyInfo.xcprivacy` stays, harmless and true. The privacy
policy URL stays compiled in and its repository stays the only copy, because the policy
is still the honest answer to what the capture does and 006 does not make it false.

~~`docs/app-store.md` is kept as a record rather than deleted.~~ **Deleted on 2026-09-29,
with `docs/listing.md`.** Four hundred lines of process for a store this app is not on is noise in
a public repository, and the reader it was written for no longer exists. What was load-bearing was
already held elsewhere and stays: the sandbox measurement is in 004 and in `AGENTS.md`, and the
architecture check's commands moved into `AGENTS.md` rather than being pointed at. What went with
it was store process, the review-clause table, and the listing copy.

**005 still points at that file and is left pointing.** A decision records what was true when it
was made, and repairing its prose to match a later one would make the record agree with itself
rather than with what happened.

**What this accepts is discovery.** Nobody finds this in a store search. The two apps
that do the same thing are free, listed, and the ones people will find, and this one
is reachable only by someone who already has the link.
