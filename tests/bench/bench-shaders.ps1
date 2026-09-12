<#
Shader pipeline bench: at what point is the chain too strong for this GPU?
Method: REAL-TIME FULLSCREEN playback of each clip through the real config
(gpu-next/Vulkan + auto profiles + shader chains) - fullscreen matches real
viewing and avoids windowed-DWM present-slot jitter, which showed up as 0-4
spurious mistimed frames per window and is not GPU load (delayed stayed 0).
Then read mpv's own drop counters over IPC.
Why not --untimed fps: on this stack untimed wall time mixes one-time Vulkan
pipeline compile, swapchain present behavior and process startup, and the GPU
sat at ~10% while it reported 18fps — the number measured everything except
render cost. Drop counters don't lie about playback.
Metric (drops over a fixed 8s window starting at 30% into each clip; load and
seek settle before the baseline is taken, so one-time pipeline-compile
stutter never counts):
  mistimed + delayed == 0   OK         (sustains realtime)
  mistimed + delayed < 10   MARGINAL   (plays, no headroom)
  mistimed + delayed >= 10  TOO STRONG (visible drops; lighten the chain)
Usage:
  powershell -NoProfile -ExecutionPolicy Bypass -File tests/bench/bench-shaders.ps1
Params: -Clips, -Presets (stock/nlmeans/heavy) to narrow the matrix. Values
may be space- or comma-separated (comma form survives launchers that eat
extra array words: -Clips res480.mp4,res720.mp4).
Close games/browsers first: background GPU load causes drops that are not the
pipeline's fault (rerun clean before concluding). Results append to
tests/bench/bench-results.csv for driver/config comparisons.
Exit 0 = bench completed (verdicts are informational, never fail).
#>
param(
    [string[]]$Clips = @('real480-ntsc.mkv', 'real720-av1.mkv', 'real1080-dual.mkv', 'real2160-pq.mkv'),
    [string[]]$Presets = @('stock', 'nlmeans', 'heavy')
)
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$testDir = Split-Path $PSScriptRoot -Parent
$clipRoots = @((Join-Path $testDir 'clips'), (Join-Path (Join-Path $testDir 'clips') 'real'))
$csv = Join-Path $PSScriptRoot 'bench-results.csv'
$inv = [System.Globalization.CultureInfo]::InvariantCulture
# Accept comma-separated values too: some launch layers swallow extra array
# words, so `-Clips a b` can arrive as just `a`; `a,b` always survives.
$Clips = @($Clips | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
$Presets = @($Presets | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })
Write-Output ('bench matrix: {0} clip(s) x {1} preset(s)' -f $Clips.Count, $Presets.Count)
$PresetArgs = @{
    'stock'   = @()
    'nlmeans' = @('--glsl-shaders-append=~~/shaders/nlmeans.glsl')
    'heavy'   = @('--glsl-shaders-append=~~/shaders/nlmeans.glsl', '--deband-iterations=4')
}
function ReadReply($r) {
    $deadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $deadline) {
        $line = $r.ReadLine()
        if ($line -match '"request_id"') { return $line }
    }
    throw 'IPC reply timeout'
}
function GetNum($w, $r, $prop) {
    $w.WriteLine("{ `"command`": [`"get_property`", `"$prop`" ] }")
    $m = [regex]::Match((ReadReply $r), '"data":([0-9.]+)')
    if ($m.Success) { return [double]$m.Groups[1].Value }
    return 0
}
if (-not (Test-Path $csv)) { 'timestamp,clip,preset,duration,mistimed,delayed,vsync_ratio,verdict' | Out-File $csv -Encoding utf8 }
$stamp = Get-Date -Format 'yyyy-MM-dd HH:mm'
foreach ($clip in $Clips) {
    $full = $clipRoots | ForEach-Object { Join-Path $_ $clip } | Where-Object { Test-Path $_ } | Select-Object -First 1
    if (-not $full) { Write-Output "SKIP: $clip (missing from clips/ and clips/real/)"; continue }
    foreach ($preset in $Presets) {
        $extra = $PresetArgs[$preset]
        if ($null -eq $extra) { Write-Output "SKIP: unknown preset $preset"; continue }
        $pipeName = 'mpv-bench-{0:x}' -f (Get-Random -Maximum 0xFFFFF)
        $args = @($full, '--vo=gpu-next', '--ao=null', '--force-window=yes', '--fullscreen', '--keep-open=yes', '--no-resume-playback', '--no-autocreate-playlist', '--no-terminal', "--input-ipc-server=$pipeName") + $extra
        $p = Start-Process $mpv -ArgumentList $args -PassThru -WindowStyle Normal -RedirectStandardOutput NUL
        try {
            $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
            $pipe.Connect(15000)
            $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
            $r = New-Object System.IO.StreamReader($pipe)
            # Handshake: wait until time-pos reports (mpv still initializing
            # pipelines before that; early property reads return errors).
            $ready = $false
            $deadline = (Get-Date).AddSeconds(60)
            while (((Get-Date) -lt $deadline) -and (-not $p.HasExited) -and (-not $ready)) {
                try {
                    $w.WriteLine('{ "command": ["get_property", "time-pos"] }')
                    if ((ReadReply $r) -match '"data":([0-9.]+)') { $ready = $true }
                } catch { Start-Sleep -Milliseconds 500 }
            }
            if (-not $ready) { Write-Output "SKIP: $clip $preset (mpv never became ready)"; continue }
            $dur = 0
            for ($i = 0; ($i -lt 10) -and ($dur -le 0); $i++) { $dur = GetNum $w $r 'duration' }
            if ($dur -le 0) { Write-Output "SKIP: $clip $preset (no duration)"; continue }
            # Fixed-window sampling: seek to 30%, settle 2s (seek + any
            # re-settle), baseline, sample 8s, finals. Faster than half-to-EOF
            # and immune to clip length.
            try {
                # Invariant decimal point: locale formatting would emit 1,5,
                # which is not valid JSON and mpv never replies to it.
                $seekTo = [string]::Format($inv, '{0:F1}', ($dur * 0.3))
                $w.WriteLine('{ "command": ["set_property", "time-pos", ' + $seekTo + '] }')
                [void](ReadReply $r)
                Start-Sleep -Milliseconds 2000
            } catch { Write-Output "SKIP: $clip $preset (seek failed)"; continue }
            try {
                $m0 = GetNum $w $r 'mistimed-frame-count'
                $d0 = GetNum $w $r 'vo-delayed-frame-count'
                $ratio = GetNum $w $r 'vsync-ratio'
            } catch { Write-Output "SKIP: $clip $preset (exited before baseline)"; continue }
            # Sample a fixed 8s window, then read finals while still playing.
            Start-Sleep -Milliseconds 8000
            $mist = 0; $del = 0
            if (-not $p.HasExited) {
                $mist = (GetNum $w $r 'mistimed-frame-count') - $m0
                $del = (GetNum $w $r 'vo-delayed-frame-count') - $d0
                $w.WriteLine('{ "command": ["quit"] }')
                $pipe.Close()
                $p.WaitForExit(15000) | Out-Null
            }
            $drops = $mist + $del
            $verdict = if ($drops -eq 0) { 'OK' } elseif ($drops -lt 10) { 'MARGINAL' } else { 'TOO STRONG' }
            Write-Output ([string]::Format($inv, '{0,-20} {1,-8} mistimed={2} delayed={3} vsync={4:F2}  {5}', $clip, $preset, $mist, $del, $ratio, $verdict))
            [string]::Format($inv, '{0},{1},{2},{3:F1},{4},{5},{6:F2},{7}', $stamp, $clip, $preset, $dur, $mist, $del, $ratio, $verdict) | Out-File $csv -Append -Encoding utf8
        } finally { if (-not $p.HasExited) { $p.Kill() } }
    }
}
Write-Output 'appended to tests/bench-results.csv'
exit 0
