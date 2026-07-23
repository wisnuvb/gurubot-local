@echo off
REM Wrapper untuk ensure-setup-agent — hindari redirect di baris start (Windows 11)
call "%~dp0start-setup-agent.bat"
