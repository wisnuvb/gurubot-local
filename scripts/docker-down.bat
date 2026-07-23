@echo off
setlocal
title GuruBot - Docker Down

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot - Docker Compose Down
echo ============================================
echo.

cd /d "%BUNDLE_ROOT%"
docker compose down

if errorlevel 1 (
  echo [ERROR] docker compose down gagal.
  pause
  exit /b 1
)

echo.
echo [OK] Semua container GuruBot dihentikan.
pause
exit /b 0
