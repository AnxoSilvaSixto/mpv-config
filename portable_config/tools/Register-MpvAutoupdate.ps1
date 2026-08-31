<#
.SYNOPSIS
    One-time setup: registers the daily mpv/hdr-toys/uosc update as a
    Scheduled Task that runs at login. Run this once, manually, yourself.
.NOTES
    Does NOT need admin rights - "at log on" tasks run in your own user
    context, which is also why login (not raw system startup) is used:
    your network/proxy settings are only available once you've logged in,
    so a true pre-login "at startup" trigger would frequently fire before
    the network is up and just fail silently.
#>

$Action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\mpv\portable_config\tools\Update-MpvEnvironment.ps1"'

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Trigger.Delay = 'PT1M'   # 1-minute delay after login, so networking has time to come up before the first request fires

$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -DontStopOnIdleEnd -ExecutionTimeLimit (New-TimeSpan -Minutes 15) -MultipleInstances IgnoreNew   # belt-and-suspenders alongside the script's own mutex: Task Scheduler itself won't start a second copy if one is already running

Register-ScheduledTask -TaskName 'mpv-autoupdate' `
    -Action $Action -Trigger $Trigger -Settings $Settings `
    -Description 'Daily check/update for mpv, hdr-toys, and uosc (see Update-MpvEnvironment.ps1)' `
    -Force

Write-Host "Registered. Test it immediately with:  Start-ScheduledTask -TaskName 'mpv-autoupdate'"
Write-Host "Then check the log at C:\mpv\portable_config\tools\update-log.txt"
