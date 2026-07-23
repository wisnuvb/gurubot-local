@echo off
REM Start GuruBot PM2 apps
REM Requires: call "%~dp0lib\common.bat" and PM2_HOME already set

if not defined PM2_HOME set "PM2_HOME=%BUNDLE_ROOT%\.pm2"
set "BUNDLE_ROOT=%BUNDLE_ROOT%"

set "PM2_ANY_STARTED=0"

if not exist "%NEXTJS_DIR%\server.js" (
  echo [ERROR] Tidak ada: %NEXTJS_DIR%\server.js
  exit /b 1
)
if not exist "%CONFIG_DIR%\ecosystem.config.js" (
  echo [ERROR] Tidak ada: %CONFIG_DIR%\ecosystem.config.js
  exit /b 1
)

where pm2 >nul 2>&1
if errorlevel 1 (
  echo [ERROR] pm2 CLI tidak ditemukan — npm install -g pm2
  exit /b 1
)

echo PM2_HOME=%PM2_HOME%
echo BUNDLE_ROOT=%BUNDLE_ROOT%

set "PATH=%TOOLS_DIR%\ffmpeg;%PATH%"

call "%~dp0kill-listener.bat" 2050
timeout /t 1 /nobreak >nul

pm2 delete gurubot-app gurubot-ocr gurubot-whisper 2>nul

echo [PM2] Starting gurubot-app (server.js via ecosystem.config.js)...
set "BUNDLE_ROOT=%BUNDLE_ROOT%"
pm2 start "%CONFIG_DIR%\ecosystem.config.js" --only gurubot-app --update-env
if errorlevel 1 goto :pm2_fail

timeout /t 3 /nobreak >nul
pm2 describe gurubot-app 2>nul | findstr /I "status.*online" >nul 2>&1
if errorlevel 1 (
  echo [ERROR] gurubot-app tidak online setelah start
  goto :pm2_fail
)
set "PM2_ANY_STARTED=1"
echo [ OK ] gurubot-app online

if exist "%NEXTJS_DIR%\ml-training\venv\Scripts\python.exe" (
  echo [PM2] Starting gurubot-ocr...
  pm2 start "%CONFIG_DIR%\ecosystem.config.js" --only gurubot-ocr --update-env
  if errorlevel 1 echo [WARN] gurubot-ocr gagal start
) else (
  echo [WARN] OCR venv belum ada — lewati gurubot-ocr
)

if exist "%WHISPER_DIR%\venv\Scripts\python.exe" (
  echo [PM2] Starting gurubot-whisper...
  pm2 start "%CONFIG_DIR%\ecosystem.config.js" --only gurubot-whisper --update-env
  if errorlevel 1 echo [WARN] gurubot-whisper gagal start
) else (
  echo [WARN] Whisper venv belum ada — lewati gurubot-whisper
)

pm2 save
pm2 list
exit /b 0

:pm2_fail
echo.
echo [ERROR] PM2 gagal menjalankan gurubot-app
if exist "%PM2_HOME%\logs\gurubot-app-error.log" (
  echo --- gurubot-app-error.log ---
  type "%PM2_HOME%\logs\gurubot-app-error.log"
)
echo.
echo Coba manual (lihat error langsung): scripts\run-app-manual.bat
exit /b 1
