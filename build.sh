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
	openssl req -x509 -newkey rsa:2048 -sha256 -days 3650 -nodes \
		-keyout "$TMP/key.pem" -out "$TMP/cert.pem" \
		-subj "/CN=$IDENTITY" \
		-addext "basicConstraints=critical,CA:FALSE" \
		-addext "keyUsage=critical,digitalSignature" \
		-addext "extendedKeyUsage=critical,codeSigning" 2>/dev/null
	openssl pkcs12 -export -out "$TMP/bundle.p12" -inkey "$TMP/key.pem" \
		-in "$TMP/cert.pem" -passout pass:tilt -name "$IDENTITY" 2>/dev/null
	security import "$TMP/bundle.p12" -k "$KEYCHAIN" -P tilt -A >/dev/null
	HASH=$(identity_hash)
	[ -n "$HASH" ] || { echo "could not create the signing identity" >&2; exit 1; }
fi

# --test builds TiltTest.app instead, with the lid sensor readable from
# /tmp/tilt-fake-lid so transitions can be driven without a hand on the hinge.
# Tilt.app never gets that flag, so the hook cannot reach a shipped binary.
APP="Tilt.app"
EXTRA=""
if [ "${1:-}" = "--test" ]; then
	# Outside the project on purpose. Built here it turned up in launchers beside
	# the real app, with the same name, icon and bundle id, and the only way to
	# tell them apart was the path.
	APP="${TMPDIR:-/tmp}TiltTest.app"
	EXTRA="-D TILT_TEST_HOOK"
fi
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# The icon is generated rather than checked in: it is drawn by makeicon.swift,
# and regenerating beats keeping a binary in sync with the code that draws it.
# A supplied AppIcon.png (1024x1024) wins over the drawn one. Delete AppIcon.icns
# after dropping a new PNG in, or the stale icns is reused.
if [ ! -f AppIcon.icns ]; then
	ICONTMP=$(mktemp -d)
	if [ -f AppIcon.png ]; then
		echo "building AppIcon.icns from AppIcon.png"
		cp AppIcon.png "$ICONTMP/icon.png"
	else
		echo "drawing AppIcon.icns"
		swiftc -O makeicon.swift -o "$ICONTMP/makeicon"
		"$ICONTMP/makeicon" "$ICONTMP/icon.png" > /dev/null
	fi
	mkdir -p "$ICONTMP/AppIcon.iconset"
	for px in 16 32 128 256 512; do
		sips -z $px $px "$ICONTMP/icon.png" \
			--out "$ICONTMP/AppIcon.iconset/icon_${px}x${px}.png" > /dev/null
		sips -z $((px * 2)) $((px * 2)) "$ICONTMP/icon.png" \
			--out "$ICONTMP/AppIcon.iconset/icon_${px}x${px}@2x.png" > /dev/null
	done
	iconutil -c icns "$ICONTMP/AppIcon.iconset" -o AppIcon.icns
	rm -rf "$ICONTMP"
fi
cp AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# The menu bar glyph. Tabler Icons, MIT licensed: https://tabler.io/icons
# Swapping the icon means replacing this one file.
cp MenuIcon.svg "$APP/Contents/Resources/MenuIcon.svg"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key><string>Tilt</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundleIdentifier</key><string>io.sxong.tilt</string>
	<key>CFBundleName</key><string>Tilt</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>0.1</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>NSHighResolutionCapable</key><true/>
	<key>LSUIElement</key><true/>
</dict>
</plist>
PLIST

swiftc -O -target arm64-apple-macos14.0 $EXTRA main.swift -o "$APP/Contents/MacOS/Tilt"
codesign --force --sign "$HASH" --timestamp=none "$APP"
case "$APP" in
	/*) echo "built $APP" ;;
	*)  echo "built $(pwd)/$APP" ;;
esac
codesign -d -r- "$APP" 2>&1 | grep designated
