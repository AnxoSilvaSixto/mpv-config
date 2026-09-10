@echo off
setlocal

:: --unregister removes registry keys tied to the CURRENT folder path - re-run
:: mpv-register.bat after moving the portable install; this is the one piece that isn't portable by design.
"%~dp0mpv" --unregister
if %errorlevel% neq 0 (
    echo Deregistration failed. Make sure mpv is in the same folder as this script.
    pause
    exit /b %errorlevel%
)

pause
endlocal
