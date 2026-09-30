<#
.SYNOPSIS
    Registers the updater as a logon Scheduled Task. Run once.
.NOTES
    No admin needed. Logon (not startup) so network is up. 1-min delay.
#>

$Action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "$PSScriptRoot\Update-MpvEnvironment.ps1"'

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Trigger.Delay = 'PT1M'

$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew

Register-ScheduledTask -TaskName 'mpv-autoupdate' `
    -Action $Action -Trigger $Trigger -Settings $Settings `
    -Description 'Daily check/update for mpv, hdr-toys, uosc, thumbfast, and animebuild (see Update-MpvEnvironment.ps1)' `
    -Force

Write-Host "Registered. Test it immediately with:  Start-ScheduledTask -TaskName 'mpv-autoupdate'"
Write-Host "Then check the log at $PSScriptRoot\update-log.txt"
