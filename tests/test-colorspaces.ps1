<#
Colorspace profiles: NTSC / PAL / gray must apply with the right target-prim.
Needs tests/clips/{ntsc,pal}.mp4 and gray.mkv (FFV1) from make-test-clips.ps1.
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
function PlayLog($clip, $quitAtSec = 3) {
    $log = Join-Path $env:TEMP ("mpv-test-{0}.log" -f [System.IO.Path]::GetFileNameWithoutExtension($clip))
    Remove-Item $log -ErrorAction SilentlyContinue
    $pipeName = ("mpv-pl-{0}" -f ([System.IO.Path]::GetFileNameWithoutExtension($clip) -replace '[^A-Za-z0-9]', ''))
    # IPC lifecycle: --loop-file=inf never ends alone, so quit once steady playback
    # is confirmed. --no-autocreate-playlist keeps single-file (config auto-queues
    # folder episodes); --no-resume-playback avoids stale watch_later seeks.
    $p = Start-Process $mpv -ArgumentList @((Join-Path $clips $clip), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$log", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
    try {
        $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
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
    $full = Get-Content $log -Raw
    $script:lastFull = $full
    # Steady-state window: track-selector restarts playback at EOF/track changes and
    # profiles re-evaluate with transient params afterwards — assert only on t<5s.
    return (($full -split "`n" | Where-Object { $_ -match '^\[\s*[0-4]\.' }) -join "`n")
}
$log = PlayLog 'ntsc.mp4'
Check 'NTSC applies Colorspace-NTSC' ($log -match 'Applying auto profile: Colorspace-NTSC')
Check 'NTSC target-prim=bt.601-525' ($log -match "Setting option 'target-prim' = 'bt.601-525'")
Check 'ntsc log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
$log = PlayLog 'pal.mp4'
Check 'PAL applies Colorspace-PAL' ($log -match 'Applying auto profile: Colorspace-PAL')
Check 'PAL target-prim=bt.601-625' ($log -match "Setting option 'target-prim' = 'bt.601-625'")
Check 'pal log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
$log = PlayLog 'gray.mkv'
Check 'gray clip applies gray profile' ($log -match 'Applying auto profile: gray')
$dels = @('CfL_Prediction', 'ArtCNN_C4F32', 'ravu-zoom-ar-r4', 'SSimSuperRes', 'SSimDownscaler') | Where-Object { $log -match "glsl-shaders-del.*$_" }
Check 'gray removes all chroma-reconstruction shaders (5 dels)' (@($dels).Count -eq 5)
Check 'gray log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
exit $fail
