"""Pick the best recording of every aligned ayah, verify it, and install per-ayah files for the app.

Usage: python export.py <work-dir> <dest-dir>
dest-dir is the reciter's offline folder, e.g.
  ~/Library/Application Support/FloatingAyah/Audio/Ziyaad_Patel
It receives SSS/SSSAAA.mp3, timings.json (the app's TimedAyah format) and, last, manifest.json.
Ayahs without a verified recording are left out, and the app disables them.
"""
import json
import re
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from pathlib import Path

import mlx_whisper
import numpy as np
from rapidfuzz.fuzz import ratio

from quran_text import load_ayahs, match_key, tokens

MODEL = "mlx-community/whisper-large-v3-turbo"
LEAD, TAIL = 0.25, 0.5   # Seconds kept before the first word and after the last one.
TRIES = 3                # Candidates verified per ayah before giving up.


def priority(title: str) -> int:
    """Clean per-surah recordings first, then loose surahs, then taraweeh (2020 before older)."""
    if re.match(r"^\d{3} ", title):
        return 0
    if "Ramadan" in title or "Juz" in title:
        return 2 if "2020" in title else 3
    return 1


def decode(path: Path, rate: int, channels: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", str(channels),
                          "-ar", str(rate), "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels)


def skeleton(words: list[str]) -> str:
    return " ".join(k for k in (match_key(w) for w in words) if k)


def verified(audio16: np.ndarray, start: float, end: float, words: list[str]) -> tuple[bool, float]:
    clip = audio16[int(start * 16000):int(end * 16000), 0]
    heard = mlx_whisper.transcribe(np.ascontiguousarray(clip), path_or_hf_repo=MODEL, language="ar",
                                   condition_on_previous_text=False)["text"]
    similarity = ratio(skeleton(tokens(heard)), skeleton(words))
    return similarity >= (60 if len(words) <= 2 else 70), similarity


def main(work: Path, dest: Path) -> None:
    episodes = {e["id"]: e for e in json.loads((work / "episodes.json").read_text())}
    words_of = {(a.surah, a.ayah): a.words for a in load_ayahs()}
    aligned = {}
    candidates = defaultdict(list)
    for path in sorted((work / "align").glob("*.json")):
        episode = path.stem
        entries = sorted(json.loads(path.read_text()), key=lambda e: e["start"])
        aligned[episode] = entries
        for index, entry in enumerate(entries):
            candidates[(entry["surah"], entry["ayah"])].append(
                (priority(episodes[episode]["title"]), -entry["score"], episode, index))
    for options in candidates.values():
        options.sort()

    # Verify in rounds grouped by episode, so each recording is decoded once per round.
    chosen, attempt, rejected = {}, defaultdict(int), defaultdict(list)
    pending = set(candidates)
    while pending:
        by_episode = defaultdict(list)
        for key in pending:
            _, _, episode, index = candidates[key][attempt[key]]
            by_episode[episode].append((key, index))
        pending = set()
        for episode, items in sorted(by_episode.items()):
            audio16 = decode(work / "raw" / f"{episode}.mp3", 16000, 1)
            for key, index in items:
                entry = aligned[episode][index]
                ok, similarity = verified(audio16, entry["start"] - LEAD, entry["end"] + TAIL, words_of[key])
                if ok:
                    chosen[key] = (episode, index, similarity)
                else:
                    rejected[key].append((episode, round(similarity)))
                    attempt[key] += 1
                    if attempt[key] < min(TRIES, len(candidates[key])):
                        pending.add(key)
            print(f"verified {episode} ({len(items)}), total {len(chosen)}", flush=True)

    staging = dest.with_name(dest.name + ".new")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    timings, sources = [], {}
    by_episode = defaultdict(list)
    for key, (episode, index, similarity) in chosen.items():
        by_episode[episode].append((key, index, similarity))
    for episode, items in sorted(by_episode.items()):
        audio = decode(work / "raw" / f"{episode}.mp3", 44100, 2)
        entries = aligned[episode]
        for (surah, ayah), index, similarity in items:
            entry = entries[index]
            # Never take in a neighbouring ayah's words.
            before = entries[index - 1]["end"] if index > 0 else 0.0
            after = entries[index + 1]["start"] if index + 1 < len(entries) else len(audio) / 44100
            start = max(entry["start"] - LEAD, (before + entry["start"]) / 2, 0.0)
            end = min(entry["end"] + TAIL, (entry["end"] + after) / 2, len(audio) / 44100)
            target = staging / f"{surah:03d}" / f"{surah:03d}{ayah:03d}.mp3"
            target.parent.mkdir(exist_ok=True)
            pcm = audio[int(start * 44100):int(end * 44100)]
            subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "f32le", "-ar", "44100", "-ac", "2", "-i", "-",
                            "-af", f"afade=t=in:d=0.02,afade=t=out:st={max(0.0, end - start - 0.05):.3f}:d=0.05",
                            "-c:a", "libmp3lame", "-b:a", "128k", "-y", str(target)],
                           input=np.ascontiguousarray(pcm).tobytes(), check=True)
            timings.append({"surah": surah, "ayah": ayah, "segments": [
                [i, i + 1, round((w[0] - start) * 1000), round((w[1] - start) * 1000)]
                for i, w in enumerate(entry["words"])]})
            sources[f"{surah}:{ayah}"] = {"episode": episodes[episode]["title"], "start": round(start, 2),
                                          "end": round(end, 2), "verified": round(similarity)}
        print(f"exported {episode} ({len(items)})", flush=True)

    timings.sort(key=lambda t: (t["surah"], t["ayah"]))
    (staging / "timings.json").write_text(json.dumps(timings, separators=(",", ":")))
    (staging / "manifest.json").write_text(json.dumps({
        "reciter": "Ziyaad Patel", "source": "Quran Central podcast feed (rss.qurancentral.com/ziyaad-patel.rss)",
        "generatedAt": time.strftime("%Y-%m-%dT%H:%M:%S%z"), "ayahs": len(timings),
        "unverified": {f"{s}:{a}": r for (s, a), r in rejected.items() if (s, a) not in chosen},
        "sources": sources}, ensure_ascii=False, indent=1))
    shutil.rmtree(dest, ignore_errors=True)
    staging.rename(dest)
    print(f"installed {len(timings)} ayahs into {dest}")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]).expanduser())
