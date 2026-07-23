@echo off
setlocal
title GuruBot - Stop nginx Windows (port 80)
call "%~dp0lib\common.bat"
taskkill /IM nginx.exe /F >nul 2>&1
if errorlevel 1 (
  echo [INFO] Tidak ada proses nginx.exe di Windows — port 80 hanya Docker.
  exit /b 0
)
echo [OK] nginx.exe Windows dihentikan. HP: pakai https:// bukan http://
if not defined GURUBOT_NONINTERACTIVE pause
exit /b 0
