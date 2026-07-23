@echo off
call "%~dp0lib\common.bat"

echo Stopping GuruBot services...

where pm2 >nul 2>&1
if not errorlevel 1 pm2 stop all 2>nul

if exist "%NSSM_EXE%" (
  "%NSSM_EXE%" stop GuruBot-Nginx 2>nul
  "%NSSM_EXE%" stop GuruBot-DNS 2>nul
)

echo Done.
pause
