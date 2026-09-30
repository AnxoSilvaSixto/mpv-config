@echo off
setlocal

:: Registry keys follow the current folder — re-run after moving. Needs admin.
"%~dp0mpv.exe" --register
if %errorlevel% neq 0 (
    echo Registration failed. Make sure mpv is in the same folder as this script.
    pause
    exit /b %errorlevel%
)

pause
endlocal
