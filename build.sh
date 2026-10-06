#!/bin/sh
# Builds Tilt.app next to this script.
#
# Signed ad hoc, so nothing touches the keychain. The price is that macOS pins
# the screen recording grant to the binary's hash, and every rebuild is a new
# app to it: --install resets the old grant so it asks once, cleanly. A
# self-signed certificate kept the grant across rebuilds, and was dropped on
# 2026-09-29 because its first build asked for the login keychain password.
set -eu
cd "$(dirname "$0")"

# The swiftc -target below is arm64, and on an Intel Mac it would build an app
# that cannot launch. hw.optional.arm64 is 1 on Apple silicon even from a shell
# running under Rosetta, where uname -m says x86_64.
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || {
	echo "Tilt needs Apple silicon. build.sh targets arm64 (see swiftc -target)." >&2
	exit 1
}

# --test builds TiltTest.app instead, with the lid sensor readable from
# /tmp/tilt-fake-lid so transitions can be driven without a hand on the hinge.
# Tilt.app never gets that flag, so the hook cannot reach a shipped binary.
APP="Tilt.app"
EXTRA=""
ENTITLEMENTS="Resources/Tilt.entitlements"
if [ "${1:-}" = "--test" ]; then
	# Outside the project on purpose. Built here it turned up in launchers beside
	# the real app, with the same name, icon and bundle id, and the only way to
	# tell them apart was the path.
	APP="${TMPDIR:-/tmp/}TiltTest.app"
	EXTRA="-D TILT_TEST_HOOK"
	# Unsandboxed on purpose: the fake lid angle is read from /tmp, which the
	# container would hide, and the point of this build is to drive transitions.
	ENTITLEMENTS=""
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

./makeicns.sh
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The menu bar glyph. Tabler Icons, MIT licensed: https://tabler.io/icons
# Swapping the icon means replacing this one file, and its notice below.
cp MenuIcon.svg "$APP/Contents/Resources/MenuIcon.svg"
# The MIT licence asks for its notice in the copies, and the README does not
# travel with the bundle.
cp THIRD-PARTY-NOTICES.md "$APP/Contents/Resources/THIRD-PARTY-NOTICES.md"

cp Resources/Info.plist "$APP/Contents/Info.plist"
# The privacy manifest. Nothing off the store reads it, and it is kept because
# it is true.
cp Resources/PrivacyInfo.xcprivacy "$APP/Contents/Resources/PrivacyInfo.xcprivacy"

swiftc -O -target arm64-apple-macos14.0 $EXTRA main.swift -o "$APP/Contents/MacOS/Tilt"
if [ -n "$ENTITLEMENTS" ]; then
	codesign --force --sign - --timestamp=none \
		--options runtime --entitlements "$ENTITLEMENTS" "$APP"
else
	codesign --force --sign - --timestamp=none "$APP"
fi
case "$APP" in
	/*) echo "built $APP" ;;
	*)  echo "built $(pwd)/$APP" ;;
esac
codesign -d -r- "$APP" 2>&1 | grep designated

# --install puts the build in /Applications and opens it, which is where the
# Open at login switch needs it. Only when asked: a plain build touches nothing
# outside this directory.
if [ "${1:-}" = "--install" ]; then
	DEST=/Applications/Tilt.app
	# Replace Tilt, and nothing else that happens to have the name. 1.0 shipped
	# as io.sxong.tilt, before the id moved to the cottonferry.com domain, so an
	# installed copy may carry either.
	OLD_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' \
		"$DEST/Contents/Info.plist" 2>/dev/null || true)"
	if [ -e "$DEST" ]; then
		case "$OLD_ID" in
			com.cottonferry.tilt|io.sxong.tilt) ;;
			*) echo "$DEST is not Tilt, so it is left alone" >&2; exit 1 ;;
		esac
	fi
	# Quit a running copy first: a bundle replaced under it keeps the old code
	# running. Asked only when one is running, because osascript fails on an app
	# id macOS has never seen, which is every Mac this has not been installed on.
	if pgrep -f "$DEST/Contents/MacOS/Tilt" >/dev/null; then
		osascript -e "tell application id \"$OLD_ID\" to quit" >/dev/null
	fi
	n=0
	while pgrep -f "$DEST/Contents/MacOS/Tilt" >/dev/null; do
		n=$((n + 1))
		[ "$n" -le 50 ] || { echo "Tilt did not quit; quit it and run again" >&2; exit 1; }
		sleep 0.2
	done
	# The grant belongs to the old build's hash and no longer applies. Left in
	# place it shows as switched on while capture is refused. tccutil finds the
	# app through Launch Services, so this runs while the old copy is still
	# there, and on a first install it has nothing to reset.
	[ -n "$OLD_ID" ] && { tccutil reset ScreenCapture "$OLD_ID" >/dev/null 2>&1 || true; }
	rm -rf "$DEST"
	ditto "$APP" "$DEST"
	open "$DEST"
	echo "installed $DEST"
fi
