# Panduan Lengkap — Dari Build sampai Siswa Akses gurubot.sekolah

Panduan end-to-end, berurutan, dari **build code di `gurubot-pwa`** sampai **siswa SD bisa buka `https://gurubot.sekolah` dari HP Android di WiFi kelas** — termasuk membuat laptop server **otomatis menyalakan semua service setiap kali dinyalakan**, tanpa ada yang perlu login atau menjalankan skrip manual.

Dokumen lain (`DEPLOY-SEKOLAH.md`, `DNS-LAN.md`, `SSL.md`, dll.) tetap ada sebagai rujukan mendalam per topik — link ke sana disertakan di tiap bagian.

**Target pembaca:** siapa pun yang menyiapkan laptop server sekolah, tidak harus programmer, tapi nyaman menjalankan perintah di PowerShell/Command Prompt.

---

## Ringkasan alur

```
[gurubot-pwa]                    [gurubot-local-deploy]                  [Laptop sekolah]
  build artifact  ──copy──►  artifacts/nextjs/  ──bundle ke USB──►  extract + docker-up.bat
  (maintainer)                                                            │
                                                                           ▼
                                                        Docker: app + ocr + whisper + nginx (HTTPS) + dns (Technitium)
                                                                           │
                                                                           ▼
                                                     Autostart (Task Scheduler + auto-login) supaya
                                                     semua di atas otomatis nyala tiap laptop boot
                                                                           │
                                                                           ▼
                                          Router DHCP DNS ──► semua HP kelas resolve https://gurubot.sekolah
```

---

## 1. Maintainer — build artifact dari `gurubot-pwa`

Dilakukan di **mesin development** (bukan laptop sekolah), sekali per rilis.

```bash
cd gurubot-local-deploy
./scripts/maintainer/build-and-copy-nextjs.sh /path/to/gurubot-pwa
./scripts/maintainer/verify-nextjs-artifact.sh
```

Ini otomatis:
- Build `gurubot-pwa` dengan profil **`local`** (`.env.school`, bukan `.env.production`/`app.gurubot.io`)
- Set `NEXTAUTH_URL`/`NEXT_PUBLIC_API_URL=https://gurubot.sekolah` **saat build** (nilai ini di-bake ke bundle client, tidak bisa diperbaiki lewat env runtime — lihat [BUILD-ARTIFACT.md](BUILD-ARTIFACT.md))
- Copy hasil standalone ke `artifacts/nextjs/`

> **Penting:** kalau `artifacts/nextjs/` di bundle yang kamu punya sekarang dibuild **sebelum** rename ke `gurubot.sekolah`, dia masih mengandung `gurubot.local` di bundle JS-nya. **Wajib rebuild** dengan perintah di atas sebelum deploy — `verify-nextjs-artifact.sh` akan menandai kalau bundle masih mengandung domain lama.

Salin folder `gurubot-local-deploy` (dengan `artifacts/` terisi) ke USB/installer untuk dibawa ke sekolah.

---

## 2. Prasyarat laptop sekolah (Windows)

Instal manual sebelum lanjut — lihat [requirements/prerequisites.md](../requirements/prerequisites.md):

- **Docker Desktop** (WSL2 backend)
- **MySQL Server 8.0** (Windows Service)
- **Ollama** + `ollama pull qwen3:1.7b`
- **mkcert** (`choco install mkcert`)

Tidak perlu Acrylic/dnsmasq — DNS sudah otomatis lewat Technitium (container Docker), lihat bagian 5.

---

## 3. Konfigurasi & database

```powershell
cd C:\GuruBot\gurubot-local-deploy
copy config\.env.docker.example .env.docker
```

Import dump MySQL production:

```powershell
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS gurubot_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p gurubot_db < C:\path\ke\backup_production.sql
```

Edit `.env.docker` — isi **hanya** `DATABASE_URL` (pakai `host.docker.internal`, bukan `127.0.0.1`):

```env
DATABASE_URL=mysql://root:SANDI_ANDA@host.docker.internal:3306/gurubot_db
```

`NEXTAUTH_SECRET`, `JWT_SECRET`, `DNS_SERVER_ADMIN_PASSWORD` **tidak perlu diisi manual** — digenerate otomatis di langkah 5 saat `.env.docker` pertama kali dipakai.

---

## 4. Sertifikat HTTPS (mkcert)

```powershell
scripts\setup-ssl.bat
```

Membuat `certs\gurubot.sekolah.pem` + `-key.pem`, mencakup `gurubot.sekolah`, `localhost`, `127.0.0.1`, dan **IP LAN saat ini** (auto-deteksi). HTTPS wajib supaya mic/kamera di HP berfungsi (secure context browser). Detail: [SSL.md](SSL.md).

---

## 5. Start stack Docker (app + DNS otomatis)

```powershell
scripts\docker-up.bat
```

Script ini otomatis:
1. Generate `NEXTAUTH_SECRET`/`JWT_SECRET`/`DNS_SERVER_ADMIN_PASSWORD` (kalau `.env.docker` baru dibuat)
2. `docker compose up -d --build` — naikkan `app`, `ocr`, `whisper`, `nginx`, dan **`dns` (Technitium)**
3. Jalankan health check
4. Jalankan `scripts\setup-dns.bat` — konfigurasi zone + record `gurubot.sekolah` → IP LAN server saat ini di Technitium, plus arahkan DNS adapter Windows & hosts lokal

Build pertama kali bisa 10–30 menit. Detail arsitektur & troubleshooting: [DOCKER-WINDOWS.md](DOCKER-WINDOWS.md), [DNS-LAN.md](DNS-LAN.md).

Verifikasi:

```powershell
scripts\docker-health-check.bat
```

Semua baris harus `[ OK ]`, termasuk `DNS gurubot.sekolah (Technitium)`.

---

## Autostart

## 6. Autostart saat laptop dinyalakan

**Kenapa perlu:** Docker Desktop (beda dari server Linux) butuh sesi Windows yang login untuk bisa jalan. Supaya server kelas hidup sendiri begitu laptop dicolok listrik/dinyalakan — tanpa guru/TU perlu login dan menjalankan skrip — laptop perlu di-set **auto-login** ke satu akun khusus, dan Docker Desktop di-set start otomatis saat login itu.

**Trade-off keamanan:** auto-login berarti siapa pun yang menyalakan laptop fisik langsung masuk ke Windows tanpa password. Ini masuk akal **hanya** kalau laptop didedikasikan sebagai server (bukan dipakai guru untuk kerja lain) dan disimpan di tempat aman (ruang guru/TU, bukan meja terbuka). Kalau tidak yakin, tetap bisa pakai jalur manual (jalankan `docker-up.bat` tiap pagi) dan lewati bagian ini.

### 6.1 Auto-login Windows (manual, sekali)

Disarankan pakai **Sysinternals Autologon** (resmi Microsoft, password tersimpan sebagai LSA secret, lebih aman dari edit registry manual):

1. Unduh dari [learn.microsoft.com/sysinternals/downloads/autologon](https://learn.microsoft.com/en-us/sysinternals/downloads/autologon)
2. Buat akun Windows khusus, misal `GuruBotServer`, jadikan **Administrator lokal**
3. Jalankan `Autologon.exe`, isi username/domain/password akun tersebut, klik **Enable**

### 6.2 Docker Desktop — start otomatis saat login

Login ke akun `GuruBotServer` tersebut sekali, buka **Docker Desktop → Settings → General**, centang **"Start Docker Desktop when you log in"**.

### 6.3 Daftarkan Task Scheduler

Login sebagai `GuruBotServer` (atau admin lain), jalankan **sebagai Administrator**:

```powershell
scripts\setup-autostart.bat
```

Isi nama akun `GuruBotServer` saat diminta. Ini mendaftarkan task **"GuruBot Autostart"** yang menjalankan `scripts\autostart-guard.bat` setiap kali akun itu login — script ini menunggu Docker Desktop siap, menjalankan `docker compose up -d`, mengonfigurasi ulang DNS (menangani kasus IP berubah setelah reboot), dan memverifikasi MySQL/Ollama.

### 6.4 Uji

Jangan anggap selesai sebelum diuji dengan **restart penuh** (bukan sekadar logout):

1. Restart laptop dari Start Menu (bukan sleep/hibernate).
2. Tunggu sampai layar desktop `GuruBotServer` muncul otomatis (auto-login).
3. Tunggu 1-3 menit (Docker Desktop + container start).
4. Dari **HP lain** di WiFi yang sama: buka `https://gurubot.sekolah/welcome` — harus langsung bisa diakses tanpa siapa pun menjalankan apa pun di laptop.
5. Cek log: `logs\autostart-YYYYMMDD.log` di folder bundle.

Kalau langkah 4 gagal, cek `docs\DOCKER-WINDOWS.md` bagian troubleshooting, atau jalankan manual: `scripts\docker-health-check.bat`.

---

## 7. Router — supaya semua HP otomatis resolve (opsional tapi disarankan)

Set **DHCP DNS Server** di router WiFi kelas ke IP LAN laptop server (lihat `scripts\show-server-info.bat`). Setelah ini, **semua** HP yang connect ke WiFi kelas otomatis bisa resolve `gurubot.sekolah` tanpa setting apa pun di HP. Detail per merk router: [DNS-LAN.md](DNS-LAN.md).

Kalau tidak bisa/tidak mau ubah router (SD tertinggal dsb.), skip bagian ini dan pakai fallback IP + QR code di bagian 8.

---

## 8. Tablet/HP guru — siapkan akses

### 8.1 Install root CA mkcert (1x per HP, guru/TU yang siapkan)

```powershell
scripts\setup-ssl-mobile.bat
```

Menghasilkan `certs\mobile\gurubot-mkcert-rootCA.pem`. Salin ke tablet (USB/WhatsApp/Drive), lalu di HP: **Settings → Security → Encryption & credentials → Install a certificate → CA certificate**. Detail: [SSL.md](SSL.md).

Tanpa langkah ini, browser HP menampilkan peringatan sertifikat dan **mic tidak akan berfungsi** (secure context browser menolak).

### 8.2 Buat akses mudah untuk siswa

- **QR code** ke `https://gurubot.sekolah/welcome` (kalau router sudah diarahkan) atau `https://<IP-SERVER>/welcome` (fallback)
- **Shortcut** di home screen tablet
- Siswa **tidak perlu install apa pun** — cukup scan QR / buka shortcut

Info IP & URL: `scripts\show-server-info.bat`.

---

## 9. Verifikasi akhir sebelum kelas

| Cek | Cara |
|-----|------|
| Server healthy | `scripts\docker-health-check.bat` — semua `[ OK ]` |
| DB terhubung | `scripts\test-db.bat` |
| Dari laptop server | `https://gurubot.sekolah` bisa diakses |
| Dari 1 tablet Android | HTTPS **tanpa** peringatan + halaman welcome |
| Login siswa | Scan QR kelas / kode siswa — `scripts\test-login.bat` untuk API langsung |
| **Restart penuh laptop** | Semua di atas tetap jalan tanpa intervensi manual (lihat 6.4) |

Checklist cetak untuk guru lapangan ada di [DEPLOY-SEKOLAH.md](DEPLOY-SEKOLAH.md).

---

## 10. Troubleshooting gabungan

| Gejala | Kemungkinan penyebab | Solusi |
|--------|----------------------|--------|
| `docker compose up` gagal | Docker Desktop belum jalan / port 80-443 dipakai Apache-XAMPP | Buka Docker Desktop; `netstat -ano \| findstr :443` |
| `gurubot.sekolah` tidak resolve | Container `dns` belum jalan, atau IP berubah | `docker compose logs dns`; jalankan ulang `scripts\setup-dns.bat` |
| HP: koneksi tidak aman | Root CA belum di-trust | `scripts\setup-ssl-mobile.bat` + install ulang di HP |
| HP: IP bisa, domain tidak | Router DNS belum diarahkan | Set DHCP DNS router, atau pakai fallback IP + QR |
| Login redirect loop | `NEXTAUTH_URL` di `.env.docker` tidak sama dengan URL browser | Samakan persis, termasuk `https://` |
| Mic gagal di HP | HTTPS belum trusted | Ulangi bagian 8.1 |
| LLM/Analisa AI gagal | Ollama belum jalan/model belum ada | `curl http://127.0.0.1:11434/api/tags`; `ollama pull qwen3:1.7b` |
| IP server berubah setelah pindah router | DHCP assign IP baru | `show-server-info.bat` → `setup-ssl.bat` ulang (regenerate cert) → restart laptop (autostart-guard re-run DNS otomatis) |
| Autostart tidak jalan setelah restart | Auto-login belum aktif, atau Docker Desktop "start on login" belum dicentang | Ulangi bagian 6.1-6.2; cek `schtasks /query /tn "GuruBot Autostart"` |
| Setup-dns.bat gagal login Technitium | `.env.docker` diedit setelah container `dns` pernah start pertama kali | `docker compose down`; hapus volume `dns-config`; `docker-up.bat` lagi |

---

## Referensi dokumen lain

- [DEPLOY-SEKOLAH.md](DEPLOY-SEKOLAH.md) — ringkasan operasional + checklist cetak
- [BUILD-ARTIFACT.md](BUILD-ARTIFACT.md) — detail build & copy artifact Next.js
- [DOCKER-WINDOWS.md](DOCKER-WINDOWS.md) — panduan Docker langkah-demi-langkah + troubleshooting
- [DNS-LAN.md](DNS-LAN.md) — detail Technitium DNS + setting router
- [SSL.md](SSL.md) — mkcert + trust CA di HP/tablet
- [UPDATE.md](UPDATE.md) — update versi bundle setelah rilis baru
