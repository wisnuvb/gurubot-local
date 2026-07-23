FROM python:3.12-slim-bookworm

RUN apt-get update \
  && apt-get install -y --no-install-recommends curl \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY docker/ocr/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt \
  && pip install --no-cache-dir torch torchvision \
    --index-url https://download.pytorch.org/whl/cpu

COPY artifacts/nextjs/ml-training/ocr_server.py ./ocr_server.py

ENV PYTHONUNBUFFERED=1
ENV HF_HOME=/models/huggingface
ENV TRANSFORMERS_CACHE=/models/huggingface

EXPOSE 2059

HEALTHCHECK --interval=30s --timeout=10s --start-period=120s --retries=5 \
  CMD curl -sf http://127.0.0.1:2059/docs || exit 1

CMD ["python", "ocr_server.py"]
