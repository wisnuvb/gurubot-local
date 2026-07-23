@echo off
REM Patch instrumentation Sentry -> no-op (fix Windows standalone crash)
REM Jalankan dari ROOT bundle:  gurubot-local-deploy\scripts\patch-nextjs-instrumentation.bat

set "BUNDLE_ROOT=%~dp0.."
call "%BUNDLE_ROOT%\scripts\lib\common.bat"

set "STUB=%SCRIPTS_DIR%\maintainer\instrumentation.stub.js"
set "TARGET=%NEXTJS_DIR%\.next\server\instrumentation.js"

echo ============================================
echo  Patch Next.js instrumentation (no Sentry)
echo ============================================
echo Bundle : %BUNDLE_ROOT%
echo Target : %TARGET%
echo.

if not exist "%STUB%" (
  echo [ERROR] Stub tidak ada: %STUB%
  echo         Pastikan folder scripts\maintainer\ ikut di-copy ke server.
  pause
  exit /b 1
)
if not exist "%TARGET%" (
  echo [ERROR] instrumentation.js tidak ada: %TARGET%
  pause
  exit /b 1
)

echo Sebelum patch:
findstr /C:"turbopack" "%TARGET%" >nul 2>&1 && echo   [WARN] Masih turbopack/Sentry
findstr /C:"GuruBot local deploy" "%TARGET%" >nul 2>&1 && echo   [OK] Sudah di-patch sebelumnya

copy /Y "%STUB%" "%TARGET%" >nul
if errorlevel 1 (
  echo [ERROR] Gagal copy stub ke target
  pause
  exit /b 1
)

findstr /C:"GuruBot local deploy" "%TARGET%" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Verifikasi gagal — file masih versi lama
  pause
  exit /b 1
)

findstr /C:"turbopack" "%TARGET%" >nul 2>&1
if not errorlevel 1 (
  echo [ERROR] Masih ada turbopack di instrumentation.js
  pause
  exit /b 1
)

echo.
echo [OK] instrumentation.js berhasil di-patch.
echo Test: cd artifacts\nextjs ^&^& set PORT=2050 ^&^& set HOSTNAME=127.0.0.1 ^&^& node server.js
if /i not "%~1"=="/quiet" pause
exit /b 0
