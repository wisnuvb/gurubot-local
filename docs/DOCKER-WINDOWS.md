# Panduan Docker GuruBot — Windows (Dari Nol Sampai Jalan)

Panduan langkah demi langkah untuk menjalankan **GuruBot Local Deploy** dengan **Docker Compose** di Windows 10/11. MySQL dan Ollama tetap di **host Windows**; aplikasi (Next.js, OCR, Whisper, nginx) berjalan di **container Docker**.

---

## Ringkasan arsitektur

```
Browser / HP Android
        │
        ▼
https://gurubot.sekolah:443  ──►  nginx (container)
                                    │
                                    ├──► app:2050      (Next.js)
                                    ├──► ocr:2059      (OCR, internal)
                                    └──► whisper:2063  (STT, internal)

app (container) ──► host.docker.internal:3306   (MySQL di Windows)
app (container) ──► host.docker.internal:11434  (Ollama di Windows)
```

| Komponen | Lokasi | Port |
|----------|--------|------|
| nginx HTTPS | Docker | 443 (publik), 80 (redirect) |
| Next.js | Docker (internal) | 2050 |
| OCR | Docker (internal) | 2059 |
| Whisper | Docker (internal) | 2063 |
| MySQL | Host Windows | 3306 |
| Ollama | Host Windows | 11434 |

---

## Fase 0 — Persiapan hardware

| Sumber daya | Minimum | Disarankan |
|-------------|---------|------------|
| OS | Windows 10/11 64-bit | Windows 11 |
| RAM | 8 GB | **16 GB** |
| Disk kosong | 20 GB | 40 GB+ |
| CPU | x64, 4 core | 8 core |

Build image Docker pertama kali membutuhkan waktu dan ruang disk tambahan (model Whisper/OCR diunduh saat runtime pertama).

---

## Fase 1 — Instal prasyarat di Windows

### 1.1 Docker Desktop (WSL2)

1. Unduh **Docker Desktop for Windows**: https://docs.docker.com/desktop/setup/install/windows-install/
2. Saat instalasi, pilih backend **WSL 2** (disarankan).
3. Jika diminta, aktifkan fitur Windows:
   - **WSL 2**
   - **Virtual Machine Platform**
4. Restart PC jika diperlukan.
5. Buka **Docker Desktop** dari Start Menu — tunggu sampai status **Engine running** (ikon hijau).
6. Verifikasi di **PowerShell** atau **Command Prompt**:

```powershell
docker --version
docker compose version
docker info
```

Semua perintah harus sukses tanpa error *"Docker daemon is not running"*.

> **Tips:** Matikan atau ubah port layanan yang bentrok dengan GuruBot: **Apache/XAMPP/IIS** di port **80** dan **443**.

---

### 1.2 MySQL 8.0

1. Instal **MySQL Server 8.0** untuk Windows: https://dev.mysql.com/downloads/mysql/
2. Catat **username** dan **password** root saat instalasi.
3. Pastikan service MySQL berjalan:
   - Buka **Services** (`services.msc`) → cari **MySQL80** (atau **MySQL**) → status **Running**.
4. Buat database dan import dump production:

```powershell
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS gurubot_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p gurubot_db < C:\path\ke\backup_production.sql
```

Ganti path dump sesuai file backup Anda.

> Container Docker **tidak** bisa pakai `127.0.0.1` untuk MySQL. Nanti di `.env.docker` gunakan **`host.docker.internal`**.

---

### 1.3 Ollama (fitur AI guru)

1. Unduh dan instal: https://ollama.com/download/windows
2. Pull model default:

```powershell
ollama pull qwen3:1.7b
```

3. Verifikasi:

```powershell
curl http://127.0.0.1:11434/api/tags
```

Harus mengembalikan JSON berisi model `qwen3:1.7b`.

---

### 1.4 mkcert (sertifikat HTTPS lokal)

Instal salah satu cara:

```powershell
# Via Chocolatey (disarankan jika sudah punya choco)
choco install mkcert

# Atau unduh binary dari:
# https://github.com/FiloSottile/mkcert/releases
```

Verifikasi:

```powershell
mkcert -version
```

---

### 1.5 DNS untuk `gurubot.sekolah` di LAN — tidak perlu instal apa pun

DNS LAN dijawab oleh container **Technitium DNS** yang sudah termasuk di `docker-compose.yml` — naik otomatis bareng `docker-up.bat` (Fase 6), tidak perlu instal Acrylic atau tool DNS terpisah.

Yang masih perlu manual (opsional, per sekolah): arahkan **DHCP DNS Server** router WiFi kelas ke IP LAN PC server — lihat [DNS-LAN.md](DNS-LAN.md).

**Alternatif SD tanpa DNS:** akses langsung **`https://<IP-SERVER>`** — lihat [DEPLOY-SEKOLAH.md](DEPLOY-SEKOLAH.md).

---

## Fase 2 — Siapkan bundle GuruBot

1. Ekstrak folder `gurubot-local-deploy` ke lokasi permanen, contoh:

```
C:\GuruBot\gurubot-local-deploy\
```

2. Pastikan artifact sudah ada (dari maintainer):

```
artifacts/nextjs/     ← build Next.js standalone
artifacts/whisper/    ← kode Whisper STT
```

3. Buka **PowerShell** atau **cmd** — untuk skrip setup DNS/firewall, jalankan **Command Prompt sebagai Administrator**.

---

## Fase 3 — Konfigurasi environment

### 3.1 Buat file `.env.docker`

Dari root folder bundle:

```powershell
cd C:\GuruBot\gurubot-local-deploy
copy config\.env.docker.example .env.docker
```

### 3.2 Edit `.env.docker`

`NEXTAUTH_SECRET`, `JWT_SECRET`, dan `DNS_SERVER_ADMIN_PASSWORD` **digenerate otomatis** saat `scripts\docker-up.bat` pertama kali membuat file ini (Fase 6) — tidak perlu diisi manual. Yang wajib diisi manual cuma `DATABASE_URL`:

```env
DATABASE_URL=mysql://root:SANDI_ANDA@host.docker.internal:3306/gurubot_db
NEXTAUTH_URL=https://gurubot.sekolah
NEXT_PUBLIC_API_URL=https://gurubot.sekolah
```

| Variabel | Penjelasan |
|----------|------------|
| `DATABASE_URL` | **Wajib diisi manual** — `host.docker.internal`, bukan `127.0.0.1` |
| `NEXTAUTH_URL` | Harus **sama persis** dengan URL di browser (default sudah benar) |
| `NEXT_PUBLIC_API_URL` | Sama dengan `NEXTAUTH_URL` untuk deploy HTTPS (default sudah benar) |
| `NEXTAUTH_SECRET` / `JWT_SECRET` / `DNS_SERVER_ADMIN_PASSWORD` | Digenerate otomatis oleh `docker-up.bat` — jangan diubah manual kecuali tahu risikonya |

Jika pakai IP LAN (tanpa DNS):

```env
NEXTAUTH_URL=https://192.168.1.50
NEXT_PUBLIC_API_URL=https://192.168.1.50
```

(Ganti IP sesuai PC server — cek dengan `scripts\show-server-info.bat`.)

---

## Fase 4 — DNS untuk `gurubot.sekolah` (otomatis)

Tidak ada langkah manual di fase ini — `scripts\docker-up.bat` (Fase 6) otomatis menjalankan `scripts\setup-dns.bat` yang mengonfigurasi container Technitium DNS (zone + record `gurubot.sekolah` → IP LAN server saat ini), plus entri hosts Windows.

Untuk DNS di seluruh WiFi sekolah (semua HP otomatis, tanpa setting per HP), set router DHCP DNS ke IP PC server — lihat [DNS-LAN.md](DNS-LAN.md).

> Kalau cuma pakai **`https://<IP-SERVER>`** tanpa DNS sama sekali, fase ini bisa diabaikan sepenuhnya.

---

## Fase 5 — Generate sertifikat HTTPS

Jalankan (Administrator disarankan untuk trust CA otomatis):

```powershell
scripts\setup-ssl.bat
```

Skrip membuat:
- `certs\gurubot.sekolah.pem`
- `certs\gurubot.sekolah-key.pem`

Sertifikat mencakup `gurubot.sekolah`, `localhost`, `127.0.0.1`, dan **IP LAN** saat generate.

**Untuk HP/tablet Android** — export root CA ke perangkat siswa:

```powershell
scripts\setup-ssl-mobile.bat
```

Detail trust CA: [SSL.md](SSL.md).

---

## Fase 6 — Start Docker Compose

Pastikan **Docker Desktop sudah running**, lalu:

```powershell
scripts\docker-up.bat
```

Skrip akan:
1. Cek `docker` dan daemon aktif
2. Buat `.env.docker` dari template jika belum ada
3. Cek sertifikat SSL ada
4. Menjalankan `docker compose up -d --build`
5. Menunggu healthcheck
6. Menjalankan `docker-health-check.bat`

**Build pertama** bisa memakan **10–30 menit** (unduh base image, compile Prisma, dll.).

---

## Fase 7 — Verifikasi

### 7.1 Status container

```powershell
docker compose ps
```

Semua service harus **Up**; `gurubot-app` status **healthy**.

### 7.2 Health check otomatis

```powershell
scripts\docker-health-check.bat
```

Harus menampilkan `[ OK ]` untuk:
- nginx HTTPS
- Ollama Qwen (host)
- OCR internal
- Whisper /health dan /ready

### 7.3 Browser

Buka di PC server:
- **https://gurubot.sekolah**
- atau **https://\<IP-SERVER\>**

### 7.4 Uji login

Setelah DB dan secret benar:

```powershell
scripts\test-login.bat
```

Pastikan URL di skrip mengarah ke `https://gurubot.sekolah` jika perlu.

### 7.5 Info IP untuk sekolah

```powershell
scripts\show-server-info.bat
```

---

## Operasi sehari-hari

| Tindakan | Perintah |
|----------|----------|
| Start stack | `scripts\docker-up.bat` |
| Stop stack | `scripts\docker-down.bat` |
| Cek kesehatan | `scripts\docker-health-check.bat` |
| Lihat log semua | `docker compose logs -f` |
| Log satu service | `docker compose logs -f app` |
| Restart satu service | `docker compose restart app` |
| Rebuild setelah update artifact | `docker compose up -d --build` |

**Urutan start (manual, sekali ini saja):**
1. MySQL service (Windows) — running (otomatis, Windows Service)
2. Ollama — running (`ollama serve` otomatis setelah instal, lewat Startup)
3. Docker Desktop — engine running
4. `scripts\docker-up.bat`

**Supaya urutan di atas otomatis setiap laptop dinyalakan** (disarankan untuk server kelas, tidak perlu ada yang menekan tombol apa pun): jalankan `scripts\setup-autostart.bat` sekali (Administrator) setelah setup awal berhasil. Detail prasyarat (auto-login Windows, Docker Desktop "start on login") ada di [PANDUAN-LENGKAP-SEKOLAH.md](PANDUAN-LENGKAP-SEKOLAH.md#autostart).

---

## Troubleshooting

### Docker Desktop / daemon

| Gejala | Solusi |
|--------|--------|
| `Docker tidak ditemukan` | Instal Docker Desktop; restart terminal |
| `Docker daemon tidak berjalan` | Buka Docker Desktop; tunggu engine ready |
| WSL error | `wsl --update`; restart PC; cek Virtualization di BIOS |

### Port bentrok

| Gejala | Solusi |
|--------|--------|
| `bind: address already in use` port 80/443 | Stop IIS, Apache/XAMPP, atau nginx Windows lain |
| Cek siapa pakai port | `netstat -ano \| findstr :443` lalu `tasklist /FI "PID eq ..."` |

### Container & aplikasi

| Gejala | Solusi |
|--------|--------|
| `nginx container exit` | Sertifikat hilang → `scripts\setup-ssl.bat` |
| `gurubot-app unhealthy` | `docker compose logs app` — cek `DATABASE_URL`, Prisma |
| MySQL connection refused | Pastikan MySQL jalan; URL pakai `host.docker.internal` |
| Login redirect loop | `NEXTAUTH_URL` harus sama dengan URL browser (https + hostname) |
| OCR model not loaded | Runtime pertama unduh model HF; `docker compose logs ocr` |
| Whisper `/ready` FAIL | Tunggu 1–3 menit load model; `docker compose logs whisper` |
| LLM / Analisa AI gagal | `curl http://127.0.0.1:11434/api/tags`; `ollama pull qwen3:1.7b` |
| Mic gagal di HP | Trust mkcert root CA di Android — [SSL.md](SSL.md) |
| Build gagal `package.json hilang` | Artifact Next.js belum lengkap — hubungi maintainer / [BUILD-ARTIFACT.md](BUILD-ARTIFACT.md) |
| `gurubot.sekolah` tidak resolve | Container `dns` belum jalan / IP berubah | `docker compose logs dns`; jalankan ulang `scripts\setup-dns.bat` — detail [DNS-LAN.md](DNS-LAN.md) |

### Perintah diagnosa cepat

```powershell
# Log error app
docker compose logs app --tail 100

# Masuk ke container app
docker exec -it gurubot-app sh

# Cek MySQL dari host
mysql -u root -p -e "SELECT 1"

# Cek Ollama
curl http://127.0.0.1:11434/api/tags

# Hapus semua container & rebuild bersih (data volume model tetap)
docker compose down
docker compose up -d --build
```

---

## Checklist cepat (copy untuk lapangan)

```
[ ] Docker Desktop terinstal & engine running
[ ] MySQL 8.0 service running + database gurubot_db di-import
[ ] Ollama terinstal + ollama pull qwen3:1.7b
[ ] mkcert di PATH
[ ] Bundle gurubot-local-deploy diekstrak
[ ] .env.docker dibuat (DATABASE_URL diisi manual; secret & DNS_SERVER_ADMIN_PASSWORD otomatis)
[ ] scripts\setup-ssl.bat — sertifikat di certs\
[ ] scripts\docker-up.bat — semua container Up/healthy (DNS Technitium otomatis)
[ ] scripts\docker-health-check.bat — semua OK
[ ] Browser: https://gurubot.sekolah atau https://IP
[ ] HP Android: root CA mkcert di-trust (setup-ssl-mobile.bat)
[ ] scripts\test-login.bat — login berhasil
[ ] scripts\setup-autostart.bat — autostart boot dikonfigurasi + diuji restart
```

---

## Dokumentasi terkait

- [PANDUAN-LENGKAP-SEKOLAH.md](PANDUAN-LENGKAP-SEKOLAH.md) — panduan end-to-end + autostart boot
- [INSTALL.md](INSTALL.md) — panduan instalasi lengkap + maintainer
- [DEPLOY-SEKOLAH.md](DEPLOY-SEKOLAH.md) — deploy di sekolah, QR code, Android
- [SSL.md](SSL.md) — HTTPS & trust CA di perangkat mobile
- [DNS-LAN.md](DNS-LAN.md) — Technitium DNS + router sekolah
- [UPDATE.md](UPDATE.md) — update versi bundle
- [requirements/prerequisites.md](../requirements/prerequisites.md) — spesifikasi hardware/software
