# Portal operator sekolah (PC server saja)

**Terpisah** dari aplikasi guru/siswa di **https://gurubot.sekolah**.

| | URL |
|---|-----|
| **Aplikasi sekolah** (HP, guru, siswa) | https://gurubot.sekolah/welcome |
| **Portal operator** (TU / admin IT, hanya di laptop server) | **http://127.0.0.1:2077/** |

## Membuka portal

```bat
scripts\open-operator-portal.bat
```

Atau pastikan agent jalan lalu buka manual: `http://127.0.0.1:2077/`

```bat
scripts\ensure-setup-agent.bat
scripts\start-setup-agent.bat
```

PIN: `OPERATOR_SETUP_PIN` di `.env.docker` (generate: `scripts\ensure-operator-env.bat`).

## Komponen

| Bagian | Lokasi |
|--------|--------|
| UI + API | [`scripts/setup-agent/server.py`](../scripts/setup-agent/server.py) + [`static/`](../scripts/setup-agent/static/) |
| Health JSON | [`scripts/lib/health-check.ps1`](../scripts/lib/health-check.ps1) |

Domain **gurubot.sekolah** tidak lagi memuat `/operator` — nginx hanya meneruskan ke Next.js (app sekolah).

## Integrasi gurubot-pwa

Tidak perlu route `/operator` di PWA. Patch opsional [`gurubot-pwa-patch/`](../gurubot-pwa-patch/) untuk proxy API bisa diabaikan jika hanya memakai agent lokal.

## Troubleshooting

| Gejala | Penyebab | Solusi |
|--------|----------|--------|
| `ERR_CONNECTION_REFUSED` di :2077 | Agent tidak jalan (proses ditutup atau gagal start) | `scripts\start-setup-agent.bat` — biarkan jendela terbuka, atau `ensure-setup-agent.bat` |
| Log: Python tidak ditemukan | Python tidak di PATH | Install Python 3.12+ dari python.org, centang "Add to PATH", atau `py -3` |
| Port 2077 listen tapi PIN gagal | Token/PIN belum digenerate | `scripts\ensure-operator-env.bat` |
| `502` di **http://192.168.x.x/** header `nginx/1.30.x` | **nginx lain di Windows** ikut pakai port 80 (bukan container GuruBot) | Stop nginx host: `taskkill /IM nginx.exe /F` (atau stop XAMPP). Pakai **https://gurubot.sekolah/welcome** atau **https://IP/welcome** |

Agent **bukan** container Docker — harus ada proses Python di Windows host (`127.0.0.1:2077`). Menutup jendela "GuruBot Setup Agent" = portal mati.
