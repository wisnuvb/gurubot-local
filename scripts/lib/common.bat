@echo off
REM GuruBot common helpers
REM Usage:
REM   call "%~dp0lib\common.bat"           — init paths
REM   call "%~dp0lib\common.bat" log "msg"
REM   call "%~dp0lib\common.bat" fail "msg"
REM   call "%~dp0lib\common.bat" require_admin

if /i "%~1"=="log" (
  echo [%date% %time%] %~2
  exit /b 0
)
if /i "%~1"=="fail" (
  echo.
  echo [ERROR] %~2
  echo.
  exit /b 1
)
if /i "%~1"=="require_admin" (
  net session >nul 2>&1
  if errorlevel 1 call "%~f0" fail "Jalankan skrip ini sebagai Administrator — Run as admin."
  exit /b 0
)
if /i "%~1"=="require_file" (
  if not exist "%~2" call "%~f0" fail "File tidak ditemukan: %~2"
  exit /b 0
)
if /i "%~1"=="require_dir" (
  if not exist "%~2\" call "%~f0" fail "Folder tidak ditemukan: %~2"
  exit /b 0
)
if /i "%~1"=="generate_secret" (
  for /f "delims=" %%a in ('powershell -NoProfile -Command "[Convert]::ToBase64String((1..32|ForEach-Object{Get-Random -Maximum 256}))"') do set "GENERATED_SECRET=%%a"
  exit /b 0
)
if /i "%~1"=="resolve_python" (
  set "PYTHON_EXE="
  for /f "delims=" %%P in ('where python 2^>nul') do (
    if not defined PYTHON_EXE (
      echo %%P | findstr /i /c:"WindowsApps" >nul || set "PYTHON_EXE=%%P"
    )
  )
  if not defined PYTHON_EXE (
    for /f "delims=" %%P in ('py -3 -c "import sys; print(sys.executable)" 2^>nul') do set "PYTHON_EXE=%%P"
  )
  if not defined PYTHON_EXE if exist "%LOCALAPPDATA%\Python\bin\python.exe" (
    set "PYTHON_EXE=%LOCALAPPDATA%\Python\bin\python.exe"
  )
  if not defined PYTHON_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python313\python.exe" (
    set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python313\python.exe"
  )
  if not defined PYTHON_EXE if exist "%LOCALAPPDATA%\Programs\Python\Python312\python.exe" (
    set "PYTHON_EXE=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
  )
  if not defined PYTHON_EXE if exist "C:\Python313\python.exe" set "PYTHON_EXE=C:\Python313\python.exe"
  if not defined PYTHON_EXE if exist "C:\Python312\python.exe" set "PYTHON_EXE=C:\Python312\python.exe"
  exit /b 0
)
if /i "%~1"=="set_env_value" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPTS_DIR%\lib\set-env-value.ps1" -Path "%BUNDLE_ROOT%\.env.docker" -Key "%~2" -Value "%~3"
  exit /b 0
)
if /i "%~1"=="get_env_value" (
  if not defined BUNDLE_ROOT (
    for %%I in ("%~dp0..\..") do set "BUNDLE_ROOT=%%~fI"
  )
  set "ENV_VALUE="
  REM Pakai %BUNDLE_ROOT% langsung — %_ENV_FILE% di dalam (...) diekspansi saat parse (kosong pada panggilan pertama).
  if exist "%BUNDLE_ROOT%\.env.docker" (
    for /f "usebackq tokens=1,* delims==" %%A in ("%BUNDLE_ROOT%\.env.docker") do (
      if /i "%%A"=="%~2" set "ENV_VALUE=%%B"
    )
  )
  exit /b 0
)
if /i "%~1"=="resolve_mysql" (
  set "MYSQL_EXE="
  where mysql >nul 2>&1 && for /f "delims=" %%M in ('where mysql 2^>nul') do (
    if not defined MYSQL_EXE set "MYSQL_EXE=%%M"
  )
  if not defined MYSQL_EXE if exist "C:\xampp\mysql\bin\mysql.exe" set "MYSQL_EXE=C:\xampp\mysql\bin\mysql.exe"
  if not defined MYSQL_EXE if exist "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe" (
    set "MYSQL_EXE=C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
  )
  exit /b 0
)

REM --- init paths (default call) ---
if not defined BUNDLE_ROOT (
  for %%I in ("%~dp0..\..") do set "BUNDLE_ROOT=%%~fI"
)

set "CONFIG_DIR=%BUNDLE_ROOT%\config"
set "SCRIPTS_DIR=%BUNDLE_ROOT%\scripts"
set "ARTIFACTS_DIR=%BUNDLE_ROOT%\artifacts"
set "TOOLS_DIR=%BUNDLE_ROOT%\tools"
set "NEXTJS_DIR=%ARTIFACTS_DIR%\nextjs"
set "WHISPER_DIR=%ARTIFACTS_DIR%\whisper"
set "LLM_DIR=%ARTIFACTS_DIR%\llm"
set "NGINX_DIR=%TOOLS_DIR%\nginx"
set "NSSM_EXE=%TOOLS_DIR%\nssm\nssm.exe"
exit /b 0
