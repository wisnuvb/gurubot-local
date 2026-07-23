@echo off
title GuruBot - Setup Ollama Model
setlocal

set "OLLAMA_MODEL=qwen3:1.7b"

where ollama >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Ollama tidak ditemukan. Instal dari https://ollama.com/download/windows
  pause
  exit /b 1
)

echo Pull model !OLLAMA_MODEL! ...
ollama pull !OLLAMA_MODEL!
if errorlevel 1 (
  echo [ERROR] ollama pull gagal
  pause
  exit /b 1
)

echo.
echo [OK] Model siap. Verifikasi:
ollama list
echo.
pause
