@echo off
setlocal EnableDelayedExpansion
REM Generate Prisma Client untuk Windows (wajib jika artifact di-build di Mac)
call "%~dp0lib\common.bat"

echo ============================================
echo  Prisma generate (Windows query engine)
echo ============================================

if not exist "%NEXTJS_DIR%\prisma\schema.prisma" (
  echo [ERROR] prisma\schema.prisma tidak ada
  pause
  exit /b 1
)

pushd "%NEXTJS_DIR%"

echo [1/3] Install prisma + @prisma/client (artifact standalone tidak lengkap)...
call npm install prisma@5.22.0 @prisma/client@5.22.0 --no-save --legacy-peer-deps
if errorlevel 1 (
  echo [ERROR] npm install prisma gagal
  popd
  pause
  exit /b 1
)

echo [2/3] Patch schema.prisma (binaryTargets Windows)...
node "%SCRIPTS_DIR%\maintainer\patch-prisma-schema.js"
if errorlevel 1 (
  echo [ERROR] patch schema gagal
  popd
  pause
  exit /b 1
)

echo [3/3] prisma generate...
call npx prisma@5.22.0 generate
set "EXIT_CODE=!ERRORLEVEL!"
popd

if !EXIT_CODE! neq 0 (
  echo [ERROR] prisma generate gagal
  if not defined GURUBOT_NONINTERACTIVE pause
  exit /b 1
)

findstr /I /C:"windows" "%NEXTJS_DIR%\node_modules\.prisma\client\index.js" >nul 2>&1
if errorlevel 1 (
  echo [WARN] Engine Windows belum terdeteksi — cek log di atas
) else (
  echo [OK] Prisma Client Windows siap
)

echo.
echo Restart PM2: scripts\start-pm2.bat
if not defined GURUBOT_NONINTERACTIVE pause
exit /b 0
