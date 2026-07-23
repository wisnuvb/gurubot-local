# Prasyarat Hardware & Software

## Hardware

| Sumber daya | Minimum | Disarankan |
|-------------|---------|------------|
| OS | Windows 10/11 64-bit | Windows 11 |
| RAM | 8 GB | **16 GB** |
| Disk | 20 GB kosong | 40 GB+ (termasuk model Whisper + Ollama ~400 MB) |
| CPU | x64 4 core | 8 core |

## Software — deploy Docker (disarankan)

| Software | Versi | Catatan |
|----------|-------|---------|
| Docker Desktop | Terbaru | WSL2 backend; jalankan `docker compose` |
| MySQL Server | **8.0** | Windows Service — data production dump |
| Ollama | Terbaru | [ollama.com/download/windows](https://ollama.com/download/windows) — LLM Qwen |
| mkcert | Terbaru | Sertifikat HTTPS lokal — `choco install mkcert` |

## Software — legacy PM2 (deprecated)

| Software | Versi | Catatan |
|----------|-------|---------|
| Node.js | **20 LTS** | Hanya jika pakai jalur PM2 lama |
| Python | **3.12+** | Hanya jika pakai venv OCR/Whisper di host |
| npm global | pm2 | Diinstal otomatis oleh `setup-services.bat` |

## Tools (salin ke `tools/` sebelum deploy lapangan)

| Tool | Folder | Unduh | Docker deploy |
|------|--------|-------|---------------|
| Acrylic DNS | `tools/acrylic/` | [AcrylicHome](https://mayakron.altervista.org/wikibase/show.php?id=AcrylicHome) | **Legacy PM2 saja** — Docker pakai Technitium (container, otomatis, tanpa unduh manual) |
| ffmpeg | `tools/ffmpeg/ffmpeg.exe` | https://ffmpeg.org/download.html | Opsional (sudah di image Whisper) |
| nginx win64 | `tools/nginx/` | https://nginx.org/en/download.html | Legacy PM2 saja |
| NSSM | `tools/nssm/nssm.exe` | https://nssm.cc/download | Legacy PM2 saja |

## Artifacts (maintainer)

| Artifact | Isi |
|----------|-----|
| `artifacts/nextjs/` | Standalone build + prisma + ml-training |
| `artifacts/whisper/` | app + wheels (opsional) + model cache |
| `artifacts/llm/` | Panduan Ollama + `setup-ollama.bat` |

Build Next.js untuk Docker HTTPS:

```bash
export NEXTAUTH_URL=https://gurubot.sekolah
export NEXT_PUBLIC_API_URL=https://gurubot.sekolah
yarn build:next
```

Lihat [docs/INSTALL.md](../docs/INSTALL.md) bagian maintainer.
