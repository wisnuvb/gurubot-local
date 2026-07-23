# Tools — binary portable

Folder ini berisi binary pihak ketiga yang **tidak** disertakan di git.

> **Jalur Docker (disarankan) tidak butuh folder ini sama sekali.** nginx dan DNS (Technitium) sudah jadi container di `docker-compose.yml`, ffmpeg sudah ada di image Whisper. Semua isi file ini (nginx win64, Apache, NSSM, Acrylic DNS) hanya relevan untuk jalur **legacy PM2** (`scripts/setup.bat` + `setup-services.bat`).

## nginx

1. Unduh **nginx/Windows** win64 stable dari https://nginx.org/en/download.html
2. Ekstrak zip — isinya hanya **`nginx.exe`** (tanpa DLL terpisah; itu normal untuk build resmi Windows)
3. Salin `nginx.exe` ke `tools/nginx/`
4. `setup.bat` menyalin `config/nginx.conf` dan `config/mime.types`, membuat folder `logs/` dan `temp/`

> Jika `nginx.exe -t` gagal, pastikan `mime.types` ada di folder yang sama dan port 80 tidak dipakai Apache/XAMPP.

## Apache XAMPP (alternatif nginx)

Jika memakai **Apache XAMPP** sebagai reverse proxy port 80, nginx tidak wajib.

1. Aktifkan modul proxy di `C:\xampp\apache\conf\httpd.conf`
2. Salin isi `config/apache-vhost.conf` ke `conf/extra/httpd-vhosts.conf`
3. Restart Apache — **jangan** jalankan `GuruBot-Nginx` (NSSM) bersamaan

Lihat [docs/INSTALL.md](../docs/INSTALL.md) bagian Apache.

## NSSM

1. Unduh NSSM 2.24 win64
2. Salin `win64/nssm.exe` ke `tools/nssm/nssm.exe`

## Acrylic DNS Proxy

Acrylic **bukan** satu file `.exe` portable seperti nginx. Yang dibutuhkan service Windows:

1. Unduh dan **instal** [Acrylic DNS Proxy](https://mayakron.altervista.org/wikibase/show.php?id=AcrylicHome) di PC server (atau PC build, lalu salin file)
2. Dari folder instalasi (biasanya `C:\Program Files (x86)\Acrylic DNS Proxy\`), salin ke `tools/acrylic/`:
   - **`AcrylicService.exe`** (wajib — untuk NSSM `GuruBot-DNS`)
   - `AcrylicConsole.exe` (opsional)
   - `AcrylicConfiguration.ini` (opsional — `setup.bat` generate dari template)
3. `setup.bat` menulis `AcrylicConfiguration.ini` dari `config/acrylic.template.ini`

> File `Acrylic.exe` kecil di repo bukan pengganti `AcrylicService.exe`. Tanpa `AcrylicService.exe`, DNS LAN service dilewati (hosts + fallback IP tetap bisa dipakai).

## ffmpeg

1. Unduh ffmpeg win64 static build
2. Salin `ffmpeg.exe` ke `tools/ffmpeg/ffmpeg.exe`
3. Whisper membutuhkan ffmpeg di PATH — PM2 ecosystem menambahkan `tools\ffmpeg` saat runtime
