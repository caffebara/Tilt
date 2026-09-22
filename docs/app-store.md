# Submitting Tilt to the Mac App Store

The app is built and signed for it. What is left needs an Apple Developer account.

`build.sh` stays the local loop: it signs with a certificate it creates itself, which is what
keeps the screen recording permission across rebuilds. `Tilt.xcodeproj` is the submission path,
and both read the same `Resources/Info.plist`, `Resources/Tilt.entitlements` and `makeicns.sh`.

## What the sandbox needed

The store requires the app sandbox, and the lid angle sensor stops answering inside it. Measured
with a bundle id holding no permission grants at all, so nothing else could account for it:

| signed with | sensor read |
| --- | --- |
| sandbox alone | fails, 0xE00002CD |
| sandbox and `com.apple.security.device.usb` | succeeds |

That entitlement is the one grant the sensor needs. ScreenCaptureKit needs no entitlement, only
the screen recording permission.

## Steps that need the account

1. Enrol in the Apple Developer Program. **$99 a year**, read off Apple's own page on 2026-09-17:
   "Join the Apple Developer Program, $99 annual membership. Enrol as an individual or
   organization." The $299 one is the Enterprise programme, for private distribution inside a
   company, and does not apply. Enrol as an individual: the store then shows a person's name in the
   DEVELOPER field, which is why `NSHumanReadableCopyright` says Myungkeun Song rather than a
   handle or an employer.
2. Register the app id `io.sxong.tilt`.
3. Create a Mac App Store provisioning profile for it.
4. Open `Tilt.xcodeproj`, set the team on the Tilt target, leave signing automatic.
5. Product, then Archive, then Distribute App to App Store Connect.
6. Fill in App Store Connect: name, description, screenshots, and a privacy policy URL, which
   every app needs. It is written and served, at <https://caffebara.github.io/tilt-privacy/>,
   and says the screen capture never leaves the machine, because that is the question the capture
   raises.
7. Tilt is being sold rather than given away, so the Paid Applications Agreement has to be accepted
   and the banking and tax details supplied before a price can be set. None of that touches the
   app, and all of it blocks the listing.

   **Opt into the Small Business Program separately.** It is not automatic and it is the difference
   between keeping 85% and keeping 70%. At a price of one thousand won that is 850 against 700, and
   against the annual fee it is 158 sales a year to break even rather than 192. Arithmetic from
   2026-09-17, when the fee came to about 135,000 won.

   Price tiers are Apple's own list, so whether a thousand won is one of them is a question for
   that screen rather than for this file. A price can be changed later, and so can free to paid.

   Review is not affected. 4.2 is the clause that decides whether a utility is substantial enough,
   and its text says nothing about price; the only place the guidelines separate paid from free is
   3.1.3(f), about free companions to paid web tools. The risk below is the same either way.

Worth writing in the review notes, since the review machine may have no lid at all:

> Tilt reads the MacBook lid angle from the built-in HID sensor and renders the desktop in
> perspective as the lid closes. `com.apple.security.device.usb` is what grants IOKit access to
> that sensor and is used for nothing else, no external or removable device. Screen recording is
> what draws the desktop as the tilting plane. Tilt asks for no other permission, and in
> particular does not ask for input monitoring. The only key handling is a local monitor, which
> sees nothing but events already dispatched to Tilt's own process, reads each one only far enough
> to tell whether it is escape, and passes every other one straight through. Nothing is stored or
> counted. Opening the lid dismisses the overlay as well, without any key at all.
>
> Tilt draws no recording indicator of its own, and 2.5.14 is answered by what the app is rather
> than by one it draws: Tilt's output is the capture. The captured screen fills the display in
> front of the user for as long as the capture runs, and the capture stops the moment the overlay
> does, so there is no state in which Tilt is recording and the user cannot see it. macOS draws
> its own indicator in the menu bar and beside the front window's close button as well, observed
> in both places while the overlay was up.
>
> The shipped binary also answers one command line flag. `Tilt --check` reads the lid angle once,
> prints it, runs a self-test of the angle filter against synthetic input, and exits without
> opening a window or capturing anything. It is a development aid, reachable only from a terminal,
> and it reads nothing the app does not already read while running.
>
> On a Mac with no lid angle sensor, or with the lid shut and an external display, Tilt does
> nothing at all, and its menu says which of the two it is: "No lid angle sensor on this Mac" or
> "Waiting for the built-in display". That is the app working correctly rather than failing. It
> reads a MacBook hinge, so hardware without one has nothing for it to read. Decision 005 in the
> repository records why there is no demo mode to show the effect instead.

## Before the upload

Ordered, and the first one gates the rest: App Store Connect will not reserve a name somebody else
holds, so there is no point filling in a listing under a name that turns out to be taken.

1. **Reserve the name.** Checked on 2026-09-15 through the iTunes Search API, US and KR storefronts,
   macOS and iOS: **no shipping app is called exactly "Tilt".** The near misses are all longer
   names, so none of them holds it: "Tilt Shift Focus", "Tilt Shift : Miniature Effect", "Tilt
   Shift for Final Cut Pro", "Tilt - Posture Monitor", "TILTRIRIS".

   That is a good signal and not a guarantee. The search API lists apps currently on sale, and a
   name reserved in App Store Connect by somebody who never shipped is invisible to it. Only
   entering the name in App Store Connect settles it, which is why this is still step 1.

   Re-checked 2026-09-22, same two storefronts and the same query: still no app called exactly
   "Tilt", and the near misses are the same four. A week of nothing moving is not the name being
   held.
2. ~~`PrivacyInfo.xcprivacy`~~ **Done.** `Resources/PrivacyInfo.xcprivacy` declares no tracking, no
   collected data, and the one required-reason API this app touches: `UserDefaults`, reason CA92.1.
   It is wired into **both** build paths, the `PBXResourcesBuildPhase` in `Tilt.xcodeproj` and a
   `cp` in `build.sh`, because one path only is exactly the bug 003 names.
   Verified by building both: the file lands in both bundles and the two copies are identical.

   ~~The one thing left open is `CACurrentMediaTime()`~~ **Settled, 2026-09-22, and it needed no
   account.** The required-reason list is public documentation. The sentence that stood here, to
   check it against that list once the account exists because the list is not readable from here,
   was wrong about where the answer lived rather than about the question.

   Apple's own page splits the manifest in two. The collected data types are required "for your app
   or third-party SDK on all platforms"; the required reasons APIs are required "for your app or
   third-party SDK on iOS, iPadOS, tvOS, visionOS, and watchOS". macOS is in the first list and
   absent from the second, and the required-reason article repeats it in its own words: "Describe
   the reasons your app or third-party SDK on iOS, iPadOS, tvOS, visionOS, or watchOS uses these
   APIs." Both read 2026-09-22. So the required-reason half of this file does not apply to a Mac
   App Store submission at all.

   It would not catch `CACurrentMediaTime()` if it did. The system boot time category names two
   APIs, `systemUptime` and `mach_absolute_time()`, and `main.swift` calls neither: grep it for
   both, and for `ProcessInfo`, which is what `systemUptime` hangs off. The other four categories
   are file timestamps, disk space, the active keyboard and user defaults, and the file touches
   none of the first three.

   And the binary does not import `mach_absolute_time` at all:

   ```sh
   nm -u Tilt.app/Contents/MacOS/Tilt | grep -iE 'mach_absolute|CACurrentMediaTime'
   # _CACurrentMediaTime, and nothing else
   ```

   `CACurrentMediaTime` is what the app calls; `mach_absolute_time` is what CoreAnimation calls on
   the other side of it, inside a system framework rather than in this bundle.

   The file stays as it is. The collected-data half is "all platforms", which is this app, and the
   `UserDefaults` declaration is surplus on macOS rather than wrong.
3. ~~Verify the rendering change on hardware~~ **Done, 2026-09-15.** Seen on a real lid, and it
   cost a commit: the surround darkened as the lid came over while the windows floating on it went
   pale. `gloss` was white through source-atop, which lifts blacks more than it drops whites, so
   `d65ed53` removes it. An LCD seen off axis converges on mid grey rather than on white, so the
   colour was wrong rather than merely strong.

   Nothing offscreen would have caught it. `CALayer.render(in:)` ignores `compositingFilter`,
   measured at an alpha of 96 where source-atop would have left 0, and source-atop is what the
   whole treatment rests on. The screen is the only instrument for this one.
4. ~~`ITSAppUsesNonExemptEncryption`~~ **Done.** `false`, in `Resources/Info.plist`, which removes
   the export compliance question App Store Connect otherwise asks on every single upload. The key
   is real: Xcode's `CoreBuildSystem.xcspec` carries it as
   `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption`. Verified present in both built bundles.
5. ~~The privacy policy~~ **Done.** Served at https://caffebara.github.io/tilt-privacy/, from
   `caffebara/tilt-privacy`, which holds nothing else. A repository's visibility is all or nothing,
   so publishing the policy out of this one would have published the source with it, and a policy
   nobody can open is not a policy. That repository is the only copy: the same text maintained in
   two places drifts, and the copy that drifts is the one Apple reads.

   Every claim in it was checked against the code rather than written from the usual template, and
   that is what this repository still owes it. `main.swift` contains no networking API at all, its
   only file write is stderr in the `--check` path, the captured frame is one `CVPixelBuffer`
   released when the next lands, and the stored settings are exactly the six `UserDefaults` keys
   (grep `Key = "` in `main.swift`). If any of those stops being true, the policy is wrong and the
   change belongs in the same commit.

   **Line numbers are not used here any more.** Three were repaired on 2026-09-15 and one of them
   had rotted again four commits later, so the pin is the defect rather than the particular number.
   A grep target survives an edit above it; a line number does not.
6. Screenshots, and the App Privacy questionnaire, whose answer is that no data is collected.
   Answer it as "Data Not Collected"; nothing in the app contradicts that.

   **The sizes are fixed, and none of them is this screen.** One to ten images, `.png`, `.jpg` or
   `.jpeg`, at 1280x800, 1440x900, 2560x1600 or 2880x1800, all 16:10, required for Mac apps. Read
   off the screenshot specifications on 2026-09-22. This machine's display is 3024x1964, which is
   neither 16:10 nor 16:9, so every asset here is a scale or a crop rather than a raw
   `screencapture` output.

   Screenshots are the awkward one, and worth thinking about before the day of. The effect only
   exists while the lid is partly closed, which is exactly when nobody is looking at the screen.
   `screencapture -T <seconds>` on a delay, run before folding the lid, is the way to get one
   without a second machine. Decision 005 removed the demo, so a screenshot is what a reviewer sees
   instead of the effect.

   **Apple's own product images may not be tilted. A generic device drawn from scratch may.** Both
   halves are in the Marketing Resources and Identity Guidelines, read 2026-09-18. Product images
   are to be used "as is and without modification", where modifications expressly include
   "cropping, **tilting**, or obstructing any part of the images", and Unauthorized Uses forbids
   "Rendering in 3D or creating any simulation of an Apple product", "Illustrations that depict an
   Apple product", and "Graphics, illustrations, or logotypes to represent an Apple product". Then
   the escape hatch, in the same list: "If your marketing contains illustrations of **generic
   devices**, ensure that these devices do not include details that are unique to Apple products,
   such as the iPhone Home button, sensor housing, Ring/Silent switch, or volume controls."

   So the sanctioned route is the one every App Store listing already uses: a plain rounded
   rectangle with no Apple mark, no notch, and nothing identifying. Apple's bezel assets are the
   thing that must stay untouched, and drawing your own is not touching them.

   The word "screenshot" appears nowhere in that document, which calls itself rules for marketing
   materials, so whether it governs a product page at all is not settled by it. Review guideline
   2.3.9 makes the rights to everything in a screenshot the developer's problem either way.

   **And tilting the frame is probably the wrong picture anyway.** The illusion is that the screen
   stays where it is while the desktop leans, so what a user actually sees is a square-on screen
   with a tilted desktop inside it. A leaning frame says the laptop moved and the picture followed,
   which is the opposite. A square-on frame holding a tilted desktop is the honest image, and the
   caption is where the lid comes in. What a still cannot show is the cause, not the effect.

   ~~Whether a preview video is even available for a macOS app is unverified~~ **It is available,
   and it is the lead asset rather than a bonus.** Read off the app preview specifications on
   2026-09-22: Mac takes 1920x1080, landscape only, 15 to 30 seconds, up to three per
   localisation. The paragraph that stood here fetched three product pages, found no video markup,
   could not tell "no video" from "rendered in JavaScript", and concluded the answer needed the
   account. It needed the help page. The plan it recommended is now backwards: what a still cannot
   show is the cause, and a recording of the lid coming over is the cause.

   The cost is the frame. 1920x1080 is 16:9, this screen is not, and the screenshots are 16:10, so
   the two assets crop differently from the same capture.

   **Both captures are taken blind**, because the effect exists only while the lid is over. So the
   transforms are settled here rather than on the day, measured 2026-09-22 against a synthetic
   3024x1964 source, which is what this machine's display reports. Raise **Engage below** before
   shooting so a shallow fold engages, and put it back afterwards: at 120 the effect engages at an
   ordinary working angle. Run the effect once before the first take, because the "esc to dismiss"
   caption is shown on the first engage of the app's life and would otherwise land in the shot.

   ```sh
   # stills: delay, then fold the lid. The terminal needs screen recording too.
   screencapture -T 10 -x ~/Desktop/tilt-raw.png
   sips -c 1890 3024 tilt-raw.png   # 3024x1964 -> 16:10, 74px of height goes
   sips -z 1800 2880 tilt-raw.png   # -> 2880x1800, one of the four accepted sizes

   # preview: 20 seconds of video, fold and open again inside it
   sleep 5; screencapture -v -V 20 -x ~/Desktop/tilt-raw.mov
   ffmpeg -i tilt-raw.mov -vf "crop=3024:1701:0:0,scale=1920:1080" -pix_fmt yuv420p preview.mov
   ```

   **The crop is anchored to the top on purpose.** 16:9 costs 263 rows of a 1964-row screen, and
   the edge that leans away as the lid comes over is the top one, which is the whole picture. If
   that loss turns out to hurt, the alternative keeps the screen whole and pays in pillarbox bars:
   `scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2`.
   Whether App Store Connect objects to those bars is unverified.

7. ~~A support URL, and there is no page to point it at~~ **Written and served, 2026-09-22, at
   <https://caffebara.github.io/tilt-privacy/support.html>.** That is the string the Support URL
   field takes. App Store Connect marks Support URL required on every version, and says what it
   has to carry: "This URL must lead to actual contact information (legal address, email address,
   telephone number), as may be required by local law, so that users can reach you regarding app
   issues, general feedback, and feature enhancement requests." Read 2026-09-22.

   **It carries one email and no postal address or telephone number.** Apple conditions those two
   on local law, the seller of record on the store is Apple rather than the developer, and a
   private address published to answer a field is a disclosure that cannot be taken back. If a
   reviewer asks for more, adding it is one line on a page nothing else depends on.

   **It is one more page in `caffebara/tilt-privacy`**, not a repository of its own, because the
   account and repository names are already load-bearing for the policy URL compiled into every
   shipped binary, and a second name is a second thing that can break. That buys something back:
   the two pages are one Jekyll site, so a build broken there takes the policy page with it, and
   the policy is the one every released copy points at. Nothing stops the same URL going in both
   fields either, and it is not what happened: the policy answers a different question, and the
   support page was written for the one the field asks.

   Peer-reviewed before publishing, 2026-09-22, two lenses: Codex on facts against `main.swift`,
   and a fresh-context reviewer on counter-cases. Eighteen findings: the page is rewritten against
   fifteen, two are decisions rather than defects, and one is the coupling written above. Two are
   worth carrying out of the review, because they are true of the app rather than of the draft:

   - **The overlay takes key focus on purpose**, so while it is up the keyboard reaches Tilt and
     not the app underneath. The first draft had repeated the review notes' "passes every other one
     straight through", which is true of the event monitor and false of the machine. The review
     notes are answering "is this a keylogger", and a user reading the same sentence takes it as
     permission to keep typing over a terminal.
   - **Granting the permission without letting macOS relaunch leaves the app inert for that whole
     run**, with a menu that shows neither of the two status strings, so the troubleshooting any
     support page would offer routes the user to controls that are not on screen. The app's own
     note already says to let it quit and reopen; the page now says so too.

8. **The fields the listing cannot be submitted without.** Read off the App Store Connect help on
   2026-09-22, so that the day of the submission is not the first time they are seen. App
   information: name, bundle id, SKU, primary category, age rating, and the privacy policy URL,
   "Required for iOS and macOS apps". Per platform version: screenshots, description, keywords,
   support URL, version number, and a copyright string. App Review Information: a contact name,
   email, and **telephone number in international format**, the field that "doesn't accept
   numbers-only entry" and the one item on this list that the repository records nowhere. Optional:
   promotional text, marketing URL, subtitle, a second category. The sign-in fields do not apply,
   since Tilt has no account. The text for all of them is written and measured against these
   limits in `docs/listing.md`.

   Two of these are already answered by the build rather than by the form.
   `LSApplicationCategoryType` is `public.app-category.utilities`, so the primary category is
   chosen, and `NSHumanReadableCopyright` carries the copyright string. **The version is not.** Both
   build paths say 0.1, `CFBundleShortVersionString` and `MARKETING_VERSION` alike, and whether the
   first public version goes out as 0.1 or 1.0 is a decision nobody has made.

Two things to check on the exported archive rather than before it:

**`get-task-allow` must not be in it.** `CODE_SIGN_INJECT_BASE_ENTITLEMENTS` is `YES`, so a locally
signed build carries it. Measured with ad-hoc signing on 2026-09-14: the product's entitlements are
`app-sandbox`, `device.usb` and `get-task-allow`. Distribute App is supposed to strip the last one,
and an archive that keeps it is rejected automatically. Worth one `codesign -d --entitlements :-`
on the exported bundle.

**The icon may need `CFBundleIconName` and an asset catalog.** `AppIcon.icns` is well formed, all
ten sizes from 16 through 512@2x, and that is not the same as the store accepting it. Measured on
this machine: all 15 installed Mac App Store apps carry both `Assets.car` and `CFBundleIconName`,
and none ships a bare `CFBundleIconFile`. This bundle ships a bare `CFBundleIconFile`. No macOS
validation rule was found either way, so the first upload is what decides it.

## Every clause this path pulls in

App Store Review Guidelines, revision **June 8, 2026**, read in full on 2026-09-15 rather than
recalled. The channel is the Mac App Store, which is what pulls in 2.4.5; on iOS that block does not
apply and others do. A verdict here is only as good as the revision beside it, so check the revision
line before trusting the table.

| clause | verdict | what decides it |
| --- | --- | --- |
| 2.1 App Completeness | met | the policy's contact address is filled in and it is served at https://caffebara.github.io/tilt-privacy/, verified HTTP 200 on 2026-09-16 |
| 2.3.1 hidden features | met | `main.swift` ships a `--check` mode in the submitted binary, undocumented to the user, which is what the clause names. The review notes above now describe it, which is the cheaper of the two answers: gating it would remove the one command that proves the sensor decode on a machine this one cannot reach |
| 2.4.5(i) sandbox | met | `Resources/Tilt.entitlements` carries `com.apple.security.app-sandbox` |
| 2.4.5(ii) Xcode packaging, self-contained | met | `Tilt.xcodeproj` is the submission path, per 003. The bundle is seven files, no helper, nothing in a shared location. `build.sh` is the local loop and is not a submission path |
| 2.4.5(iii) launch at login | met | registration happens only inside the switch handler, and the default is not registered, so turning it on is the consent. **The clause did not apply before `8639f6a`**: adding the feature opened it |
| 2.4.5(iv) no downloaded code | met | no networking API anywhere in `main.swift` |
| 2.4.5(v) no root or setuid | met | neither |
| 2.4.5(vi) no licence keys | met | none |
| 2.4.5(vii) updates via the store | met | no updater, and no network to reach one |
| 2.4.5(viii) current OS | met | `LSMinimumSystemVersion` 14.0, running on 26.1 |
| 2.4.5(ix) one bundle for localisation | met | no `.lproj`, English only |
| 2.5.1 public APIs | met | no `CGS`/`SLS` symbol, no `dlopen`, no `@_silgen_name`, no `NSClassFromString`. The sensor is public IOKit; what is undocumented is the HID usage value, not the API |
| 2.5.14 recording | met | consent is the system prompt; the indication is drawn by macOS in two places, and the structural argument below is the primary answer since the clause asks the app for it |
| 4.2 Minimum Functionality | judgement | a native app reading a hardware sensor, not a repackaged anything. The exposure is 005's accepted risk: on a reviewer's machine with no lid sensor it does nothing |
| 5.1.1(i) privacy policy, and what it must say | met in the app, one field left | the menu opens <https://caffebara.github.io/tilt-privacy/>, and the page answers all four content requirements, not only the link. See below: two of its sentences were false until 2026-09-16 |

### 2.5.14, which is met twice over

The clause wants two things: explicit consent, and a clear visual or audible indication while
recording. macOS asks for the screen recording permission on its own, which settles consent.

**There are two indications, and macOS draws both.** Observed on 2026-09-16 while the overlay was
up: a purple indicator in the menu bar, and a second one on the front window beside its close,
minimise and zoom buttons. The system's own record agrees: `ControlCenter` logs
`Sorted active attributions from SystemStatus update: [[scr] Tilt (io.sxong.tilt)]` as the capture
starts and drops it as the capture ends. Tilt draws neither and has no code that could: its layers
are the backdrop, its tint, the stage, the captured screen and its masks, the dim, and the hint.

Neither can be switched off, which is the right answer to the question. The only privacy-adjacent
property on `SCStreamConfiguration` is `presenterOverlayPrivacyAlertSetting`, and that governs the
Presenter Overlay alert rather than the recording indicator: read from the SDK header, not recalled.
An indicator an app could suppress would not be one, and suppressing it is the behaviour this very
clause exists to forbid.

What the indicators do not settle is whose obligation they discharge. The clause says the **app**
must provide the indication, and these are the system's, so the argument below stays the primary
answer and the indicators are corroboration.

The answer here is structural. **Tilt's output is the capture.** There is no state in which it is
recording and the user cannot see it, because what it records is drawn full screen in front of them
for as long as it runs, and it stops the moment the overlay does. An indicator would be a smaller,
later copy of the thing already filling the display. It is invisible from the clause, so it is
written into the review notes above rather than left to be inferred.

### The two that were not met, and what closed them

Both were the same missing thing, a policy nobody could open, and both closed on 2026-09-16.

**5.1.1(i)** is unconditional, "All apps", and wants the link in App Store Connect **and** inside
the app. The policy is served at <https://caffebara.github.io/tilt-privacy/> and the menu opens it
from `addFooter`, which runs in both states the menu has. The App Store Connect half is a form
field and is filled in at submission; nothing in the repository can close that one.

**2.1(a)** wanted the placeholder scrubbed and the URL functional. The contact address is filled
in and the URL answers 200.

**And the clause is four requirements, not one.** 5.1.1(i) asks for the link, then for what data is
collected and how it is used, then for third parties, then to "explain its data retention/deletion
policies and describe how a user can revoke consent". This table read "met" off the link alone for
a day. Checked properly on 2026-09-16, the page was missing the retention and deletion half
entirely and carried two sentences that were not true: that Tilt does not read keystrokes, when a
local monitor reads every key far enough to tell whether it is escape, and an explanation of the
input monitoring prompt by the overlay's window position, which `d6d88ee` had disproved. Both are
corrected and the missing half is written. A link that resolves is not a policy that complies.

What is left is not a clause but a dependency: the policy's claims are true of this code, and the
code can change. `main.swift` gaining a network call, a file write, or a seventh stored setting
makes the served policy false, and the repository that serves it will not notice. Whoever makes
that change updates both.

## Known risks

No lid angle app is on the Mac App Store today, so there is no precedent either way. Two things a
reviewer may ask about: a USB entitlement on an app that touches no removable device, and a sensor
whose HID usage Apple has not documented, although it is read through public IOKit calls rather
than a private API.

A third used to be here, an input monitoring prompt, and it is gone rather than mitigated.
`d6d88ee` isolated it by building three throwaway apps instead of reasoning about it, after four
guesses about the overlay had all been wrong: a borderless full-screen window at the shielding
level taking key focus raises no prompt, a HID manager matching nil raises it with no window on
screen at all, and a HID manager matching usage page 0x20 usage 0x8A raises none. The app matches
the one sensor now, so the prompt does not arrive. **The paragraph that used to sit here explained
it by the overlay's window position, which is precisely the hypothesis that commit disproved**, and
it survived in this file for two days after the code stopped raising the prompt at all.

The name is worth checking early, since several apps beginning with Tilt are already there. It is
step 1 above because it gates the upload rather than the review.

A fourth risk that no reviewer will ask about, because nothing reports it at all. `angle(from:)`
returns the raw feature report value with no range check, and the `0...180` guard lives only in
`--check`. A Mac whose sensor reports on another scale would sit permanently below the threshold,
inert, with a menu saying nothing is wrong. That is the failure 005 accepted, arriving from the
decode rather than from the hardware being absent, and it would look identical to a reviewer.

## Checked, and not a problem

Both of these were raised as blockers by a submission review on 2026-09-14, and both were wrong.
The commands that settled them are written down because the reasoning that produced them is easy to
repeat: each one looks right from the code alone.

**The two build paths differ on architecture, and that is fine.** `build.sh` passes
`-target arm64-apple-macos14.0`, while the project sets no `ARCHS` and inherits `arm64 x86_64`, so
the archive is universal. That reads as a slice nobody has ever run. Run it. On the Xcode product,
not on `Tilt.app`, which is arm64 by design:

```sh
arch -arm64  "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
arch -x86_64 "$DERIVED/Build/Products/Release/Tilt.app/Contents/MacOS/Tilt" --check
```

Both read the real sensor and print identical output. Pinning `ARCHS = arm64` to make the two paths
agree would cut a platform off the listing, which is the one change in this area that cannot be
walked back, in exchange for nothing measured.

**The two IOKit error codes in this repository are both correct.** `0xE00002CD` is
`kIOReturnNotOpen` and `0xE00002E2` is `kIOReturnNotPermitted` (`IOReturn.h:115` and `:138`), and
they are one failure seen at two call sites: in `main.swift` the `IOHIDManagerOpen` call discards
what it returns, so the code the app can actually surface is the `kIOReturnNotOpen` that
`IOHIDDeviceGetReport` returns afterwards. Reconciling them to a single value deletes the record
that this is a permission failure, and a reader left holding "device not open" fixes it by opening
the device and drops `com.apple.security.device.usb`. `AGENTS.md` says what that costs.
