<#
Resolution ladder: each height bucket must trigger its Res-* profile with the
right shader chain. Needs tests/clips/res*.mp4 from make-test-clips.ps1.
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
$ladder = @(
    @{ Clip = 'res480.mp4';  Profile = 'Res-SD';          Has = 'ArtCNN_C4F16.glsl' },
    @{ Clip = 'res720.mp4';  Profile = 'Res-720p-Clean2x'; Has = 'ArtCNN_C4F32.glsl' },
    @{ Clip = 'res1000.mp4'; Profile = 'Res-Fractional';  Has = 'ravu-zoom-ar-r4.hook' },
    @{ Clip = 'res1400.mp4'; Profile = 'Res-NearNative';  Has = 'CfL_Prediction.glsl'; HasNot = 'ravu-zoom-ar-r4.hook' },
    @{ Clip = 'res2160.mp4'; Profile = 'Res-Downscale';   Dscale = 'ewa_lanczos' }
)
foreach ($r in $ladder) {
    $log = PlayLog $r.Clip
    Check "$($r.Clip) applies $($r.Profile)" ($log -match "Applying auto profile: $($r.Profile)")
    if ($r.Has) { Check "$($r.Clip) loads $($r.Has)" ($log -match [regex]::Escape($r.Has)) }
    if ($r.HasNot) { Check "$($r.Clip) skips $($r.HasNot)" (-not ($log -match [regex]::Escape($r.HasNot))) }
    if ($r.Dscale) { Check "$($r.Clip) dscale=$($r.Dscale)" ($log -match "Setting option 'dscale' = '$($r.Dscale)'") }
    Check "$($r.Clip) log clean" (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
}
exit $fail
