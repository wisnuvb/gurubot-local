@echo off
setlocal EnableDelayedExpansion
title GuruBot Setup Services

call "%~dp0lib\common.bat"
call "%~dp0lib\common.bat" require_admin

set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
set "PM2_FAILED=1"
if not exist "%PM2_HOME%" mkdir "%PM2_HOME%"

echo ============================================
echo  GuruBot - Setup Services (PM2 + NSSM)
echo ============================================
echo  PM2_HOME=%PM2_HOME%
echo  BUNDLE_ROOT=%BUNDLE_ROOT%
echo ============================================
echo.

call :setup_pm2
call :setup_nssm_nginx
call :setup_nssm_acrylic

echo.
echo Cek status PM2 (PM2_HOME=%PM2_HOME%):
pm2 status
echo.
if "!PM2_FAILED!"=="0" (
  echo [OK] PM2 apps terdaftar. Cek: scripts\health-check.bat
) else (
  echo [WARN] PM2 masih kosong — lihat pesan [ERROR] di atas.
  echo        Diagnostik: scripts\diagnose.bat
  echo        Coba manual: scripts\start-pm2.bat
)
pause
exit /b 0

:setup_pm2
call :log "PM2 setup..."

call :diag_file "Next.js server.js" "%NEXTJS_DIR%\server.js"
call :diag_file "OCR venv python" "%NEXTJS_DIR%\ml-training\venv\Scripts\python.exe"
call :diag_file "Whisper venv python" "%WHISPER_DIR%\venv\Scripts\python.exe"
echo.

if not exist "%NEXTJS_DIR%\server.js" (
  echo [ERROR] artifacts\nextjs\server.js tidak ada — jalankan setup.bat dulu.
  goto :eof
)
if not exist "%NEXTJS_DIR%\ml-training\venv\Scripts\python.exe" (
  echo [ERROR] OCR venv belum ada — jalankan setup.bat ulang sampai "OCR venv OK".
  goto :eof
)
if not exist "%WHISPER_DIR%\venv\Scripts\python.exe" (
  echo [ERROR] Whisper venv belum ada — jalankan setup.bat ulang sampai "Whisper venv OK".
  goto :eof
)

where pm2 >nul 2>&1
if errorlevel 1 (
  call :log "Instal PM2 global..."
  call npm install -g pm2 pm2-windows-startup
)

where pm2 >nul 2>&1
if errorlevel 1 (
  echo [ERROR] pm2 tidak ditemukan setelah npm install -g pm2
  goto :eof
)

where pm2 >nul 2>&1
if errorlevel 1 (
  echo [ERROR] pm2 tidak ditemukan setelah npm install -g pm2
  goto :eof
)

set "PATH=%TOOLS_DIR%\ffmpeg;%PATH%"

call "%~dp0lib\pm2-start-apps.bat"
if errorlevel 1 (
  echo [ERROR] pm2 start gagal.
  pm2 logs --lines 30 --nostream 2>nul
  goto :eof
)

where pm2-startup >nul 2>&1
if not errorlevel 1 pm2-startup install

set "PM2_FAILED=0"
call :log "PM2 apps started"
goto :eof

:setup_nssm_nginx
if not exist "%NSSM_EXE%" (
  echo [WARN] NSSM tidak ada di tools\nssm\nssm.exe — lewati service nginx
  goto :eof
)
if not exist "%NGINX_DIR%\nginx.exe" (
  echo [WARN] nginx.exe tidak ada — lewati service nginx
  goto :eof
)

netstat -ano | findstr /R /C:":80 .*LISTENING" >nul 2>&1
if not errorlevel 1 (
  echo [WARN] Port 80 sudah dipakai — lewati GuruBot-Nginx.
  echo        Jika pakai Apache XAMPP, cukup VirtualHost proxy ke :2050.
  echo        Jika ingin nginx, stop service yang memakai port 80 dulu.
  goto :eof
)

"%NSSM_EXE%" stop GuruBot-Nginx >nul 2>&1
"%NSSM_EXE%" remove GuruBot-Nginx confirm >nul 2>&1
"%NSSM_EXE%" install GuruBot-Nginx "%NGINX_DIR%\nginx.exe" "-p" "%NGINX_DIR%" "-c" "%NGINX_DIR%\nginx.conf"
"%NSSM_EXE%" set GuruBot-Nginx AppDirectory "%NGINX_DIR%"
"%NSSM_EXE%" set GuruBot-Nginx Start SERVICE_AUTO_START
"%NSSM_EXE%" start GuruBot-Nginx
call :log "NSSM GuruBot-Nginx OK"
goto :eof

:setup_nssm_acrylic
set "ACRYLIC_SVC=%TOOLS_DIR%\acrylic\AcrylicService.exe"
if not exist "%ACRYLIC_SVC%" (
  echo [WARN] AcrylicService.exe tidak ada — lewati DNS service
  echo        Jalankan tools\acrylic\Acrylic.exe installer di Windows
  goto :eof
)
if not exist "%NSSM_EXE%" goto :eof

"%NSSM_EXE%" stop GuruBot-DNS >nul 2>&1
"%NSSM_EXE%" remove GuruBot-DNS confirm >nul 2>&1
"%NSSM_EXE%" install GuruBot-DNS "%ACRYLIC_SVC%"
"%NSSM_EXE%" set GuruBot-DNS AppDirectory "%TOOLS_DIR%\acrylic"
"%NSSM_EXE%" set GuruBot-DNS Start SERVICE_AUTO_START
"%NSSM_EXE%" start GuruBot-DNS
call :log "NSSM GuruBot-DNS OK"
goto :eof

:diag_file
if exist "%~2" (
  echo [ OK ] %~1
) else (
  echo [MISS] %~1
)
goto :eof

:log
call "%~dp0lib\common.bat" log "%~1"
goto :eof
