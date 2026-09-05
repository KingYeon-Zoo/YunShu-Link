@echo off
setlocal

rem Resolve project root from scripts directory
for %%I in ("%~dp0..") do set "PROJECT_ROOT=%%~fI"

echo [Frontend] Starting manager-web dev server...
cd /d "%PROJECT_ROOT%\main\manager-web"
echo [Frontend] Working directory: %cd%

call npm.cmd run serve
