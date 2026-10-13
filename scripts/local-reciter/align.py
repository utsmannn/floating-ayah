"""Force-align the located ayahs word by word with the MMS CTC aligner.

Usage: python align.py <work-dir> [episode-id ...]
Reads locate/<id>.json and writes align/<id>.json:
  [{"surah", "ayah", "start", "end", "words": [[start, end], ...], "score", "worst"}, ...]
Times are seconds in the episode. Scores are mean log-probabilities per frame; higher is better.
"""
import json
import os
import subprocess
import sys
import urllib.request
from pathlib import Path

import numpy as np
import onnxruntime
from ctc_forced_aligner import (MODEL_URL, SAMPLING_FREQ, Tokenizer, generate_emissions, get_alignments,
                                get_spans)

from quran_text import episode_priority, load_ayahs, romanize

PAD = 4.0          # Seconds around a chunk's estimated span; <star> absorbs anything extra.
CHUNK = 45.0       # Longest estimated audio per alignment pass.


def model(work: Path) -> onnxruntime.InferenceSession:
    path = work.parent / "models" / "mms-fa.onnx"
    if not path.exists():
        path.parent.mkdir(exist_ok=True)
        urllib.request.urlretrieve(MODEL_URL, path.with_suffix(".part"))
        path.with_suffix(".part").rename(path)
    options = onnxruntime.SessionOptions()
    options.intra_op_num_threads = int(os.environ.get("ALIGN_THREADS", "4"))
    return onnxruntime.InferenceSession(str(path), options, providers=["CPUExecutionProvider"])


def decode(path: Path) -> np.ndarray:
    raw = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(path), "-ac", "1",
                          "-ar", str(SAMPLING_FREQ), "-f", "f32le", "-"], check=True, capture_output=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def chunks(run):
    group = []
    for ayah in run:
        # Ayahs that share an uncertain window (a gap the ASR missed) stay in one pass.
        same_window = group and ayah[2] == group[-1][2]
        if group and ayah[3] - group[0][2] > CHUNK and not same_window:
            yield group
            group = []
        group.append(ayah)
    if group:
        yield group


def windows(groups, total):
    """Stretches of the episode that hold located ayahs, so prayer pauses are never processed.
    Built from whole chunks, so every chunk lies inside a single window."""
    spans = sorted((max(0.0, min(g[0][2], g[-1][3]) - PAD - 1), min(total, max(g[0][2], g[-1][3]) + PAD + 1))
                   for g in groups)
    merged = []
    for start, end in spans:
        if merged and start <= merged[-1][1] + 2:
            merged[-1][1] = max(merged[-1][1], end)
        else:
            merged.append([start, end])
    return merged


def align_chunk(tokenizer, window, group, words_of):
    window_start, all_emissions, seconds_per_frame = window
    first_frame = max(0, int((group[0][2] - PAD - window_start) / seconds_per_frame))
    last_frame = min(len(all_emissions), int((group[-1][3] + PAD - window_start) / seconds_per_frame))
    if last_frame - first_frame < 25:
        return []
    emissions = np.ascontiguousarray(all_emissions[first_frame:last_frame])
    begin = window_start + first_frame * seconds_per_frame
    tokens, labels = [], []
    for surah, ayah, _, _ in group:
        tokens.append("<star>")
        labels.append(None)
        for index, word in enumerate(words_of[(surah, ayah)]):
            tokens.append(" ".join(romanize(word)))
            labels.append((surah, ayah, index))
    tokens.append("<star>")
    labels.append(None)
    # CTC needs a frame per character plus a blank between repeated ones; the native aligner aborts
    # the whole process otherwise, so a window too short for its words is skipped instead.
    characters = " ".join(tokens).split(" ")
    needed = len(characters) + sum(a == b for a, b in zip(characters, characters[1:]))
    if len(emissions) < needed:
        return []
    segments, scores, blank = get_alignments(emissions, tokens, tokenizer)
    spans = get_spans(tokens, segments, blank)
    found = {}
    for label, span in zip(labels, spans):
        if label is None:
            continue
        # Score only the frames that carry the word's own characters, not padding blanks.
        voiced = [s for s in span if s.label != blank] or span
        first, last = voiced[0].start, voiced[-1].end
        score = float(scores[first:last + 1].mean()) if last >= first else -10.0
        found.setdefault(label[:2], []).append([round(begin + first * seconds_per_frame, 3),
                                                round(begin + (last + 1) * seconds_per_frame, 3), score])
    result = []
    for surah, ayah, _, _ in group:
        words = found.get((surah, ayah), [])
        if len(words) != len(words_of[(surah, ayah)]):
            continue
        result.append({"surah": surah, "ayah": ayah, "start": words[0][0], "end": words[-1][1],
                       "words": [w[:2] for w in words],
                       "score": round(float(np.mean([w[2] for w in words])), 3),
                       "worst": round(float(min(w[2] for w in words)), 3)})
    return result


def main(work: Path, only: list[str]) -> None:
    words_of = {(a.surah, a.ayah): a.words for a in load_ayahs()}
    session, tokenizer = model(work), Tokenizer()
    out = work / "align"
    out.mkdir(exist_ok=True)
    def covered():
        return {(e["surah"], e["ayah"]) for done in out.glob("*.json") if not done.name.endswith(".tried.json")
                for e in json.loads(done.read_text())}

    located_all = [json.loads(path.read_text()) for path in sorted((work / "locate").glob("*.json"))]
    # Best sources first. A lower-priority episode whose ayahs are already aligned elsewhere is
    # skipped; export falls back to it only if verification later rejects the better source.
    located_all.sort(key=lambda l: (episode_priority(l["title"]), l["id"]),
                     reverse=os.environ.get("ALIGN_REVERSE") == "1")
    have = covered()
    for located in located_all:
        path = work / "locate" / f"{located['id']}.json"
        target = out / path.name
        tried_file = out / f"{path.stem}.tried.json"
        if (only and located["id"] not in only) or not located["runs"]:
            continue
        wanted = {(a[0], a[1]) for run in located["runs"] for a in run["ayahs"]}
        existing, tried = [], set()
        if target.exists():
            # Already aligned: only ayahs that locate added since then, such as run edges.
            existing = json.loads(target.read_text())
            tried = {tuple(k) for k in json.loads(tried_file.read_text())} if tried_file.exists() else \
                {(e["surah"], e["ayah"]) for e in existing}
            if not wanted - tried:
                continue
        elif not only and episode_priority(located["title"]) >= 2 and len(wanted - have) <= 0.05 * len(wanted):
            continue
        lock = out / f"{path.stem}.lock"
        try:
            os.close(os.open(lock, os.O_CREAT | os.O_EXCL))
        except FileExistsError:
            continue
        audio = decode(work / "raw" / f"{located['id']}.mp3")
        # One model pass per window; each chunk then aligns against a slice of its window.
        groups = [group for run in located["runs"]
                  for group in chunks([a for a in run["ayahs"] if (a[0], a[1]) not in tried])]
        passes = []
        for start, end in windows(groups, len(audio) / SAMPLING_FREQ):
            clip = audio[int(start * SAMPLING_FREQ):int(end * SAMPLING_FREQ)]
            emissions, _ = generate_emissions(session, clip, batch_size=4)
            passes.append((start, end, emissions, len(clip) / SAMPLING_FREQ / emissions.shape[0]))
        aligned = []
        for group in groups:
            middle = (group[0][2] + group[-1][3]) / 2
            window = next((p for p in passes if p[0] <= middle <= p[1]), None)
            if window is None:
                continue
            start, _, emissions, seconds_per_frame = window
            aligned += align_chunk(tokenizer, (start, emissions, seconds_per_frame), group, words_of)
        target.write_text(json.dumps(existing + aligned))
        tried_file.write_text(json.dumps(sorted(tried | wanted)))
        lock.unlink(missing_ok=True)
        have |= {(e["surah"], e["ayah"]) for e in aligned}
        print(f"{located['id']} {located['title']}: {len(aligned)} ayahs", flush=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2:])
