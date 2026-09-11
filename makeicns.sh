#!/bin/sh
# Writes AppIcon.icns from AppIcon.png, or from makeicon.swift when there is no
# PNG. Does nothing if the icns is already there: delete it to force a rebuild.
set -eu
cd "$(dirname "$0")"
[ -f AppIcon.icns ] && exit 0

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
if [ -f AppIcon.png ]; then
	cp AppIcon.png "$TMP/icon.png"
else
	swiftc -O makeicon.swift -o "$TMP/makeicon"
	"$TMP/makeicon" "$TMP/icon.png" > /dev/null
fi
mkdir -p "$TMP/AppIcon.iconset"
for px in 16 32 128 256 512; do
	sips -z $px $px "$TMP/icon.png" \
		--out "$TMP/AppIcon.iconset/icon_${px}x${px}.png" > /dev/null
	sips -z $((px * 2)) $((px * 2)) "$TMP/icon.png" \
		--out "$TMP/AppIcon.iconset/icon_${px}x${px}@2x.png" > /dev/null
done
iconutil -c icns "$TMP/AppIcon.iconset" -o AppIcon.icns
