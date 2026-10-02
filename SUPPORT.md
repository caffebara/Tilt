# Tilt support

Email: sxong2x@gmail.com

Bug reports and questions are also welcome as
[GitHub issues](https://github.com/caffebara/Tilt/issues).

## Requirements

- An Apple silicon MacBook with a lid angle sensor
- macOS 14 or later
- The built-in display. An external display does not turn with the lid, so Tilt does nothing there.
- The Screen Recording permission, which macOS asks for the first time Tilt opens

## Getting out of the effect

Press **Esc**, or open the lid back past the angle the effect started at. After Esc it stays away
until the lid has been opened past that angle again, and the menu says so.

## If nothing happens when the lid comes down

Open the menu bar icon: the menu says why.

- A note about screen recording means the permission has not taken hold yet. Switch Tilt on in
  System Settings, under Privacy & Security, then Screen & System Audio Recording, and reopen Tilt.
- "No lid angle sensor on this Mac" means Tilt cannot run on this Mac.
- "Waiting for the built-in display" means only an external display is in use.
- If the menu shows all its controls, check that Enabled is on and that Engage below is higher than
  the angle your lid stops at.

## Privacy

Tilt collects nothing and has no network code. The [privacy policy](PRIVACY.html) says what it
reads and what it keeps.
