@echo off
setlocal EnableDelayedExpansion
set "LAN_IP="

REM Ambil IPv4 pertama yang bukan 127.0.0.1 dari ipconfig
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4"') do (
  set "IP=%%a"
  set "IP=!IP: =!"
  if not "!IP!"=="" if not "!IP!"=="127.0.0.1" (
    if not defined LAN_IP set "LAN_IP=!IP!"
  )
)

if not defined LAN_IP (
  echo [WARN] Tidak menemukan IPv4 LAN. Set LAN_IP manual di environment.
  exit /b 1
)

echo %LAN_IP%
exit /b 0
