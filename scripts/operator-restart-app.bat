@echo off
setlocal
call "%~dp0lib\common.bat"
pushd "%BUNDLE_ROOT%"
docker compose restart app
set "EXIT_CODE=%ERRORLEVEL%"
popd
if not defined GURUBOT_NONINTERACTIVE pause
exit /b %EXIT_CODE%
