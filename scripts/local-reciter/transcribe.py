"""Transcribe every raw episode with Whisper so recordings can be located in the Quran text.

Usage: python transcribe.py <work-dir> [episode-id ...]
Writes <work-dir>/asr/<id>.json (segments with start, end, text). Existing results are kept.
"""
import json
import sys
import time
from pathlib import Path

import mlx_whisper
import numpy as np
from mlx_whisper.audio import SAMPLE_RATE, load_audio

MODEL = "mlx-community/whisper-large-v3-turbo"
FRAME = 0.03


def clips(audio: np.ndarray, shortest=4.0, longest=24.0) -> list[float]:
    """Cut points in breathing pauses. On long melodic recitation Whisper often ends a 30-second
    window after one ayah and skips the rest; short clips cut at pauses avoid that."""
    hop = int(FRAME * SAMPLE_RATE)
    frames = len(audio) // hop
    rms = np.sqrt(np.mean(audio[:frames * hop].reshape(frames, hop) ** 2, axis=1) + 1e-12)
    db = 20 * np.log10(rms)
    low, high = np.percentile(db, 15), np.percentile(db, 90)
    silent = db < low + 0.3 * (high - low)
    pauses = []  # (middle seconds, length seconds)
    start = None
    for i, quiet in enumerate(np.append(silent, False)):
        if quiet and start is None:
            start = i
        elif not quiet and start is not None:
            if (i - start) * FRAME >= 0.25:
                pauses.append(((start + i) / 2 * FRAME, (i - start) * FRAME))
            start = None
    total = len(audio) / SAMPLE_RATE
    bounds, begin = [], 0.0
    while total - begin > longest:
        options = [p for p in pauses if begin + shortest <= p[0] <= begin + longest]
        # Prefer the longest pause, which is most likely the end of an ayah.
        cut = max(options, key=lambda p: p[1])[0] if options else begin + longest
        bounds += [begin, cut]
        begin = cut
    bounds += [begin, total]
    return [round(b, 2) for b in bounds]


def main(work: Path, only: list[str]) -> None:
    out = work / "asr"
    out.mkdir(exist_ok=True)
    episodes = json.loads((work / "episodes.json").read_text())
    if only:
        episodes = [e for e in episodes if e["id"] in only]
    # Shortest first, so results arrive early and long tarawih files come last.
    episodes.sort(key=lambda e: (work / "raw" / f"{e['id']}.mp3").stat().st_size)
    for episode in episodes:
        target = out / f"{episode['id']}.json"
        if target.exists():
            continue
        began = time.time()
        audio = np.array(load_audio(str(work / "raw" / f"{episode['id']}.mp3")))
        result = mlx_whisper.transcribe(audio, path_or_hf_repo=MODEL, language="ar",
                                        condition_on_previous_text=False, clip_timestamps=clips(audio))
        segments = [{"start": round(s["start"], 2), "end": round(s["end"], 2), "text": s["text"].strip()}
                    for s in result["segments"]]
        target.write_text(json.dumps({"id": episode["id"], "title": episode["title"], "segments": segments},
                                     ensure_ascii=False))
        print(f"{episode['id']} {time.time() - began:.0f}s {episode['title']}", flush=True)
    print("done")


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2:])
