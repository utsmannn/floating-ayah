#!/bin/bash
# Floating Ayah installer. Requires macOS 13+ on Apple Silicon; no sudo.
set -euo pipefail

REPOSITORY="utsmannn/floating-ayah"
BUNDLE_ID="com.codeutsman.floating-ayah"
WORK=""
STAGING=""
BACKUP=""
REPLACED=0
SUCCESS=0
APP="$HOME/Applications/Floating Ayah.app"

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
cleanup() {
    local result=$?
    trap - EXIT
    if [ "$SUCCESS" = 0 ] && { [ "$REPLACED" = 1 ] || { [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; }; }; then
        rm -rf "$APP"
        if [ -n "$BACKUP" ] && [ -d "$BACKUP" ]; then
            if ! mv "$BACKUP" "$APP"; then
                printf 'Restore the previous app from: %s\n' "$BACKUP" >&2
                STAGING="" # Preserve the backup if automatic restoration fails.
            fi
        fi
    fi
    [ -z "$STAGING" ] || rm -rf "$STAGING"
    [ -z "$WORK" ] || rm -rf "$WORK"
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

[ "$(uname -s)" = Darwin ] || fail "This installer supports macOS only."
[ "$(id -u)" != 0 ] || fail "Run this installer as your normal user, without sudo."
VERSION="$(sw_vers -productVersion)"
[ "${VERSION%%.*}" -ge 13 ] || fail "macOS 13 or newer is required."
# sysctl recognizes Apple Silicon even when the shell runs under Rosetta.
[ "$(uname -m)" = arm64 ] || [ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" = 1 ] \
    || fail "The current release requires an Apple Silicon Mac."

printf '%s\n' \
    "Installing Floating Ayah from the latest GitHub release." \
    "This installer removes quarantine ONLY from the installed Floating Ayah bundle" \
    "after verifying its checksum and code signature. The current release is" \
    "ad-hoc signed and has not been notarized by Apple. Gatekeeper is not disabled." \
    "Settings and offline audio are preserved. Destination: $APP" ""

WORK="$(mktemp -d "${TMPDIR:-/tmp}/floating-ayah-install.XXXXXX")"
download() {
    curl --fail --silent --show-error --location --retry 3 \
        --connect-timeout 15 --max-time 300 --proto '=https' --proto-redir '=https' \
        "$1" --output "$2"
}

download "https://api.github.com/repos/$REPOSITORY/releases/latest" "$WORK/release.json"
TAG="$(plutil -extract tag_name raw -o - "$WORK/release.json")"
ZIP_NAME=""
ZIP_URL=""
SHA_URL=""
INDEX=0
while NAME="$(plutil -extract "assets.$INDEX.name" raw -o - "$WORK/release.json" 2>/dev/null)"; do
    URL="$(plutil -extract "assets.$INDEX.browser_download_url" raw -o - "$WORK/release.json")"
    case "$NAME" in
        Floating-Ayah-*-macos-arm64.zip)
            [ -z "$ZIP_NAME" ] || fail "Release contains multiple Apple Silicon ZIPs."
            ZIP_NAME="$NAME"; ZIP_URL="$URL" ;;
    esac
    INDEX=$((INDEX + 1))
done
[ -n "$ZIP_NAME" ] || fail "No Apple Silicon ZIP found in release $TAG."
# Require a plain filename and the official repository's release asset URLs.
case "$ZIP_NAME" in *[!a-zA-Z0-9._-]*) fail "Invalid release filename." ;; esac
SHA_NAME="${ZIP_NAME%.zip}.sha256"
INDEX=0
while NAME="$(plutil -extract "assets.$INDEX.name" raw -o - "$WORK/release.json" 2>/dev/null)"; do
    if [ "$NAME" = "$SHA_NAME" ]; then
        SHA_URL="$(plutil -extract "assets.$INDEX.browser_download_url" raw -o - "$WORK/release.json")"
    fi
    INDEX=$((INDEX + 1))
done
[ -n "$SHA_URL" ] || fail "Release $TAG is missing its SHA-256 manifest."
for URL in "$ZIP_URL" "$SHA_URL"; do
    case "$URL" in
        "https://github.com/$REPOSITORY/releases/download/"*) ;;
        *) fail "Unexpected release asset URL." ;;
    esac
done

printf 'Downloading release %s…\n' "$TAG"
download "$ZIP_URL" "$WORK/$ZIP_NAME"
download "$SHA_URL" "$WORK/$SHA_NAME"
EXPECTED="$(awk -v name="$ZIP_NAME" '$2 == name { print $1 }' "$WORK/$SHA_NAME")"
[ "${#EXPECTED}" = 64 ] || fail "Missing or invalid ZIP checksum."
case "$EXPECTED" in *[!a-fA-F0-9]*) fail "Invalid SHA-256 digest." ;; esac
printf '%s  %s\n' "$EXPECTED" "$ZIP_NAME" > "$WORK/zip.sha256"
(cd "$WORK" && shasum -a 256 -c zip.sha256) || fail "Checksum verification failed; nothing was installed."

ditto -x -k "$WORK/$ZIP_NAME" "$WORK/extracted"
SOURCE="$WORK/extracted/Floating Ayah.app"
[ -d "$SOURCE" ] && [ ! -L "$SOURCE" ] || fail "Release does not contain Floating Ayah.app."
[ "$(plutil -extract CFBundleIdentifier raw -o - "$SOURCE/Contents/Info.plist")" = "$BUNDLE_ID" ] \
    || fail "Unexpected application bundle identifier."
codesign --verify --deep --strict "$SOURCE" || fail "Application signature verification failed."

mkdir -p "$HOME/Applications"
[ ! -L "$APP" ] || fail "Destination is a symlink; refusing to replace it."
if [ -e "$APP" ]; then
    [ -d "$APP" ] || fail "Destination is not an app bundle."
    [ "$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")" = "$BUNDLE_ID" ] \
        || fail "Destination contains an unrelated application."
fi
STAGING="$(mktemp -d "$HOME/Applications/.floating-ayah-install.XXXXXX")"
ditto "$SOURCE" "$STAGING/Floating Ayah.app"
codesign --verify --deep --strict "$STAGING/Floating Ayah.app"
# Remove quarantine from this verified bundle only, never globally.
xattr -dr com.apple.quarantine "$STAGING/Floating Ayah.app"

if pgrep -x FloatingAyah >/dev/null; then
    osascript -e 'tell application id "com.codeutsman.floating-ayah" to quit' \
        || fail "Quit Floating Ayah and run the installer again."
    for _ in 1 2 3 4 5; do
        if ! pgrep -x FloatingAyah >/dev/null; then break; fi
        sleep 1
    done
    if pgrep -x FloatingAyah >/dev/null; then fail "Floating Ayah is still running. Quit it and retry."; fi
fi
if [ -d "$APP" ]; then
    BACKUP="$STAGING/previous.app"
    mv "$APP" "$BACKUP"
fi
REPLACED=1
mv "$STAGING/Floating Ayah.app" "$APP"
open "$APP"
SUCCESS=1
printf '\nInstalled %s and launched Floating Ayah. Look for the book icon in the menu bar.\n' "$TAG"
