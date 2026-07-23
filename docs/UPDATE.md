# Panduan Update GuruBot

## Prosedur Docker (disarankan)

1. **Stop container**

```powershell
scripts\docker-down.bat
```

2. **Backup** — salin `.env.docker` ke `backup/` manual jika berisi secret production

3. **Ganti artifact**

- `artifacts/nextjs/` (standalone build baru — rebuild dengan `https://gurubot.sekolah`)
- `artifacts/whisper/app/` (jika ada versi STT baru)

4. **Rebuild & start**

```powershell
scripts\docker-up.bat
```

5. **Verifikasi**

```powershell
scripts\docker-health-check.bat
```

Model Ollama jika perlu:

```powershell
ollama pull qwen3:1.7b
```

## Prosedur legacy PM2

1. `scripts\stop-all.bat`
2. Ganti artifact
3. `scripts\update.bat` — restore `.env`, migrate, restart PM2

## Maintainer: build artifact baru

```bash
# gurubot-pwa — wajib HTTPS untuk deploy Docker
export NEXTAUTH_URL=https://gurubot.sekolah
export NEXT_PUBLIC_API_URL=https://gurubot.sekolah
export NEXT_BUILD_WEBPACK=1
export SKIP_SENTRY_WEBPACK=1
yarn build:next

./scripts/maintainer/copy-nextjs-artifact.sh /path/to/gurubot-pwa
```

## Catatan

- Jangan timpa `.env.docker` kecuali sengaja
- Jika schema DB berubah, pastikan `prisma/migrations/` ikut di artifact nextjs
- Volume Docker `whisper-models` / `ocr-models` menyimpan cache HF — tidak perlu dihapus kecuali ganti model
- Pastikan `LLM_MODEL` di `.env.docker` cocok dengan `ollama list`
