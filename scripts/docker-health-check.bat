@echo off
setlocal EnableDelayedExpansion
title GuruBot - Docker Health Check

call "%~dp0lib\common.bat"

set "FAIL=0"
set "WARN=0"

echo ============================================
echo  GuruBot Docker Health Check
echo ============================================
echo.

call :check_nginx_https

call :check "Ollama Qwen (host)" "http://127.0.0.1:11434/api/tags" ""

set "LAN_IP="
for /f "delims=" %%I in ('call "%SCRIPTS_DIR%\lib\detect-lan-ip.bat" 2^>nul') do set "LAN_IP=%%I"
call :check_dns_optional

docker compose ps 2>nul
echo.

call :check_docker "OCR internal" "gurubot-ocr" "http://127.0.0.1:2059/docs"
call :check_docker "Whisper /health" "gurubot-whisper" "http://127.0.0.1:2063/health"
call :check_docker_ready "Whisper /ready" "gurubot-whisper" "http://127.0.0.1:2063/ready"

echo.
if "%FAIL%"=="0" (
  if "%WARN%"=="0" (
    echo [OK] Semua check lulus.
  ) else (
    echo [OK] Check inti lulus — ada peringatan ^(model STT/OCR mungkin masih unduh^).
  )
) else (
  echo [FAIL] Ada service yang belum siap.
)
exit /b %FAIL%

:check_nginx_https
curl -sf --max-time 10 -k "https://gurubot.sekolah/api/health" >nul 2>&1
if not errorlevel 1 (
  echo [ OK ] nginx HTTPS - https://gurubot.sekolah/api/health
  goto :eof
)
curl -sf --max-time 10 -k -H "Host: gurubot.sekolah" "https://127.0.0.1/api/health" >nul 2>&1
if not errorlevel 1 (
  echo [ OK ] nginx HTTPS - https://127.0.0.1/api/health ^(Host: gurubot.sekolah^)
  goto :eof
)
echo [FAIL] nginx HTTPS - cek container gurubot-nginx dan certs\gurubot.sekolah.pem
set "FAIL=1"
goto :eof

:check
set "NAME=%~1"
set "URL=%~2"
set "EXTRA=%~3"
curl -sf --max-time 10 %EXTRA% "!URL!" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] !NAME! - !URL!
  set "FAIL=1"
) else (
  echo [ OK ] !NAME! - !URL!
)
goto :eof

:check_docker
set "NAME=%~1"
set "CONTAINER=%~2"
set "URL=%~3"
docker ps --filter "name=%CONTAINER%" --filter "status=running" -q 2>nul | findstr /r "." >nul 2>&1
if errorlevel 1 (
  echo [FAIL] !NAME! - container !CONTAINER! tidak running
  set "FAIL=1"
  goto :eof
)
docker exec "!CONTAINER!" curl -sf --max-time 10 "!URL!" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] !NAME! - !CONTAINER! !URL!
  set "FAIL=1"
) else (
  echo [ OK ] !NAME! - !CONTAINER!
)
goto :eof

:check_docker_ready
set "NAME=%~1"
set "CONTAINER=%~2"
set "URL=%~3"
docker ps --filter "name=%CONTAINER%" --filter "status=running" -q 2>nul | findstr /r "." >nul 2>&1
if errorlevel 1 (
  echo [FAIL] !NAME! - container !CONTAINER! tidak running
  set "FAIL=1"
  goto :eof
)
docker exec "!CONTAINER!" curl -sf --max-time 10 "!URL!" >nul 2>&1
if errorlevel 1 (
  echo [WARN] !NAME! - model masih unduh/muat, tunggu 5-15 menit lalu cek lagi
  set "WARN=1"
) else (
  echo [ OK ] !NAME! - !CONTAINER!
)
goto :eof

:check_dns_optional
docker ps --filter "name=gurubot-dns" --filter "status=running" -q 2>nul | findstr /r "." >nul 2>&1
if errorlevel 1 (
  echo [WARN] DNS Technitium - container gurubot-dns tidak jalan ^(lewati; jalankan docker compose up -d dns^)
  set "WARN=1"
  goto :eof
)
if not defined LAN_IP (
  echo [WARN] DNS gurubot.sekolah - IP LAN tidak terdeteksi, lewati verifikasi
  set "WARN=1"
  goto :eof
)
set "DOUT="
for /f "delims=" %%L in ('nslookup gurubot.sekolah 127.0.0.1 2^>nul ^| findstr /i "Address"') do set "DOUT=!DOUT! %%L"
echo !DOUT! | findstr /c:"!LAN_IP!" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] DNS gurubot.sekolah - tidak resolve ke !LAN_IP!. Output:!DOUT!
  echo        Jalankan: scripts\setup-dns.bat
  set "FAIL=1"
) else (
  echo [ OK ] DNS gurubot.sekolah -^> !LAN_IP!
)
goto :eof
