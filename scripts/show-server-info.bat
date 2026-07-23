@echo off
setlocal EnableDelayedExpansion
title GuruBot - Info Server Sekolah

call "%~dp0lib\common.bat"

set "LAN_IP="
for /f "delims=" %%I in ('call "%~dp0lib\detect-lan-ip.bat" 2^>nul') do set "LAN_IP=%%I"

echo ============================================
echo  GuruBot - Info Server (Windows)
echo ============================================
echo.
echo IP LAN PC server ^(WiFi/LAN^):  %LAN_IP%
echo.
echo URL akses dari HP/tablet di WiFi yang sama:
echo   https://gurubot.sekolah/welcome   ^(DNS router ke IP server^)
echo   https://%LAN_IP%/welcome         ^(fallback IP + QR^)
echo.
echo Portal operator ^(setup server, bukan app sekolah^):
echo   http://127.0.0.1:2077/   ^(scripts\open-operator-portal.bat^)
echo   PIN: OPERATOR_SETUP_PIN di .env.docker
echo.
echo Aplikasi sekolah ^(HP/guru/siswa^):
echo   https://gurubot.sekolah/welcome
echo.
echo Catatan IP:
echo   - IP ini OTOMATIS terdeteksi dari jaringan saat ini
echo   - Bisa BERUBAH jika pindah WiFi/router tanpa IP statis
echo   - Disarankan: set IP statis di router ^(DHCP reservation^)
echo.
echo File CA untuk Android:
echo   %BUNDLE_ROOT%\certs\mobile\gurubot-mkcert-rootCA.pem
echo   ^(generate: scripts\setup-ssl-mobile.bat^)
echo.
echo Skrip terkait:
echo   scripts\docker-up.bat           - start stack + portal operator
echo   scripts\ensure-setup-agent.bat  - agen monitoring host
echo   scripts\setup-ssl.bat           - sertifikat HTTPS
echo   scripts\setup-ssl-mobile.bat    - export CA ke HP
echo   docs\OPERATOR-PORTAL.md         - panduan UI operator
echo.
pause
exit /b 0
