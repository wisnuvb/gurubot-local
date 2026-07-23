# GuruBot LLM — Ollama + Qwen

LLM dijalankan oleh **Ollama** (prasyarat manual), bukan binary bundle di repo ini.

## Prasyarat

1. Unduh dan instal [Ollama for Windows](https://ollama.com/download/windows)
2. Pastikan Ollama berjalan (system tray)
3. Pull model bundle:

```powershell
ollama pull qwen3:1.7b
```

## Konfigurasi Next.js (`.env`)

```env
LLM_PROVIDER=qwen
LLM_MODEL=qwen3:1.7b
QWEN_API_URL=http://127.0.0.1:11434/v1/chat/completions
```

`LLM_MODEL` harus **persis sama** dengan output `ollama list`.

## Autostart

Ollama autostart via aplikasi Ollama / Task Manager → Startup. **Tidak** lewat NSSM bundle.

## Verifikasi

```powershell
ollama list
curl http://127.0.0.1:11434/api/tags
ollama run qwen3:1.7b "Tes bahasa Indonesia"
```

## Upgrade / ganti model (opsional)

```powershell
ollama pull qwen3:4b
# atau model lain di library Ollama
```

Update `LLM_MODEL` di `artifacts/nextjs/.env` sesuai tag baru.

## Helper

```powershell
artifacts\llm\setup-ollama.bat
```
