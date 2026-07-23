# GuruBot Whisper STT (Calistung)

Service FastAPI + faster-whisper untuk latihan suara siswa.

## Port

- **2063** — bind `127.0.0.1` (hanya diakses Next.js via `STT_API_URL`)

## Struktur

| Folder | Isi |
|--------|-----|
| `app/` | Kode Python (FastAPI) |
| `wheels/` | Paket pip offline (win_amd64) — isi saat build bundle maintainer |
| `models/huggingface/` | Cache model (pre-seed `cahya/faster-whisper-medium-id`) |
| `venv/` | Dibuat oleh `setup.bat` |

## Maintainer: siapkan wheels offline

```powershell
cd artifacts\whisper
python -m pip download -r app\requirements.txt -d wheels\ --platform win_amd64 --python-version 312 --only-binary=:all:
```

## Verifikasi

```powershell
curl http://127.0.0.1:2063/health
curl http://127.0.0.1:2063/ready
```
