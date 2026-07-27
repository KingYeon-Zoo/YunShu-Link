@echo off
setlocal

cd /d "%~dp0"
set "SCRIPTS_DIR=%cd%"
for %%I in ("%SCRIPTS_DIR%\..") do set "PROJECT_ROOT=%%~fI"

echo ============================================
echo   YunShu-Link Dev Environment Starter
echo ============================================
echo Project root: %PROJECT_ROOT%
echo Frontend URL: http://localhost:8001
echo Backend URL:  http://localhost:8002/xiaozhi
echo.
echo Opening two terminal windows...
echo.

start "Frontend - manager-web" cmd /k "cd /d "%SCRIPTS_DIR%" && start-frontend.bat"
start "Backend - Docker"       cmd /k "cd /d "%SCRIPTS_DIR%" && start-backend.bat"

echo.
echo Frontend and backend terminals are starting.
echo It may take 30-60 seconds for the dev server to compile.
echo Run check-dev.bat to verify both services are responding.
echo.
