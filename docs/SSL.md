# HTTPS Lokal — mkcert + gurubot.sekolah

GuruBot deploy Docker memakai **HTTPS** di `https://gurubot.sekolah` agar mic/kamera di HP/tablet berfungsi (secure context). Sertifikat dibuat dengan **mkcert** — CA lokal, bukan Let's Encrypt.

## 1. Generate sertifikat di PC server

```powershell
scripts\setup-ssl.bat
```

Skrip ini:

- Menjalankan `mkcert -install` (trust CA di Windows server)
- Mendeteksi IP LAN dan memasukkannya ke SAN sertifikat
- Menulis file ke `certs/`:
  - `gurubot.sekolah.pem`
  - `gurubot.sekolah-key.pem`

Prasyarat: [mkcert](https://github.com/FiloSottile/mkcert) di PATH (`choco install mkcert`).

## 2. Lokasi root CA mkcert

Setelah `mkcert -install`, root CA disimpan di:

```
%LOCALAPPDATA%\mkcert\rootCA.pem
```

File ini yang perlu dibagikan ke HP/tablet agar browser mempercayai `https://gurubot.sekolah`.

## 3. Trust CA di perangkat lain

### Windows (PC lain di LAN)

1. Salin `rootCA.pem` ke PC tersebut
2. Double-click → **Install Certificate** → **Local Machine** → **Trusted Root Certification Authorities**

### Android

1. Salin `rootCA.pem` ke HP (USB / share)
2. **Settings → Security → Encryption & credentials → Install a certificate → CA certificate**
3. Pilih `rootCA.pem`
4. Reconnect WiFi jika perlu

### iOS / iPadOS

1. Kirim `rootCA.pem` ke perangkat (AirDrop / email)
2. Buka file → **Install Profile**
3. **Settings → General → About → Certificate Trust Settings** → aktifkan trust untuk mkcert root CA

Tanpa langkah ini, browser menampilkan peringatan sertifikat dan **getUserMedia (mic)** bisa gagal.

## 4. Verifikasi

Di PC server:

```powershell
curl.exe -k https://gurubot.sekolah/api/health
scripts\docker-health-check.bat
```

Di HP (setelah trust CA): buka `https://gurubot.sekolah` — tidak ada peringatan sertifikat.

## 5. Fallback IP

Jika akses via `https://192.168.x.x`, IP harus ada di sertifikat saat generate:

```powershell
scripts\setup-ssl.bat
```

Skrip otomatis menambahkan IP LAN. Set juga di `.env.docker`:

```env
NEXTAUTH_URL=https://192.168.1.50
NEXT_PUBLIC_API_URL=https://192.168.1.50
```

> `NEXT_PUBLIC_API_URL` tersemat saat build Next.js — untuk fallback IP penuh, rebuild artifact dengan URL tersebut.

## 6. Troubleshooting

| Gejala | Solusi |
|--------|--------|
| `NET::ERR_CERT_AUTHORITY_INVALID` di HP | Install `rootCA.pem` di perangkat |
| nginx tidak start | Cek `certs/gurubot.sekolah.pem` ada; jalankan `setup-ssl.bat` |
| Mic gagal di HP padahal HTTPS OK | Pastikan URL `https://gurubot.sekolah` bukan IP tanpa trust |
| Redirect loop login | `NEXTAUTH_URL` harus persis `https://gurubot.sekolah` |

## 7. Keamanan

- Root CA mkcert hanya untuk jaringan lokal / lab — jangan dipakai di internet publik.
- Jangan commit `certs/` atau `rootCA.pem` ke git (sudah di `.gitignore`).
