@echo off
title GuruBot - Portal Operator
call "%~dp0ensure-setup-agent.bat"
if errorlevel 1 (
  echo.
  echo Gagal menyalakan setup-agent. Baca logs\setup-agent.log
  echo Coba manual: scripts\start-setup-agent.bat
  pause
  exit /b 1
)
start "" "http://127.0.0.1:2077/"
echo Portal operator dibuka di browser.
echo Aplikasi sekolah ^(siswa/guru^): https://gurubot.sekolah/welcome
exit /b 0
