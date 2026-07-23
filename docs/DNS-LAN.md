# DNS LAN — gurubot.sekolah

Agar semua perangkat di WiFi yang sama bisa mengakses GuruBot via **https://gurubot.sekolah** (tanpa port), jalur Docker memakai **Technitium DNS Server** — berjalan sebagai container Docker (`gurubot-dns`), sama persis di Windows maupun macOS. Tidak perlu install Acrylic atau dnsmasq lagi untuk jalur ini.

## Arsitektur

```
[HP/Tablet] --DNS query--> [Router DHCP DNS = IP PC server]
                                |
                                v
                    [Technitium DNS (container) :53]
                    gurubot.sekolah -> 192.168.x.x
                                |
                                v
                    [nginx Docker :443] -> [Next.js :2050]
```

OCR (:2059) dan Whisper (:2063) **tidak** diakses langsung dari HP — hanya internal Docker network. Admin console Technitium (:5380) juga cuma bisa diakses dari PC server sendiri (`127.0.0.1:5380`), bukan dari LAN.

## Cara kerja otomatis

`scripts\docker-up.bat` (Windows) / `scripts/docker-up.sh` (macOS) otomatis menjalankan `scripts\setup-dns.bat` setelah container naik, yang:

1. Login ke API Technitium (password dari `DNS_SERVER_ADMIN_PASSWORD` di `.env.docker`, digenerate otomatis saat `.env.docker` pertama kali dibuat).
2. Membuat zone `gurubot.sekolah` dan record A yang menunjuk ke **IP LAN server saat ini** (auto-deteksi, sama seperti mkcert).
3. Mengarahkan DNS adapter Windows aktif ke `127.0.0.1` (primer) + `8.8.8.8` (sekunder) supaya PC server sendiri ikut resolve `gurubot.sekolah`.
4. Menambah entri hosts sebagai fallback lokal.

Karena idempotent, script ini aman dijalankan berkali-kali — termasuk otomatis dipanggil ulang oleh `autostart-guard.bat` setiap laptop boot, sehingga **IP server yang berubah setelah reboot/pindah router otomatis ter-update** tanpa langkah manual.

## Setup router — supaya semua HP otomatis resolve

Ini satu-satunya langkah manual yang tersisa, dan sifatnya **per sekolah/router**, bukan per laptop:

Atur **DHCP DNS Server** di router WiFi kelas ke IP LAN PC server (lihat `scripts\show-server-info.bat`):

| Router | Lokasi setting |
|--------|----------------|
| TP-Link | DHCP → Primary DNS = IP PC server |
| Mikrotik | IP → DHCP Server → Networks → DNS Server |
| IndiHome ONT | LAN → DHCP → DNS (jika tersedia) |

Perangkat WiFi perlu **renew DHCP** (reconnect WiFi) setelah perubahan ini.

## Verifikasi

Di PC server:

```powershell
nslookup gurubot.sekolah 127.0.0.1
ping gurubot.sekolah
curl.exe -k https://gurubot.sekolah/api/health
scripts\docker-health-check.bat
```

Dari HP (browser, setelah CA di-trust dan router DNS diarahkan): **https://gurubot.sekolah**

Portal operator (setup server, hanya di PC server): **http://127.0.0.1:2077/** — lihat [OPERATOR-PORTAL.md](OPERATOR-PORTAL.md). Aplikasi sekolah: **https://gurubot.sekolah/welcome**.

Admin console Technitium untuk cek query log / record manual (di PC server saja): **http://127.0.0.1:15380** (port host; di dalam container tetap 5380). Di Windows port 5380 sering diblokir Hyper-V — lihat `docker-compose.yml`.

---

## Fallback — tanpa ubah router DNS

Jika router tidak bisa diubah (SD tertinggal, dsb.), skip setup router dan pakai **IP langsung + QR code**:

```
https://<IP-SERVER>/welcome
```

`setup-ssl.bat` otomatis menyertakan IP LAN di sertifikat, jadi ini tetap HTTPS valid. Lihat [DEPLOY-SEKOLAH.md](DEPLOY-SEKOLAH.md).

## hosts manual per perangkat (opsional)

Kalau cuma butuh 1-2 device tanpa setting router:

```
192.168.1.50   gurubot.sekolah
```

---

## Jalur legacy (Acrylic / dnsmasq) — non-Docker saja

Skrip lama `scripts\setup.bat` (Windows, PM2) masih memakai **Acrylic DNS** sebagai NSSM service, dan `scripts/setup-dns.sh` (macOS) masih mendokumentasikan **dnsmasq** manual. Ini **hanya relevan jika benar-benar tidak memakai Docker Compose** — untuk deploy Docker (disarankan), abaikan bagian ini sepenuhnya, Technitium sudah menggantikannya.

## Troubleshooting

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| `nslookup` gagal | Container `dns` belum jalan / port 53 dipakai proses lain | `docker compose ps`; `docker compose logs dns`; cek `netstat -ano \| findstr :53` |
| Resolve ke IP salah / lama | Belum sempat auto-update sejak IP berubah | Jalankan ulang `scripts\setup-dns.bat` manual, atau restart laptop (autostart-guard akan re-run) |
| HP tidak resolve | Router DNS belum diarahkan ke IP server | Set DHCP DNS router, atau pakai fallback IP + QR |
| Browser warning sertifikat | CA belum di-trust di HP | [SSL.md](SSL.md) — install `rootCA.pem` |
| HTTP redirect ke HTTPS | By design | Pakai `https://gurubot.sekolah` |
| Login Technitium API gagal di `setup-dns.bat` | `.env.docker` diedit setelah container `dns` pernah start (password lama tetap dipakai) | `docker compose down`; `docker volume rm <project>_dns-config`; jalankan `docker-up.bat` lagi |
