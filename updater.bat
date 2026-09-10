@echo OFF
:: Primary entry point — runs Update-MpvEnvironment.ps1; no legacy fallback
:: portable_config/tools/Update-MpvEnvironment.ps1 (mpv + hdr-toys + uosc + thumbfast + track-selector).
pushd %~dp0
set updater_script="%~dp0\portable_config\tools\Update-MpvEnvironment.ps1"

:: Check if pwsh is in the system's PATH
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    :: pwsh is in PATH, so run the script using PowerShell Core
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
) else (
    :: pwsh is not in PATH, run the script using Windows PowerShell
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
)

:: Capture the updater result now — a trailing command would clobber %errorlevel%.
set updater_failed=%errorlevel%

:: Failures pause indefinitely so the error stays visible; success auto-closes.
if %updater_failed% neq 0 (
    echo Update failed with error %updater_failed% - leaving window open.
    pause
    exit /b %updater_failed%
)
timeout 5
