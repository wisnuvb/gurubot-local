from __future__ import annotations

import logging
import os
import threading
import time
import uuid
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydub.exceptions import CouldntDecodeError

from calistung_mapper import (
    chars_tolerantly_match,
    normalize_transcript_text,
    syllables_tolerantly_match,
    words_tolerantly_match,
)
from config import SETTINGS, load_settings
from stt_calistung import (
    ensure_model_loaded,
    get_audio_duration_seconds,
    is_model_ready,
    resolve_api_status,
    transcribe_letter,
)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Muat model di thread terpisah agar uvicorn langsung listen (/health tidak menunggu unduhan besar)."""

    def _load_in_background() -> None:
        try:
            ensure_model_loaded()
        except Exception:
            logger.exception(
                "Gagal memuat model di background — cek log, jaringan Hugging Face, "
                "WHISPER_MODEL, atau WHISPER_MODEL_PRESET"
            )

    threading.Thread(
        target=_load_in_background,
        daemon=True,
        name="whisper-model-load",
    ).start()
    yield


app = FastAPI(title="Gurubot Calistung STT", lifespan=lifespan)

_cors = os.environ.get("CORS_ORIGINS", "").strip()
if _cors:
    if _cors == "*":
        app.add_middleware(
            CORSMiddleware,
            allow_origins=["*"],
            allow_credentials=False,
            allow_methods=["*"],
            allow_headers=["*"],
        )
    else:
        app.add_middleware(
            CORSMiddleware,
            allow_origins=[o.strip() for o in _cors.split(",") if o.strip()],
            allow_credentials=True,
            allow_methods=["*"],
            allow_headers=["*"],
        )


@app.get("/health")
async def health():
    return {"status": "ok"}


@app.get("/ready")
async def ready():
    if is_model_ready():
        s = load_settings()
        return {
            "ready": True,
            "preset": s.whisper_model_preset,
            "model": s.whisper_model,
            "default_mode": SETTINGS.calistung_mode,
        }
    raise HTTPException(status_code=503, detail="Model belum siap")


@app.post("/transcribe/")
async def transcribe(
    file: UploadFile = File(...),
    mode: str | None = Form(None),
    expected: str | None = Form(None),
):
    settings = SETTINGS
    request_id = str(uuid.uuid4())
    t0 = time.perf_counter()

    eff_mode = (mode or settings.calistung_mode or "char").strip().lower()
    if eff_mode not in ("char", "syllable", "word"):
        logger.info(
            "request_id=%s latency_ms=0 status=invalid_audio reason=bad_mode",
            request_id,
        )
        return {
            "text": "",
            "raw_text": "",
            "confidence": 0.0,
            "language_probability": None,
            "max_no_speech_prob": None,
            "status": "invalid_audio",
            "mode": eff_mode,
            "request_id": request_id,
            "detail": 'mode harus "char", "syllable", atau "word" (Form field opsional)',
        }

    exp_raw = (expected or "").strip()
    exp_norm_word: str | None = None
    if exp_raw and eff_mode == "word":
        exp_norm_word = normalize_transcript_text(exp_raw)
        if len(exp_norm_word) > settings.word_max_expected_chars:
            logger.info(
                "request_id=%s latency_ms=0 status=invalid_audio reason=expected_too_long",
                request_id,
            )
            return {
                "text": "",
                "raw_text": "",
                "confidence": 0.0,
                "language_probability": None,
                "max_no_speech_prob": None,
                "status": "invalid_audio",
                "mode": eff_mode,
                "request_id": request_id,
                "detail": (
                    f"expected terlalu panjang (maks {settings.word_max_expected_chars} karakter "
                    "setelah normalisasi)"
                ),
            }
    elif exp_raw:
        exp_norm_legacy = exp_raw.lower()
    else:
        exp_norm_legacy = ""

    suffix = ""
    if file.filename:
        suffix = Path(file.filename).suffix.lower()
    if suffix and suffix not in settings.allowed_extensions:
        logger.info(
            "request_id=%s latency_ms=0 status=invalid_audio reason=bad_extension",
            request_id,
        )
        return {
            "text": "",
            "raw_text": "",
            "confidence": 0.0,
            "language_probability": None,
            "max_no_speech_prob": None,
            "status": "invalid_audio",
            "mode": eff_mode,
            "request_id": request_id,
            "detail": f"Ekstensi tidak diizinkan: {suffix}",
        }

    body = await file.read()
    if len(body) > settings.max_upload_bytes:
        logger.info(
            "request_id=%s latency_ms=0 status=invalid_audio reason=too_large",
            request_id,
        )
        return {
            "text": "",
            "raw_text": "",
            "confidence": 0.0,
            "language_probability": None,
            "max_no_speech_prob": None,
            "status": "invalid_audio",
            "mode": eff_mode,
            "request_id": request_id,
            "detail": "Ukuran file melebihi batas",
        }

    ext = suffix if suffix else ".wav"
    temp_dir = os.environ.get("TEMP", os.environ.get("TMP", "/tmp"))
    temp_path = os.path.join(temp_dir, f"gurubot_{request_id}{ext}")

    try:
        with open(temp_path, "wb") as buffer:
            buffer.write(body)

        try:
            duration = get_audio_duration_seconds(temp_path)
        except (CouldntDecodeError, OSError, ValueError):
            logger.info(
                "request_id=%s latency_ms=%.1f status=invalid_audio reason=decode",
                request_id,
                (time.perf_counter() - t0) * 1000,
            )
            return {
                "text": "",
                "raw_text": "",
                "confidence": 0.0,
                "language_probability": None,
                "max_no_speech_prob": None,
                "status": "invalid_audio",
                "mode": eff_mode,
                "request_id": request_id,
                "detail": "Audio tidak bisa dibaca (format rusak atau tidak didukung)",
            }

        if duration > settings.max_audio_seconds:
            logger.info(
                "request_id=%s latency_ms=%.1f status=invalid_audio reason=duration",
                request_id,
                (time.perf_counter() - t0) * 1000,
            )
            return {
                "text": "",
                "raw_text": "",
                "confidence": 0.0,
                "language_probability": None,
                "max_no_speech_prob": None,
                "status": "invalid_audio",
                "mode": eff_mode,
                "request_id": request_id,
                "detail": f"Durasi {duration:.2f}s melebihi {settings.max_audio_seconds}s",
            }

        expected_prompt = exp_norm_word if eff_mode == "word" else None
        result = transcribe_letter(
            temp_path,
            mode=eff_mode,
            expected_prompt=expected_prompt,
        )
        api_status = resolve_api_status(result)
        elapsed_ms = (time.perf_counter() - t0) * 1000

        match_exact: bool | None = None
        match_tolerant: bool | None = None
        accepted: bool | None = None
        if eff_mode == "word":
            exp_for_match = exp_norm_word or ""
        else:
            exp_for_match = exp_norm_legacy if exp_raw else ""

        if exp_for_match:
            if result.text:
                if eff_mode == "word":
                    pred = normalize_transcript_text(result.text)
                    match_exact = pred == exp_for_match
                    match_tolerant = (not match_exact) and words_tolerantly_match(
                        exp_for_match, result.text
                    )
                elif eff_mode == "syllable":
                    match_exact = result.text == exp_for_match
                    match_tolerant = (not match_exact) and syllables_tolerantly_match(
                        exp_for_match, result.text
                    )
                else:
                    match_exact = result.text == exp_for_match
                    match_tolerant = (not match_exact) and chars_tolerantly_match(
                        exp_for_match, result.text
                    )
                accepted = bool(match_exact or match_tolerant)
            else:
                match_exact = False
                match_tolerant = False
                accepted = False

        audio_bits = ""
        if result.normalize_stats:
            ns = result.normalize_stats
            audio_bits = (
                f" audio_in_dbfs={ns.get('input_dbfs')} audio_out_dbfs={ns.get('output_dbfs')}"
            )

        logger.info(
            "request_id=%s mode=%s latency_ms=%.1f status=%s text=%s raw=%s conf=%s "
            "lang_prob=%s nsp=%s expected=%s accepted=%s%s",
            request_id,
            eff_mode,
            elapsed_ms,
            api_status,
            result.text,
            result.raw_text,
            result.confidence,
            result.language_probability,
            result.max_no_speech_prob,
            (exp_for_match if exp_for_match else "-"),
            accepted if accepted is not None else "-",
            audio_bits,
        )

        out: dict = {
            "text": result.text,
            "raw_text": result.raw_text,
            "confidence": result.confidence,
            "language_probability": result.language_probability,
            "max_no_speech_prob": result.max_no_speech_prob,
            "status": api_status,
            "mode": eff_mode,
            "request_id": request_id,
        }
        if result.normalize_stats:
            if "input_dbfs" in result.normalize_stats:
                out["audio_input_dbfs"] = result.normalize_stats["input_dbfs"]
            if "output_dbfs" in result.normalize_stats:
                out["audio_output_dbfs"] = result.normalize_stats["output_dbfs"]

        if exp_for_match:
            out["expected"] = exp_for_match
            out["match_exact"] = match_exact
            out["match_tolerant"] = match_tolerant
            out["accepted"] = accepted
        return out
    finally:
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except OSError:
                logger.warning("request_id=%s gagal hapus %s", request_id, temp_path)
