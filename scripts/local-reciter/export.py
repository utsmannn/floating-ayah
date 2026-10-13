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


def without_overlaps(entries: list[dict]) -> list[dict]:
    """Two ayahs of one recording cannot share the same seconds; one of them was forced into
    place (a basmalah where the prayer reading has none, an edge ayah over its neighbour). Drop the
    entry that collides with the most others, the weaker alignment first, until none collide."""
    def clash(a, b):
        overlap = min(a["end"], b["end"]) - max(a["start"], b["start"])
        if overlap <= 0.2:
            return False
        # Consecutive ayahs often disagree on their shared edge (a final madd stretched over the
        # next ayah's start). That is settled later at the pause between them, not by dropping one.
        consecutive = a["surah"] == b["surah"] and abs(a["ayah"] - b["ayah"]) == 1
        shortest = min(a["end"] - a["start"], b["end"] - b["start"])
        return not (consecutive and overlap < min(3.0, 0.5 * shortest))

    entries = list(entries)
    while True:
        clashes = [sum(1 for o in entries if o is not e and clash(e, o)) for e in entries]
        if not any(clashes):
            return entries
        worst = max(range(len(entries)), key=lambda i: (clashes[i], -entries[i]["score"]))
        entries.pop(worst)


def voiced_bounds(level: np.ndarray, threshold: float, first: float, last: float,
                  earliest: float, latest: float) -> tuple[float, float]:
    """Widen [first, last] to where the voice actually starts and fades out. A long madd at the end
    of an ayah often outlasts the aligner's last frame. Never crosses [earliest, latest]."""
    frame = 0.01

    def voiced(t):
        i = int(t / frame)
        return 0 <= i < len(level) and level[i] > threshold

    end, quiet = last, 0.0
    while end < latest and quiet < 0.15:
        quiet = 0.0 if voiced(end) else quiet + frame
        end += frame
    start, quiet = first, 0.0
    while start > earliest and quiet < 0.1:
        quiet = 0.0 if voiced(start) else quiet + frame
        start -= frame
    return max(earliest, start - 0.05), min(latest, max(end, last + 0.1))


def pause_between(level: np.ndarray, threshold: float, previous: dict, following: dict) -> float:
    """Where one ayah ends and the next begins: the middle of the longest quiet stretch around the
    join. The aligner's own edges drift by a few tenths of a second, enough to clip a madd or to
    carry the first sound of the next ayah. Searches no further back than the previous ayah's last
    word and no further on than the following ayah's first word."""
    frame = 0.01
    lo = max(previous["words"][-1][0] + 0.1, min(previous["end"], following["start"]) - 0.8)
    hi = min(following["words"][0][1] - 0.1, max(previous["end"], following["start"]) + 0.3)
    first, last = int(lo / frame), int(hi / frame)
    if last <= first:
        return (previous["end"] + following["start"]) / 2
    window = level[first:last]
    best, run_start = (0, 0, 0), None
    for i, quiet in enumerate(np.append(window < threshold, False)):
        if quiet and run_start is None:
            run_start = i
        elif not quiet and run_start is not None:
            if i - run_start > best[0]:
                best = (i - run_start, run_start, i)
            run_start = None
    if best[0] == 0:
        return (first + int(np.argmin(window))) * frame
    return (first + (best[1] + best[2]) / 2) * frame


def clip_bounds(level: np.ndarray, threshold: float, entries: list[dict], index: int, total: float):
    """Start and end of one ayah's clip: at the pause shared with an adjacent ayah of the same
    recording, otherwise where the voice starts and fades out."""
    entry = entries[index]
    previous = entries[index - 1] if index > 0 and entry["start"] - entries[index - 1]["end"] < 3 else None
    following = entries[index + 1] if index + 1 < len(entries) and entries[index + 1]["start"] - entry["end"] < 3 else None
    before = entries[index - 1]["end"] + 0.05 if index > 0 else 0.0
    after = entries[index + 1]["start"] - 0.05 if index + 1 < len(entries) else total
    start, end = voiced_bounds(level, threshold, entry["start"], entry["end"],
                               max(before, entry["start"] - 1.0, 0.0), min(after, entry["end"] + 3.0, total))
    if previous is not None:
        start = pause_between(level, threshold, previous, entry)
    if following is not None:
        end = pause_between(level, threshold, entry, following)
    return start, end


def loudness(audio: np.ndarray) -> tuple[np.ndarray, float]:
    """Level in dB per 10 ms of a 44.1 kHz stereo recording, and its silence threshold."""
    hop = 441
    frames = len(audio) // hop
    level = 20 * np.log10(np.sqrt(np.mean(audio[:frames * hop].reshape(frames, hop, 2) ** 2, axis=(1, 2))) + 1e-9)
    low, high = np.percentile(level, 15), np.percentile(level, 90)
    return level, low + 0.25 * (high - low)


def main(work: Path, dest: Path) -> None:
    episodes = {e["id"]: e for e in json.loads((work / "episodes.json").read_text())}
    words_of = {(a.surah, a.ayah): a.words for a in load_ayahs()}
    aligned = {}
    candidates = defaultdict(list)
    for path in sorted((work / "align").glob("*.json")):
        if path.name.endswith(".tried.json"):
            continue
        episode = path.stem
        entries = without_overlaps(sorted(json.loads(path.read_text()), key=lambda e: e["start"]))
        aligned[episode] = entries
        title = episodes[episode]["title"]
        for index, entry in enumerate(entries):
            rank = priority(title)
            # A numbered recording is the best source for its own surah only. What follows it in the
            # same file (the short surahs of the next rak'ah) ranks after the loose recordings.
            numbered = re.match(r"^(\d{3}) ", title)
            if numbered and int(numbered.group(1)) != entry["surah"]:
                rank = 1.5
            # Al-Fatihah 1:1 is the basmalah played before every surah: take the dedicated recording.
            if entry["surah"] == 1 and title.startswith("Surah Fatiha"):
                rank = -1
            candidates[(entry["surah"], entry["ayah"])].append((rank, -entry["score"], episode, index))
    for options in candidates.values():
        options.sort()

    # Verification results survive between runs: a re-export after changing how clips are cut
    # does not transcribe anything again.
    cache_file = work / "verify-cache.json"
    cache = json.loads(cache_file.read_text()) if cache_file.exists() else {}

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
                cache_key = f"{episode}:{key[0]}:{key[1]}:{entry['start']:.3f}:{entry['end']:.3f}"
                if cache_key in cache:
                    ok, closeness = cache[cache_key]
                else:
                    ok, closeness = verified(None, asr, *span, words_of[key], entry["score"])
                    if not ok:
                        if audio16 is None:
                            audio16 = decode(work / "raw" / f"{episode}.mp3", 16000, 1)
                        ok, closeness = verified(audio16, asr, *span, words_of[key], entry["score"])
                    cache[cache_key] = (ok, closeness)
                if ok:
                    chosen[key] = (episode, index, closeness)
                else:
                    rejected[key].append((episode, round(closeness)))
                    attempt[key] += 1
                    if attempt[key] < min(TRIES, len(candidates[key])):
                        pending.add(key)
            print(f"verified {episode} ({len(items)}), total {len(chosen)}", flush=True)
            cache_file.write_text(json.dumps(cache))

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
        total = len(audio) / 44100
        level, threshold = loudness(audio)
        entries = aligned[episode]
        for (surah, ayah), index, closeness in items:
            entry = entries[index]
            start, end = clip_bounds(level, threshold, entries, index, total)
            target = staging / f"{surah:03d}" / f"{surah:03d}{ayah:03d}.mp3"
            target.parent.mkdir(exist_ok=True)
            pcm = audio[int(start * 44100):int(end * 44100)]
            subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-f", "f32le", "-ar", "44100", "-ac", "2", "-i", "-",
                            "-af", f"afade=t=in:d=0.02,afade=t=out:st={max(0.0, end - start - 0.05):.3f}:d=0.05",
                            "-c:a", "libmp3lame", "-b:a", "128k", "-y", str(target)],
                           input=np.ascontiguousarray(pcm).tobytes(), check=True)
            timings.append({"surah": surah, "ayah": ayah, "segments": [
                [i, i + 1, round((max(w[0], start) - start) * 1000), round((min(w[1], end) - start) * 1000)]
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
