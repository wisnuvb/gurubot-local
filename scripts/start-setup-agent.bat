@echo off
setlocal
title GuruBot - Setup Agent

call "%~dp0lib\common.bat"

set "AGENT_DIR=%SCRIPTS_DIR%\setup-agent"
set "PORT=2077"
if defined GURUBOT_SETUP_AGENT_PORT set "PORT=%GURUBOT_SETUP_AGENT_PORT%"

call "%~dp0lib\common.bat" resolve_python
if not defined PYTHON_EXE (
  if not exist "%BUNDLE_ROOT%\logs" mkdir "%BUNDLE_ROOT%\logs"
  echo [%date% %time%] Python tidak ditemukan untuk setup-agent >> "%BUNDLE_ROOT%\logs\setup-agent.log"
  echo [ERROR] Python tidak ditemukan — diperlukan untuk setup-agent.
  echo        Install Python 3 dari python.org ^(centang Add to PATH^) atau pastikan where python berhasil.
  pause
  exit /b 1
)

REM Load OPERATOR_AGENT_TOKEN from .env.docker into environment for agent process
for /f "usebackq tokens=1,* delims==" %%A in ("%BUNDLE_ROOT%\.env.docker") do (
  if /i "%%A"=="OPERATOR_AGENT_TOKEN" set "OPERATOR_AGENT_TOKEN=%%B"
  if /i "%%A"=="OPERATOR_SETUP_PIN" set "OPERATOR_SETUP_PIN=%%B"
)

echo [INFO] Starting GuruBot setup-agent on 127.0.0.1:%PORT% ...
"%PYTHON_EXE%" "%AGENT_DIR%\server.py"
exit /b %ERRORLEVEL%
