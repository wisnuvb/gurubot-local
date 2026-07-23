@echo off
setlocal EnableDelayedExpansion
title GuruBot - Start PM2 Apps

call "%~dp0lib\common.bat"

set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
if not exist "%PM2_HOME%" mkdir "%PM2_HOME%"

echo PM2_HOME=%PM2_HOME%
echo BUNDLE_ROOT=%BUNDLE_ROOT%
echo.

call "%~dp0lib\pm2-start-apps.bat"
if errorlevel 1 (
  pause
  exit /b 1
)

set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
pm2 status
echo.
echo PM2_HOME=%PM2_HOME%
echo Log error: %PM2_HOME%\logs\gurubot-app-error.log
echo Test DB: scripts\test-db.bat
echo Test: http://127.0.0.1:2050/api/health
pause
