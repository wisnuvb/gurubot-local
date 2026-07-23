# Panduan Instalasi GuruBot Local Deploy

## 1. Persiapan maintainer (sebelum distribusi)

> **Panduan lengkap:** [docs/BUILD-ARTIFACT.md](BUILD-ARTIFACT.md) — build gurubot-pwa, copy artifact, Prisma cross-platform, verifikasi.

### Build Next.js artifact (HTTPS) — ringkas

Satu perintah (Mac/Linux):

```bash
./scripts/maintainer/build-and-copy-nextjs.sh /path/to/gurubot-pwa
```

Manual di **gurubot-pwa**:

```bash
export GURUBOT_BUILD_ENV=local
export NEXTAUTH_URL=https://gurubot.sekolah
export NEXT_PUBLIC_API_URL=https://gurubot.sekolah
export NEXT_BUILD_WEBPACK=1
export SKIP_SENTRY_WEBPACK=1
yarn install && rm -rf .next && yarn build:next:local
```

Pastikan `.env.school` ada di root gurubot-pwa (dari `.env.school.example`).

Salin ke bundle:

```bash
./scripts/maintainer/copy-nextjs-artifact.sh /path/to/gurubot-pwa
./scripts/maintainer/verify-nextjs-artifact.sh
```

Skrip copy otomatis mem-patch `instrumentation.js` (no-op tanpa Sentry).

> **Penting:** Build harus pakai profil **local** (`.env.school`). `NEXT_PUBLIC_*` tersemat di bundle client — `.env.docker` runtime tidak bisa memperbaiki URL/Sentry/Whisper yang salah di-bake. Artifact lama dari profil production perlu rebuild.

> **Prisma:** engine Prisma harus cocok dengan platform target. Untuk Docker Linux (node:24-bookworm), generate di mesin build Linux atau jalankan `prisma generate` di dalam container saat pertama build jika engine tidak cocok.

**Jangan** menyalin isi folder `.next` langsung ke `artifacts/nextjs/` tanpa parent `.next/`.

Layout yang benar:

```
artifacts/nextjs/
├── server.js
├── node_modules/
├── .next/
│   ├── BUILD_ID
│   ├── server/
│   └── static/
├── prisma/
├── ml-training/
└── public/
```

Verifikasi lokal:

```bash
cd artifacts/nextjs
export PORT=2050 HOSTNAME=0.0.0.0
node server.js
curl http://127.0.0.1:2050/api/health
```

### Whisper & OCR artifact

- Whisper: `artifacts/whisper/app/` — dibuild ke image `docker/whisper/Dockerfile`
- OCR: `artifacts/nextjs/ml-training/ocr_server.py` — dibuild ke image `docker/ocr/Dockerfile`
- Opsional pre-seed model HF ke volume Docker saat runtime pertama (unduh otomatis)

### LLM — Ollama (prasyarat host)

- Model default: **`qwen3:1.7b`**
- Lihat [artifacts/llm/README.md](../artifacts/llm/README.md)

### Tools

- DNS `gurubot.sekolah` di LAN sudah otomatis lewat container **Technitium** (docker-compose) — tidak perlu tool tambahan.
- Acrylic/nginx/NSSM di `tools/` hanya untuk jalur **legacy PM2** — lihat [tools/README.md](../tools/README.md)

---

## 2. Instalasi Docker (disarankan)

### 2.1 Prasyarat host

1. Windows 10/11 64-bit + **Docker Desktop** (WSL2)
2. **MySQL 8.0** service berjalan
3. **Ollama** + `ollama pull qwen3:1.7b`
4. **mkcert** di PATH (`choco install mkcert`)

### 2.2 MySQL — import database

```powershell
mysql -u root -p gurubot_db < C:\path\to\backup_production.sql
```

Edit `.env.docker` (buat dari template):

```powershell
copy config\.env.docker.example .env.docker
```

```env
DATABASE_URL=mysql://root:PASSWORD@host.docker.internal:3306/gurubot_db
NEXTAUTH_URL=https://gurubot.sekolah
NEXT_PUBLIC_API_URL=https://gurubot.sekolah
```

`NEXTAUTH_SECRET`, `JWT_SECRET`, `DNS_SERVER_ADMIN_PASSWORD` digenerate otomatis saat `docker-up.bat` pertama kali membuat file ini — tidak perlu diisi manual.

### 2.3 DNS (Technitium) — otomatis

Tidak ada langkah manual — DNS LAN dijawab oleh container `dns` (Technitium), dikonfigurasi otomatis oleh `docker-up.bat` (lihat 2.5). Untuk DNS di seluruh WiFi sekolah, set router DHCP DNS ke IP PC server — lihat [DNS-LAN.md](DNS-LAN.md).

### 2.4 HTTPS (mkcert)

```powershell
scripts\setup-ssl.bat
```

Trust root CA di HP/tablet — [SSL.md](SSL.md).

### 2.5 Start Docker Compose

```powershell
scripts\docker-up.bat
```

Alur:

```
https://gurubot.sekolah:443  →  nginx (Docker)  →  app:2050 (Next.js)
                                              ↘  ocr:2059, whisper:2063 (internal)
app  →  host.docker.internal:3306 (MySQL)
app  →  host.docker.internal:11434 (Ollama)
```

### 2.6 Verifikasi

```powershell
scripts\docker-health-check.bat
```

Buka **https://gurubot.sekolah** dari browser PC server dan HP.

Uji login setelah DB + secrets benar:

```powershell
scripts\test-login.bat
```

> Ubah URL di `test-login.bat` ke `https://gurubot.sekolah` jika masih `http://`.

### 2.7 Autostart saat laptop dinyalakan (disarankan untuk server kelas)

Supaya semua service (Docker, DNS, dst.) otomatis jalan tanpa ada yang login/klik apa pun:

```powershell
scripts\setup-autostart.bat
```

Prasyarat dan detail lengkap (auto-login Windows, Docker Desktop "start on login") ada di [PANDUAN-LENGKAP-SEKOLAH.md](PANDUAN-LENGKAP-SEKOLAH.md#autostart).

---

## 3. Instalasi legacy PM2 (deprecated)

Jalur lama: Node.js 20 + Python 3.12 + PM2 + nginx Windows + venv OCR/Whisper.

```powershell
scripts\setup.bat
scripts\setup-services.bat
scripts\start-all.bat
scripts\health-check.bat
```

Build artifact legacy memakai `http://gurubot.sekolah` — tidak cocok untuk mic di HP tanpa HTTPS.

---

## 4. Troubleshooting

### Docker

| Gejala | Solusi |
|--------|--------|
| `docker compose up` gagal | Pastikan Docker Desktop jalan; port 80/443 tidak dipakai Apache |
| nginx container exit | Sertifikat hilang — `scripts\setup-ssl.bat` |
| App unhealthy | `docker compose logs app` — cek `DATABASE_URL`, Prisma engine |
| OCR model not loaded | Pertama kali unduh model HF; `docker compose logs ocr` |
| Whisper `/ready` 503 | Tunggu model load; `docker compose logs whisper` |
| Login redirect loop | `NEXTAUTH_URL` harus `https://gurubot.sekolah` sama dengan browser |
| Mic gagal di HP | Trust mkcert root CA — [SSL.md](SSL.md) |
| LLM gagal | Ollama jalan di host; `curl http://127.0.0.1:11434/api/tags` |
| MySQL connection refused dari container | MySQL listen di host; coba `host.docker.internal` bukan `127.0.0.1` di `.env.docker` |

### Legacy PM2

| Gejala | Solusi |
|--------|--------|
| PM2 kosong | `scripts\run-app-manual.bat`; cek `PM2_HOME` |
| OCR/Whisper FAIL | Selesaikan `setup.bat` venv |
| login-qr error | `scripts\test-db.bat`; cek `.pm2\logs\gurubot-app-error.log` |
| `production-start-no-build-id` | Jalankan `copy-nextjs-artifact.sh` |

---

## 5. Akun demo

Jika menjalankan seed database ([gurubot-pwa](https://github.com/your-org/gurubot-pwa)):

- Guru: `teacher@gurubot.sekolah` / `password123`
- Orang tua: `parent@gurubot.sekolah` / `password123`
