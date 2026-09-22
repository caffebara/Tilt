# The App Store listing

The text App Store Connect asks for, written before the account exists so that the day of the
submission is a paste rather than a draft. Field limits are Apple's, read off the platform version
information reference on 2026-09-22, and the name and subtitle maxima of 30 characters off the app
information reference the same day; `docs/app-store.md` § 8 has which fields are required.

Everything here is plain text. The description field does not render HTML or Markdown, so the
headings below are the literal lines that go in it.

Every sentence is a claim about the app, and 2.3 makes accurate metadata a review matter. Anything
that stops being true of `main.swift` is wrong here too, the same dependency the privacy policy has.

## Name

```
Tilt
```

## Subtitle

```
The desktop leans with the lid
```

## Promotional text

```
Close the lid and your desktop lies back, drawn in the perspective the angle asks for. Read from
the hinge sensor, degree by degree.
```

## Keywords

Nothing here repeats a word from the name, the subtitle or the category, because Apple's search
guidance says not to: "Do not repeat any words included in your app name, subtitle, or category",
and plurals of a word already used count as duplicates. Read 2026-09-22. That is what rules out
`tilt`, `desktop`, `lid` and `utilities`, which are the four most obvious words for this app and
all four are already indexed. A phrase keeps its space, per the same page's own example.

```
hinge,angle,perspective,3d,depth,wallpaper,parallax,menu bar,laptop,fold,gesture,animation,sensor
```

## Description

```
Tilt turns closing your laptop into something worth watching.

As the lid comes over, the desktop lies back. The wallpaper stays where it is and the windows
lean away from it, drawn in the perspective you would see if the screen were a sheet of glass
laid flat in front of you. Open the lid and it comes back. None of it is faked: the angle is read
from the sensor in the hinge, so the picture follows the lid as it moves.

IT LIVES IN THE MENU BAR

No window and no Dock icon. One icon with a switch in it, and the rest is the lid.

SET IT TO YOUR MACHINE AND YOUR DESK

Engage below — the angle the effect starts under, from 40 to 120 degrees.

You sit about — how far you are from the screen. The perspective is drawn for that distance, so a
laptop on a desk and the same laptop on your knees are not the same picture.

Glass effect — how much the far edge blurs and darkens as it leans away, from off to strong.

Show angle in menu bar — the lid angle, live, beside the icon.

Escape gets you out of the effect, and so does opening the lid.

WHAT IT NEEDS

A MacBook. Tilt reads the lid angle from the sensor in the hinge, and a Mac with no lid has no
sensor.

The built-in display. The effect is a picture held still while the lid turns in front of it, and
an external display does not turn.

Permission to record the screen, because the desktop is the picture Tilt tilts. macOS asks for it
when the app starts.

WHAT IT DOES NOT DO

Tilt has no network code of any kind. What it captures is drawn on your screen and discarded frame
by frame, never written to disk and never sent anywhere. It keeps your settings on your Mac and
nothing else.

Support: https://caffebara.github.io/tilt-privacy/support.html
```
