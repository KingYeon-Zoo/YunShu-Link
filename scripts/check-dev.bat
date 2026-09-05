@echo off
setlocal

echo ============================================
echo   Checking development environment
echo ============================================
echo.

set "FRONTEND_URL=http://localhost:8001"
set "BACKEND_URL=http://localhost:8002/xiaozhi/"

echo Frontend: %FRONTEND_URL%
for /f "delims=" %%a in ('curl -s -o nul -w "%%{http_code}" "%FRONTEND_URL%"') do (
    if "%%a"=="200" (
        echo   Status: OK, HTTP 200
    ) else (
        echo   Status: Not ready, HTTP %%a
    )
)
echo.

echo Backend: %BACKEND_URL%
for /f "delims=" %%a in ('curl -s -o nul -w "%%{http_code}" "%BACKEND_URL%"') do (
    if "%%a"=="200" (
        echo   Status: OK, HTTP 200
    ) else (
        echo   Status: Not ready, HTTP %%a
    )
)
echo.

pause
