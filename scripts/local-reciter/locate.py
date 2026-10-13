"""Locate each transcribed episode in the Quran text and estimate where every recited ayah sits.

Usage: python locate.py <work-dir>
Reads asr/<id>.json and writes locate/<id>.json:
  {"runs": [{"ayahs": [[surah, ayah, approxStart, approxEnd], ...]}, ...]}
A run is a stretch recited continuously. Takbir, repeated Al-Fatihah in prayer, and anything else
that breaks the forward reading order is left out of the runs.
"""
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

from rapidfuzz.fuzz import ratio

from quran_text import load_ayahs, match_key, tokens

COMMON_LIMIT = 400  # Bigrams more frequent than this are too ambiguous to vote.
MAX_GAP_WORDS = 150  # Words the ASR may miss inside a continuous reading.
MAX_PAUSE = 300.0    # Seconds between two located segments of one reading, such as a rak'ah break.


def continues(previous, following) -> bool:
    """Whether two located segments belong to one continuous reading. Whisper drops or
    hallucinates over some passages, so a gap is kept when its length is plausible to recite."""
    gap_words = following[1] - previous[2] - 1
    seconds = following[0]["start"] - previous[0]["end"]
    if gap_words <= 6:
        return seconds <= MAX_PAUSE
    return gap_words <= MAX_GAP_WORDS and 0.15 * gap_words <= seconds <= MAX_PAUSE


def build_index(keys):
    index = defaultdict(list)
    for i in range(len(keys) - 1):
        index[(keys[i], keys[i + 1])].append(i)
    return index


def local_align(seg, quran, offset):
    """Smith-Waterman over words. Returns (matches, first quran index, last quran index)."""
    rows, cols = len(seg) + 1, len(quran) + 1
    score = [[0.0] * cols for _ in range(rows)]
    origin = [[None] * cols for _ in range(rows)]
    hits = [[0] * cols for _ in range(rows)]
    best = (0.0, 0, 0)
    for i in range(1, rows):
        for j in range(1, cols):
            similar = ratio(seg[i - 1], quran[j - 1]) >= 70
            diagonal_origin = origin[i - 1][j - 1] if origin[i - 1][j - 1] is not None else j - 1
            options = [(score[i - 1][j - 1] + (1 if similar else -0.6), diagonal_origin,
                        hits[i - 1][j - 1] + similar),
                       (score[i - 1][j] - 0.5, origin[i - 1][j], hits[i - 1][j]),
                       (score[i][j - 1] - 0.5, origin[i][j - 1], hits[i][j - 1])]
            value, start, count = max(options, key=lambda o: o[0])
            if value <= 0:
                continue
            score[i][j], origin[i][j], hits[i][j] = value, start, count
            if value > best[0]:
                best = (value, i, j)
    _, i, j = best
    if j == 0 or origin[i][j] is None:
        return 0, 0, 0
    return hits[i][j], offset + origin[i][j], offset + j - 1


def candidates(seg, keys, index):
    votes = defaultdict(int)
    for j in range(len(seg) - 1):
        positions = index.get((seg[j], seg[j + 1]), [])
        if len(positions) > COMMON_LIMIT:
            continue
        for p in positions:
            votes[p - j] += 1
    # One shared word pair is enough to try a location; local_align then has to confirm it. A short
    # segment with a single misheard word (سبح اسم رمك الأعلى) has no second pair to offer.
    need = 1
    found = []
    for start, count in sorted(votes.items(), key=lambda kv: -kv[1])[:15]:
        if count < need:
            break
        lo = max(0, start - 3)
        hits, qs, qe = local_align(seg, keys[lo:start + len(seg) + 6], lo)
        if hits >= max(2, 0.5 * len(seg)):
            found.append((hits, qs, qe))
    return sorted(set(found), key=lambda c: -c[0])[:8]


def chain(segments):
    """Best forward-reading path through each segment's candidate locations."""
    states = []  # (segment index, hits, qs, qe)
    for s, seg in enumerate(segments):
        for hits, qs, qe in seg["candidates"]:
            states.append((s, hits, qs, qe))
    best = [0.0] * len(states)
    back = [None] * len(states)
    for k, (s, hits, qs, qe) in enumerate(states):
        best[k] = hits
        for p in range(k - 1, -1, -1):
            ps, _, pqs, pqe = states[p]
            if ps == s:
                continue
            if s - ps > 150:
                break
            gap = qs - pqe
            if gap < -2:  # Reading never goes backwards except a slight overlap.
                continue
            value = best[p] + hits - 0.5 * math.log10(1 + max(0, gap))
            if value > best[k]:
                best[k], back[k] = value, p
    if not states:
        return []
    k = max(range(len(states)), key=best.__getitem__)
    path = []
    while k is not None:
        path.append(states[k])
        k = back[k]
    return path[::-1]


EDGE = 25.0  # Seconds searched beyond a run for its unmatched neighbouring ayahs.


def extend_edges(runs, ayahs):
    """Add up to two ayahs of the same surah before and after each run. Edges are where the ASR
    most often fails: ayah 1 right after the basmalah, disjoined letters (كاف ها يا عين صاد),
    and the last ayah of a recording. They get the unmatched time beside the run as their window,
    and the aligner and the export verification decide whether they are really there."""
    index = {(a.surah, a.ayah): i for i, a in enumerate(ayahs)}
    taken = {(a[0], a[1]) for run in runs for a in run["ayahs"]}
    for run in runs:
        before, after, start, end = run["bounds"]
        first, last = run["ayahs"][0], run["ayahs"][-1]
        head = []
        i = index[(first[0], first[1])]
        for _ in range(2):
            i -= 1
            if i < 0 or ayahs[i].surah != first[0] or (ayahs[i].surah, ayahs[i].ayah) in taken:
                break
            head.insert(0, [ayahs[i].surah, ayahs[i].ayah, round(max(before, start - EDGE, 0.0), 2), first[2]])
        i = index[(last[0], last[1])]
        tail = []
        for _ in range(2):
            i += 1
            if i >= len(ayahs) or ayahs[i].surah != last[0] or (ayahs[i].surah, ayahs[i].ayah) in taken:
                break
            tail.append([ayahs[i].surah, ayahs[i].ayah, last[3], round(min(after, end + EDGE), 2)])
        taken |= {(a[0], a[1]) for a in head + tail}
        run["ayahs"] = head + run["ayahs"] + tail


def interpolate(points, word):
    """Time at a Quran word index from (word index, seconds) anchor points."""
    if word <= points[0][0]:
        return points[0][1]
    for (w0, t0), (w1, t1) in zip(points, points[1:]):
        if w0 <= word <= w1:
            return t0 if w1 == w0 else t0 + (t1 - t0) * (word - w0) / (w1 - w0)
    return points[-1][1]


def main(work: Path) -> None:
    ayahs = load_ayahs()
    keys, owner, first_word = [], [], []
    for i, a in enumerate(ayahs):
        first_word.append(len(keys))
        for w in a.words:
            keys.append(match_key(w))
            owner.append(i)
    index = build_index(keys)
    out = work / "locate"
    out.mkdir(exist_ok=True)
    for path in sorted((work / "asr").glob("*.json")):
        target = out / path.name
        if target.exists():
            continue
        asr = json.loads(path.read_text())
        segments = []
        for seg in asr["segments"]:
            words = [k for k in (match_key(t) for t in tokens(seg["text"])) if k]
            if len(words) < 2:
                continue
            segments.append({**seg, "candidates": candidates(words, keys, index)})
        path_states = chain(segments)
        runs, current = [], []
        for s, _, qs, qe in path_states:
            if current and not continues(current[-1], (segments[s], qs, qe)):
                runs.append(current)
                current = []
            current.append((segments[s], qs, qe))
        if current:
            runs.append(current)
        result = []
        bounds = [(run[0][0]["start"], run[-1][0]["end"]) for run in runs]
        file_end = (asr["segments"][-1]["end"] + 10) if asr["segments"] else 0
        for r, run in enumerate(runs):
            points = []
            for seg, qs, qe in run:
                points += [(qs, seg["start"]), (qe + 1, seg["end"])]
            points.sort()
            # Words the ASR missed inside a run: (first word, last word, start time, end time).
            gaps = [(a[2] + 1, b[1] - 1, a[0]["end"], b[0]["start"])
                    for a, b in zip(run, run[1:]) if b[1] - a[2] > 1]

            def time_at(word, edge):
                """Interpolated time, or the whole gap's bound when the word fell into a gap."""
                for first, last, start, end in gaps:
                    if first <= word <= last:
                        return start if edge == "start" else end
                return interpolate(points, word)

            lo, hi = run[0][1], run[-1][2]
            covered = []
            for i in range(owner[lo], owner[hi] + 1):
                ws, we = first_word[i], first_word[i] + len(ayahs[i].words) - 1
                slack = 1 if len(ayahs[i].words) >= 4 else 0
                if ws >= lo - slack and we <= hi + slack:
                    covered.append([ayahs[i].surah, ayahs[i].ayah,
                                    round(time_at(ws, "start"), 2), round(time_at(we, "end"), 2)])
            if covered:
                result.append({"ayahs": covered, "bounds": (0.0 if r == 0 else bounds[r - 1][1],
                                                            bounds[r + 1][0] if r + 1 < len(runs) else file_end,
                                                            *bounds[r])})
        extend_edges(result, ayahs)
        for run in result:
            run.pop("bounds")
        target.write_text(json.dumps({"id": asr["id"], "title": asr["title"], "runs": result}))
        summary = ", ".join(f"{r['ayahs'][0][0]}:{r['ayahs'][0][1]}-{r['ayahs'][-1][0]}:{r['ayahs'][-1][1]}"
                            for r in result)
        print(f"{asr['id']} {asr['title']}: {summary}", flush=True)


if __name__ == "__main__":
    main(Path(sys.argv[1]))
