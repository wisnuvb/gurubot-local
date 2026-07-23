@echo off
setlocal
title GuruBot - Run Next.js (foreground debug)

call "%~dp0lib\common.bat"

echo Jalankan Next.js di foreground — Ctrl+C untuk stop.
echo Folder: %NEXTJS_DIR%
echo URL: http://127.0.0.1:2050
echo.

if not exist "%NEXTJS_DIR%\server.js" (
  echo [ERROR] server.js tidak ada
  pause
  exit /b 1
)

call "%~dp0lib\kill-listener.bat" 2050

cd /d "%NEXTJS_DIR%"
set NODE_ENV=production
set PORT=2050
set HOSTNAME=127.0.0.1
set SENTRY_DSN=
set OTEL_SDK_DISABLED=true
node server.js
