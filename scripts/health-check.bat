@echo off
setlocal EnableDelayedExpansion
title GuruBot Health Check

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot Health Check
echo ============================================
echo.

call :check "Docker HTTPS" "https://gurubot.sekolah/api/health" "-k"
call :check "Next.js via nginx HTTP (legacy)" "http://gurubot.sekolah/api/health"
call :check "Next.js direct (legacy PM2)" "http://127.0.0.1:2050/api/health"
call :check "OCR TrOCR (legacy PM2)" "http://127.0.0.1:2059/docs"
call :check "Whisper STT ready (legacy PM2)" "http://127.0.0.1:2063/ready"
call :check "Ollama Qwen" "http://127.0.0.1:11434/api/tags"

echo.
pause
exit /b 0

:check
set "NAME=%~1"
set "URL=%~2"
curl -sf --max-time 5 "!URL!" >nul 2>&1
if errorlevel 1 (
  echo [FAIL] !NAME! - !URL!
) else (
  echo [ OK ] !NAME! - !URL!
)
goto :eof
