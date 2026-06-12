@echo off
cd /d "%~dp0"
echo Build...
call npm run build
if errorlevel 1 exit /b 1
echo Arret ancien serveur sur port 8081...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr ":8081" ^| findstr "LISTENING"') do taskkill /F /PID %%a 2>nul
set PORT=8081
start "" "http://127.0.0.1:8081/"
echo Serveur sur http://127.0.0.1:8081/
node server.js
