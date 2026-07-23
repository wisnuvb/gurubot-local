@echo off
setlocal EnableDelayedExpansion
title GuruBot - Test Database

call "%~dp0lib\common.bat"

echo ============================================
echo  Test koneksi MySQL (Prisma)
echo ============================================
echo.

if not exist "%NEXTJS_DIR%\.env" (
  echo [ERROR] %NEXTJS_DIR%\.env tidak ada
  echo Jalankan setup.bat atau edit DATABASE_URL manual.
  pause
  exit /b 1
)

if not exist "%NEXTJS_DIR%\node_modules\@prisma\client\package.json" (
  echo [ERROR] @prisma/client belum ada di artifacts\nextjs\node_modules
  echo Jalankan dulu: scripts\prisma-generate.bat
  pause
  exit /b 1
)

pushd "%NEXTJS_DIR%"
node "%SCRIPTS_DIR%\maintainer\test-db.js" "%NEXTJS_DIR%"
set "EXIT_CODE=!ERRORLEVEL!"
popd

echo.
if !EXIT_CODE! neq 0 (
  echo Perbaiki artifacts\nextjs\.env lalu jalankan ulang.
) else (
  echo Jika login masih 500, cek log: .pm2\logs\gurubot-app-error.log
)
pause
exit /b !EXIT_CODE!
