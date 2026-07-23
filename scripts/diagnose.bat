@echo off
setlocal EnableDelayedExpansion
title GuruBot Diagnose

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot Diagnose
echo ============================================
echo BUNDLE_ROOT=%BUNDLE_ROOT%
echo PM2_HOME=%BUNDLE_ROOT%\.pm2
echo.

call :chk "server.js" "%NEXTJS_DIR%\server.js"
call :chk ".next BUILD_ID" "%NEXTJS_DIR%\.next\BUILD_ID"
call :chk "nextjs .env" "%NEXTJS_DIR%\.env"
call :chk "OCR venv" "%NEXTJS_DIR%\ml-training\venv\Scripts\python.exe"
call :chk "Whisper venv" "%WHISPER_DIR%\venv\Scripts\python.exe"
call :chk "nginx.exe" "%NGINX_DIR%\nginx.exe"
call :chk "pm2 CLI" ""

where pm2 >nul 2>&1
if errorlevel 1 (echo [MISS] pm2 CLI) else (echo [ OK ] pm2 CLI)

echo.
echo --- DATABASE_URL (.env) ---
if exist "%NEXTJS_DIR%\.env" (
  findstr /I /C:"DATABASE_URL" "%NEXTJS_DIR%\.env"
) else (
  echo [MISS] .env
)

echo.
echo --- Test MySQL ---
pushd "%NEXTJS_DIR%"
node "%SCRIPTS_DIR%\maintainer\test-db.js" "%NEXTJS_DIR%" 2>&1
popd

echo.
echo --- PM2 bundle (PM2_HOME=%BUNDLE_ROOT%\.pm2) ---
set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
pm2 status 2>nul
if errorlevel 1 echo [FAIL] pm2 status bundle

echo.
echo --- PM2 global (%USERPROFILE%\.pm2) ---
set "PM2_HOME=%USERPROFILE%\.pm2"
pm2 status 2>nul

echo.
echo --- Proses yang listen port 2050 ---
set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":2050" ^| findstr "LISTENING"') do (
  echo PID %%P:
  tasklist /FI "PID eq %%P" /FO TABLE /NH 2>nul
)
netstat -ano | findstr ":2050" | findstr "LISTENING" >nul 2>&1
if errorlevel 1 echo [FAIL] Tidak ada proses di port 2050 — halaman web tidak akan bisa load API

echo.
echo --- PM2 log terakhir (gurubot-app bundle) ---
if exist "%BUNDLE_ROOT%\.pm2\logs\gurubot-app-error.log" (
  powershell -NoProfile -Command "Get-Content '%BUNDLE_ROOT%\.pm2\logs\gurubot-app-error.log' -Tail 15"
) else (
  echo [MISS] .pm2\logs\gurubot-app-error.log
)

echo.
echo --- Port listen ---
netstat -ano | findstr ":2050 :2059 :2063 :80 :3306 " 2>nul

echo.
echo --- Prisma engine ---
findstr /I /C:"windows" "%NEXTJS_DIR%\node_modules\.prisma\client\index.js" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] Prisma masih Mac/Linux — jalankan: scripts\prisma-generate.bat
) else (
  echo [ OK ] Prisma engine Windows
)

echo.
echo --- Test API ---
curl -sf --max-time 3 http://127.0.0.1:2050/api/health 2>nul && echo [ OK ] Next.js :2050 || echo [FAIL] Next.js :2050 tidak merespons
curl -sf --max-time 3 http://gurubot.sekolah/api/health 2>nul && echo [ OK ] gurubot.sekolah || echo [FAIL] gurubot.sekolah
echo [INFO] /api/health TIDAK cek database — login-qr butuh MySQL

echo.
echo --- Test login-qr (harus JSON, bukan "Internal Server Error") ---
curl -s --max-time 5 -X POST http://127.0.0.1:2050/api/auth/login-qr ^
  -H "Content-Type: application/json" ^
  -d "{\"classCode\":\"1A2B3C\",\"studentCode\":\"123456\"}" 2>nul
echo.

echo.
echo Jika PM2 kosong tapi :2050 hidup: scripts\restart-app.bat
echo Jika DB FAIL: edit artifacts\nextjs\.env lalu scripts\test-db.bat
pause
exit /b 0

:chk
if "%~2"=="" goto :eof
if exist "%~2" (echo [ OK ] %~1) else (echo [MISS] %~1)
goto :eof
