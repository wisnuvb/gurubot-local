@echo off
setlocal EnableDelayedExpansion
title GuruBot - Setup DNS (Technitium)

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot - Setup DNS LAN (Technitium)
echo ============================================
echo.

REM --- Ambil password admin Technitium dari .env.docker ---
call "%~dp0lib\common.bat" get_env_value DNS_SERVER_ADMIN_PASSWORD
set "DNS_PASS=%ENV_VALUE%"
if not defined DNS_PASS (
  echo [ERROR] DNS_SERVER_ADMIN_PASSWORD tidak ditemukan di .env.docker
  echo         Jalankan scripts\docker-up.bat dulu supaya .env.docker + secret otomatis dibuat.
  exit /b 1
)

REM --- Deteksi IP LAN ---
set "LAN_IP="
for /f "delims=" %%I in ('call "%SCRIPTS_DIR%\lib\detect-lan-ip.bat" 2^>nul') do set "LAN_IP=%%I"
if not defined LAN_IP (
  echo [WARN] IP LAN tidak terdeteksi — pakai 127.0.0.1 ^(HP di WiFi lain tidak akan bisa resolve^)
  set "LAN_IP=127.0.0.1"
)
echo IP LAN server: %LAN_IP%
echo.

REM --- Jalankan orkestrasi Technitium via PowerShell ---
REM Password dilewatkan via env var (bukan argumen) supaya tidak tampil di daftar proses.
set "GURUBOT_DNS_ADMIN_PASSWORD=%DNS_PASS%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\lib\setup-dns-technitium.ps1" -LanIp "%LAN_IP%" -Domain "gurubot.sekolah"
set "PS_RESULT=%ERRORLEVEL%"
set "GURUBOT_DNS_ADMIN_PASSWORD="
set "DNS_PASS="

echo.
if "%PS_RESULT%"=="0" (
  echo [OK] DNS LAN siap.
  echo      Router DHCP DNS bisa diarahkan ke IP server ini agar semua HP otomatis resolve gurubot.sekolah.
) else (
  echo [WARN] Setup DNS belum sepenuhnya sukses — lihat pesan di atas.
  echo        Diagnosa: docker compose logs dns
  echo        Admin console Technitium ^(di PC server saja^): http://127.0.0.1:15380
)
exit /b %PS_RESULT%
