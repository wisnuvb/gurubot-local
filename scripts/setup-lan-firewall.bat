@echo off
setlocal
title GuruBot - Firewall LAN (443 / 53)

call "%~dp0lib\common.bat" require_admin

echo [INFO] Menambah aturan firewall untuk akses WiFi ke GuruBot...

netsh advfirewall firewall show rule name="GuruBot HTTPS 443" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot HTTPS 443" dir=in action=allow protocol=TCP localport=443
  echo [ OK ] GuruBot HTTPS 443
) else (
  echo [INFO] GuruBot HTTPS 443 sudah ada
)

netsh advfirewall firewall show rule name="GuruBot HTTP 80" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot HTTP 80" dir=in action=allow protocol=TCP localport=80
  echo [ OK ] GuruBot HTTP 80
)

netsh advfirewall firewall show rule name="GuruBot DNS 53 UDP" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot DNS 53 UDP" dir=in action=allow protocol=UDP localport=53
  echo [ OK ] GuruBot DNS 53 UDP
)

netsh advfirewall firewall show rule name="GuruBot DNS 53 TCP" >nul 2>&1
if errorlevel 1 (
  netsh advfirewall firewall add rule name="GuruBot DNS 53 TCP" dir=in action=allow protocol=TCP localport=53
  echo [ OK ] GuruBot DNS 53 TCP
)

echo [OK] Firewall LAN siap.
exit /b 0
