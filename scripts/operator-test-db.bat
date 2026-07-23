@echo off
setlocal EnableDelayedExpansion
REM Tes MySQL via Prisma — baca DATABASE_URL dari .env.docker (portal operator / Docker)
call "%~dp0lib\common.bat"

set "ENV_DOCKER=%BUNDLE_ROOT%\.env.docker"
set "EXIT_CODE=1"

if not exist "%ENV_DOCKER%" (
  echo [FAIL] %ENV_DOCKER% tidak ada
  goto :done
)

call "%~dp0lib\common.bat" get_env_value DATABASE_URL
if not defined ENV_VALUE (
  echo [FAIL] DATABASE_URL kosong di .env.docker
  goto :done
)

if not exist "%NEXTJS_DIR%\node_modules\@prisma\client\package.json" (
  echo [FAIL] @prisma/client belum ada di artifacts\nextjs\node_modules
  echo HINT: Jalankan tombol "Prisma generate" di portal operator, atau scripts\prisma-generate.bat
  goto :done
)

set "DB_URL=!ENV_VALUE!"
set "DB_URL=!DB_URL:host.docker.internal=127.0.0.1!"

set "TMP_ENV=%TEMP%\gurubot-operator-test-db.env"
set "BACKUP_ENV="
if exist "%NEXTJS_DIR%\.env" (
  set "BACKUP_ENV=%TEMP%\gurubot-operator-test-db.env.bak"
  copy /Y "%NEXTJS_DIR%\.env" "!BACKUP_ENV!" >nul
)

> "%TMP_ENV%" echo DATABASE_URL=!DB_URL!
copy /Y "%TMP_ENV%" "%NEXTJS_DIR%\.env" >nul

pushd "%NEXTJS_DIR%"
node "%SCRIPTS_DIR%\maintainer\test-db.js" "%NEXTJS_DIR%"
set "EXIT_CODE=!ERRORLEVEL!"
popd

if defined BACKUP_ENV (
  copy /Y "!BACKUP_ENV!" "%NEXTJS_DIR%\.env" >nul
  del "!BACKUP_ENV!" >nul 2>&1
) else if exist "%NEXTJS_DIR%\.env" (
  del "%NEXTJS_DIR%\.env" >nul 2>&1
)
del "%TMP_ENV%" >nul 2>&1

if !EXIT_CODE! neq 0 (
  echo.
  echo HINT: Perbaiki user/password/database di .env.docker ^(root bundle^).
  echo HINT: Pastikan service MySQL80 RUNNING dan database sudah dibuat ^(tombol Buat database^).
)

:done
if not defined GURUBOT_NONINTERACTIVE pause
exit /b !EXIT_CODE!
