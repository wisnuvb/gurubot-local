@echo off
setlocal
set "BUNDLE_ROOT=%~dp0..\.."
cd /d "%BUNDLE_ROOT%\artifacts\nextjs\ml-training"
"%BUNDLE_ROOT%\artifacts\nextjs\ml-training\venv\Scripts\python.exe" ocr_server.py
