@echo off
setlocal EnableDelayedExpansion
call "%~dp0lib\common.bat"

set "PORT=2077"
if defined GURUBOT_SETUP_AGENT_PORT set "PORT=%GURUBOT_SETUP_AGENT_PORT%"

powershell -NoProfile -Command ^
  "$c = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { exit 0 } else { exit 1 }"
if not errorlevel 1 exit /b 0

if not exist "%BUNDLE_ROOT%\logs" mkdir "%BUNDLE_ROOT%\logs"

REM Jalankan agent (proses blocking — jendela min tetap hidup selama server jalan)
start "GuruBot Setup Agent" /MIN "%SCRIPTS_DIR%\run-setup-agent-window.bat"

set "READY=0"
for /l %%i in (1,1,15) do (
  if "!READY!"=="0" (
    powershell -NoProfile -Command ^
      "$c = Get-NetTCPConnection -LocalPort %PORT% -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1; if ($c) { exit 0 } else { exit 1 }"
    if not errorlevel 1 set "READY=1"
    if "!READY!"=="0" timeout /t 1 /nobreak >nul
  )
)

if "!READY!"=="0" (
  echo [WARN] Setup-agent belum listen di port %PORT%.
  echo        Cek logs\setup-agent.log — sering karena Python tidak terdeteksi.
  exit /b 1
)
exit /b 0
