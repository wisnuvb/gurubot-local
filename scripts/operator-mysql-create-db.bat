@echo off
setlocal
call "%~dp0lib\common.bat"
powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\operator-mysql-create-db.ps1" -BundleRoot "%BUNDLE_ROOT%"
set "EXIT_CODE=%ERRORLEVEL%"
if not defined GURUBOT_NONINTERACTIVE pause
exit /b %EXIT_CODE%
