@echo off
setlocal

rem Resolve project root from scripts directory
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

echo [Backend] Checking Docker Desktop...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo [Backend] Docker Desktop is not running. Starting it...
    start "" "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    :wait
    timeout /t 5 /nobreak >nul
    docker info >nul 2>&1
    if %errorlevel% neq 0 goto wait
    echo [Backend] Docker Desktop is ready.
)

echo [Backend] Starting Docker services...
cd /d "%PROJECT_ROOT%\main\xiaozhi-server"
docker compose -f docker-compose_all.yml up xiaozhi-esp32-server-db xiaozhi-esp32-server-redis xiaozhi-esp32-server-web
