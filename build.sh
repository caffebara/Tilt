#!/bin/sh
# Builds Tilt.app next to this script.
#
# Signing matters more than it looks: an ad-hoc signature pins the designated
# requirement to the binary's cdhash, so every rebuild looks like a different
# app and macOS asks for screen recording again. A self-signed certificate pins
# it to the certificate instead, and the grant survives rebuilds. The identity
# is created here on first run.
set -eu
cd "$(dirname "$0")"

# The swiftc -target below is arm64, and on an Intel Mac it would build an app
# that cannot launch. hw.optional.arm64 is 1 on Apple silicon even from a shell
# running under Rosetta, where uname -m says x86_64.
[ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = 1 ] || {
	echo "Tilt needs Apple silicon. build.sh targets arm64 (see swiftc -target)." >&2
	exit 1
}

IDENTITY="Tilt Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

identity_hash() {
	security find-identity -p codesigning 2>/dev/null \
		| awk -v name="\"$IDENTITY\"" '$0 ~ name { print $2; exit }'
}

HASH=$(identity_hash)
if [ -z "$HASH" ]; then
	echo "creating code signing identity: $IDENTITY"
	TMP=$(mktemp -d)
	trap 'rm -rf "$TMP"' EXIT
	# The system's LibreSSL, not whatever is first on PATH. A Homebrew OpenSSL 3
	# writes a PKCS#12 that `security import` rejects with "MAC verification
	# failed", measured 2026-09-29.
	/usr/bin/openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
		-keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
		-subj "/CN=$IDENTITY" \
		-addext "basicConstraints=critical,CA:FALSE" \
		-addext "keyUsage=critical,digitalSignature" \
		-addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
	/usr/bin/openssl pkcs12 -export -out "$TMP/bundle.p12" -inkey "$TMP/key.pem" \
		-in "$TMP/cert.pem" -passout pass:tilt -name "$IDENTITY" 2>/dev/null
	# -A lets codesign use the key on every build without asking. It also lets any
	# other process running as this user sign with it, and so pass for Tilt to the
	# screen recording grant. Narrowing it to codesign would not change that, since
	# any process can run codesign. The README says so.
	security import "$TMP/bundle.p12" -k "$KEYCHAIN" -P tilt -A >/dev/null
	HASH=$(identity_hash)
	[ -n "$HASH" ] || { echo "could not create the signing identity" >&2; exit 1; }
fi

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
	codesign --force --sign "$HASH" --timestamp=none \
		--options runtime --entitlements "$ENTITLEMENTS" "$APP"
else
	codesign --force --sign "$HASH" --timestamp=none "$APP"
fi
case "$APP" in
	/*) echo "built $APP" ;;
	*)  echo "built $(pwd)/$APP" ;;
esac
codesign -d -r- "$APP" 2>&1 | grep designated
