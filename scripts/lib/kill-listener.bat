@echo off
REM Matikan proses yang listen di port tertentu (orphan node.exe dll.)
REM Usage: kill-listener.bat 2050

setlocal EnableDelayedExpansion
set "PORT=%~1"
if "%PORT%"=="" exit /b 0

set "FOUND=0"
for /f "tokens=5" %%P in ('netstat -ano ^| findstr ":%PORT% " ^| findstr "LISTENING"') do (
  set "FOUND=1"
  echo [kill] Port %PORT% PID %%P
  wmic process where "ProcessId=%%P" get CommandLine /value 2>nul | findstr /I "CommandLine"
  taskkill /PID %%P /F >nul 2>&1
  if errorlevel 1 (
    echo [WARN] Gagal kill PID %%P — jalankan PowerShell sebagai Administrator
  ) else (
    echo [ OK ] PID %%P dimatikan
  )
)

if "%FOUND%"=="0" (
  echo [INFO] Tidak ada proses di port %PORT%
)
exit /b 0
