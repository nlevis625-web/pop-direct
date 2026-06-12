@echo off
title Popup Direct - Landing
cd /d "%~dp0"
echo.
echo  Landing page popup direct
echo  -----------------------
call npm run build
if errorlevel 1 (
  echo ERREUR build
  pause
  exit /b 1
)
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8081" ^| findstr "LISTENING"') do taskkill /F /PID %%a >nul 2>&1
set PORT=8081
set CLOAKING_ENABLED=true
echo.
echo  Site : http://127.0.0.1:8081/
echo  Fermez cette fenetre pour arreter le serveur.
echo.
start "" "http://127.0.0.1:8081/"
node server.js
