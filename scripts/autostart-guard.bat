@echo off
setlocal EnableDelayedExpansion
title GuruBot - Autostart Guard

REM Dipanggil otomatis oleh Task Scheduler saat akun server login (lihat setup-autostart.bat).
REM Tujuan: pastikan Docker + DNS (Technitium) + MySQL + Ollama semua jalan tanpa
REM intervensi manual setiap laptop dinyalakan. Aman dijalankan berkali-kali (idempotent).

call "%~dp0lib\common.bat"

if not exist "%BUNDLE_ROOT%\logs" mkdir "%BUNDLE_ROOT%\logs"
for /f "delims=" %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd"') do set "LOGDATE=%%D"
set "LOGFILE=%BUNDLE_ROOT%\logs\autostart-%LOGDATE%.log"

call :log "=== GuruBot autostart-guard mulai ==="

REM --- 1. Tunggu Docker Desktop / daemon siap (maks ~5 menit) ---
set "DOCKER_READY=0"
for /l %%i in (1,1,60) do (
  if "!DOCKER_READY!"=="0" (
    docker info >nul 2>&1
    if not errorlevel 1 (
      set "DOCKER_READY=1"
    ) else (
      timeout /t 5 /nobreak >nul
    )
  )
)
if "!DOCKER_READY!"=="0" (
  call :log "[ERROR] Docker daemon tidak siap setelah 5 menit - batal. Cek Docker Desktop manual."
  exit /b 1
)
call :log "[ OK ] Docker daemon siap"

REM --- 2. Start container (tanpa rebuild - cepat, image sudah ada dari setup awal) ---
cd /d "%BUNDLE_ROOT%"
docker compose up -d >> "%LOGFILE%" 2>&1
if errorlevel 1 (
  call :log "[ERROR] docker compose up -d gagal - lihat %LOGFILE%"
) else (
  call :log "[ OK ] docker compose up -d selesai"
)

REM --- 3. Konfigurasi ulang DNS (Technitium) - jaga-jaga IP LAN berubah setelah reboot ---
call "%SCRIPTS_DIR%\setup-dns.bat" >> "%LOGFILE%" 2>&1
call :log "[INFO] setup-dns.bat selesai (exit %ERRORLEVEL%) - detail di %LOGFILE%"

call "%SCRIPTS_DIR%\ensure-setup-agent.bat" >> "%LOGFILE%" 2>&1
call :log "[INFO] ensure-setup-agent selesai"

REM --- 4. Pastikan service MySQL RUNNING ---
set "MYSQL_UP=0"
sc query MySQL80 2>nul | findstr /i "RUNNING" >nul 2>&1
if not errorlevel 1 set "MYSQL_UP=1"
if "!MYSQL_UP!"=="0" (
  sc query MySQL 2>nul | findstr /i "RUNNING" >nul 2>&1
  if not errorlevel 1 set "MYSQL_UP=1"
)
if "!MYSQL_UP!"=="0" (
  call :log "[WARN] Service MySQL belum RUNNING - mencoba net start..."
  net start MySQL80 >nul 2>&1
  net start MySQL >nul 2>&1
) else (
  call :log "[ OK ] Service MySQL RUNNING"
)

REM --- 5. Cek Ollama (retry ~1 menit, warn only - tray app perlu waktu start setelah login) ---
set "OLLAMA_READY=0"
for /l %%i in (1,1,12) do (
  if "!OLLAMA_READY!"=="0" (
    curl -sf --max-time 3 http://127.0.0.1:11434/api/tags >nul 2>&1
    if not errorlevel 1 (
      set "OLLAMA_READY=1"
    ) else (
      timeout /t 5 /nobreak >nul
    )
  )
)
if "!OLLAMA_READY!"=="1" (
  call :log "[ OK ] Ollama merespons"
) else (
  call :log "[WARN] Ollama belum merespons setelah 1 menit - cek tray app Ollama manual (fitur Analisa AI akan gagal sampai Ollama siap)."
)

call :log "=== GuruBot autostart-guard selesai ==="
exit /b 0

:log
echo [%date% %time%] %~1
echo [%date% %time%] %~1 >> "%LOGFILE%"
goto :eof
