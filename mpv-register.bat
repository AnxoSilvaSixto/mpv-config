@echo off
setlocal

:: --register writes registry keys tied to the CURRENT folder path - re-run this
:: after moving the portable install; this is the one piece that isn't portable by design.
:: Requires elevation (admin) for machine-wide file associations.
"%~dp0mpv.exe" --register
if %errorlevel% neq 0 (
    echo Registration failed. Make sure mpv is in the same folder as this script.
    pause
    exit /b %errorlevel%
)

pause
endlocal
