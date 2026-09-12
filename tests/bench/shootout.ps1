<#
Shader shootout: perf-gate + fidelity screenshots for ONE candidate chain.
Runs --no-config with a fixed base mirroring the real config (gpu-next /
Vulkan / high-quality / deband / fruit) so chains compare fairly.
- Perf: fixed 8s window drops via IPC (same method as bench-shaders).
- Fidelity: 2 screenshots (post-renderer, shaders applied) at fixed media
  timestamps for A/B judging.
Usage:
  ... bench/shootout.ps1 -Clip <path> -Label <name> -Chain <shader paths>
  (-Chain comma- or space-separated; absolute paths recommended.)
Shots land in tests/bench/shots/<Label>/.
Exit 0 = measured (verdict informational).
#>
param(
    [Parameter(Mandatory=$true)][string]$Clip,
    [Parameter(Mandatory=$true)][string]$Label,
    [string[]]$Chain = @(),
    [double]$ShotAt1 = 0,
    [double]$ShotAt2 = 0
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$mpv = Join-Path $root 'mpv.exe'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$Chain = @($Chain | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
foreach ($s in $Chain) { if (-not (Test-Path $s)) { Write-Output "SKIP: shader missing: $s"; exit 0 } }
$shotDir = Join-Path (Join-Path $PSScriptRoot 'shots') $Label
New-Item -ItemType Directory -Force -Path $shotDir | Out-Null
$args = @($Clip, '--no-config', '--vo=gpu-next', '--gpu-api=vulkan', '--hwdec=auto-safe', '--hwdec-extra-frames=10', '--profile=high-quality', '--scale-antiring=0.7', '--deband=yes', '--dither-depth=auto', '--dither=fruit', '--target-prim=bt.709', '--target-trc=bt.1886', '--ao=null', '--force-window=yes', '--fullscreen', '--keep-open=yes', '--no-terminal', '--screenshot-format=png', '--screenshot-png-compression=1', '--input-ipc-server=mpv-shoot-{0:x}' -f (Get-Random -Maximum 0xFFFFF))
foreach ($s in $Chain) { $args += "--glsl-shaders-append=$s" }
$pipeName = ($args | Where-Object { $_ -match 'input-ipc-server=(.*)' } | ForEach-Object { $Matches[1] } | Select-Object -First 1)
function ReadReply($r) {
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        $line = $r.ReadLine()
        if ($line -match '"request_id"') { return $line }
    }
    throw 'IPC reply timeout'
}
function GetNum($w, $r, $prop) {
    $w.WriteLine(('{ "command": ["get_property", "' + $prop + '"] }'))
    $m = [regex]::Match((ReadReply $r), '"data":([0-9.]+)')
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return 0
}
$p = Start-Process $mpv -ArgumentList $args -PassThru -WindowStyle Normal -RedirectStandardOutput NUL
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(15000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    $ready = $false
    $deadline = (Get-Date).AddSeconds(60)
    while (((Get-Date) -lt $deadline) -and (-not $p.HasExited) -and (-not $ready)) {
        try {
            $w.WriteLine('{ "command": ["get_property", "time-pos"] }')
            if ((ReadReply $r) -match '"data":([0-9.]+)') { $ready = $true }
        } catch { Start-Sleep -Milliseconds 500 }
    }
    if (-not $ready) { Write-Output "SKIP: $Label (mpv never became ready)"; exit 0 }
    $dur = 0
    for ($i = 0; ($i -lt 10) -and ($dur -le 0); $i++) { $dur = GetNum $w $r 'duration' }
    if ($dur -le 0) { Write-Output "SKIP: $Label (no duration)"; exit 0 }
    if ($ShotAt1 -le 0) { $ShotAt1 = $dur * 0.3 }
    if ($ShotAt2 -le 0) { $ShotAt2 = $dur * 0.6 }
    try {
        $w.WriteLine(('{ "command": ["set_property", "time-pos", ' + ([string]::Format($inv, '{0:F1}', $ShotAt1)) + '] }'))
        [void](ReadReply $r)
        Start-Sleep -Milliseconds 2000
    } catch { Write-Output "SKIP: $Label (seek failed)"; exit 0 }
    try {
        $m0 = GetNum $w $r 'mistimed-frame-count'
        $d0 = GetNum $w $r 'vo-delayed-frame-count'
        $ratio = GetNum $w $r 'vsync-ratio'
    } catch { Write-Output "SKIP: $Label (exited before baseline)"; exit 0 }
    Start-Sleep -Milliseconds 8000
    $mist = 0; $del = 0
    if (-not $p.HasExited) {
        $mist = (GetNum $w $r 'mistimed-frame-count') - $m0
        $del = (GetNum $w $r 'vo-delayed-frame-count') - $d0
        $shot1 = Join-Path $shotDir 'shot1.png'
        $shot2 = Join-Path $shotDir 'shot2.png'
        $w.WriteLine(('{ "command": ["screenshot-to-file", "' + ($shot1 -replace '\\', '/') + '", "window"] }'))
        [void](ReadReply $r)
        Start-Sleep -Milliseconds 500
        $w.WriteLine(('{ "command": ["set_property", "time-pos", ' + ([string]::Format($inv, '{0:F1}', $ShotAt2)) + '] }'))
        [void](ReadReply $r)
        Start-Sleep -Milliseconds 1500
        $w.WriteLine(('{ "command": ["screenshot-to-file", "' + ($shot2 -replace '\\', '/') + '", "window"] }'))
        [void](ReadReply $r)
        $w.WriteLine('{ "command": ["quit"] }')
        $pipe.Close()
        $p.WaitForExit(15000) | Out-Null
    }
    $drops = $mist + $del
    $verdict = if ($drops -eq 0) { 'OK' } elseif ($drops -lt 10) { 'MARGINAL' } else { 'TOO STRONG' }
    Write-Output ([string]::Format($inv, '{0,-24} mistimed={1} delayed={2}  {3}  shots={4}', $Label, $mist, $del, $verdict, $shotDir))
} finally { if (-not $p.HasExited) { $p.Kill() } }
exit 0
