@echo off
setlocal EnableDelayedExpansion
title GuruBot - Start Nginx

call "%~dp0lib\common.bat"

echo ============================================
echo  Start nginx (port 80 -^> Next.js :2050)
echo ============================================
echo NGINX_DIR=%NGINX_DIR%
echo.

if not exist "%NGINX_DIR%\nginx.exe" (
  echo [ERROR] nginx.exe tidak ada di tools\nginx\
  echo Unduh dari https://nginx.org/en/download.html lalu salin ke tools\nginx\
  pause
  exit /b 1
)

if not exist "%NGINX_DIR%\nginx.conf" (
  echo [INFO] nginx.conf belum ada — salin dari config...
  if not exist "%NGINX_DIR%\logs" mkdir "%NGINX_DIR%\logs"
  copy /Y "%CONFIG_DIR%\nginx.conf" "%NGINX_DIR%\nginx.conf" >nul
  copy /Y "%CONFIG_DIR%\mime.types" "%NGINX_DIR%\mime.types" >nul
)

echo --- Cek port 80 ---
netstat -ano | findstr ":80 " | findstr "LISTENING"
if not errorlevel 1 (
  echo [WARN] Port 80 masih dipakai. Pastikan Apache/XAMPP sudah STOP.
  echo        Lanjutkan hanya jika proses di atas bukan Apache.
  echo.
)

pushd "%NGINX_DIR%"
echo --- Test config ---
nginx.exe -t -p "%NGINX_DIR%" -c nginx.conf
if errorlevel 1 (
  popd
  pause
  exit /b 1
)

if exist "%NSSM_EXE%" (
  "%NSSM_EXE%" status GuruBot-Nginx >nul 2>&1
  if not errorlevel 1 (
    echo --- Start service NSSM GuruBot-Nginx ---
    "%NSSM_EXE%" start GuruBot-Nginx
    goto :after_start
  )
)

echo --- Start nginx manual (belum terdaftar NSSM) ---
nginx.exe -s stop 2>nul
timeout /t 1 /nobreak >nul
start "" nginx.exe -p "%NGINX_DIR%" -c nginx.conf
echo [INFO] Untuk autostart, jalankan setup-services.bat sebagai Administrator

:after_start
popd

echo.
echo --- Test proxy ---
curl -sf --max-time 5 http://gurubot.sekolah/api/health >nul 2>&1
if errorlevel 1 (
  echo [FAIL] http://gurubot.sekolah/api/health — pastikan PM2 gurubot-app jalan di :2050
  echo        Jalankan: scripts\start-pm2.bat
) else (
  echo [ OK ] nginx proxy ke Next.js berhasil
)

echo.
pause
exit /b 0
