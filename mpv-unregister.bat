@echo off
setlocal

:: Removes keys for the current folder — re-run register after moving. Needs admin if machine-wide.
"%~dp0mpv.exe" --unregister
if %errorlevel% neq 0 (
    echo Deregistration failed. Make sure mpv is in the same folder as this script.
    pause
    exit /b %errorlevel%
)

pause
endlocal
