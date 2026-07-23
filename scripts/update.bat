@echo off
setlocal EnableDelayedExpansion
title GuruBot Update

call "%~dp0lib\common.bat"
call :require_admin

echo ============================================
echo  GuruBot Update
echo  Salin paket artifact baru ke folder artifacts\ sebelum lanjut
echo ============================================
echo.
pause

set "BACKUP_DIR=%BUNDLE_ROOT%\backup\%date:~-4%%date:~3,2%%date:~0,2%_%time:~0,2%%time:~3,2%"
set "BACKUP_DIR=!BACKUP_DIR: =0!"
mkdir "!BACKUP_DIR!" 2>nul

if exist "%NEXTJS_DIR%\.env" copy /Y "%NEXTJS_DIR%\.env" "!BACKUP_DIR!\nextjs.env" >nul
if exist "%WHISPER_DIR%\.env" copy /Y "%WHISPER_DIR%\.env" "!BACKUP_DIR!\whisper.env" >nul

call "%~dp0stop-all.bat"

echo.
echo Setelah mengganti folder artifacts\nextjs, whisper, llm tekan Enter...
pause >nul

if exist "!BACKUP_DIR!\nextjs.env" copy /Y "!BACKUP_DIR!\nextjs.env" "%NEXTJS_DIR%\.env" >nul
if exist "!BACKUP_DIR!\whisper.env" copy /Y "!BACKUP_DIR!\whisper.env" "%WHISPER_DIR%\.env" >nul

call :verify_nextjs_build

echo.
echo [INFO] Prisma migrate dilewati — restore DB manual jika perlu.
echo        Untuk schema baru dari nol: scripts\migrate-db.bat
echo.
pause

call "%~dp0setup-services.bat"
call "%~dp0health-check.bat"
exit /b 0

:verify_nextjs_build
if not exist "%NEXTJS_DIR%\.next\BUILD_ID" call "%~dp0lib\common.bat" fail "Build Next.js tidak lengkap setelah update."
goto :eof
