@echo off
setlocal
set "BUNDLE_ROOT=%~dp0..\.."
cd /d "%BUNDLE_ROOT%\artifacts\nextjs"
set NODE_ENV=production
set PORT=2050
set HOSTNAME=127.0.0.1
set SENTRY_DSN=
set OTEL_SDK_DISABLED=true
node server.js
