@echo off
setlocal EnableDelayedExpansion
title GuruBot - Restart Next.js App

call "%~dp0lib\common.bat"

set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
if not exist "%PM2_HOME%" mkdir "%PM2_HOME%"

echo ============================================
echo  Restart Next.js (bersihkan orphan process)
echo ============================================
echo BUNDLE_ROOT=%BUNDLE_ROOT%
echo PM2_HOME=%PM2_HOME%
echo.

echo [1/4] Proses yang sekarang di port 2050:
netstat -ano | findstr ":2050 " | findstr "LISTENING"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":2050 " ^| findstr "LISTENING"') do (
  echo.
  echo --- Detail PID %%P ---
  wmic process where "ProcessId=%%P" get ProcessId,CommandLine /format:list 2>nul
)

echo.
echo [2/4] Matikan semua listener port 2050 (termasuk orphan di luar PM2)...
call "%~dp0lib\kill-listener.bat" 2050
timeout /t 2 /nobreak >nul

echo.
echo [3/4] Reset daftar PM2 bundle...
set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
pm2 delete gurubot-app gurubot-ocr gurubot-whisper 2>nul

echo.
echo [4/4] Start ulang via PM2 bundle...
call "%~dp0lib\pm2-start-apps.bat"
set "EXIT_CODE=!ERRORLEVEL!"

echo.
set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
pm2 status

echo.
echo --- Verifikasi ---
curl -sf --max-time 5 http://127.0.0.1:2050/api/health >nul 2>&1
if errorlevel 1 (
  echo [FAIL] Next.js :2050 tidak merespons
) else (
  echo [ OK ] Next.js :2050 hidup
)

echo.
echo --- Test login-qr (harus JSON, bukan plain text) ---
curl -s --max-time 5 -X POST http://127.0.0.1:2050/api/auth/login-qr ^
  -H "Content-Type: application/json" ^
  -d "{\"classCode\":\"1A2B3C\",\"studentCode\":\"123456\"}"
echo.
echo.

if !EXIT_CODE! neq 0 (
  echo [ERROR] PM2 gagal start — cek .pm2\logs\gurubot-app-error.log
  echo Atau jalankan: scripts\run-app-manual.bat ^(lihat error langsung^)
) else (
  echo Test login: scripts\test-login.bat
  echo Test DB: scripts\test-db.bat
)

pause
exit /b !EXIT_CODE!
