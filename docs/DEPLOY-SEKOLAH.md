# Deploy GuruBot di Server Sekolah — Ringkasan Final

Panduan operasional untuk **Windows** atau **macOS** sebagai PC server di sekolah. Target: siswa SD akses via **HP Android** di WiFi kelas.

---

## Tentang IP `192.168.1.5` — darimana & apakah berubah?

| Pertanyaan | Jawaban |
|------------|---------|
| Darimana? | **IP LAN WiFi** PC/Mac server — terdeteksi otomatis dari jaringan saat setup (`detect-lan-ip`) |
| Apakah sama di semua sekolah? | **Tidak** — tiap sekolah/router bisa beda (mis. `192.168.0.50`, `10.0.0.12`) |
| Apakah bisa berubah? | **Ya**, jika: pindah router, reinstall WiFi, DHCP assign IP baru |
| Cara stabilkan | **DHCP reservation** di router (bind MAC address PC server → IP tetap) atau **IP statis** di PC server |

**Jangan hardcode `192.168.1.5` di materi sekolah.** Gunakan skrip info server:

| OS | Perintah |
|----|----------|
| macOS | `./scripts/show-server-info.sh` |
| Windows | `scripts\show-server-info.bat` |

Sertifikat mkcert (`setup-ssl`) otomatis memasukkan **IP LAN saat generate** ke sertifikat HTTPS. Jika IP berubah, **regenerate SSL** + distribusi ulang CA ke tablet (jarang jika IP sudah distatis).

---

## Dua URL — pilih strategi sekolah

| URL | Perlu DNS? | Perlu CA di HP? | Cocok untuk |
|-----|------------|-----------------|-------------|
| `https://gurubot.sekolah` | Ya (Technitium — otomatis via Docker + router DHCP) | Ya | Sekolah dengan akses router |
| `https://<IP-SERVER>` | **Tidak** | Ya | **SD tertinggal** — pakai QR code |

**Rekomendasi SD daerah tertinggal:** `https://<IP-SERVER>/welcome` + **QR code** + prep tablet oleh guru.

---

## Prasyarat server sekolah

| Software | Windows | macOS |
|----------|---------|-------|
| Docker Desktop | ✅ | ✅ |
| MySQL 8.0 | ✅ Service | ✅ `brew services` |
| Ollama + `qwen3:1.7b` | ✅ | ✅ |
| mkcert | ✅ `choco install mkcert` | ✅ `brew install mkcert` |
| DNS LAN | Technitium (container, otomatis) | Technitium (container, otomatis) |

**Hardware disarankan:** RAM ≥ 16 GB, disk ≥ 40 GB, WiFi/router kelas.

---

## Fase 1 — Maintainer (sekali, sebelum distribusi bundle)

Di mesin development — lihat [BUILD-ARTIFACT.md](BUILD-ARTIFACT.md):

```bash
# Build artifact dari gurubot-pwa (profil local → .env.school)
./scripts/maintainer/build-and-copy-nextjs.sh /path/to/gurubot-pwa
./scripts/maintainer/verify-nextjs-artifact.sh
```

Skrip maintainer default `GURUBOT_BUILD_ENV=local` (bukan production/`app.gurubot.io`). Pastikan `gurubot-pwa/.env.school` sudah diisi.

Salin folder `gurubot-local-deploy` ke USB/installer sekolah.

---

## Fase 2 — Instalasi di PC server sekolah

### Windows

```powershell
# 1. Prasyarat: Docker Desktop, MySQL, Ollama, mkcert
ollama pull qwen3:1.7b

# 2. Import dump MySQL ke gurubot_db

# 3. Setup env
copy config\.env.docker.example .env.docker
# Edit DATABASE_URL (NEXTAUTH_SECRET/JWT_SECRET/DNS_SERVER_ADMIN_PASSWORD digenerate otomatis)

# 4. HTTPS (sertifikat + IP LAN otomatis)
scripts\setup-ssl.bat

# 5. Start Docker + DNS (Technitium otomatis dikonfigurasi ke gurubot.sekolah)
scripts\docker-up.bat

# 6. Cek
scripts\docker-health-check.bat
scripts\show-server-info.bat

# 7. Autostart saat laptop nyala (disarankan untuk server kelas) — lihat
#    docs/PANDUAN-LENGKAP-SEKOLAH.md bagian autostart, lalu:
scripts\setup-autostart.bat
```

### macOS

```bash
# 1. Prasyarat: Docker Desktop, MySQL, Ollama, mkcert
ollama pull qwen3:1.7b

# 2. Import dump MySQL

# 3. Setup
./scripts/setup.sh              # .env.docker (secret otomatis) + hosts
./scripts/setup-ssl.sh          # sertifikat HTTPS
./scripts/docker-up.sh          # Docker + DNS (Technitium otomatis)
./scripts/docker-health-check.sh
./scripts/show-server-info.sh
```

---

## Fase 3 — Persiapan tablet Android (guru/TU, bukan siswa)

### 3.1 Export file CA

| OS | Perintah |
|----|----------|
| Windows | `scripts\setup-ssl-mobile.bat` |
| macOS | `./scripts/setup-ssl-mobile.sh` |

File: `certs/mobile/gurubot-mkcert-rootCA.pem`

### 3.2 Install CA di setiap tablet (1x per HP)

1. Salin `.pem` ke tablet (USB / WhatsApp / Drive)
2. **Settings → Security → Encryption & credentials**
3. **Install a certificate → CA certificate**
4. Pilih `gurubot-mkcert-rootCA.pem`

### 3.3 Buat akses mudah untuk siswa

- **QR code** ke `https://<IP-SERVER>/welcome` (dari `show-server-info`)
- **Shortcut** di home screen tablet
- Siswa **tidak perlu** install apa pun — cukup scan/buka shortcut

---

## Fase 4 — DNS & router (opsional)

### Opsi A — Router DHCP DNS (semua HP otomatis, tanpa setting per HP)

Atur di router WiFi kelas:

```
DHCP DNS Server = <IP-SERVER>
```

DNS dijawab otomatis oleh container **Technitium** (`docker-up` sudah menjalankan `setup-dns.bat`/`setup-dns.sh`) — sama di Windows maupun macOS, tidak ada langkah tambahan per OS.

Siswa buka: `https://gurubot.sekolah/welcome`

### Opsi B — Tanpa ubah router (paling praktis SD tertinggal)

- Skip DNS
- Pakai **QR / IP langsung**: `https://<IP-SERVER>/welcome`
- CA tetap wajib di tablet

---

## Fase 5 — Verifikasi sebelum kelas

| Cek | Cara |
|-----|------|
| Server healthy | `docker-health-check` (.bat / .sh) |
| DB OK | `test-db` (.bat / .sh) |
| Dari Mac/PC server | `https://gurubot.sekolah` atau `https://localhost` |
| Dari 1 tablet Android | HTTPS **tanpa** peringatan + halaman welcome |
| Login siswa | Scan QR kelas / kode siswa |

---

## Skrip cross-platform (referensi)

| Fungsi | Windows | macOS |
|--------|---------|-------|
| Setup awal (env + secret) | `setup-ssl.bat` lalu `docker-up.bat` | `setup.sh` |
| SSL server | `setup-ssl.bat` | `setup-ssl.sh` |
| Export CA mobile | `setup-ssl-mobile.bat` | `setup-ssl-mobile.sh` |
| Info IP & URL | `show-server-info.bat` | `show-server-info.sh` |
| DNS LAN | otomatis (`setup-dns.bat`, dipanggil `docker-up.bat`) | otomatis (dipanggil `docker-up.sh`) |
| Docker up/down | `docker-up.bat` / `docker-down.bat` | `docker-up.sh` / `docker-down.sh` |
| Health check | `docker-health-check.bat` | `docker-health-check.sh` |
| Test DB | `test-db.bat` | `test-db.sh` |
| Fallback IP env | `setup-fallback-ip.bat` | `setup-fallback-ip.sh` |
| Autostart saat boot | `setup-autostart.bat` | — (jalankan manual setelah login) |

---

## Troubleshooting singkat

| Gejala | Solusi |
|--------|--------|
| HP: koneksi tidak aman | Install `gurubot-mkcert-rootCA.pem` di tablet |
| HP: IP bisa, domain tidak | Normal tanpa DNS — pakai IP + QR |
| IP berubah setelah pindah router | `show-server-info` → regenerate `setup-ssl` → update QR |
| Login loop | `NEXTAUTH_URL` di `.env.docker` harus match URL browser |
| Mic gagal | Pastikan HTTPS trusted (CA terinstal) |

---

## Checklist cetak untuk guru lapangan

```
□ PC server: Docker + MySQL + Ollama jalan
□ scripts setup-ssl + docker-up sukses (DNS Technitium ikut otomatis)
□ Catat IP server: ___________________  (show-server-info)
□ Router DNS → IP server (opsional): □ Ya  □ Tidak (pakai QR)
□ QR code https://<IP>/welcome dicetak/ditempel
□ Semua tablet: CA mkcert terinstal (guru prep)
□ Tes 1 tablet: welcome + login siswa OK
□ Autostart boot dikonfigurasi (setup-autostart.bat) + tes restart laptop
□ Baru mulai kelas
```
