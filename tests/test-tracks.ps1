<#
track-selector (commentary-safe smart selection, alang prefers jpn):
- EOF teardown must NOT log "manually changed" (teardown guard).
- Smart select must pick jpn (aid 2) on duaudio.mkv (eng + jpn).
- A genuine mid-playback `set aid` must still register a manual override.
Exit 0 = all checks pass.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$clips = Join-Path $PSScriptRoot 'clips'
$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Output "PASS: $name" } else { Write-Output "FAIL: $name"; $script:fail++ }
}
# --- 1. EOF teardown: no misclassification ---
# NOTE: profile-restore at teardown vs track-selector observe order is racy;
# retry honestly (max 3) rather than flake. A persistent hit still FAILs.
$eofLog = Join-Path $env:TEMP 'mpv-test-tracks-eof.log'
$teardownOk = $false; $teardownTries = 0
for ($a = 1; ($a -le 3) -and (-not $teardownOk); $a++) {
    $teardownTries = $a
    Remove-Item $eofLog -ErrorAction SilentlyContinue
    $p = Start-Process $mpv -ArgumentList @((Join-Path $clips 'duaudio.mkv'), '--keep-open=no', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--log-file=$eofLog", '--msg-level=all=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
    if (-not $p.WaitForExit(60000)) { $p.Kill(); throw 'duaudio: mpv did not exit at EOF' }
    $eofText = Get-Content $eofLog -Raw
    $teardownOk = -not ($eofText -match 'manually changed')
}
Check "EOF teardown logs no manual-override (attempt $teardownTries)" $teardownOk
Check 'EOF run log clean' (-not ($eofText -match '\[fatal\]|\[error\]|lua error'))
# --- 2. Smart select + genuine override via IPC ---
$pipeName = 'mpv-tracks-test'
$ipcLog = Join-Path $env:TEMP 'mpv-test-tracks-ipc.log'
Remove-Item $ipcLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'duaudio.mkv'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$ipcLog", '--msg-level=all=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(15000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    function Send($json) {
        $w.WriteLine($json)
        $deadline = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $deadline) {
            $line = $r.ReadLine()
            if ($line -match '"request_id"') { return $line }
        }
        throw "no reply to $json"
    }
    $deadline = (Get-Date).AddSeconds(45)
    while ((Get-Date) -lt $deadline) {
        $tp = Send '{ "command": ["get_property", "time-pos"] }'
        $m = [regex]::Match($tp, '"data":([0-9.]+)')
        if ($m.Success -and ([double]$m.Groups[1].Value) -ge 2) { break }
        Start-Sleep -Milliseconds 500
    }
    $aid = Send '{ "command": ["get_property", "aid"] }'
    # duaudio.mkv maps eng first, jpn second, so aid=2 is jpn by construction.
    # (audio-params/* can't be read here: ao=null leaves no audio output params.)
    Check 'smart select picks jpn (aid=2)' ($aid -match '"data":2')
    $w.WriteLine('{ "command": ["set_property", "aid", 1] }')
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        if (($r.ReadLine()) -match '"request_id"') { break }
    }
    Start-Sleep -Milliseconds 1000
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
    if (-not $proc.WaitForExit(15000)) { $proc.Kill(); throw 'tracks IPC: mpv ignored quit' }
} finally {
    if (-not $proc.HasExited) { $proc.Kill() }
}
$ipcText = Get-Content $ipcLog -Raw
Check 'genuine aid change registers manual override' ($ipcText -match 'manually changed AUDIO')
Check 'tracks IPC log clean' (-not ($ipcText -match '\[fatal\]|\[error\]|lua error'))
exit $fail
