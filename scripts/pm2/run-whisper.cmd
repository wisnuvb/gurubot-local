@echo off
setlocal
set "BUNDLE_ROOT=%~dp0..\.."
set "PATH=%BUNDLE_ROOT%\tools\ffmpeg;%PATH%"
cd /d "%BUNDLE_ROOT%\artifacts\whisper\app"
"%BUNDLE_ROOT%\artifacts\whisper\venv\Scripts\python.exe" -m uvicorn main:app --host 127.0.0.1 --port 2063 --workers 1
