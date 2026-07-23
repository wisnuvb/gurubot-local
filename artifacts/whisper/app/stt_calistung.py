from __future__ import annotations

import logging
import math
import os
import re
import tempfile
import threading
from dataclasses import dataclass

from pydub import AudioSegment
from pydub.silence import detect_nonsilent
from faster_whisper import WhisperModel

from calistung_mapper import (
    INITIAL_PROMPT_SYLLABLE,
    INITIAL_PROMPT_VOCAB,
    map_raw_to_calistung_char,
    map_raw_to_calistung_syllable,
    normalize_transcript_text,
)
from config import SETTINGS, load_settings

logger = logging.getLogger(__name__)

_model: WhisperModel | None = None
_load_lock = threading.Lock()


def _load_model() -> WhisperModel:
    s = load_settings()
    logger.info("Memuat model Whisper: %s", s.whisper_model)
    return WhisperModel(
        s.whisper_model,
        device="cpu",
        compute_type=s.compute_type,
        cpu_threads=s.cpu_threads,
    )


def ensure_model_loaded() -> WhisperModel:
    global _model
    if _model is not None:
        return _model
    with _load_lock:
        if _model is not None:
            return _model
        _model = _load_model()
    return _model


def is_model_ready() -> bool:
    return _model is not None


def _apply_target_dbfs(
    audio: AudioSegment,
    target_dbfs: float,
    min_input_dbfs: float,
) -> AudioSegment:
    """Gain agar peak loudness mendekati target_dBFS (bukan peak-normalize penuh)."""
    if target_dbfs <= -100:
        return audio
    chunk_db = audio.dBFS
    if chunk_db == float("-inf") or chunk_db < min_input_dbfs:
        return audio
    return audio.apply_gain(target_dbfs - chunk_db)


def _strip_silence_edges(
    audio: AudioSegment,
    *,
    min_silence_len: int,
    silence_thresh: float,
    keep_silence: int,
) -> AudioSegment:
    """Kupas diam di awal/akhir; pydub stdlib tidak mengekspor `strip_silence`."""
    ranges = detect_nonsilent(
        audio,
        min_silence_len=min_silence_len,
        silence_thresh=silence_thresh,
        seek_step=1,
    )
    if not ranges:
        return audio
    start = max(0, int(ranges[0][0]) - keep_silence)
    end = min(len(audio), int(ranges[-1][1]) + keep_silence)
    return audio[start:end]


# Prompt ringan jika mode word tanpa expected (decoder bahasa Indonesia singkat).
_INITIAL_PROMPT_WORD_FALLBACK = (
    f"{INITIAL_PROMPT_VOCAB} percakapan singkat bahasa indonesia"
)


def normalize_audio(audio_path: str) -> tuple[str, dict[str, float]]:
    """
    Preprocessing audio khusus suara anak SD.
    Mengembalikan ``(path_wav_normal, stats)`` — stats memuat dBFS & durasi untuk log.
    """
    s = SETTINGS
    stats: dict[str, float] = {}
    try:
        audio = AudioSegment.from_file(audio_path)
        stats["duration_ms_input"] = float(len(audio))
        indb = audio.dBFS
        stats["input_dbfs"] = -100.0 if indb == float("-inf") else round(float(indb), 2)

        audio = audio.set_channels(1)
        audio = audio.set_frame_rate(16000)
        audio = audio.high_pass_filter(80)
        audio = audio.low_pass_filter(8000)
        audio = _apply_target_dbfs(
            audio,
            s.normalize_target_dbfs,
            s.normalize_min_input_dbfs,
        )
        chunk_db = audio.dBFS
        if (
            chunk_db != float("-inf")
            and chunk_db < s.quiet_input_dbfs_threshold
            and s.quiet_extra_gain_db > 0.0
        ):
            audio = audio.apply_gain(s.quiet_extra_gain_db)
        if s.strip_silence and len(audio) > 0:
            trimmed = _strip_silence_edges(
                audio,
                min_silence_len=s.strip_silence_min_len_ms,
                silence_thresh=float(s.strip_silence_thresh_dbfs),
                keep_silence=s.strip_silence_keep_ms,
            )
            if len(trimmed) > 0:
                audio = trimmed

        outdb = audio.dBFS
        stats["output_dbfs"] = -100.0 if outdb == float("-inf") else round(float(outdb), 2)
        stats["duration_ms_output"] = float(len(audio))

        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp:
            normalized_path = tmp.name
            audio.export(normalized_path, format="wav")
        return normalized_path, stats
    except Exception:
        logger.exception("Gagal normalisasi audio")
        return audio_path, {}


def _confidence_from_avg_logprob(avg_logprob: float) -> float:
    """Skor sederhana dari avg_logprob segment (bukan probabilitas kalibrasi)."""
    try:
        return min(1.0, max(0.0, math.exp(avg_logprob)))
    except OverflowError:
        return 0.0


def _pick_best_calistung_segment(
    segment_list: list,
) -> object | None:
    """
    Satu segment Calistung: yang avg_logprob tertinggi dan teks tidak kosong.
    Jika tidak ada teks, None.
    """
    nonempty = [seg for seg in segment_list if seg.text and seg.text.strip()]
    if not nonempty:
        return None
    return max(nonempty, key=lambda seg: seg.avg_logprob)


def _merge_whisper_segments(segment_list: list) -> tuple[str, float, float]:
    """
    Gabungkan teks semua segmen berurutan (mode ``word``).
    Mengembalikan ``(teks_gabungan_lower, mean_avg_logprob, max_no_speech_prob)``.
    """
    nonempty = [seg for seg in segment_list if seg.text and seg.text.strip()]
    if not nonempty:
        return "", float("-inf"), 1.0
    parts: list[str] = []
    total_lp = 0.0
    max_nsp = 0.0
    for seg in nonempty:
        parts.append(" ".join(seg.text.strip().split()))
        total_lp += seg.avg_logprob
        max_nsp = max(max_nsp, seg.no_speech_prob)
    merged = normalize_transcript_text(" ".join(parts))
    mean_lp = total_lp / len(nonempty)
    return merged, mean_lp, max_nsp


def clean_repetition_loops(text: str) -> str:
    """
    Menghilangkan loop pengulangan (halusinasi) pada level kata atau karakter.
    Hanya menghilangkan jika pola diulang 3 kali atau lebih (untuk menjaga kata ulang sah seperti 'kupu-kupu' atau 'anak-anak' yang hanya diulang 2 kali).
    """
    if not text:
        return ""
    prev = ""
    # Loop untuk menangani pengulangan bersarang (nested)
    while prev != text:
        prev = text
        # 1. Pengulangan 1 kata: 3x atau lebih (misal 'ding ding ding' -> 'ding')
        text = re.sub(r"\b(\w+)( \1){2,}\b", r"\1", text, flags=re.IGNORECASE)
        # 2. Pengulangan 2 kata: 3x atau lebih (misal 'da de da de da de' -> 'da de')
        text = re.sub(r"\b(\w+ \w+)( \1){2,}\b", r"\1", text, flags=re.IGNORECASE)
        # 3. Pengulangan 3 kata: 3x atau lebih (misal 'd u d d u d d u d' -> 'd u d')
        text = re.sub(r"\b(\w+ \w+ \w+)( \1){2,}\b", r"\1", text, flags=re.IGNORECASE)
        # 4. Pengulangan karakter/suku kata di dalam kata (panjang unit 2-10): 3x atau lebih (misal 'ueueue' -> 'ue')
        text = re.sub(r"(\w{2,10}?)\1{2,}", r"\1", text, flags=re.IGNORECASE)
    return text


@dataclass
class TranscribeResult:
    text: str
    raw_text: str
    confidence: float
    language_probability: float | None
    max_no_speech_prob: float
    internal_status: str  # success | low_confidence | no_speech | transcribe_error
    normalize_stats: dict[str, float] | None = None

    @property
    def language_prob(self) -> float | None:
        return self.language_probability


def resolve_api_status(result: TranscribeResult) -> str:
    """Status untuk response API (gabungkan aturan no_char -> low_confidence)."""
    st = result.internal_status
    if st == "transcribe_error":
        return "transcribe_error"
    if st == "success" and not result.text:
        return "low_confidence"
    return st


def get_audio_duration_seconds(path: str) -> float:
    """Durasi file audio dalam detik (untuk validasi API)."""
    audio = AudioSegment.from_file(path)
    return len(audio) / 1000.0


def _truncate_prompt(text: str, max_len: int) -> str:
    t = text.strip()
    if len(t) <= max_len:
        return t
    return t[:max_len]


def transcribe_letter(
    audio_path: str,
    *,
    mode: str | None = None,
    expected_prompt: str | None = None,
) -> TranscribeResult:
    """
    Transkripsi: Calistung (char/syllable) atau teks ucapan ``word`` (kata/frasa).

    ``mode``: ``char`` | ``syllable`` | ``word``. Default dari ``CALISTUNG_MODE``.
    ``expected_prompt``: untuk ``word``, dipakai sebagai ``initial_prompt`` Whisper (bias jawaban).
    """
    whisper = ensure_model_loaded()
    s = SETTINGS
    m = (mode if mode is not None else s.calistung_mode).strip().lower()
    if m not in ("char", "syllable", "word"):
        m = "char"

    if m == "word":
        ep = (expected_prompt or "").strip()
        if ep:
            initial_prompt = _truncate_prompt(ep, s.word_max_expected_chars)
        else:
            initial_prompt = _INITIAL_PROMPT_WORD_FALLBACK
    elif m == "syllable":
        initial_prompt = INITIAL_PROMPT_SYLLABLE
    else:
        initial_prompt = INITIAL_PROMPT_VOCAB

    normalized_path: str | None = None
    norm_stats: dict[str, float] | None = None
    try:
        normalized_path, norm_stats = normalize_audio(audio_path)

        gen, info = whisper.transcribe(
            normalized_path,
            language="id",
            beam_size=s.beam_size,
            best_of=s.best_of,
            patience=0.5,
            vad_filter=True,
            vad_parameters=dict(
                min_silence_duration_ms=s.vad_min_silence_duration_ms,
                threshold=s.vad_threshold,
            ),
            temperature=0.0,
            word_timestamps=False,
            condition_on_previous_text=False,
            initial_prompt=initial_prompt,
        )

        segment_list = list(gen)
        lang_prob = getattr(info, "language_probability", None)

        if m == "word":
            raw_collapsed, avg_logprob, max_nsp = _merge_whisper_segments(segment_list)
            raw_collapsed = clean_repetition_loops(raw_collapsed)
            mapped = raw_collapsed
            if avg_logprob == float("-inf"):
                conf = 0.0
            else:
                conf = _confidence_from_avg_logprob(avg_logprob)
        else:
            best_seg = _pick_best_calistung_segment(segment_list)
            if best_seg is not None:
                raw_text = best_seg.text.strip().lower()
                raw_collapsed = " ".join(raw_text.split())
                raw_collapsed = clean_repetition_loops(raw_collapsed)
                avg_logprob = best_seg.avg_logprob
                max_nsp = best_seg.no_speech_prob
                conf = _confidence_from_avg_logprob(avg_logprob)
            else:
                raw_collapsed = ""
                max_nsp = 1.0
                conf = 0.0

            mapped = (
                map_raw_to_calistung_syllable(raw_collapsed)
                if m == "syllable"
                else map_raw_to_calistung_char(raw_collapsed)
            )

        if not segment_list or not raw_collapsed:
            internal = "no_speech"
        elif max_nsp >= s.no_speech_prob_threshold:
            internal = "no_speech"
        elif conf < s.confidence_threshold:
            internal = "low_confidence"
        else:
            internal = "success"

        if norm_stats:
            logger.info(
                "normalize_audio in_dbfs=%s out_dbfs=%s dur_in_ms=%s dur_out_ms=%s",
                norm_stats.get("input_dbfs"),
                norm_stats.get("output_dbfs"),
                norm_stats.get("duration_ms_input"),
                norm_stats.get("duration_ms_output"),
            )

        return TranscribeResult(
            text=mapped,
            raw_text=raw_collapsed,
            confidence=round(conf, 4),
            language_probability=round(lang_prob, 4) if lang_prob is not None else None,
            max_no_speech_prob=round(max_nsp, 4),
            internal_status=internal,
            normalize_stats=norm_stats,
        )

    except Exception:
        logger.exception("Gagal transcribe")
        return TranscribeResult(
            text="",
            raw_text="",
            confidence=0.0,
            language_probability=None,
            max_no_speech_prob=1.0,
            internal_status="transcribe_error",
            normalize_stats=norm_stats,
        )
    finally:
        if (
            normalized_path
            and normalized_path != audio_path
            and os.path.exists(normalized_path)
        ):
            try:
                os.remove(normalized_path)
            except OSError:
                logger.warning("Tidak bisa hapus file normalisasi: %s", normalized_path)


if __name__ == "__main__":
    ensure_model_loaded()
    test_file = input("Masukkan path audio test: ").strip()
    if os.path.exists(test_file):
        r = transcribe_letter(test_file)
        print(f"\nHasil: '{r.text}' (raw: '{r.raw_text}')")
        print(f"Confidence: {r.confidence} status={r.internal_status}")
    else:
        print("File tidak ditemukan!")
