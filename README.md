# GuruBot Local Deploy (Windows / macOS)

Paket instalasi offline untuk menjalankan GuruBot di **Windows 10/11** atau **macOS**. **Jalur utama: Docker Compose** (nginx HTTPS + Next.js + OCR + Whisper + **Technitium DNS**). MySQL dan Ollama di host.

> **Panduan lengkap end-to-end:** lihat [docs/PANDUAN-LENGKAP-SEKOLAH.md](docs/PANDUAN-LENGKAP-SEKOLAH.md) — dari build `gurubot-pwa` sampai siswa akses `https://gurubot.sekolah`, termasuk **autostart saat laptop dinyalakan**.
>
> **Deploy sekolah (ringkas):** lihat [docs/DEPLOY-SEKOLAH.md](docs/DEPLOY-SEKOLAH.md) — checklist guru, Android, IP, SSL.

## Prasyarat (host)

Instal manual sebelum deploy:

- **Docker Desktop** untuk Windows
- **MySQL 8.0** (Windows Service)
- **Ollama** + model `qwen3:1.7b`
- **mkcert** (sertifikat HTTPS lokal)

Lihat [requirements/prerequisites.md](requirements/prerequisites.md).

> Jalur legacy PM2/Python venv di host masih ada di `scripts/setup.bat` tetapi **deprecated** — gunakan Docker. DNS (Acrylic) di jalur legacy itu terpisah dari Technitium yang dipakai jalur Docker.

## Instalasi cepat (Docker)

DNS LAN (`gurubot.sekolah`) sekarang otomatis: container **Technitium DNS** ikut naik bareng `docker compose`, dan `docker-up.bat`/`docker-up.sh` otomatis mengarahkan record ke IP LAN server saat ini — **tidak perlu install Acrylic/dnsmasq lagi** untuk jalur Docker.

### Windows

1. Instal Ollama + pull model:
   ```powershell
   ollama pull qwen3:1.7b
   ```
2. Import dump MySQL ke database lokal
3. Konfigurasi env: `copy config\.env.docker.example .env.docker` (secret di-generate otomatis saat `docker-up.bat` jalan pertama kali — cukup isi `DATABASE_URL`)
4. Generate sertifikat HTTPS: `scripts\setup-ssl.bat`
5. Start stack (Docker + DNS otomatis): `scripts\docker-up.bat`
6. Portal operator (PC server): **http://127.0.0.1:2077/** — `scripts\open-operator-portal.bat` — lihat [docs/OPERATOR-PORTAL.md](docs/OPERATOR-PORTAL.md). App sekolah: **https://gurubot.sekolah/welcome**
6. Export CA untuk tablet: `scripts\setup-ssl-mobile.bat`
7. Info IP sekolah: `scripts\show-server-info.bat`
8. **Autostart saat laptop nyala** (opsional tapi disarankan untuk server kelas): `scripts\setup-autostart.bat` — lihat [docs/PANDUAN-LENGKAP-SEKOLAH.md](docs/PANDUAN-LENGKAP-SEKOLAH.md) bagian autostart untuk prasyarat auto-login.
9. Buka **https://gurubot.sekolah** atau **https://\<IP-SERVER\>**

### macOS

1. Prasyarat: `brew install --cask docker mysql mkcert` + Ollama
2. Import dump MySQL
3. `cp config/.env.docker.example .env.docker` (edit `DATABASE_URL`; secret NEXTAUTH/JWT digenerate otomatis oleh `setup.sh`)
4. `./scripts/setup.sh` → `./scripts/setup-ssl.sh`
5. `./scripts/docker-up.sh` (Docker + Technitium DNS otomatis)
6. `./scripts/setup-ssl-mobile.sh` → `./scripts/show-server-info.sh`

## Struktur

```
config/          nginx legacy, PM2, .env, .env.docker.example
docker/          Dockerfile app, ocr, whisper + nginx.conf HTTPS
docker-compose.yml   app, ocr, whisper, nginx, dns (Technitium)
certs/           Sertifikat mkcert (generate lokal, gitignored)
scripts/         docker-up.bat, setup-ssl.bat, setup-dns.bat (Technitium),
                 setup-autostart.bat, autostart-guard.bat, setup.bat (legacy PM2), ...
artifacts/
  nextjs/        Standalone Next.js + OCR source
  whisper/       STT Calistung (Python)
  llm/           Panduan Ollama
tools/           Acrylic, ffmpeg, NSSM (khusus jalur legacy PM2)
```

## Operasi

| Fungsi | Windows | macOS |
|--------|---------|-------|
| Docker up/down | `docker-up.bat` / `docker-down.bat` | `docker-up.sh` / `docker-down.sh` |
| Health check | `docker-health-check.bat` | `docker-health-check.sh` |
| SSL server | `setup-ssl.bat` | `setup-ssl.sh` |
| Export CA mobile | `setup-ssl-mobile.bat` | `setup-ssl-mobile.sh` |
| Info IP sekolah | `show-server-info.bat` | `show-server-info.sh` |
| DNS LAN (Technitium) | otomatis via `docker-up.bat` / `setup-dns.bat` | otomatis via `docker-up.sh` |
| Autostart saat boot | `setup-autostart.bat` (Windows saja) | — (jalankan `docker-up.sh` manual setelah login) |
| Setup awal (legacy PM2) | `setup.bat` | `setup.sh` |

## Port

| Layanan | Port | Akses |
|---------|------|-------|
| nginx HTTPS (Docker) | 443 | LAN via `https://gurubot.sekolah` |
| nginx HTTP redirect | 80 | Redirect ke 443 |
| Next.js (Docker internal) | 2050 | Hanya jaringan Docker |
| OCR (Docker internal) | 2059 | Hanya jaringan Docker |
| Whisper (Docker internal) | 2063 | Hanya jaringan Docker |
| DNS (Technitium, Docker) | 53/udp, 53/tcp | LAN (query DNS) |
| DNS admin console (Technitium) | 5380 | Loopback PC server saja |
| Ollama (host) | 11434 | localhost / host.docker.internal |
| MySQL (host) | 3306 | host.docker.internal |

Perangkat LAN **tidak** perlu akses `:2059`, `:2063`, atau `:5380` — browser hanya ke `https://gurubot.sekolah`.

## Dokumentasi

- [docs/PANDUAN-LENGKAP-SEKOLAH.md](docs/PANDUAN-LENGKAP-SEKOLAH.md) — **panduan lengkap end-to-end + autostart**
- [docs/DEPLOY-SEKOLAH.md](docs/DEPLOY-SEKOLAH.md) — deploy sekolah (Android, IP, SSL)
- [docs/BUILD-ARTIFACT.md](docs/BUILD-ARTIFACT.md) — build artifact dari gurubot-pwa
- [docs/INSTALL.md](docs/INSTALL.md) — panduan lengkap + rebuild HTTPS
- [docs/SSL.md](docs/SSL.md) — mkcert + trust CA di HP
- [docs/DNS-LAN.md](docs/DNS-LAN.md) — DNS Technitium + router
- [docs/UPDATE.md](docs/UPDATE.md) — prosedur update versi
- [artifacts/llm/README.md](artifacts/llm/README.md) — Ollama + Qwen
