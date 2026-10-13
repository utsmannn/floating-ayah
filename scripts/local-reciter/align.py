"""Force-align the located ayahs word by word with the MMS CTC aligner.

Usage: python align.py <work-dir> [episode-id ...]
Reads locate/<id>.json and writes align/<id>.json:
  [{"surah", "ayah", "start", "end", "words": [[start, end], ...], "score", "worst"}, ...]
Times are seconds in the episode. Scores are mean log-probabilities per frame; higher is better.
"""
import json
import subprocess
import sys
import urllib.request
from pathlib import Path

import numpy as np
import onnxruntime
from ctc_forced_aligner import (MODEL_URL, SAMPLING_FREQ, Tokenizer, generate_emissions, get_alignments,
                                get_spans)

from quran_text import load_ayahs, romanize

PAD = 4.0          # Seconds around a chunk's estimated span; <star> absorbs anything extra.
CHUNK = 45.0       # Longest estimated audio per alignment pass.


def model(work: Path) -> onnxruntime.InferenceSession:
    path = work.parent / "models" / "mms-fa.onnx"
    if not path.exists():
        path.parent.mkdir(exist_ok=True)
        urllib.request.urlretrieve(MODEL_URL, path.with_suffix(".part"))
        path.with_suffix(".part").rename(path)
    return onnxruntime.InferenceSession(str(path), providers=["CPUExecutionProvider"])


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


def align_chunk(tokenizer, all_emissions, seconds_per_frame, group, words_of):
    first_frame = max(0, int((group[0][2] - PAD) / seconds_per_frame))
    last_frame = min(len(all_emissions), int((group[-1][3] + PAD) / seconds_per_frame))
    if last_frame - first_frame < 25:
        return []
    emissions = np.ascontiguousarray(all_emissions[first_frame:last_frame])
    begin = first_frame * seconds_per_frame
    tokens, labels = [], []
    for surah, ayah, _, _ in group:
        tokens.append("<star>")
        labels.append(None)
        for index, word in enumerate(words_of[(surah, ayah)]):
            tokens.append(" ".join(romanize(word)))
            labels.append((surah, ayah, index))
    tokens.append("<star>")
    labels.append(None)
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
    for path in sorted((work / "locate").glob("*.json")):
        located = json.loads(path.read_text())
        target = out / path.name
        if target.exists() or (only and located["id"] not in only) or not located["runs"]:
            continue
        audio = decode(work / "raw" / f"{located['id']}.mp3")
        # One pass over the whole episode; chunks then align against slices of it.
        emissions, _ = generate_emissions(session, audio, batch_size=4)
        seconds_per_frame = len(audio) / SAMPLING_FREQ / emissions.shape[0]
        aligned = []
        for run in located["runs"]:
            for group in chunks(run["ayahs"]):
                aligned += align_chunk(tokenizer, emissions, seconds_per_frame, group, words_of)
        target.write_text(json.dumps(aligned))
        print(f"{located['id']} {located['title']}: {len(aligned)} ayahs", flush=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]), sys.argv[2:])
