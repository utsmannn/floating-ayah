# Local reciter pipeline

Builds per-ayah audio and word timings for a reciter that EveryAyah does not have, from
full-surah or taraweeh recordings. The result stays on this Mac: the app shows a local reciter
only when its folder is installed, and disables every ayah that has no verified recording.

Currently used for Ziyaad Patel, from the Quran Central podcast feed. These recordings belong to
their publishers; keep the output for personal use unless they give permission to redistribute.

## Run

```sh
scripts/local-reciter/run.sh
```

Work files go to `work/ziyaad-patel/` (ignored by git). Each step skips results that already
exist, so an interrupted run resumes. Delete a step's folder to redo it after changing that step.

| Step | Output | What it does |
|---|---|---|
| `download.py` | `raw/`, `episodes.json` | Fetches every feed episode. |
| `transcribe.py` | `asr/` | Whisper large-v3-turbo (MLX) on clips cut at breathing pauses. |
| `locate.py` | `locate/` | Places transcript segments in the Quran by word skeletons and keeps the forward reading order, which drops takbir and the Al-Fatihah of each rak'ah. |
| `align.py` | `align/` | MMS CTC forced alignment of each located ayah's exact words. |
| `export.py` | the app's offline folder | Picks the best recording per ayah, re-transcribes the cut clip to verify it, and writes `SSS/SSSAAA.mp3`, `timings.json` and `manifest.json`. |

`manifest.json` records where each ayah came from and which ayahs failed verification. Its
`verified` value is the transcript similarity; `0` marks an ayah accepted because both
neighbouring ayahs from the same recording were verified.
Word indices follow the app's tokenization (`quran_text.py` mirrors `TimedAyah.wordRanges`).
