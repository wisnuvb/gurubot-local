@echo off
setlocal EnableDelayedExpansion
title GuruBot - Setup Autostart

call "%~dp0lib\common.bat"
call "%~dp0lib\common.bat" require_admin

echo ============================================
echo  GuruBot - Setup Autostart (Task Scheduler)
echo ============================================
echo.
echo Skrip ini mendaftarkan tugas Task Scheduler yang menjalankan
echo scripts\autostart-guard.bat setiap kali akun tertentu login ke Windows.
echo.
echo PRASYARAT (lakukan manual dulu - lihat docs\PANDUAN-LENGKAP-SEKOLAH.md bagian autostart):
echo   1. Auto-login Windows aktif untuk akun server (disarankan pakai
echo      Sysinternals Autologon.exe, bukan edit registry manual)
echo   2. Akun tersebut adalah Administrator lokal
echo   3. Docker Desktop -^> Settings -^> General -^>
echo      "Start Docker Desktop when you log in" dicentang
echo.
echo Tanpa autostart Docker Desktop di langkah 3, container tidak akan
echo otomatis naik walau Task Scheduler jalan.
echo.

set /p TASK_USER="Nama akun Windows untuk autostart [default: %USERNAME%]: "
if "!TASK_USER!"=="" set "TASK_USER=%USERNAME%"

set "TASK_NAME=GuruBot Autostart"
set "GUARD_SCRIPT=%SCRIPTS_DIR%\autostart-guard.bat"

if not exist "%GUARD_SCRIPT%" (
  echo [ERROR] %GUARD_SCRIPT% tidak ditemukan.
  pause
  exit /b 1
)

schtasks /query /tn "%TASK_NAME%" >nul 2>&1
if not errorlevel 1 (
  echo [INFO] Task "%TASK_NAME%" sudah ada - menghapus dulu...
  schtasks /delete /tn "%TASK_NAME%" /f >nul 2>&1
)

echo.
echo [INFO] Membuat scheduled task - Windows mungkin minta password akun "%TASK_USER%".
schtasks /create /tn "%TASK_NAME%" /tr "\"%GUARD_SCRIPT%\"" /sc onlogon /ru "%TASK_USER%" /rl highest /f
if errorlevel 1 (
  echo [ERROR] Gagal membuat Task Scheduler entry.
  echo         Pastikan skrip ini dijalankan sebagai Administrator dan password benar.
  pause
  exit /b 1
)

echo.
echo [OK] Task "%TASK_NAME%" terdaftar - akan jalan otomatis saat "%TASK_USER%" login.
echo.
echo Verifikasi terdaftar:
echo   schtasks /query /tn "%TASK_NAME%"
echo.
echo Uji jalankan sekarang tanpa perlu logoff:
echo   schtasks /run /tn "%TASK_NAME%"
echo   (lalu cek log terbaru di logs\autostart-*.log)
echo.
echo Uji sesungguhnya (wajib sebelum dipakai kelas): RESTART laptop penuh,
echo tunggu auto-login selesai, lalu cek dari HP lain di WiFi yang sama:
echo   https://gurubot.sekolah/welcome
echo.
pause
exit /b 0
