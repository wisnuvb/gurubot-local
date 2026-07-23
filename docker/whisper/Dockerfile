FROM python:3.12-slim-bookworm

RUN apt-get update \
  && apt-get install -y --no-install-recommends ffmpeg curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY artifacts/whisper/app/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

COPY artifacts/whisper/app/ ./

ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/models/huggingface
ENV WHISPER_MODEL_PRESET=medium
ENV WHISPER_COMPUTE_TYPE=int8
ENV WHISPER_CPU_THREADS=8
ENV CALISTUNG_MODE=char

EXPOSE 2063

HEALTHCHECK --interval=30s --timeout=10s --start-period=180s --retries=5 \
  CMD curl -sf http://127.0.0.1:2063/health || exit 1

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "2063", "--workers", "1"]
