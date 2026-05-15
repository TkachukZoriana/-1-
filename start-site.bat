@echo off
cd /d "%~dp0"
set "SITE_PORT=8016"
start "Local Booking Server" cmd /k "set PORT=%SITE_PORT%&& node local-preview-server.js"
timeout /t 2 /nobreak >nul
start "" http://localhost:%SITE_PORT%/booking.html
