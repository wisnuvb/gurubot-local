@echo off
call "%~dp0lib\common.bat"

echo Starting GuruBot services...

if exist "%NSSM_EXE%" (
  "%NSSM_EXE%" start GuruBot-Nginx 2>nul
  "%NSSM_EXE%" start GuruBot-DNS 2>nul
)

where pm2 >nul 2>&1
if not errorlevel 1 (
  set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
  call "%~dp0lib\pm2-start-apps.bat" 2>nul
)

echo Done. Run scripts\health-check.bat
pause
