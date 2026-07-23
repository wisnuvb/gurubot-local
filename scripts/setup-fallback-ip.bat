@echo off
setlocal EnableDelayedExpansion
title GuruBot Fallback IP

call "%~dp0lib\common.bat"

for /f "delims=" %%i in ('call "%~dp0lib\detect-lan-ip.bat"') do set "LAN_IP=%%i"
if not defined LAN_IP (
  set /p LAN_IP="Masukkan IPv4 LAN PC server: "
)

echo.
echo PERINGATAN: NEXT_PUBLIC_API_URL disematkan saat build Next.js.
echo Jika auth/PWA bermasalah setelah ganti IP, rebuild artifact dengan URL baru.
echo.

set "ENV_DOCKER=%BUNDLE_ROOT%\.env.docker"
if not exist "%ENV_DOCKER%" call "%~dp0lib\common.bat" fail ".env.docker tidak ada — jalankan setup.bat / copy template dulu"

powershell -NoProfile -Command ^
  "$u='https://%LAN_IP%'; $c=Get-Content '%ENV_DOCKER%'; $c=$c|ForEach-Object{if($_ -match '^NEXTAUTH_URL='){'NEXTAUTH_URL='+$u}elseif($_ -match '^NEXT_PUBLIC_API_URL='){'NEXT_PUBLIC_API_URL='+$u}else{$_}}; $c|Set-Content '%ENV_DOCKER%' -Encoding UTF8"

echo [OK] .env.docker diupdate ke https://%LAN_IP%
echo.
echo Regenerate sertifikat: scripts\setup-ssl.bat
echo Restart stack: scripts\docker-down.bat ^&^& scripts\docker-up.bat
echo Akses dari HP: https://%LAN_IP%/welcome
echo Untuk DNS penuh: Acrylic + router DHCP (docs\DNS-LAN.md)
pause
