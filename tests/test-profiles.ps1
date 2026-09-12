<#
End-to-end verification: Colorspace-BT709 auto-profile (SDR) + Alt+h hdr-toggle (HDR).
Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests/test-profiles.ps1
Repo root is derived from this script's location (portable). Needs tests/clips/*.mp4
from make-test-clips.ps1. Exit 0 = all checks pass.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$clips = Join-Path $PSScriptRoot 'clips'
$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Output "PASS: $name" } else { Write-Output "FAIL: $name"; $script:fail++ }
}

# --- 1. SDR: BT.709 profile must apply, no errors (IPC lifecycle with explicit
# quit; single-file + no-resume flags for determinism, see PlaySdr) ---
function PlaySdr($quitAtSec = 3) {
    $clip = 'sdr709.mp4'
    $sdrLog = Join-Path $env:TEMP 'mpv-test-sdr.log'
    Remove-Item $sdrLog -ErrorAction SilentlyContinue
    $p = Start-Process $mpv -ArgumentList @((Join-Path $clips $clip), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', '--input-ipc-server=mpv-pl-sdr', "--log-file=$sdrLog", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
    try {
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', 'mpv-pl-sdr', [System.IO.Pipes.PipeDirection]::InOut)
        $pipe.Connect(15000)
        $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
        $r = New-Object System.IO.StreamReader($pipe)
        $done = $false
        $deadline = (Get-Date).AddSeconds(60)
        while ((-not $done) -and ((Get-Date) -lt $deadline)) {
            $w.WriteLine('{ "command": ["get_property", "time-pos"] }')
            $rd = (Get-Date).AddSeconds(5)
            while ((Get-Date) -lt $rd) {
                $line = $r.ReadLine()
                if ($line -match '"request_id"') {
                    $m = [regex]::Match($line, '"data":([0-9.]+)')
                    if ($m.Success -and ([double]$m.Groups[1].Value) -ge $quitAtSec) { $done = $true }
                    break
                }
            }
            Start-Sleep -Milliseconds 500
        }
        if (-not $done) { throw "${clip}: never reached ${quitAtSec}s playback" }
        $w.WriteLine('{ "command": ["quit"] }')
        $pipe.Close()
        if (-not $p.WaitForExit(15000)) { $p.Kill(); throw "${clip}: mpv ignored quit" }
    } finally { if (-not $p.HasExited) { $p.Kill() } }
    return (Get-Content $sdrLog -Raw)
}
$log = PlaySdr 3
Check 'SDR run completed via IPC quit' ($true)
Check 'Colorspace-BT709 applied on SDR clip' ($log -match 'Applying auto profile: Colorspace-BT709')
Check 'SDR log has no fatal/error/lua lines' (-not ($log -match '\[fatal\]|\[error\]|lua error'))

# --- 2. HDR: Alt+h must engage the native fallback ---
$hdrLog = Join-Path $env:TEMP 'mpv-test-hdr.log'
Remove-Item $hdrLog -ErrorAction SilentlyContinue
$pipeName = 'mpv-profile-test'
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'hdrpq.mp4'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', "--input-ipc-server=$pipeName", "--log-file=$hdrLog", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
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
    $kp = Send '{ "command": ["keypress", "Alt+h"] }'
    Check 'Alt+h keypress accepted' ($kp -match '"error":"success"')
    Start-Sleep -Milliseconds 1500
    $tm = Send '{ "command": ["get_property", "tone-mapping"] }'
    Check 'tone-mapping == spline after Alt+h' ($tm -match '"data":"spline"')
    $gm = Send '{ "command": ["get_property", "gamut-mapping-mode"] }'
    Check 'gamut-mapping-mode == auto after Alt+h' ($gm -match '"data":"auto"')
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
} finally {
    if (-not $proc.HasExited) { $proc.Kill() }
}
$hdrLogText = Get-Content $hdrLog -Raw
Check 'HDR log sets tone-mapping=spline' ($hdrLogText -match 'Set property: tone-mapping="spline"')
Check 'HDR log has no unknown script-binding' (-not ($hdrLogText -match 'unknown script-binding'))
Check 'HDR log has no fatal/error/lua lines' (-not ($hdrLogText -match '\[fatal\]|\[error\]|lua error'))
exit $fail
