@echo off
setlocal EnableDelayedExpansion
title GuruBot - Test Login QR

call "%~dp0lib\common.bat"

echo ============================================
echo  Test POST /api/auth/login-qr
echo ============================================
echo.

set "CURL=curl.exe"
where curl.exe >nul 2>&1
if errorlevel 1 set "CURL=curl"

echo --- Direct :2050 ---
%CURL% -s --max-time 10 -X POST "http://127.0.0.1:2050/api/auth/login-qr" ^
  -H "Content-Type: application/json" ^
  -d "{\"classCode\":\"1A2B3C\",\"studentCode\":\"123456\"}"
echo.
echo.

echo --- Via nginx gurubot.sekolah (HTTPS) ---
%CURL% -s --max-time 10 -k -X POST "https://gurubot.sekolah/api/auth/login-qr" ^
  -H "Content-Type: application/json" ^
  -d "{\"classCode\":\"1A2B3C\",\"studentCode\":\"123456\"}"
echo.
echo.

echo --- Via nginx gurubot.sekolah (HTTP legacy) ---
%CURL% -s --max-time 10 -X POST "http://gurubot.sekolah/api/auth/login-qr" ^
  -H "Content-Type: application/json" ^
  -d "{\"classCode\":\"1A2B3C\",\"studentCode\":\"123456\"}"
echo.
echo.

echo Harapan: JSON dengan "success":true atau "success":false
echo Jika plain text "Internal Server Error" = app crash / belum jalan
echo.
echo Cek data login di DB: scripts\test-db.bat
pause
