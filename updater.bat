@echo OFF
:: Sole updater entry point -> portable_config/tools/Update-MpvEnvironment.ps1
pushd %~dp0
set updater_script="%~dp0portable_config\tools\Update-MpvEnvironment.ps1"

where pwsh >nul 2>nul
if %errorlevel% equ 0 (
    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
) else (
    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%
)

set updater_failed=%errorlevel%

if exist "%~dp0updater.ps1" (
    del "%~dp0updater.ps1"
)
if %updater_failed% neq 0 (
    echo Update failed with error %updater_failed% - leaving window open.
    pause
    exit /b %updater_failed%
)

timeout 5
