@echo off
setlocal EnableDelayedExpansion
title GuruBot - SSL Mobile (export root CA)

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot - Trust SSL di HP/Tablet
echo ============================================
echo.

where mkcert >nul 2>&1
if errorlevel 1 (
  echo [ERROR] mkcert tidak ditemukan. Jalankan: scripts\setup-ssl.bat
  pause
  exit /b 1
)

set "OUT_DIR=%BUNDLE_ROOT%\certs\mobile"
set "OUT_FILE=%OUT_DIR%\gurubot-mkcert-rootCA.pem"

for /f "delims=" %%D in ('mkcert -CAROOT 2^>nul') do set "CA_DIR=%%D"
set "CA_FILE=%CA_DIR%\rootCA.pem"

if not exist "%CA_FILE%" (
  echo [ERROR] rootCA.pem tidak ada. Jalankan dulu: scripts\setup-ssl.bat
  pause
  exit /b 1
)

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
copy /Y "%CA_FILE%" "%OUT_FILE%" >nul

echo File CA untuk perangkat Android/tablet:
echo   %OUT_FILE%
echo.
echo --- Android ---
echo 1. Salin file ke HP ^(USB / WhatsApp / Drive^)
echo 2. Settings - Security - Encryption ^& credentials
echo 3. Install a certificate - CA certificate
echo 4. Pilih gurubot-mkcert-rootCA.pem
echo.
echo --- Verifikasi ---
for /f "delims=" %%I in ('call "%~dp0lib\detect-lan-ip.bat" 2^>nul') do set "LAN_IP=%%I"
if defined LAN_IP (
  echo Buka https://%LAN_IP%/welcome — tanpa peringatan SSL
) else (
  echo Buka https://IP-SERVER-SEKOLAH/welcome — tanpa peringatan SSL
)
echo.
echo Lihat docs\DEPLOY-SEKOLAH.md untuk panduan lengkap.
echo.
start "" explorer "%OUT_DIR%"
pause
exit /b 0
