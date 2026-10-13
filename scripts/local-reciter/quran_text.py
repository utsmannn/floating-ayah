"""Quran text helpers shared by the local reciter pipeline.

Words are tokenized exactly like the app (TimedAyah.wordRanges and Quran.openingParts), so the
word indices in exported timings line up with what the panel highlights.
"""
import json
import re
from dataclasses import dataclass
from pathlib import Path

QURAN_JSON = Path(__file__).resolve().parents[2] / "Sources/FloatingAyah/Resources/quran.json"
BASMALAH = ["بسم", "الله", "الرحمن", "الرحيم"]
DIACRITICS = re.compile("[ً-ٰٟۖ-ۭـ﻿]")


@dataclass
class Ayah:
    surah: int
    ayah: int
    words: list[str]  # Display words, basmalah prefix removed, waqf-only tokens dropped.


def _has_letter(token: str) -> bool:
    import unicodedata
    return any(unicodedata.category(ch) in ("Lu", "Ll", "Lt", "Lm", "Lo") for ch in token)


def tokens(text: str) -> list[str]:
    return [t for t in text.split() if _has_letter(t)]


def _plain(token: str) -> str:
    letters = "".join(ch for ch in token if ch.isalpha() and not DIACRITICS.match(ch))
    return letters.replace("ٱ", "ا")


def load_ayahs() -> list[Ayah]:
    surahs = json.loads(QURAN_JSON.read_text())
    result = []
    for surah in surahs:
        for ayah in surah["ayahs"]:
            words = tokens(ayah["text"].replace("﻿", ""))
            opening = (ayah["number"] == 1 and surah["number"] not in (1, 9) and len(words) > 4
                       and [_plain(w) for w in words[:4]] == BASMALAH)
            result.append(Ayah(surah["number"], ayah["number"], words[4:] if opening else words))
    return result


def match_key(word: str) -> str:
    """Consonant skeleton. Uthmani and modern spellings differ mostly in long vowels and hamza
    seats (أَدْرَىٰكَ / أدراك, ٱلصَّلَوٰةَ / الصلاة), and ASR often adds or drops a leading wa."""
    w = DIACRITICS.sub("", word).replace("ة", "ه")
    return "".join(ch for ch in w if "ء" <= ch <= "ي" and ch not in "اويىءأإآؤئٱ")


CONSONANTS = {
    "ب": "b", "ت": "t", "ث": "th", "ج": "j", "ح": "h", "خ": "kh", "د": "d", "ذ": "dh", "ر": "r",
    "ز": "z", "س": "s", "ش": "sh", "ص": "s", "ض": "d", "ط": "t", "ظ": "z", "ع": "'", "غ": "gh",
    "ف": "f", "ق": "q", "ك": "k", "ل": "l", "م": "m", "ن": "n", "ه": "h", "و": "w", "ي": "y",
    "ء": "'", "أ": "'", "إ": "'", "ؤ": "'", "ئ": "'", "ة": "t", "ى": "a", "ا": "a", "آ": "'a",
}
VOWELS = {"َ": "a", "ِ": "i", "ُ": "u", "ً": "an", "ٍ": "in", "ٌ": "un",
          "ٰ": "a", "ۥ": "u", "ۦ": "i"}


LETTER_NAMES = {"ا": "alif", "ل": "laam", "م": "miim", "ص": "saad", "ر": "raa", "ك": "kaaf", "ه": "haa",
                "ي": "yaa", "ع": "'ayn", "ط": "taa", "س": "siin", "ح": "haa", "ق": "qaaf", "ن": "nuun"}


def romanize(word: str) -> str:
    """Rough vowelled romanization in the MMS aligner's alphabet (a-z and ')."""
    letters = [ch for ch in word if not DIACRITICS.match(ch)]
    # Disjoined letters (الٓمٓ, كٓهيعٓصٓ) carry a maddah and are recited by their names.
    if "ٓ" in word and letters and all(ch in LETTER_NAMES for ch in letters):
        return "".join(LETTER_NAMES[ch] for ch in letters)
    out = ""
    last = ""
    for ch in word:
        if ch == "ّ":  # Shadda doubles the consonant before it.
            out += last
        elif ch in VOWELS:
            out += VOWELS[ch]
        elif ch in CONSONANTS:
            last = CONSONANTS[ch]
            out += last
        # Wasla, sukun, maddah and Quranic pause marks are not pronounced on their own.
    out = re.sub(r"[^a-z']", "", out)
    return out or "a"
