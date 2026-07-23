@echo off
setlocal EnableDelayedExpansion
title GuruBot - Docker Up

call "%~dp0lib\common.bat"

set "ENV_DOCKER=%BUNDLE_ROOT%\.env.docker"
set "ENV_EXAMPLE=%CONFIG_DIR%\.env.docker.example"
set "CERT_FILE=%BUNDLE_ROOT%\certs\gurubot.sekolah.pem"
set "KEY_FILE=%BUNDLE_ROOT%\certs\gurubot.sekolah-key.pem"

echo ============================================
echo  GuruBot - Docker Compose Up
echo ============================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker tidak ditemukan. Instal Docker Desktop untuk Windows.
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Docker daemon tidak berjalan. Buka Docker Desktop lalu coba lagi.
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)

if not exist "%ENV_DOCKER%" (
  if exist "%ENV_EXAMPLE%" (
    echo [INFO] Membuat .env.docker dari template...
    copy /Y "%ENV_EXAMPLE%" "%ENV_DOCKER%" >nul

    echo [INFO] Generate secret otomatis ^(NEXTAUTH_SECRET, JWT_SECRET, DNS_SERVER_ADMIN_PASSWORD^)...
    call "%~dp0lib\common.bat" generate_secret
    call "%~dp0lib\common.bat" set_env_value NEXTAUTH_SECRET "!GENERATED_SECRET!"
    call "%~dp0lib\common.bat" generate_secret
    call "%~dp0lib\common.bat" set_env_value JWT_SECRET "!GENERATED_SECRET!"
    call "%~dp0lib\common.bat" generate_secret
    call "%~dp0lib\common.bat" set_env_value DNS_SERVER_ADMIN_PASSWORD "!GENERATED_SECRET!"

    echo [INFO] Generate token portal operator...
    call "%~dp0ensure-operator-env.bat"

    echo [WARN] Edit %ENV_DOCKER% — isi DATABASE_URL ^(user/password MySQL^) sebelum lanjut.
    echo        Secret NEXTAUTH_SECRET/JWT_SECRET/DNS_SERVER_ADMIN_PASSWORD sudah digenerate otomatis.
  ) else (
    echo [ERROR] Template tidak ditemukan: %ENV_EXAMPLE%
    if not defined GURUBOT_NONINTERACTIVE pause
    exit /b 1
  )
)

call "%~dp0ensure-operator-env.bat"

if not exist "%CERT_FILE%" (
  echo [ERROR] Sertifikat belum ada: %CERT_FILE%
  echo        Jalankan: scripts\setup-ssl.bat
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)
if not exist "%KEY_FILE%" (
  echo [ERROR] Private key belum ada: %KEY_FILE%
  echo        Jalankan: scripts\setup-ssl.bat
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)

cd /d "%BUNDLE_ROOT%"

echo [INFO] Build dan start container...
docker compose up -d --build
if errorlevel 1 (
  echo [ERROR] docker compose up gagal.
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)

echo.
echo [INFO] Menunggu healthcheck (maks ~60 detik)...
timeout /t 15 /nobreak >nul

echo.
docker compose ps
echo.

call "%~dp0docker-health-check.bat"
set "HC=%ERRORLEVEL%"

echo.
echo [INFO] Konfigurasi DNS LAN (Technitium) — gurubot.sekolah -^> IP LAN server...
call "%~dp0setup-dns.bat"

call "%~dp0ensure-setup-agent.bat"
echo [INFO] Portal operator (PC server saja): http://127.0.0.1:2077/ ^(scripts\open-operator-portal.bat^)

echo.
if "%HC%"=="0" (
  echo [OK] GuruBot Docker berjalan — buka https://gurubot.sekolah
) else (
  echo [WARN] Beberapa health check gagal — lihat: docker compose logs
)
echo.
if not defined GURUBOT_NONINTERACTIVE pause
exit /b %HC%
