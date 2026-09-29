@echo OFF
:: Primary entry point -> portable_config/tools/Update-MpvEnvironment.ps1 (sole updater).
:: Legacy installer/updater.ps1 is retired; ffmpeg/yt-dlp are out of scope (external tools).
pushd %~dp0
set updater_script="%~dp0portable_config\tools\Update-MpvEnvironment.ps1"

:: Prefer pwsh (PowerShell 7+) when available, fall back to Windows PowerShell 5.1.
where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    :: pwsh found, run with PowerShell 7+
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
) else (
    :: pwsh not found, run with Windows PowerShell 5.1
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
)

:: Capture the updater result now - later commands (timeout) would clobber %errorlevel%.
set updater_failed=%errorlevel%

:: Legacy cleanup: remove stray root updater.ps1 left by old flows, if any.
if exist "%~dp0updater.ps1" (
    del "%~dp0updater.ps1"
)
:: Failures pause indefinitely so the error stays visible; success auto-closes.
if %updater_failed% neq 0 (
    echo Update failed with error %updater_failed% - leaving window open.
    pause
    exit /b %updater_failed%
)

timeout 5
