"""Pemetaan teks mentah Whisper ke label Calistung.

- Mode **char**: satu karakter a–z / 0–9 (`map_raw_to_calistung_char`).
- Mode **syllable**: satu suku kata CV whitelist (`map_raw_to_calistung_syllable`).
- Mode **word** (API): teks kata/frasa utuh; gunakan ``normalize_transcript_text`` / ``words_tolerantly_match``.
"""

from __future__ import annotations

import re
from difflib import SequenceMatcher, get_close_matches

from config import SETTINGS

# Vocabulary Calistung untuk biasing decoder (huruf + angka)
INITIAL_PROMPT_VOCAB = (
    "a b c d e f g h i j k l m n o p q r s t u v w x y z "
    "0 1 2 3 4 5 6 7 8 9"
)

_PHONETIC_TOKEN_TO_CHAR: dict[str, str] = {
    "ei": "a",
    "ay": "a",
    "ah": "a",
    "ee": "e",
    "eh": "e",
    "e": "e",
    "i": "i",
    "eye": "i",
    "be": "b",
    "bi": "b",
    "ce": "c",
    "ci": "c",
    "si": "c",
    "de": "d",
    "di": "d",
    "ef": "f",
    "eff": "f",
    "ge": "g",
    "ha": "h",
    "hi": "h",
    "aitch": "h",
    "je": "j",
    "jee": "j",
    "jel": "j",
    "ka": "k",
    "kay": "k",
    "el": "l",
    "em": "m",
    "en": "n",
    "o": "o",
    "oh": "o",
    "pe": "p",
    "pi": "p",
    "ku": "q",
    "kyu": "q",
    "cue": "q",
    "ar": "r",
    "er": "r",
    "es": "s",
    "ess": "s",
    "te": "t",
    "ti": "t",
    "tee": "t",
    "yu": "u",
    "you": "u",
    "ve": "v",
    "we": "w",
    "eks": "x",
    "ex": "x",
    "ye": "y",
    "why": "y",
    "zet": "z",
    "za": "z",
    "ze": "z",
    "se": "z",
    "satu": "1",
    "dua": "2",
    "tiga": "3",
    "empat": "4",
    "lima": "5",
    "enam": "6",
    "tujuh": "7",
    "delapan": "8",
    "sembilan": "9",
    "nol": "0",
    "kosong": "0",
}

ALLOWED = frozenset("abcdefghijklmnopqrstuvwxyz0123456789")
_CHAR_LIST = sorted(ALLOWED)

# Suku kata terbuka CV (konsonan + vokal) untuk mode `syllable`
_CONSONANTS = frozenset("bcdfghjklmnpqrstvwxyz")
_VOWELS = frozenset("aeiou")
_CV_SYLLABLES: frozenset[str] = frozenset(
    f"{c}{v}" for c in sorted(_CONSONANTS) for v in sorted(_VOWELS)
)
_SYLLABLE_LIST_SORTED: list[str] = sorted(_CV_SYLLABLES)
# Prompt decoder: daftar singkat + contoh (batasi panjang agar aman untuk Whisper)
_INITIAL_SYLLABLE_SNIPPET = " ".join(_SYLLABLE_LIST_SORTED[:60])
INITIAL_PROMPT_SYLLABLE = (
    f"{INITIAL_PROMPT_VOCAB} {_INITIAL_SYLLABLE_SNIPPET} "
    "ba be bi bo bu ca ce ci co cu da de di do du "
)

# Toleransi suku kata CV: keselarasan bunyi serupa (anak / Whisper)
_SYLLABLE_ONSET_EQUIV: tuple[frozenset[str], ...] = (
    frozenset("bp"),
    frozenset("dt"),
    frozenset("gk"),
    frozenset("jc"),
)
_SYLLABLE_RIME_EQUIV: tuple[frozenset[str], ...] = (frozenset("uo"),)


def _same_phone_class(a: str, b: str, groups: tuple[frozenset[str], ...]) -> bool:
    if a == b:
        return True
    for g in groups:
        if a in g and b in g:
            return True
    return False


def syllables_tolerantly_match(expected: str, got: str) -> bool:
    """
    True jika ``got`` dianggap cukup dekat dengan ``expected`` untuk soal suku kata.
    Contoh: ``bu`` vs ``po`` (b~p dan u~o). Hanya untuk pasangan CV dalam whitelist.
    """
    e = expected.strip().lower()
    g = got.strip().lower()
    if not e or not g:
        return False
    if e == g:
        return True
    if len(e) != 2 or len(g) != 2:
        return False
    if e not in _CV_SYLLABLES or g not in _CV_SYLLABLES:
        return False
    return _same_phone_class(e[0], g[0], _SYLLABLE_ONSET_EQUIV) and _same_phone_class(
        e[1], g[1], _SYLLABLE_RIME_EQUIV
    )


def chars_tolerantly_match(expected: str, got: str) -> bool:
    """Satu huruf: kelas konsonan/vokal ringan; angka hanya exact match."""
    e = expected.strip().lower()
    g = got.strip().lower()
    if not e or not g:
        return False
    if e == g:
        return True
    if len(e) != 1 or len(g) != 1:
        return False
    if e.isdigit() or g.isdigit():
        return False
    if e not in ALLOWED or g not in ALLOWED:
        return False
    if _same_phone_class(e, g, _SYLLABLE_ONSET_EQUIV):
        return True
    return _same_phone_class(e, g, _SYLLABLE_RIME_EQUIV)


def normalize_transcript_text(s: str) -> str:
    """Normalisasi teks transkrip untuk output mode ``word`` dan perbandingan."""
    if not s or not str(s).strip():
        return ""
    norm = s.lower().strip()
    norm = re.sub(r"[\s\.,!?;:\"'`]+", " ", norm).strip()
    return " ".join(norm.split())


def words_tolerantly_match(
    expected: str, got: str, *, ratio_threshold: float | None = None
) -> bool:
    """
    Bandingkan frasa/kata jawaban dengan hipotesis STT memakai ``SequenceMatcher``.
    Threshold default dari env ``WORD_MATCH_TOLERANT_RATIO``.
    """
    thr = (
        ratio_threshold
        if ratio_threshold is not None
        else SETTINGS.word_match_tolerant_ratio
    )
    e = normalize_transcript_text(expected)
    g = normalize_transcript_text(got)
    if not e or not g:
        return False
    if e == g:
        return True
    return SequenceMatcher(None, e, g).ratio() >= thr


def _first_whitelisted_cv_in_string(s: str, syllables: frozenset[str]) -> str:
    """Ambil pasangan huruf pertama dalam s yang ada di whitelist CV."""
    s = re.sub(r"[^a-z]", "", s.lower())
    for i in range(max(0, len(s) - 1)):
        pair = s[i : i + 2]
        if pair in syllables:
            return pair
    return ""


def map_raw_to_calistung_syllable(raw_text: str) -> str:
    """
    Map teks mentah Whisper ke satu suku kata CV (whitelist) atau string kosong.
    Tidak memetakan angka/huruf tunggal — gunakan mode ``char`` untuk itu.
    """
    norm = raw_text.lower().strip()
    norm = re.sub(r"[\s\.,!?;:\"'`]+", " ", norm).strip()
    if not norm:
        return ""

    tokens = norm.split()
    no_space = re.sub(r"[^a-z]", "", norm)

    if len(no_space) == 2 and no_space in _CV_SYLLABLES:
        return no_space

    if norm in _CV_SYLLABLES:
        return norm

    for tok in tokens:
        if len(tok) == 2 and tok in _CV_SYLLABLES:
            return tok
        if tok in _CV_SYLLABLES:
            return tok

    if len(tokens) == 2 and len(tokens[0]) == 1 and len(tokens[1]) == 1:
        joined = tokens[0] + tokens[1]
        if joined in _CV_SYLLABLES:
            return joined

    if len(tokens) == 1 and len(tokens[0]) == 2 and tokens[0] in _CV_SYLLABLES:
        return tokens[0]

    first = _first_whitelisted_cv_in_string(no_space, _CV_SYLLABLES)
    if first:
        return first

    if no_space:
        matches = get_close_matches(
            no_space,
            _SYLLABLE_LIST_SORTED,
            n=1,
            cutoff=0.76,
        )
        if matches:
            return matches[0]

    cfg = SETTINGS
    max_raw = cfg.mapper_fuzzy_syllable_max_raw_len
    syl_cut = cfg.mapper_fuzzy_syllable_cutoff
    if no_space and len(no_space) <= max_raw:
        best_s: str | None = None
        best_r = 0.0
        for syl in _SYLLABLE_LIST_SORTED:
            r = SequenceMatcher(None, no_space, syl).ratio()
            if r > best_r:
                best_r = r
                best_s = syl
        if best_s is not None and best_r >= syl_cut:
            return best_s

    return ""


def map_raw_to_calistung_char(raw_text: str) -> str:
    """
    Map teks mentah Whisper ke satu karakter Calistung (a-z, 0-9).
    """
    norm = raw_text.lower().strip()
    norm = re.sub(r"[\s\.,!?;:\"'`]+", " ", norm).strip()
    if not norm:
        return ""

    if norm in _PHONETIC_TOKEN_TO_CHAR:
        return _PHONETIC_TOKEN_TO_CHAR[norm]

    if len(norm) == 1 and norm in ALLOWED:
        return norm

    no_space = re.sub(r"[^a-z0-9]", "", norm)
    if no_space in _PHONETIC_TOKEN_TO_CHAR:
        return _PHONETIC_TOKEN_TO_CHAR[no_space]

    for tok in norm.split():
        if tok in _PHONETIC_TOKEN_TO_CHAR:
            return _PHONETIC_TOKEN_TO_CHAR[tok]
        if len(tok) == 1 and tok in ALLOWED:
            return tok

    if no_space:
        keys = sorted(_PHONETIC_TOKEN_TO_CHAR.keys(), key=len, reverse=True)
        matches = get_close_matches(no_space, keys, n=1, cutoff=0.72)
        if matches:
            return _PHONETIC_TOKEN_TO_CHAR[matches[0]]

    cfg = SETTINGS
    max_raw = cfg.mapper_fuzzy_char_max_raw_len
    char_cut = cfg.mapper_fuzzy_char_cutoff
    if no_space and len(no_space) <= max_raw:
        best_c: str | None = None
        best_r = 0.0
        for c in _CHAR_LIST:
            r = SequenceMatcher(None, no_space, c).ratio()
            if r > best_r:
                best_r = r
                best_c = c
        if best_c is not None and best_r >= char_cut:
            return best_c

    return ""
