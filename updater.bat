@echo OFF
:: This batch file exists to run updater.ps1 without hassle
pushd %~dp0
if exist "%~dp0\installer\updater.ps1" (
    set updater_script="%~dp0\installer\updater.ps1"
) else (
    set updater_script="%~dp0\updater.ps1"
)

:: Check if pwsh is in the system's PATH
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    :: pwsh is in PATH, so run the script using Windows Powershell
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
) else (
    :: pwsh is not in PATH, run the script using PowerShell Core
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
)

:: Capture the updater result now - later commands (del) would clobber %errorlevel%.
set updater_failed=%errorlevel%

:: After update, updater.ps1 should not in same folder as mpv.exe
if exist "%~dp0\installer\updater.ps1" if exist "%~dp0\updater.ps1" (
    del "%~dp0\updater.ps1"
)
:: Failures pause indefinitely so the error stays visible; success auto-closes.
if %updater_failed% neq 0 (
    echo Update failed with error %updater_failed% - leaving window open.
    pause
    exit /b %updater_failed%
)

timeout 5
