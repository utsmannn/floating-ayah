"""Pick the best recording of every aligned ayah, verify it, and install per-ayah files for the app.

Usage: python export.py <work-dir> <dest-dir>
dest-dir is the reciter's offline folder, e.g.
  ~/Library/Application Support/FloatingAyah/Audio/Ziyaad_Patel
It receives SSS/SSSAAA.mp3, timings.json (the app's TimedAyah format) and, last, manifest.json.
Ayahs without a verified recording are left out, and the app disables them.
"""
import json
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from pathlib import Path

import mlx_whisper
import numpy as np
from rapidfuzz.fuzz import partial_ratio, ratio

from quran_text import episode_priority as priority, load_ayahs, match_key, spoken, tokens

MODEL = "mlx-community/whisper-large-v3-turbo"
LEAD, TAIL = 0.25, 0.5   # Seconds kept before the first word and after the last one.
TRIES = 3                # Candidates verified per ayah before giving up.


def decode(path: Path, rate: int, channels: int) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", str(channels),
                          "-ar", str(rate), "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32).reshape(-1, channels)


def skeleton(words: list[str], letter_names: bool = False) -> str:
    parts = [part for w in words for part in (spoken(w).split() if letter_names else [w])]
    return " ".join(k for k in (match_key(part) for part in parts) if k)


def similarity(scorer, heard: str, words: list[str]) -> float:
    """Disjoined letters may be transcribed as written (حم) or by name (حا ميم); take the closer."""
    return max(scorer(skeleton(words, names), heard) for names in (False, True))


def heard_in_transcript(asr: list[dict], start: float, end: float, words: list[str]) -> float:
    """How well the episode's own transcript, around the aligned span, contains the ayah."""
    nearby = " ".join(seg["text"] for seg in asr if seg["end"] > start - 1 and seg["start"] < end + 1)
    return similarity(partial_ratio, skeleton(tokens(nearby)), words)


def verified(audio16, asr: list[dict], start: float, end: float, words: list[str],
             score: float) -> tuple[bool, float]:
    # A confidently aligned ayah is confirmed from the existing transcript; a short one needs a
    # closer match there, since a few words are easy to find by chance. Weak alignments and
    # passages Whisper misheard the first time are transcribed again from the cut clip.
    nearby = heard_in_transcript(asr, start, end, words)
    if score >= -1.0 and nearby >= (80 if len(words) > 3 else 90):
        return True, nearby
    if audio16 is None:
        return False, nearby
    clip = audio16[int(max(0.0, start) * 16000):int(end * 16000), 0]
    # Whisper hears a two-second clip better with some silence around it.
    clip = np.pad(clip, 8000)
    heard = mlx_whisper.transcribe(np.ascontiguousarray(clip), path_or_hf_repo=MODEL, language="ar",
                                   condition_on_previous_text=False)["text"]
    closeness = similarity(ratio, skeleton(tokens(heard)), words)
    return closeness >= (60 if len(words) <= 4 else 70), closeness


def main(work: Path, dest: Path) -> None:
    episodes = {e["id"]: e for e in json.loads((work / "episodes.json").read_text())}
    words_of = {(a.surah, a.ayah): a.words for a in load_ayahs()}
    aligned = {}
    candidates = defaultdict(list)
    for path in sorted((work / "align").glob("*.json")):
        if path.name.endswith(".tried.json"):
            continue
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
            asr = json.loads((work / "asr" / f"{episode}.json").read_text())["segments"]
            audio16 = None
            for key, index in items:
                entry = aligned[episode][index]
                span = (entry["start"] - LEAD, entry["end"] + TAIL)
                ok, closeness = verified(None, asr, *span, words_of[key], entry["score"])
                if not ok:
                    if audio16 is None:
                        audio16 = decode(work / "raw" / f"{episode}.mp3", 16000, 1)
                    ok, closeness = verified(audio16, asr, *span, words_of[key], entry["score"])
                if ok:
                    chosen[key] = (episode, index, closeness)
                else:
                    rejected[key].append((episode, round(closeness)))
                    attempt[key] += 1
                    if attempt[key] < min(TRIES, len(candidates[key])):
                        pending.add(key)
            print(f"verified {episode} ({len(items)}), total {len(chosen)}", flush=True)

    # An ayah whose own check failed is still placed correctly when the ayahs on both sides of it,
    # aligned in the same pass of the same recording, were verified: alignment keeps reading order.
    # Very short ayahs (وَطُورِ سِينِينَ) need this, as Whisper hears two words poorly.
    for key in [k for k in candidates if k not in chosen]:
        for _, _, episode, index in candidates[key]:
            entries = aligned[episode]
            if not (0 < index < len(entries) - 1) or entries[index]["score"] < -1.0:
                continue
            before = (entries[index - 1]["surah"], entries[index - 1]["ayah"])
            after = (entries[index + 1]["surah"], entries[index + 1]["ayah"])
            if (before == (key[0], key[1] - 1) and after == (key[0], key[1] + 1)
                    and chosen.get(before, (None,))[0] == episode and chosen.get(after, (None,))[0] == episode):
                chosen[key] = (episode, index, 0)
                break
    print(f"accepted between verified neighbours: {sum(1 for c in chosen.values() if c[2] == 0)}", flush=True)

    staging = dest.with_name(dest.name + ".new")
    shutil.rmtree(staging, ignore_errors=True)
    staging.mkdir(parents=True)
    timings, sources = [], {}
    by_episode = defaultdict(list)
    for key, (episode, index, closeness) in chosen.items():
        by_episode[episode].append((key, index, closeness))
    for episode, items in sorted(by_episode.items()):
        audio = decode(work / "raw" / f"{episode}.mp3", 44100, 2)
        entries = aligned[episode]
        for (surah, ayah), index, closeness in items:
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
                                          "end": round(end, 2), "verified": round(closeness)}
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
