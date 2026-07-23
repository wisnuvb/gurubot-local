@echo off
setlocal EnableDelayedExpansion
title GuruBot - Setup SSL (mkcert)

call "%~dp0lib\common.bat"

set "CERTS_DIR=%BUNDLE_ROOT%\certs"
set "CERT_FILE=%CERTS_DIR%\gurubot.sekolah.pem"
set "KEY_FILE=%CERTS_DIR%\gurubot.sekolah-key.pem"

echo ============================================
echo  GuruBot - Generate sertifikat HTTPS lokal
echo ============================================
echo.

where mkcert >nul 2>&1
if errorlevel 1 (
  echo [ERROR] mkcert tidak ditemukan di PATH.
  echo.
  echo Instal mkcert untuk Windows:
  echo   choco install mkcert
  echo   atau unduh dari https://github.com/FiloSottile/mkcert/releases
  echo.
  pause
  exit /b 1
)

if not exist "%CERTS_DIR%" mkdir "%CERTS_DIR%"

echo [1/3] Install root CA mkcert di PC server (butuh Admin untuk trust otomatis)...
mkcert -install 2>nul
if errorlevel 1 (
  echo [WARN] mkcert -install gagal — jalankan skrip ini sebagai Administrator.
)

echo.
echo [2/3] Deteksi IP LAN...
set "LAN_IP="
for /f "delims=" %%I in ('call "%~dp0lib\detect-lan-ip.bat" 2^>nul') do set "LAN_IP=%%I"

set "MKCERT_ARGS=gurubot.sekolah localhost 127.0.0.1"
if defined LAN_IP (
  echo IP LAN: !LAN_IP!
  set "MKCERT_ARGS=!MKCERT_ARGS! !LAN_IP!"
) else (
  echo [WARN] IP LAN tidak terdeteksi — sertifikat tanpa IP fallback.
)

echo.
echo [3/3] Generate sertifikat ke %CERTS_DIR%...
cd /d "%CERTS_DIR%"
mkcert -cert-file "%CERT_FILE%" -key-file "%KEY_FILE%" %MKCERT_ARGS%
if errorlevel 1 (
  echo [ERROR] mkcert gagal generate sertifikat.
  pause
  exit /b 1
)

echo.
echo [OK] Sertifikat siap:
echo   %CERT_FILE%
echo   %KEY_FILE%
echo.
echo Langkah berikutnya:
echo   1. Salin root CA ke HP/tablet (lihat docs\SSL.md)
echo   2. copy config\.env.docker.example .env.docker  (jika belum)
echo   3. scripts\docker-up.bat
echo.
pause
exit /b 0
