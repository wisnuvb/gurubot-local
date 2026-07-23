@echo off
setlocal EnableDelayedExpansion
title GuruBot Setup

call "%~dp0lib\common.bat"
call "%~dp0lib\common.bat" require_admin

echo ============================================
echo  GuruBot Local Deploy - Setup (LEGACY PM2)
echo  Bundle: %BUNDLE_ROOT%
echo ============================================
echo  Skrip ini HANYA untuk jalur lama PM2/nginx-native/Acrylic.
echo  Jalur Docker (disarankan) TIDAK perlu skrip ini sama sekali —
echo  DNS (Technitium) dan HTTPS sudah otomatis lewat docker-up.bat.
echo  Lihat README.md / docs\PANDUAN-LENGKAP-SEKOLAH.md untuk jalur Docker.
echo ============================================
echo.

call :preflight
call :setup_ollama
call :setup_env
call :verify_nextjs_build
call :patch_nextjs_instrumentation
call :setup_prisma_generate
call :setup_mysql_prompt
call :setup_ocr_venv
call :setup_whisper_venv
call :setup_dns_hosts
call :setup_acrylic_config
call :setup_nginx
call :setup_firewall

echo.
echo [OK] Setup selesai.
echo Langkah berikutnya: jalankan scripts\setup-services.bat sebagai Administrator
echo.
pause
exit /b 0

:preflight
call "%~dp0lib\common.bat" log "Preflight checks..."

where node >nul 2>&1 || call :fail "Node.js tidak ditemukan. Instal Node.js 20 LTS."

call "%~dp0lib\common.bat" resolve_python
if not defined PYTHON_EXE (
  call :fail "Python tidak ditemukan. Instal Python 3.12+ dan centang 'Add to PATH'. Matikan alias Microsoft Store: Settings ^> Apps ^> Advanced app settings ^> App execution aliases ^> nonaktifkan python.exe / python3.exe."
)
call :log "Python: !PYTHON_EXE!"

for /f "tokens=1 delims=v." %%a in ('node -v') do set "NODE_MAJOR=%%a"
set "NODE_MAJOR=!NODE_MAJOR:v=!"
if !NODE_MAJOR! LSS 20 call :fail "Node.js 20+ diperlukan. Versi saat ini: "
node -v

sc query MySQL80 >nul 2>&1
if errorlevel 1 (
  sc query MySQL >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Service MySQL tidak terdeteksi. Pastikan MySQL 8.0 terinstal dan berjalan.
    echo        Lanjutkan setup; migrasi DB akan gagal jika MySQL belum siap.
  )
)

call :require_dir "%NEXTJS_DIR%"
call :require_dir "%WHISPER_DIR%\app"
call :log "Preflight OK"
goto :eof

:setup_ollama
call :log "Cek Ollama + model Qwen..."
set "OLLAMA_MODEL=qwen3:1.7b"

where ollama >nul 2>&1
if errorlevel 1 (
  echo [WARN] Ollama tidak ditemukan di PATH.
  echo        Instal dari https://ollama.com/download/windows
  echo        Lalu: ollama pull !OLLAMA_MODEL!
  echo        Fitur Analisa AI guru akan nonaktif sampai Ollama siap.
  goto :eof
)

curl -sf --max-time 5 http://127.0.0.1:11434/api/tags >nul 2>&1
if errorlevel 1 (
  echo [WARN] Ollama belum merespons di port 11434.
  echo        Buka aplikasi Ollama dari system tray, lalu jalankan setup ulang.
  goto :eof
)

ollama list 2>nul | findstr /i /c:"!OLLAMA_MODEL!" >nul 2>&1
if errorlevel 1 (
  call :log "Model !OLLAMA_MODEL! belum ada — menjalankan ollama pull..."
  ollama pull !OLLAMA_MODEL!
  if errorlevel 1 (
    echo [WARN] ollama pull gagal — jalankan manual: ollama pull !OLLAMA_MODEL!
  ) else (
    call :log "Model !OLLAMA_MODEL! siap"
  )
) else (
  call :log "Model !OLLAMA_MODEL! sudah terinstal"
)
goto :eof

:setup_env
call :log "Menyiapkan .env..."

if not exist "%NEXTJS_DIR%\.env" (
  copy /Y "%CONFIG_DIR%\.env.example" "%NEXTJS_DIR%\.env" >nul

  call :generate_secret
  powershell -NoProfile -Command ^
    "(Get-Content '%NEXTJS_DIR%\.env') -replace 'GANTI_RANDOM_PANJANG','%GENERATED_SECRET%' | Set-Content '%NEXTJS_DIR%\.env' -Encoding UTF8"
  call :generate_secret
  set "JWT=%GENERATED_SECRET%"
  call :generate_secret
  powershell -NoProfile -Command ^
    "$c=Get-Content '%NEXTJS_DIR%\.env'; $n=0; $c=$c|%%{if($_ -match 'GANTI_RANDOM_PANJANG'){if($n -eq 0){$n=1;$_ -replace 'GANTI_RANDOM_PANJANG','%JWT%'}else{$_ -replace 'GANTI_RANDOM_PANJANG','%GENERATED_SECRET%'}}else{$_}}; $c|Set-Content '%NEXTJS_DIR%\.env' -Encoding UTF8"

  echo.
  echo === Konfigurasi MySQL untuk DATABASE_URL ===
  echo User MySQL = akun database di server MySQL, BUKAN user Windows.
  echo Jika pakai dump production, isi sesuai DB yang sudah ada.
  echo.

  set /p DB_USER="MySQL user [default: root]: "
  if "!DB_USER!"=="" set "DB_USER=root"

  set /p DB_NAME="Nama database [default: gurubot_db]: "
  if "!DB_NAME!"=="" set "DB_NAME=gurubot_db"

  set /p DB_PASS="Password user !DB_USER!: "

  powershell -NoProfile -Command ^
    "$c=Get-Content '%NEXTJS_DIR%\.env'; $c=$c -replace 'GANTI_USER','!DB_USER!' -replace 'GANTI_SANDI','!DB_PASS!' -replace 'GANTI_DB','!DB_NAME!'; $c|Set-Content '%NEXTJS_DIR%\.env' -Encoding UTF8"

  call :log "nextjs .env dibuat"
) else (
  call :log "nextjs .env sudah ada — dilewati"
)

if not exist "%WHISPER_DIR%\.env" copy /Y "%WHISPER_DIR%\.env.example" "%WHISPER_DIR%\.env" >nul
powershell -NoProfile -Command ^
  "$root='%BUNDLE_ROOT%'; (Get-Content '%WHISPER_DIR%\.env') | ForEach-Object { $t=$_.Replace('__BUNDLE_ROOT__',$root); $t.Replace('%%BUNDLE_ROOT%%',$root) } | Set-Content '%WHISPER_DIR%\.env' -Encoding UTF8"
call :log "whisper .env siap"
goto :eof

:verify_nextjs_build
call :log "Verifikasi build Next.js..."
if not exist "%NEXTJS_DIR%\.next\BUILD_ID" call :fail "Build Next.js tidak lengkap. Folder .next\BUILD_ID tidak ada. Lihat docs\INSTALL.md bagian maintainer copy standalone."
if not exist "%NEXTJS_DIR%\.next\server\" call :fail "Build Next.js tidak lengkap. Folder .next\server tidak ada."
if not exist "%NEXTJS_DIR%\server.js" call :fail "server.js tidak ditemukan di artifacts\nextjs."
call :log "Build Next.js OK"
goto :eof

:patch_nextjs_instrumentation
call :log "Patch instrumentation tanpa Sentry..."
call "%~dp0patch-nextjs-instrumentation.bat" /quiet
goto :eof

:setup_prisma_generate
call :log "Prisma generate untuk Windows..."
pushd "%NEXTJS_DIR%"
call npm install prisma@5.22.0 @prisma/client@5.22.0 --no-save --legacy-peer-deps >nul 2>&1
node "%SCRIPTS_DIR%\maintainer\patch-prisma-schema.js"
call npx --yes prisma@5.22.0 generate
if errorlevel 1 (
  echo [WARN] prisma generate gagal — jalankan manual: scripts\prisma-generate.bat
) else (
  call :log "Prisma Client Windows OK"
)
popd
goto :eof

:setup_mysql_prompt
call :log "Database manual import..."
call "%~dp0lib\common.bat" resolve_mysql
if defined MYSQL_EXE call :log "mysql CLI terdeteksi"

echo.
echo [INFO] Prisma migrate DILEWATI - database diisi manual via dump production.
echo.
echo Pastikan artifacts\nextjs\.env sudah benar:
echo   DATABASE_URL="mysql://USER:PASS@127.0.0.1:3306/NAMA_DB"
echo   contoh: mysql://root:123456@127.0.0.1:3306/gurubot_db
echo.
echo Import dump production:
echo   mysql -u root -p NAMA_DB ^< backup_production.sql
echo.
echo Database baru dari nol - opsional:
echo   mysql -u root -p ^< scripts\lib\mysql-init.sql
echo   scripts\migrate-db.bat
echo.
goto :eof

:setup_ocr_venv
call :log "Setup OCR venv..."
set "OCR_DIR=%NEXTJS_DIR%\ml-training"
if not exist "%OCR_DIR%\ocr_server.py" (
  call :log "ocr_server.py tidak ditemukan — OCR dilewati"
  goto :eof
)

if not exist "%OCR_DIR%\venv\Scripts\python.exe" (
  "!PYTHON_EXE!" -m venv "%OCR_DIR%\venv"
)
if not exist "%OCR_DIR%\venv\Scripts\python.exe" (
  echo [WARN] OCR venv gagal dibuat — periksa instalasi Python.
  goto :eof
)

set "OCR_PY=%OCR_DIR%\venv\Scripts\python.exe"
"%OCR_PY%" -m pip install --upgrade pip >nul 2>&1

if exist "%OCR_DIR%\wheels\" (
  "%OCR_PY%" -m pip install --no-index --find-links "%OCR_DIR%\wheels" torch torchvision transformers fastapi "uvicorn[standard]" python-multipart Pillow 2>nul
)

if errorlevel 1 (
  call :log "Instal OCR online - torch CPU..."
  "%OCR_PY%" -m pip install torch torchvision --index-url https://download.pytorch.org/whl/cpu
  "%OCR_PY%" -m pip install fastapi "uvicorn[standard]" python-multipart Pillow transformers
)
call :log "OCR venv OK"
goto :eof

:setup_whisper_venv
call :log "Setup Whisper venv..."
set "WHISPER_APP=%WHISPER_DIR%\app"

if not exist "%WHISPER_DIR%\venv\Scripts\python.exe" (
  "!PYTHON_EXE!" -m venv "%WHISPER_DIR%\venv"
)
if not exist "%WHISPER_DIR%\venv\Scripts\python.exe" (
  echo [WARN] Whisper venv gagal dibuat — periksa instalasi Python.
  goto :eof
)

set "WHISPER_PY=%WHISPER_DIR%\venv\Scripts\python.exe"
"%WHISPER_PY%" -m pip install --upgrade pip >nul 2>&1

if exist "%WHISPER_DIR%\wheels\*.whl" (
  "%WHISPER_PY%" -m pip install --no-index --find-links "%WHISPER_DIR%\wheels" -r "%WHISPER_APP%\requirements.txt"
) else (
  call :log "Wheels offline tidak ada — instal whisper online..."
  "%WHISPER_PY%" -m pip install -r "%WHISPER_APP%\requirements.txt"
)

REM Muat HF_HOME dari .env whisper
for /f "usebackq tokens=1,* delims==" %%a in ("%WHISPER_DIR%\.env") do (
  if /i "%%a"=="HF_HOME" set "HF_HOME=%%b"
)
if defined HF_HOME setx HF_HOME "!HF_HOME!" >nul 2>&1

call :log "Whisper venv OK"
goto :eof

:setup_dns_hosts
call :log "Menambah hosts entry gurubot.sekolah..."
set "HOSTS=%SystemRoot%\System32\drivers\etc\hosts"
findstr /c:"gurubot.sekolah" "%HOSTS%" >nul 2>&1
if errorlevel 1 (
  echo 127.0.0.1   gurubot.sekolah>> "%HOSTS%"
  call :log "hosts: 127.0.0.1 gurubot.sekolah"
) else (
  call :log "hosts entry sudah ada"
)
ipconfig /flushdns >nul 2>&1
goto :eof

:setup_acrylic_config
call :log "Menyiapkan Acrylic DNS config..."
if not exist "%TOOLS_DIR%\acrylic\" mkdir "%TOOLS_DIR%\acrylic"

for /f "delims=" %%i in ('call "%SCRIPTS_DIR%\lib\detect-lan-ip.bat"') do set "LAN_IP=%%i"
if not defined LAN_IP set "LAN_IP=127.0.0.1"

powershell -NoProfile -Command ^
  "$t=Get-Content '%CONFIG_DIR%\acrylic.template.ini' -Raw; $t=$t -replace '%LAN_IP%','%LAN_IP%'; Set-Content '%TOOLS_DIR%\acrylic\AcrylicConfiguration.ini' $t -Encoding ASCII"

call :log "Acrylic config: gurubot.sekolah -^> %LAN_IP%"
echo        Instal Acrylic DNS Proxy ke tools\acrylic\ dan set router DHCP DNS ke IP PC server.
goto :eof

:setup_nginx
call :log "Menyiapkan nginx..."
if not exist "%NGINX_DIR%\logs" mkdir "%NGINX_DIR%\logs"
if not exist "%NGINX_DIR%\temp" mkdir "%NGINX_DIR%\temp"
if not exist "%NGINX_DIR%\temp\client_body_temp" mkdir "%NGINX_DIR%\temp\client_body_temp"
if not exist "%NGINX_DIR%\temp\proxy_temp" mkdir "%NGINX_DIR%\temp\proxy_temp"
if not exist "%NGINX_DIR%\temp\fastcgi_temp" mkdir "%NGINX_DIR%\temp\fastcgi_temp"
if not exist "%NGINX_DIR%\temp\uwsgi_temp" mkdir "%NGINX_DIR%\temp\uwsgi_temp"
if not exist "%NGINX_DIR%\temp\scgi_temp" mkdir "%NGINX_DIR%\temp\scgi_temp"

copy /Y "%CONFIG_DIR%\nginx.conf" "%NGINX_DIR%\nginx.conf" >nul
copy /Y "%CONFIG_DIR%\mime.types" "%NGINX_DIR%\mime.types" >nul

if exist "%NGINX_DIR%\nginx.exe" (
  pushd "%NGINX_DIR%"
  nginx.exe -t -p "%NGINX_DIR%" -c nginx.conf
  popd
) else (
  echo [WARN] nginx.exe belum ada di tools\nginx\ — unduh nginx-win64 dan salin ke tools\nginx\
)
goto :eof

:setup_firewall
call :log "Firewall rules..."
netsh advfirewall firewall show rule name="GuruBot HTTP 80" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot HTTP 80" dir=in action=allow protocol=TCP localport=80
)
netsh advfirewall firewall show rule name="GuruBot DNS 53" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot DNS 53" dir=in action=allow protocol=UDP localport=53
)
call :log "Firewall OK"
goto :eof

:log
call "%~dp0lib\common.bat" log "%~1"
goto :eof

:fail
call "%~dp0lib\common.bat" fail %~1
exit /b 1

:require_dir
call "%~dp0lib\common.bat" require_dir %~1
goto :eof

:generate_secret
call "%~dp0lib\common.bat" generate_secret
goto :eof
