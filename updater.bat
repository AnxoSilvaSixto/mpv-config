@echo OFF
:: Primary entry point — runs the preferred component updater
:: portable_config/tools/Update-MpvEnvironment.ps1 (mpv + hdr-toys + uosc + thumbfast + track-selector).
:: installer/updater.ps1 is legacy (interactive yt-dlp/ffmpeg); invoke it directly if you need that path.
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
timeout 5
