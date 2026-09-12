<#
Seek recovery: after seek, vsync-ratio must converge near 1.0, mistimed small.
Uses fps23976a.mkv (23.976 + audio). Exit 0 = pass.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$clips = Join-Path $PSScriptRoot 'clips'
$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Output "PASS: $name" } else { Write-Output "FAIL: $name"; $script:fail++ }
}
$pipeName = 'mpv-seek-test'
$seekLog = Join-Path $env:TEMP 'mpv-test-seek.log'
Remove-Item $seekLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'fps23976a.mkv'), '--mute=yes', '--fullscreen', '--loop-file=inf', '--keep-open=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$seekLog", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(15000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    function RR($cmd) {
        $w.WriteLine($cmd)
        $dl = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $dl) { $l = $r.ReadLine(); if ($l -match '"request_id"') { return $l } }
        throw 'IPC reply timeout'
    }
    function Drain {
        $dl2 = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $dl2) { $l2 = $r.ReadLine(); if ($l2 -match '"request_id"') { return $l2 } }
        throw 'IPC reply timeout'
    }
    Start-Sleep -Milliseconds 2000
    RR '{ "command": ["seek", 5, "absolute"] }' | Out-Null
    $dl = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $dl) { if ($r.ReadLine() -match '"request_id"') { break } }
    $ok = $false
    $minR = [double]::PositiveInfinity
    $deadline = (Get-Date).AddSeconds(25)
    while (((Get-Date) -lt $deadline) -and (-not $ok)) {
        $w.WriteLine('{ "command": ["get_property", "vsync-ratio"] }')
        $m = [regex]::Match((Drain), '"data":([0-9.]+)')
        if ($m.Success) {
            $rv = [double]$m.Groups[1].Value
            if ($rv -lt $minR) { $minR = $rv }
            if ($rv -le 1.5) { $ok = $true }
        }
        Start-Sleep -Milliseconds 400
    }
    Check "vsync-ratio converges after seek (min $minR)" $ok
    $w.WriteLine('{ "command": ["get_property", "mistimed-frame-count"] }')
    $mm = [regex]::Match((Drain), '"data":([0-9]+)')
    $mist = if ($mm.Success) { [int]$mm.Groups[1].Value } else { 99999 }
    Check "mistimed stays low after seek (got $mist)" ($mist -lt 60)
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
    if (-not $proc.WaitForExit(15000)) { $proc.Kill() }
} finally { if (-not $proc.HasExited) { $proc.Kill() } }
exit $fail
