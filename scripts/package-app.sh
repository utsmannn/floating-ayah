#!/bin/sh
set -eu
cd "$(dirname "$0")/.."

sh scripts/build-app.sh release
APP="dist/Floating Ayah.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCHITECTURES="$(lipo -archs "$APP/Contents/MacOS/FloatingAyah")"
case "$ARCHITECTURES" in
    arm64) ARCH="arm64" ;;
    x86_64) ARCH="x86_64" ;;
    *) ARCH="universal" ;;
esac
NAME="Floating-Ayah-$VERSION-macos-$ARCH"
STAGING="$(mktemp -d "${TMPDIR:-/tmp}/floating-ayah-package.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT HUP INT TERM

# Copy the whole signed bundle; never pack .build, runtime caches, or user audio.
ditto "$APP" "$STAGING/Floating Ayah.app"
ln -s /Applications "$STAGING/Applications"
if [ "${SIGNING_IDENTITY:--}" = "-" ]; then
    SIGNING_NOTICE="This build is ad-hoc signed, not Developer ID signed or notarized. macOS may block a downloaded copy. Only if you trust its source, try Control-click > Open, or use System Settings > Privacy & Security > Open Anyway after the first launch attempt. Do not disable Gatekeeper globally."
else
    SIGNING_NOTICE="This build is code-signed with a local signing identity. Signing alone is not notarization; confirm notarization before public distribution."
fi
cat > "$STAGING/Install.txt" <<INSTALL_NOTES
Floating Ayah $VERSION — macOS 13 or later — $ARCHITECTURES

INSTALL
1. Drag Floating Ayah.app to Applications.
2. Open it from Applications. Look for the book icon in the menu bar.
3. Choose a reciter and surah, then click Play. It starts paused.

The app has no Dock icon. Quit from its menu-bar menu.
Audio streams on demand. Download entire Quran saves the selected reciter's
files locally; downloaded audio and personal settings are not in this installer.
No microphone feature or Python/AI runtime is included.

SIGNING
$SIGNING_NOTICE

Fonts, Quran text, timing data and source credits are inside the app's resources.
See the project's README for source terms and known synchronization limitations.
INSTALL_NOTES

codesign --verify --deep --strict "$STAGING/Floating Ayah.app"
rm -f "dist/$NAME.dmg" "dist/$NAME.zip"
hdiutil create -volname "Floating Ayah $VERSION" -srcfolder "$STAGING" \
    -format UDZO -ov "dist/$NAME.dmg"
if [ "${SIGNING_IDENTITY:--}" != "-" ]; then
    codesign --timestamp --sign "$SIGNING_IDENTITY" "dist/$NAME.dmg"
    codesign --verify "dist/$NAME.dmg"
fi
hdiutil verify "dist/$NAME.dmg"
ditto -c -k --sequesterRsrc --keepParent "$APP" "dist/$NAME.zip"
(
    cd dist
    shasum -a 256 "$NAME.dmg" "$NAME.zip" > "$NAME.sha256"
)
printf '\nPackages:\n  dist/%s.dmg\n  dist/%s.zip\n  dist/%s.sha256\n' "$NAME" "$NAME" "$NAME"
echo "Architectures: $ARCHITECTURES"
echo "$SIGNING_NOTICE"
