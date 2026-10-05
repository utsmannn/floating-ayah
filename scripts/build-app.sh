#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in debug|release) ;; *) echo "Usage: $0 [debug|release]" >&2; exit 1 ;; esac
swift build -c "$CONFIGURATION"
BIN_DIR="$(swift build -c "$CONFIGURATION" --show-bin-path)"
APP="dist/Floating Ayah.app"
# Recreate generated bundles so removed features cannot leave stale resources.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/FloatingAyah" "$APP/Contents/MacOS/FloatingAyah"
cp assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Quran.load resolves this bundle explicitly inside Contents/Resources.
for BUNDLE in "$BIN_DIR"/*.bundle; do
    [ -d "$BUNDLE" ] || continue
    ditto "$BUNDLE" "$APP/Contents/Resources/$(basename "$BUNDLE")"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>CFBundleExecutable</key><string>FloatingAyah</string>
    <key>CFBundleIdentifier</key><string>com.codeutsman.floating-ayah</string>
    <key>CFBundleName</key><string>Floating Ayah</string>
    <key>CFBundleDisplayName</key><string>Floating Ayah</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.3</string>
    <key>CFBundleVersion</key><string>5</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>Quran text: Al Quran Cloud. Recitations: EveryAyah and the credited reciters.</string>
</dict></plist>
PLIST
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --deep --sign - "$APP"
    echo "Signing: ad-hoc (local build; not notarized)"
else
    codesign --force --deep --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP"
    echo "Signing: $SIGNING_IDENTITY (notarization is a separate step)"
fi
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Built: $APP"
