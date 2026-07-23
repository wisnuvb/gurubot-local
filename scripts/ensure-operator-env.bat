@echo off
setlocal EnableDelayedExpansion
REM Pastikan OPERATOR_AGENT_TOKEN + OPERATOR_SETUP_PIN ada di .env.docker
call "%~dp0lib\common.bat"

set "ENV_DOCKER=%BUNDLE_ROOT%\.env.docker"
if not exist "%ENV_DOCKER%" exit /b 0

call "%~dp0lib\common.bat" get_env_value OPERATOR_AGENT_TOKEN
if not defined ENV_VALUE (
  call "%~dp0lib\common.bat" generate_secret
  call "%~dp0lib\common.bat" set_env_value OPERATOR_AGENT_TOKEN "!GENERATED_SECRET!"
  echo [INFO] OPERATOR_AGENT_TOKEN digenerate otomatis.
)

call "%~dp0lib\common.bat" get_env_value OPERATOR_SETUP_PIN
if not defined ENV_VALUE (
  for /f "delims=" %%P in ('powershell -NoProfile -Command "Get-Random -Minimum 100000 -Maximum 999999"') do set "NEW_PIN=%%P"
  call "%~dp0lib\common.bat" set_env_value OPERATOR_SETUP_PIN "!NEW_PIN!"
  echo [INFO] OPERATOR_SETUP_PIN digenerate: !NEW_PIN! ^(portal http://127.0.0.1:2077/^)
)
exit /b 0
