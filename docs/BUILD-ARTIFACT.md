# Panduan Build & Copy Artifact Next.js (Cross-Platform)

Dokumen ini menjelaskan cara membangun **gurubot-pwa** dan menyalin hasilnya ke **gurubot-local-deploy** dengan benar, agar deploy berjalan di:

| Target | Cara jalan |
|--------|------------|
| **Docker** (Mac / Windows / Linux) | `docker compose` — Prisma di-regenerate otomatis di image Linux |
| **Windows PM2** (legacy) | `node server.js` + engine Prisma `windows` |
| **Mac native** (dev/test) | `node server.js` langsung di host |

---

## 1. Arsitektur singkat

```
gurubot-pwa/                    gurubot-local-deploy/
├── next.config.ts              ├── artifacts/nextjs/     ← hasil copy
│   output: "standalone"        ├── docker/nextjs/Dockerfile
├── prisma/schema.prisma        ├── docker-compose.yml
├── ml-training/ocr_server.py   └── scripts/maintainer/
└── .next/standalone/  ──copy──►      copy-nextjs-artifact.sh
    (setelah yarn build:next dengan GURUBOT_BUILD_ENV=local)
```

**Profil env (gurubot-pwa):**

| `GURUBOT_BUILD_ENV` | File sumber | Kapan |
|---------------------|-------------|--------|
| `local` (**default skrip deploy**) | `.env.school` | Bundle sekolah / offline |
| `production` | `.env.production` | app.gurubot.io — **jangan** untuk deploy sekolah |
| `beta` | `.env.beta` | beta.gurubot.io |
| `dev` | `.env` | pengembangan |

**Yang disematkan saat build (tidak bisa diubah runtime):**

- `NEXT_PUBLIC_API_URL` — URL API di bundle client (auth, fetch, PWA)
- `NEXT_PUBLIC_*` lainnya yang dipakai di kode client (Whisper URL, Sentry, Clarity, Capacitor, dll.)

**Yang bisa diubah runtime (via `.env.docker`):**

- `DATABASE_URL`, `NEXTAUTH_SECRET`, `JWT_SECRET`
- `NEXTAUTH_URL` — harus **sama** dengan URL browser (mis. `https://gurubot.sekolah`)
- `OCR_SERVICE_URL`, `STT_API_URL`, `QWEN_API_URL`, dll.

> **Aturan emas:** Build dengan profil **`local`** (`.env.school`) dan `NEXTAUTH_URL` / `NEXT_PUBLIC_API_URL` = URL HTTPS browser (`https://gurubot.sekolah`). Jangan pakai `yarn build:next` tanpa `GURUBOT_BUILD_ENV=local` — default PWA adalah production (`app.gurubot.io`).

---

## 2. Prasyarat mesin build

| Tool | Versi disarankan | Catatan |
|------|------------------|---------|
| Node.js | 20+ (22 OK) | Sama dengan runtime Docker (`node:24`) |
| Yarn | 1.x | `corepack enable` atau `npm i -g yarn` |
| rsync | any | Sudah ada di macOS |
| RAM | ≥ 8 GB | Build Next.js berat; tutup Chrome/Android Studio jika OOM |
| Disk | ~5 GB kosong | `.next` + `node_modules` |

Repo harus ada berdampingan (contoh):

```
~/Project/
├── gurubot-pwa/
└── gurubot-local-deploy/
```

---

## 3. Build sekali jalan (disarankan)

Dari **gurubot-local-deploy**:

```bash
./scripts/maintainer/build-and-copy-nextjs.sh /Users/wisnu/Project/gurubot-pwa
```

Skrip ini:

1. Set `GURUBOT_BUILD_ENV=local` (pakai `.env.school`) + URL `https://gurubot.sekolah`, tanpa Sentry webpack
2. Pastikan `.env.school` ada di gurubot-pwa
3. `yarn install` + clean `.next`
4. `yarn build:next` dengan profil local
5. Jalankan `copy-nextjs-artifact.sh` + verifikasi

### Override URL (fallback IP)

Jika deploy pakai `https://192.168.x.x` tanpa DNS:

```bash
export NEXTAUTH_URL=https://192.168.1.50
export NEXT_PUBLIC_API_URL=https://192.168.1.50
./scripts/maintainer/build-and-copy-nextjs.sh /Users/wisnu/Project/gurubot-pwa
```

---

## 4. Build manual (langkah demi langkah)

### 4.1 Env build — profil sekolah + URL

Di terminal **gurubot-pwa**:

```bash
cd /Users/wisnu/Project/gurubot-pwa

# Wajib untuk deploy sekolah — isolasi .env.school (bukan .env.production)
export GURUBOT_BUILD_ENV=local

export NEXTAUTH_URL=https://gurubot.sekolah
export NEXT_PUBLIC_API_URL=https://gurubot.sekolah

# Deploy lapangan: matikan Sentry webpack (instrumentation di-patch saat copy)
export SKIP_SENTRY_WEBPACK=1

# Disarankan untuk Mac/desktop — webpack lebih stabil daripada turbopack untuk bundle standalone
export NEXT_BUILD_WEBPACK=1

export NEXT_TELEMETRY_DISABLED=1
```

Pastikan `.env.school` ada (`cp .env.school.example .env.school` lalu sesuaikan).

**Jangan** memakai `yarn build:next` tanpa `GURUBOT_BUILD_ENV=local` — default PWA mengaktifkan `.env.production` (`https://app.gurubot.io`) dan `NEXT_PUBLIC_*` cloud ikut ke bundle.

### 4.2 Install & build

```bash
yarn install

# Build bersih (disarankan setiap rilis deploy)
rm -rf .next
yarn build:next:local
# setara: GURUBOT_BUILD_ENV=local yarn build:next
```

Jika OOM di Mac:

```bash
NODE_HEAP_MB=8192 yarn build:next:local
```

### 4.3 Verifikasi output standalone

```bash
test -f .next/standalone/server.js && echo "standalone OK"
test -f .next/BUILD_ID && echo "BUILD_ID OK"
ls .next/static/chunks | head
```

Opsional — cek chunk penting (dari repo PWA):

```bash
yarn verify:chunks
```

### 4.4 Copy ke gurubot-local-deploy

```bash
cd /Users/wisnu/Project/gurubot-local-deploy
./scripts/maintainer/copy-nextjs-artifact.sh /Users/wisnu/Project/gurubot-pwa
```

Skrip copy akan:

1. Susun layout standalone yang benar di `artifacts/nextjs/`
2. Salin `public/`, `prisma/`, `ml-training/` (termasuk `ocr_server.py`)
3. **Timpa** `@prisma/client` + `prisma` dari node_modules penuh (standalone trace tidak lengkap)
4. Patch `binaryTargets` Prisma: `native`, `windows`, `debian-openssl-3.0.x`
5. `prisma generate` — unduh engine Mac + Windows + Linux
6. Patch `instrumentation.js` → no-op (tanpa Sentry di deploy lapangan)
7. Verifikasi struktur + peringatan jika URL production masih tersisa

---

## 5. Layout artifact yang benar

```
artifacts/nextjs/
├── server.js                 ← entrypoint Next standalone
├── node_modules/
│   ├── @prisma/client/       ← lengkap (termasuk generator-build/)
│   ├── .prisma/client/       ← engine query (multi-platform)
│   └── prisma/               ← CLI Prisma
├── .next/
│   ├── BUILD_ID
│   ├── server/
│   │   └── instrumentation.js  ← stub no-op setelah copy
│   └── static/
├── prisma/
│   └── schema.prisma         ← binaryTargets patched
├── ml-training/
│   └── ocr_server.py         ← dibuild ke image docker/ocr
└── public/
```

**Jangan pernah:**

```bash
# SALAH — merusak layout standalone
cp -R gurubot-pwa/.next/* artifacts/nextjs/
cp -R gurubot-pwa/.next/standalone/.next/* artifacts/nextjs/
```

---

## 6. Prisma & cross-platform

### Masalah umum

Next.js standalone **hanya** menyalin subset `node_modules`. Paket `@prisma/client` dari trace sering **tidak lengkap** (tanpa `generator-build/`, tanpa engine).

### Solusi di pipeline

| Tahap | Apa yang terjadi |
|-------|------------------|
| `copy-nextjs-artifact.sh` | rsync prisma penuh + `prisma generate` dengan 3 binaryTargets |
| `docker/nextjs/Dockerfile` | Hapus sisa prisma artifact → `npm install` → `prisma generate` di Linux |

`binaryTargets` setelah patch:

```prisma
generator client {
  provider      = "prisma-client-js"
  binaryTargets = ["native", "windows", "debian-openssl-3.0.x"]
}
```

| Target | Engine yang dipakai |
|--------|---------------------|
| Docker (`node:24-bookworm-slim`) | Regenerate di container → Linux `debian-openssl-3.0.x` |
| Windows PM2 | `windows` dari generate saat copy |
| Mac `node server.js` | `native` (darwin-arm64 / darwin-x64) saat copy di Mac |

---

## 7. Verifikasi setelah copy

### 7.1 Cek struktur (otomatis di skrip copy)

```bash
./scripts/maintainer/verify-nextjs-artifact.sh
```

### 7.2 Tes native di Mac (tanpa Docker)

```bash
cd artifacts/nextjs
export PORT=2050 HOSTNAME=0.0.0.0
export DATABASE_URL="mysql://root:PASSWORD@127.0.0.1:3306/gurubot_db"
export NEXTAUTH_URL=https://gurubot.sekolah
export NEXTAUTH_SECRET=dev-secret-panjang
export JWT_SECRET=dev-jwt-panjang
node server.js

# terminal lain:
curl -s http://127.0.0.1:2050/api/health
```

### 7.3 Tes Docker

```bash
cd /Users/wisnu/Project/gurubot-local-deploy
./scripts/setup-ssl.sh    # jika belum
./scripts/docker-up.sh
./scripts/docker-health-check.sh
./scripts/test-db.sh
./scripts/test-login.sh
```

---

## 8. Checklist rilis deploy

- [ ] Profil: `GURUBOT_BUILD_ENV=local` / `yarn build:next:local` (file `.env.school`)
- [ ] Env build: `NEXTAUTH_URL` + `NEXT_PUBLIC_API_URL` = `https://gurubot.sekolah` (atau IP fallback)
- [ ] `SKIP_SENTRY_WEBPACK=1`
- [ ] Clean build: `rm -rf .next` sebelum build
- [ ] `copy-nextjs-artifact.sh` selesai tanpa error verifikasi
- [ ] Tidak ada peringatan `app.gurubot.io` di bundle
- [ ] `verify-nextjs-artifact.sh` lulus
- [ ] `docker compose build app` sukses
- [ ] Health + login QR OK

---

## 9. Troubleshooting

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| Docker build: `generator-build/index.js` not found | Artifact prisma tidak lengkap | Jalankan ulang `copy-nextjs-artifact.sh`; Dockerfile sudah mitigasi dengan reinstall |
| Login redirect loop | `NEXTAUTH_URL` runtime ≠ URL browser | Samakan di `.env.docker` dengan URL browser |
| API fetch ke `app.gurubot.io` | Build dengan profil production | Rebuild: `GURUBOT_BUILD_ENV=local` + `.env.school` |
| `yarn build:next:local` Killed / OOM | RAM habis | `NODE_HEAP_MB=8192`, tutup app lain |
| `production-start-no-build-id` | Layout `.next` salah | Jangan copy manual; pakai skrip copy |
| Prisma P1001 dari container | MySQL tidak listen di host | MySQL bind `0.0.0.0`; `DATABASE_URL` pakai `host.docker.internal` |
| Mic gagal di HP | Bukan artifact — HTTPS/CA | Trust mkcert root CA — `docs/SSL.md` |
| Instrumentation / Sentry crash | Sentry di standalone Windows | Skrip copy sudah patch stub; pastikan file `.next/server/instrumentation.js` ter-patch |

---

## 10. Whisper & OCR (ringkas)

Artifact Next.js sudah menyertakan `ml-training/` untuk OCR. Whisper terpisah di `artifacts/whisper/` — tidak perlu di-copy dari PWA setiap release kecuali ada update STT.

Setelah update Next.js saja:

```bash
./scripts/maintainer/build-and-copy-nextjs.sh /Users/wisnu/Project/gurubot-pwa
./scripts/docker-up.sh
```

---

## 11. Referensi file

| File | Fungsi |
|------|--------|
| `gurubot-pwa/next.config.ts` | `output: "standalone"` |
| `gurubot-pwa/scripts/build.mjs` | Wrapper heap + webpack/turbopack |
| `scripts/maintainer/build-and-copy-nextjs.sh` | Build + copy satu perintah |
| `scripts/maintainer/copy-nextjs-artifact.sh` | Copy standalone → artifacts |
| `scripts/maintainer/patch-prisma-schema.js` | binaryTargets cross-platform |
| `scripts/maintainer/verify-nextjs-artifact.sh` | Verifikasi artifact |
| `scripts/maintainer/instrumentation.stub.js` | No-op Sentry untuk deploy lapangan |
| `docker/nextjs/Dockerfile` | Prisma regenerate di Linux |
