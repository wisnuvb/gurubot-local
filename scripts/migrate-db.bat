@echo off
setlocal EnableDelayedExpansion
title GuruBot - Prisma Migrate (opsional)

call "%~dp0lib\common.bat"

echo ============================================
echo  GuruBot - Prisma Migrate (opsional)
echo  Untuk instalasi baru dari nol saja.
echo  Deploy production dengan dump: JANGAN jalankan skrip ini.
echo ============================================
echo.
pause

if not exist "%NEXTJS_DIR%\.env" (
  call "%~dp0lib\common.bat" fail "artifacts\nextjs\.env tidak ada — jalankan setup.bat dulu."
)

pushd "%NEXTJS_DIR%"
call npx --yes prisma@5.22.0 migrate deploy
set "EXIT_CODE=!ERRORLEVEL!"
popd

if !EXIT_CODE! neq 0 (
  echo.
  echo [ERROR] migrate deploy gagal.
  echo Bundle memakai Prisma 5.22 — jangan jalankan npx prisma tanpa versi.
  pause
  exit /b 1
)

echo.
echo [OK] Migrasi selesai.
pause
exit /b 0
