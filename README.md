# Floating Ayah

![Floating Ayah's transparent Ayat al-Kursi overlay over the Claude Code terminal demo](assets/readme-banner.png)

*Web demo: a code-built Claude Code terminal with Floating Ayah's transparent, word-synchronized Quran overlay.*

Native macOS menu-bar Quran player. Arabic ayahs only — no translation.

## Build from Source

### Prerequisites
- macOS 13.0+ (Ventura, Sonoma, Sequoia)
- Xcode Command Line Tools (`xcode-select --install`)
- Swift 5.9+ toolchain (included with Xcode / command line tools)

### Quick Start

```sh
# Clone repository
git clone https://github.com/codeutsman/floating-ayah.git
cd floating-ayah

# Build and run debug build
sh scripts/build-app.sh
open "dist/Floating Ayah.app"
```

### Packaging Release DMG & Verification

To create an optimized release build packaged as a drag-and-drop `.dmg` disk image with SHA-256 checksums:

```sh
# Build optimized release package (.app + .dmg + .zip + .sha256)
sh scripts/package-app.sh

# Verify binary integrity, signatures, and bundled Quran catalogs
sh scripts/verify-package.sh
```

Built artifacts are generated in the `dist/` directory:
- `dist/Floating-Ayah-0.1.2-macos-arm64.dmg`
- `dist/Floating-Ayah-0.1.2-macos-arm64.zip`
- `dist/Floating-Ayah-0.1.2-macos-arm64.sha256`

### Running Tests

```sh
# Run full unit test suite (49 tests)
swift test

# Optional: live internet smoke test downloading sample audio
FLOATING_AYAH_LIVE_TEST=1 swift test --filter OfflineIntegrationTests
```

## Logo assets

`assets/logo-original.png` preserves the user-supplied artwork. `assets/logo.png`
is its transparent, centered platform-neutral export: no background tile or
rounded frame is added. `assets/AppIcon.icns` contains all macOS icon sizes;
`Resources/MenuBarIcon.png` is the small transparent status-bar symbol, rendered
as a template so macOS chooses its monochrome foreground in light/dark mode.

To regenerate exports from the original PNG:

```sh
swift scripts/build-icons.swift
iconutil -c icns assets/AppIcon.iconset -o assets/AppIcon.icns
```

## Release packages and signing

```sh
# Optimized app + drag-to-Applications DMG + ZIP + SHA-256 checksums
sh scripts/package-app.sh
# Mount DMG, verify both signatures/checksums and relocated resources
sh scripts/verify-package.sh
```

Output names include version and architecture, e.g.
`dist/Floating-Ayah-0.1.0-macos-arm64.dmg`, `.zip`, and `.sha256`.
The DMG contains `Floating Ayah.app`, an Applications shortcut, and installation
notes. macOS 13+ is required. An arm64 build supports Apple Silicon Macs; an Intel
build must be built on a suitable x86_64 toolchain (the script does not claim a
universal binary). Users of the packaged app do not need Swift/Xcode, Python,
or external runtime packages. Audio libraries are downloaded separately.

The build script verifies the bundle signature. With no signing identity it uses
**ad-hoc signing**, which is not trusted Developer ID signing. A copy downloaded
on another Mac may be blocked by Gatekeeper. Only for a build you trust, try
Control-click → Open, or System Settings → Privacy & Security → Open Anyway
after attempting to launch. Do not disable Gatekeeper globally.

If a Developer ID Application identity with its private key is installed in the
local Keychain, sign with hardened runtime/timestamp instead:

```sh
SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' sh scripts/package-app.sh
```

This signs the app and DMG but **does not notarize them**. Public distribution
still needs an Apple Developer account and notarization, for example using an
already configured Keychain notary profile (do not put credentials in the repo):

```sh
xcrun notarytool submit dist/Floating-Ayah-0.1.0-macos-arm64.dmg --keychain-profile PROFILE --wait
xcrun stapler staple dist/Floating-Ayah-0.1.0-macos-arm64.dmg
```

After stapling, regenerate the DMG checksum; the ZIP also needs its own
notarization workflow if it is distributed independently.

## Controls

Menus, status messages, errors, and accessibility descriptions are in English.
Quran text and font preview samples remain Arabic. Download sizes use English
number formatting, independent of the Mac's current language.

- **Menu-bar book icon:** choose any of the 114 surahs, select an ayah, play/pause, choose an installed Arabic font, change font size (22–42 pt), download all 114 surahs for offline playback, or quit.
- **Reciter:** choose Mishary Rashid Alafasy (128 kbps), Mahmoud Khalil Al-Husary (64 kbps), Mohamed Siddiq Al-Minshawi (128 kbps), Abdul Basit Abdus Samad (64 kbps), Abdurrahman As-Sudais (192 kbps), or Abu Bakr Ash-Shatri (128 kbps). Choice persists; switching restarts the current ayah at zero with that qari's audio and timestamps.
- **Play sample:** preview Al-Fatihah 1:2 for the selected reciter. Pauses the main player without changing its ayah. The sample stops at the verse end, on Stop sample, when switching reciters, or starting the main player. Main audio never automatically resumes after preview. Uses a local file when available, otherwise streams only on click. Reciter selection is disabled while a download runs.
- **Click the Arabic ayah:** play/pause.
- **Hover over the panel:** reveal previous, play/pause, next, and repeat-one controls. Their space stays reserved so hover doesn't change panel height.
- **Drag anywhere in the floating window:** move it, including over Arabic text, padding, or controls. A window-wide pan recognizer delays click delivery so a drag does not also toggle play/pause or press a button. A plain click still operates its original control; wheel/trackpad scrolling is unchanged.
- **Minus button:** hide the panel without stopping audio. Reopen from the menu bar.
- **Playback mode:** **Continuous** (default) automatically advances ayah by ayah and surah by surah, stopping at 114:6. **Stop at end of surah** stops at the selected surah's final ayah. **Repeat current ayah** loops only the current ayah. **Repeat surah** continues through the selected surah, then loops to its beginning (including basmalah where applicable). Mode selection persists. The repeat-one panel button toggles repeat vs continuous mode; manual previous/next can cross surah boundaries.

The panel defaults to **420 pt wide**, configurable from **280–800 pt** under **Ayah appearance**. Its width remains constant at the selected setting; Arabic reflows right-to-left without shrinking the font. The viewport shows up to roughly **three lines**, like mini lyrics, rather than expanding to screen height. Long ayahs automatically scroll to the line being recited, keeping it near the center; the complete ayah remains manually scrollable. The previous and next ayah within the same surah share a continuous scroll document and appear dimmer. Neighboring text never crosses a surah boundary: the outgoing surah fades away with a 300-ms crossfade, leaving a clean opening. Reduce Motion disables this transition. Wrapped lines and ayah boundaries use the same baseline spacing with no blank paragraph between ayahs. **Line spacing** adjusts additional spacing from 0–24 pt (default 6). **Ayah number size** adjusts the marker to 60–120% of the main text size (default 100%). Existing appearance preferences migrate without resetting font, colors, or width. Each ayah ends with a Quran-font ornament and Arabic-Indic number (e.g. ﴿٢٨٢﴾). Numbers are display-only: source Quran strings and timing word indices are preserved. The active spoken line is brighter. Within it, the timed word (occasionally a multiword span in the upstream alignment) has a translucent marker and underline, updated about every 80 ms. This is word-level timing, not letter-level recognition. Markers hold on the last word during pauses and clear when the ayah/timing changes. A vertical opacity gradient fades the top/bottom edges instead of abruptly cutting text. Natural ayah advancement preserves the outgoing text's screen position before smoothly centering the new ayah. Auto-scroll uses a retargetable 60-Hz, 450-ms smoothstep transition; Reduce Motion skips spatial animation. The background is fully transparent while idle. Text defaults to white, with configurable color and shadow (on/off, color, depth, blur, and opacity). Transparent desktop backgrounds vary, so chosen colors cannot guarantee contrast on every app behind the panel. Hover reveals a thin translucent dark backing, header, and controls. The panel stays above ordinary app windows and joins desktop Spaces.

Selected ayah, font family, font size, text/shadow appearance, width, and panel position persist across launches. **Amiri Quran · Uthmani** is bundled under SIL OFL 1.1 and available without installing any font. The font dropdown includes a basmalah preview rendered in each font. Other font choices are installed macOS families covering Arabic letters and basic harakat; this does not guarantee every Uthmani annotation is drawn perfectly. Missing saved fonts fall back to Geeza Pro. Measurement and rendering use the same selected font so line-follow scrolling updates with it. Playback does not automatically resume on launch.

## Audio and text

- **Surah transitions:** Automatic continuous playback inserts one second of bundled silence between the last ayah and the next surah's opening. Repeat surah uses the same pause before restarting. The silence is an ordinary player item, so pause/resume remains consistent and no delayed timer can restart audio after a user action. No extra silence is added between ayahs or between basmalah and ayah 1. At-Tawbah always goes directly from the pause to 9:1 without basmalah.
- **Basmalah at surah openings:** For surahs 2–114 except 9 (At-Tawbah), the source's prepended basmalah is presented as its own unnumbered opening and played before ayah 1. It uses the selected reciter's Al-Fatihah 1:1 MP3 and matching word timestamps, which are already included in offline downloads. Al-Fatihah keeps basmalah as its numbered ayah 1; At-Tawbah has no added basmalah. Repeat-one plays an opening once, then repeats the numbered ayah; starting at a later ayah adds no opening. Source strings and the 6,236-ayah corpus remain unchanged.
- **Text:** Al Quran Cloud's `quran-uthmani` edition, fetched from <https://api.alquran.cloud/v1/quran/quran-uthmani>. All **114 surahs / 6,236 ayahs** are bundled in `Sources/FloatingAyah/Resources/quran.json`. Arabic strings are preserved as supplied, including basmalah included by this edition at the start of surahs.
- **Audio:** Six murattal collections from [EveryAyah](https://everyayah.com/recitations_ayat.html), listed above. URLs use the collection ID and local surah/ayah numbers (`001001.mp3`, `002282.mp3`, etc.). No full audio corpus is bundled.
- **Synchronization:** the floating text follows the AVQueuePlayer's actual current audio item, not a guessed timer. Intra-ayah scrolling uses Colin Fair's [quran-align](https://github.com/cpfair/quran-align) collection-specific word timestamps (CC BY 4.0), mapped to the real rendered TextKit line. Timing data is bundled offline. Waqaf marks are not counted as spoken words; the basmalah prefix is split for display only, and each playback step uses its own recording's timing. Automatically generated timings can have inaccuracies. Any verse with missing/incompatible timing indices safely uses manual scroll instead of guessing (e.g. Alafasy 10:1, 13:1, 50:34). The next ayah is queued ahead. There can still be silence in recordings or buffering between files; seamless/gapless playback is not guaranteed.
- **Offline audio:** click **Download entire Quran** in the menu bar to download all **114 surahs / 6,236 ayahs** for the **selected reciter only**. The catalog is processed sequentially per ayah file, with global progress, the currently downloading surah, and actual saved bytes. The UI shows a collection-specific full-size estimate based on EveryAyah's 6,236 per-file sizes (not an estimate from ayah count): Alafasy ~1.71 GB, Husary ~1.23 GB, Minshawi ~1.66 GB, Abdul Basit ~0.90 GB, Sudais ~1.81 GB, Shatri ~1.41 GB. Upstream sizes can change. This may take significant time/disk space; it starts only on an explicit click. Complete files survive cancellation/relaunch, and **Resume Quran download** skips them. Failed or truncated responses are not marked downloaded. Playback prefers the local file whenever it exists; undownloaded ayahs still stream and require internet. Resume/retry after downloading switches the current ayah to its local copy without restarting the app. Text and timing data are already offline.
- **Storage:** `~/Library/Application Support/FloatingAyah/Audio/<collection-id>/`. Each qari's files/counts/size are isolated; existing Alafasy downloads stay in their original folder. Downloaded surahs are not evicted as temporary caches. Closing the menu does not stop downloads; quitting the app stops the current download, while completed ayahs remain. Quitting/reopening never starts a full-Quran download without another explicit click.

Source credits and upstream links are also bundled in `Resources/SOURCES.md`. Basmalah is intentionally sourced from each qari's separate 1:1 recording, not inferred from a surah's ayah-1 MP3; listening review across recordings remains advisable.

Source attribution is not a license grant. Verify source terms and audio/text redistribution rights before public release. This prototype is not a religiously reviewed Quran edition; Arabic glyph rendering and recitation/text correspondence should receive human review before distribution.

## Verification

```sh
swift test
# Optional: downloads seven Al-Fatihah files to a temporary folder and decodes
# them locally with AVFoundation; files are removed after the test.
FLOATING_AYAH_LIVE_TEST=1 swift test --filter OfflineIntegrationTests
# Optional six-reciter preview download/AVFoundation decode test:
FLOATING_AYAH_LIVE_TEST=1 swift test --filter ReciterTests
```

Tests cover catalog completeness/order, audio filename mapping, within-surah navigation boundaries, compact fixed-width wrapping, timed word mapping including pauses/repeated phrases/waqaf/basmalah, native scroll reset/follow, timing corpus compatibility, font registration/persistence/measurement, configurable width and appearance persistence, neighboring-ayah range offsets and dimming, offline file validation/persistence/resume across surahs, full-Quran navigation modes, exact word-marker movement/removal, whole-window drag setup, configurable spacing/number size and backward-compatible appearance migration, and saved-state validation. Actual sound quality, all qari recordings, fullscreen behavior, and multi-monitor placement require on-device checks.

## License

The original application and website source code is licensed under the
[MIT License](LICENSE). Copyright © 2026 Utsman (utsmannn).

Third-party resources retain their own licenses and terms: Amiri Quran is
licensed under SIL OFL 1.1, and quran-align timing data is licensed under
CC BY 4.0. Quran text and recitation recordings are not relicensed under MIT;
see [resource credits](Sources/FloatingAyah/Resources/SOURCES.md) and the bundled
license files for attribution and upstream terms.

## Structure

- `Reciter.swift` / `ReciterView.swift` / `ReciterSample.swift`: reciter selection and explicit preview playback.
- `Quran.swift`: bundled catalog and audio mapping.
- `PlayerStore.swift`: queue playback, ayah synchronization, repeat, state persistence.
- `ArabicText.swift`: shared Arabic TextKit measurement/display, text click and header drag.
- `PanelView.swift` / `PanelController.swift`: fixed-width transparent lyric window and controls.
- `WordTimings.swift` / `LyricsText.swift`: timestamp-to-text mapping and native line-follow scrolling.
- `ArabicFonts.swift` / `FontPicker.swift`: bundled Quran font registration, installed fonts, and dropdown previews.
- `LyricAppearance.swift` / `AppearanceSettingsView.swift`: persistent color/shadow/width settings and neighboring-ayah document ranges.
- `OfflineAudio.swift` / `OfflineAudioView.swift`: durable downloads, progress/cancellation, and offline status.
- `MenuView.swift` / `FloatingAyahApp.swift`: menu-bar interface and application entry.
- `scripts/build-app.sh`: assemble and ad-hoc sign the `.app` bundle.
