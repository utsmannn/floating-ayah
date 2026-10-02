# Quran source attribution

Bundled edition: `quran-uthmani`, Al Quran Cloud API.
Corpus: 114 surahs and 6,236 ayahs.
Arabic strings are preserved exactly as returned by the source.

- API: https://api.alquran.cloud/v1/quran/quran-uthmani
- Service terms: https://alquran.cloud/terms-and-conditions
- Upstream sources acknowledged by the service: GlobalQuran, Tanzil, Quran Academy.
- Tanzil: https://tanzil.net — text license: https://tanzil.net/docs/text_license
- Quran Academy: https://quranacademy.org

Audio is streamed/downloaded on demand, not included in this bundle.
EveryAyah collections (all murattal):
- Mishary Rashid Alafasy: `Alafasy_128kbps`
- Mahmoud Khalil Al-Husary: `Husary_64kbps`
- Mohamed Siddiq Al-Minshawi: `Minshawy_Murattal_128kbps`
- Abdul Basit Abdus Samad: `Abdul_Basit_Murattal_64kbps`
- Abdurrahman As-Sudais: `Abdurrahmaan_As-Sudais_192kbps`
- Abu Bakr Ash-Shatri: `Abu_Bakr_Ash-Shaatree_128kbps`
Source: https://everyayah.com/data/<collection>/
Catalog: https://everyayah.com/recitations_ayat.html

Tanzil upstream conditions (where applicable): CC BY 3.0, verbatim copies only;
clearly attribute Tanzil and link to tanzil.net. Preserve the upstream copyright
notice with all distributed copies. Review the canonical license and exact
edition provenance before a public distribution; API availability is not a
blanket license for audio or third-party content.

## Audio download sizes

`audio-sizes.json` records EveryAyah directory listing byte sizes for exactly
6,236 numbered ayah MP3s, excluding ZIPs, basmalah extras, and other files.
Source: https://everyayah.com/data/Alafasy_128kbps/
Snapshot retrieved 2026-10-01. Sum: 1,706,672,026 bytes (about 1.71 GB decimal).
UI labels the full size an estimate because upstream audio can change; stored
bytes are measured from local files and update after each completed download.
Each additional collection has its own `<collection>-sizes.json` snapshot,
source URL, and retrieval timestamp. Totals in bytes:
Husary 1,229,657,563; Minshawi 1,656,713,666; Abdul Basit 903,568,387;
Sudais 1,813,519,256; Shatri 1,413,989,963.

## Quran font

Amiri Quran Regular, copyright 2010–2022 The Amiri Quran Project Authors.
https://github.com/aliftype/amiri
Bundled unmodified from https://github.com/google/fonts/tree/main/ofl/amiriquran
Licensed under SIL Open Font License 1.1; full notice in AmiriQuran-OFL.txt.
Registered for this app process only, not installed system-wide.
Uthmani refers to the Quran text orthography; Amiri Quran is the font family.

## Word timings

Word timing data by Colin Fair (`cpfair`), quran-align, 24 November 2016 release.
https://github.com/cpfair/quran-align
https://github.com/cpfair/quran-align/releases/tag/release-2016-11-24
Licensed under Creative Commons Attribution 4.0 International:
https://creativecommons.org/licenses/by/4.0/
Full license and upstream README are bundled as TIMING-LICENSE.txt / TIMING-README.txt.
The six matching collection files are included; unused diagnostic stats were
removed while all timestamp/word segments are unchanged. The Sudais archive
contains console crash diagnostics before its valid JSON payload; this prefix
was removed during extraction (the 6,236-entry payload was preserved). Runtime ignores standalone stop marks
and splits the API's prepended basmalah from opening ayahs for presentation.
The opening uses the selected qari's Al-Fatihah 1:1 recording and its timing,
while the numbered ayah uses its own recording/timing. Original Arabic strings
are preserved in the resource file (including variant prefixes in surahs 95/97).
Automatically generated alignment has known inaccuracies and is not human-reviewed.
Three verses with incompatible token counts (10:1, 13:1, 50:34) use manual scroll.

Opening basmalah is explicit, unnumbered, and not assumed to be in an ayah-1
file. Al-Fatihah 1:1 remains numbered; no opening is inserted for At-Tawbah.
