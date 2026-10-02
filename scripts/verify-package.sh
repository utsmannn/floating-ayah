#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
APP="dist/Floating Ayah.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
ARCH="$(lipo -archs "$APP/Contents/MacOS/FloatingAyah")"
case "$ARCH" in arm64|x86_64) ;; *) ARCH="universal" ;; esac
NAME="Floating-Ayah-$VERSION-macos-$ARCH"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/floating-ayah-verify.XXXXXX")"
MOUNT="$WORK/mounted"
MOUNTED=0
cleanup() {
    if [ "$MOUNTED" = 1 ]; then hdiutil detach "$MOUNT" >/dev/null; fi
    rm -rf "$WORK"
}
trap cleanup EXIT HUP INT TERM
(cd dist && shasum -a 256 -c "$NAME.sha256")
hdiutil verify "dist/$NAME.dmg"
mkdir "$MOUNT"
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT" "dist/$NAME.dmg" >/dev/null
MOUNTED=1
codesign --verify --deep --strict --verbose=2 "$MOUNT/Floating Ayah.app"
test "$(readlink "$MOUNT/Applications")" = /Applications
test -s "$MOUNT/Install.txt"
ditto -x -k "dist/$NAME.zip" "$WORK/unzipped"
codesign --verify --deep --strict --verbose=2 "$WORK/unzipped/Floating Ayah.app"
# Verify the relocated package without resolving any SwiftPM build-path fallback.
RESOURCE="$WORK/unzipped/Floating Ayah.app/Contents/Resources/FloatingAyah_FloatingAyah.bundle"
python3 - "$RESOURCE" "$WORK/unzipped/Floating Ayah.app/Contents/Info.plist" <<'PY'
import json, plistlib, sys
from pathlib import Path
root = Path(sys.argv[1])
quran = json.loads((root / 'quran.json').read_text())
assert len(quran) == 114
assert sum(len(s['ayahs']) for s in quran) == 6236
collections = ['Husary_64kbps', 'Minshawy_Murattal_128kbps',
               'Abdul_Basit_Murattal_64kbps', 'Abdurrahmaan_As-Sudais_192kbps',
               'Abu_Bakr_Ash-Shaatree_128kbps']
for name in ['alafasy-timings'] + [c + '-timings' for c in collections]:
    assert len(json.loads((root / (name + '.json')).read_text())) == 6236
for name in ['audio-sizes'] + [c + '-sizes' for c in collections]:
    assert len(json.loads((root / (name + '.json')).read_text())['files']) == 6236
assert (root / 'AmiriQuran-Regular.ttf').is_file()
assert (root / 'AmiriQuran-OFL.txt').is_file()
assert not list(root.rglob('*.py'))
with open(sys.argv[2], 'rb') as file:
    info = plistlib.load(file)
assert info['LSMinimumSystemVersion'] == '13.0'
assert info['LSUIElement'] is True
assert info['CFBundleIconFile'] == 'AppIcon'
assert (Path(sys.argv[2]).parent / 'Resources/AppIcon.icns').is_file()
assert (root / 'MenuBarIcon.png').is_file()
assert 'NSMicrophoneUsageDescription' not in info
print('Relocated resources verified: 114 surahs, six timing/size catalogs, font and license; no microphone runtime.')
PY
echo "Package verification passed: $NAME"
