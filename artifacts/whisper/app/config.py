"""Konfigurasi service dari environment (tanpa rebuild image)."""

from __future__ import annotations

import os
from dataclasses import dataclass

# Preset deploy A/B: `WHISPER_MODEL` eksplisit mengalahkan preset ini.
# Catatan: Cahya belum merilis `cahya/faster-whisper-small-id` (hanya medium-id).
# Preset `small` memakai Systran/faster-whisper-small — lebih cepat, bukan fine-tune ID.
WHISPER_PRESETS: dict[str, str] = {
    "small": "Systran/faster-whisper-small",
    "medium": "cahya/faster-whisper-medium-id",
}

_DEFAULT_FALLBACK_MODEL = "Systran/faster-whisper-small"


def resolve_whisper_model_from_env() -> tuple[str, str | None]:
    """
    Urutan: WHISPER_MODEL (path penuh) → WHISPER_MODEL_PRESET (small|medium) → default CI ringan.
    Mengembalikan (model_id_huggingface, nama_preset atau None jika override / default fallback).
    """
    explicit = os.environ.get("WHISPER_MODEL", "").strip()
    if explicit:
        return explicit, None
    preset_key = os.environ.get("WHISPER_MODEL_PRESET", "").strip().lower()
    if preset_key in WHISPER_PRESETS:
        return WHISPER_PRESETS[preset_key], preset_key
    return _DEFAULT_FALLBACK_MODEL, None


def _float(name: str, default: str) -> float:
    return float(os.environ.get(name, default))


def _int(name: str, default: str) -> int:
    return int(os.environ.get(name, default))


def _bool(name: str, default: str) -> bool:
    v = os.environ.get(name, default).strip().lower()
    return v in ("1", "true", "yes", "on")


def _calistung_mode_raw(default: str = "char") -> str:
    v = os.environ.get("CALISTUNG_MODE", default).strip().lower()
    return v if v in ("char", "syllable", "word") else "char"


@dataclass(frozen=True)
class Settings:
    whisper_model: str
    whisper_model_preset: str | None
    compute_type: str
    cpu_threads: int
    confidence_threshold: float
    no_speech_prob_threshold: float
    max_audio_seconds: float
    max_upload_bytes: int
    beam_size: int
    best_of: int
    allowed_extensions: frozenset[str]
    vad_threshold: float
    vad_min_silence_duration_ms: int
    normalize_target_dbfs: float
    normalize_min_input_dbfs: float
    strip_silence: bool
    strip_silence_thresh_dbfs: int
    strip_silence_min_len_ms: int
    strip_silence_keep_ms: int
    mapper_fuzzy_char_max_raw_len: int
    mapper_fuzzy_char_cutoff: float
    calistung_mode: str
    mapper_fuzzy_syllable_max_raw_len: int
    mapper_fuzzy_syllable_cutoff: float
    # Mode `word`: panjang maks teks expected untuk prompt & matching
    word_max_expected_chars: int
    # SequenceMatcher.ratio() minimal untuk match_tolerant (frasa/kata)
    word_match_tolerant_ratio: float
    # Input sangat pelan: tambah gain setelah normalisasi RMS
    quiet_input_dbfs_threshold: float
    quiet_extra_gain_db: float


def load_settings() -> Settings:
    exts = os.environ.get(
        "ALLOWED_AUDIO_EXTENSIONS",
        ".wav,.mp3,.m4a,.webm,.ogg,.flac",
    )
    allowed = frozenset(
        "." + e.strip().lstrip(".").lower() for e in exts.split(",") if e.strip()
    )
    _model, _preset = resolve_whisper_model_from_env()
    return Settings(
        whisper_model=_model,
        whisper_model_preset=_preset,
        compute_type=os.environ.get("WHISPER_COMPUTE_TYPE", "int8"),
        cpu_threads=_int("WHISPER_CPU_THREADS", "0"),
        confidence_threshold=_float("CONFIDENCE_THRESHOLD", "0.35"),
        no_speech_prob_threshold=_float("NO_SPEECH_PROB_THRESHOLD", "0.6"),
        max_audio_seconds=_float("MAX_AUDIO_SECONDS", "12.0"),
        max_upload_bytes=_int("MAX_UPLOAD_BYTES", str(5 * 1024 * 1024)),
        beam_size=_int("WHISPER_BEAM_SIZE", "5"),
        best_of=_int("WHISPER_BEST_OF", "3"),
        allowed_extensions=allowed,
        vad_threshold=_float("VAD_THRESHOLD", "0.45"),
        vad_min_silence_duration_ms=_int("VAD_MIN_SILENCE_MS", "200"),
        normalize_target_dbfs=_float("NORMALIZE_TARGET_DBFS", "-20"),
        normalize_min_input_dbfs=_float("NORMALIZE_MIN_INPUT_DBFS", "-55"),
        strip_silence=_bool("STRIP_SILENCE", "1"),
        strip_silence_thresh_dbfs=_int("STRIP_SILENCE_THRESH_DBFS", "-45"),
        strip_silence_min_len_ms=_int("STRIP_SILENCE_MIN_LEN_MS", "120"),
        strip_silence_keep_ms=_int("STRIP_SILENCE_KEEP_MS", "80"),
        mapper_fuzzy_char_max_raw_len=_int("MAPPER_FUZZY_CHAR_MAX_RAW_LEN", "6"),
        mapper_fuzzy_char_cutoff=_float("MAPPER_FUZZY_CHAR_CUTOFF", "0.6"),
        calistung_mode=_calistung_mode_raw("char"),
        mapper_fuzzy_syllable_max_raw_len=_int("MAPPER_FUZZY_SYLLABLE_MAX_RAW_LEN", "8"),
        mapper_fuzzy_syllable_cutoff=_float("MAPPER_FUZZY_SYLLABLE_CUTOFF", "0.68"),
        word_max_expected_chars=_int("WORD_MAX_EXPECTED_CHARS", "80"),
        word_match_tolerant_ratio=_float("WORD_MATCH_TOLERANT_RATIO", "0.82"),
        quiet_input_dbfs_threshold=_float("QUIET_INPUT_DBFS_THRESHOLD", "-40"),
        quiet_extra_gain_db=_float("QUIET_EXTRA_GAIN_DB", "4"),
    )


SETTINGS = load_settings()
