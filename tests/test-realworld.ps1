<#
Real-world clips in clips/real/ (see make-test-clips.ps1 'real clips' for recipes):
- real1080-dual.mkv (16s, 1080p BT.709, jpn+eng AAC, eng/por/spa ASS) cut from
  Assassination Classroom movie WEB-DL DUAL (owned file, -ss 600, all streams).
- real2160-pq.mkv (28s, 2160p HEVC BT.2020/PQ, TrueHD 7.1 jpn + eng DTS + 25 subs)
  cut from Demon Slayer Mugen Train 2160p HDR10 (Nyaa 1986971, -ss 600).
  NOTE: an earlier cut from a non-anime film used this name; replaced Sep 2026.
- real70.mkv (71s, 1080p BT.709) same AssClass source, for [ending].
- real480-ntsc.mkv (17s, 708x480 HEVC10 smpte170m NTSC, 5 audios incl. jpn mono
  broadcast + 6 subs) cut from Dragon Ball Ep2 DVD (Nyaa 2129329, -ss 120).
- real720-av1.mkv (18s, 720p AV1 10-bit BT.709, jpn opus + eng ASS) cut from
  Jujutsu Kaisen S01E01 720p (Nyaa 1836458, -ss 120).
- real720-nier.mkv (21s, 720p h264 BT.709, jpn aac + 9 subs incl. spa/spa-LA)
  cut from NieR Automata Erai-raws ep12 (Nyaa 1878229, -ss 120).
Still synthetic (no real anime source on Nyaa): 1440p ladder (upscale real1080
via ffmpeg when needed), HLG, PAL. Gray stays synthetic (or format=gray from
real1080 — TBD).
Exit 0 = all checks pass.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$clips = Join-Path (Join-Path $PSScriptRoot 'clips') 'real'
foreach ($need in @('real1080-dual.mkv', 'real2160-pq.mkv', 'real70.mkv', 'real480-ntsc.mkv', 'real720-av1.mkv', 'real720-nier.mkv')) {
    if (-not (Test-Path (Join-Path $clips $need))) {
        Write-Output "SKIP: $need absent (see make-test-clips.ps1 'real clips' section for provenance/recipe)"
        Write-Output 'SKIP: whole real-world suite (no real clips present)'
        exit 0
    }
}
$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Output "PASS: $name" } else { Write-Output "FAIL: $name"; $script:fail++ }
}
function PlayLog($clip, $quitAtSec = 3, $loop = $true) {
    $log = Join-Path $env:TEMP ("mpv-test-{0}.log" -f [System.IO.Path]::GetFileNameWithoutExtension($clip))
    Remove-Item $log -ErrorAction SilentlyContinue
    $pipeName = ("mpv-pl-{0}" -f ([System.IO.Path]::GetFileNameWithoutExtension($clip) -replace '[^A-Za-z0-9]', ''))
    $loopArg = if ($loop) { '--loop-file=inf' } else { '--loop-file=no' }
    $p = Start-Process $mpv -ArgumentList @((Join-Path $clips $clip), $loopArg, '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$log", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
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
    return (($full -split "`n" | Where-Object { $_ -match '^\[\s*[0-4]\.' }) -join "`n")
}
# --- 1. real1080-dual: SDR BT.709 + 1080p ladder + jpn audio ---
$log = PlayLog 'real1080-dual.mkv'
Check 'real1080 applies Colorspace-BT709' ($log -match 'Applying auto profile: Colorspace-BT709')
Check 'real1080 applies Res-Fractional' ($log -match 'Applying auto profile: Res-Fractional')
Check 'real1080 log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
# smart select on real dual audio (jpn first -> aid 1)
$pipeName = 'mpv-real-tracks'
$ipcLog = Join-Path $env:TEMP 'mpv-test-real-tracks.log'
Remove-Item $ipcLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'real1080-dual.mkv'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$ipcLog", '--msg-level=all=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
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
    Check 'real1080 smart select picks jpn (aid=1)' ($aid -match '"data":1')
    $slist = Send '{ "command": ["get_property", "track-list"] }'
    Check 'real1080 carries spa subtitle track' ($slist -match '"lang":"spa"')
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
    if (-not $proc.WaitForExit(15000)) { $proc.Kill(); throw 'real tracks: mpv ignored quit' }
} finally { if (-not $proc.HasExited) { $proc.Kill() } }
$ipcText = Get-Content $ipcLog -Raw
Check 'real1080 tracks log clean' (-not ($ipcText -match '\[fatal\]|\[error\]|lua error'))
# --- 2. real2160-pq: 4K downscale + PQ HDR ---
$log = PlayLog 'real2160-pq.mkv'
Check 'real2160 applies Res-Downscale' ($log -match 'Applying auto profile: Res-Downscale')
Check 'real2160 applies bt.2100-pq' ($log -match 'Applying auto profile: bt.2100-pq')
Check 'real2160 log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
# --- 3. real480-ntsc: SD ladder + NTSC colorspace + jpn-not-first selection ---
$log = PlayLog 'real480-ntsc.mkv'
Check 'real480 applies Res-SD' ($log -match 'Applying auto profile: Res-SD')
Check 'real480 applies Colorspace-NTSC' ($log -match 'Applying auto profile: Colorspace-NTSC')
Check 'real480 log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
# jpn broadcast audio is aid 2 here (eng dub first) — alang must skip ahead
$pipeName = 'mpv-real-480'
$ipcLog = Join-Path $env:TEMP 'mpv-test-real-480.log'
Remove-Item $ipcLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'real480-ntsc.mkv'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$ipcLog", '--msg-level=all=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(15000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    function Send480($json) {
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
        $tp = Send480 '{ "command": ["get_property", "time-pos"] }'
        $m = [regex]::Match($tp, '"data":([0-9.]+)')
        if ($m.Success -and ([double]$m.Groups[1].Value) -ge 2) { break }
        Start-Sleep -Milliseconds 500
    }
    $aid = Send480 '{ "command": ["get_property", "aid"] }'
    Check 'real480 smart select skips to jpn (aid=2)' ($aid -match '"data":2')
    $slist = Send480 '{ "command": ["get_property", "track-list"] }'
    Check 'real480 carries jpn mono broadcast track' ($slist -match 'Broadcast')
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
    if (-not $proc.WaitForExit(15000)) { $proc.Kill(); throw 'real480 tracks: mpv ignored quit' }
} finally { if (-not $proc.HasExited) { $proc.Kill() } }
$ipcText = Get-Content $ipcLog -Raw
Check 'real480 tracks log clean' (-not ($ipcText -match '\[fatal\]|\[error\]|lua error'))
# --- 4. real720-av1: 720p ladder on a real AV1 10-bit source ---
$log = PlayLog 'real720-av1.mkv'
Check 'real720-av1 applies Res-720p-Clean2x' ($log -match 'Applying auto profile: Res-720p-Clean2x')
Check 'real720-av1 log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
# --- 5. real720-nier: jpn audio + Spanish subs on a real multi-sub file ---
$pipeName = 'mpv-real-nier'
$ipcLog = Join-Path $env:TEMP 'mpv-test-real-nier.log'
Remove-Item $ipcLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'real720-nier.mkv'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$ipcLog", '--msg-level=all=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
try {
    $pipe = New-Object System.IO.Pipes.NamedPipeClientStream('.', $pipeName, [System.IO.Pipes.PipeDirection]::InOut)
    $pipe.Connect(15000)
    $w = New-Object System.IO.StreamWriter($pipe); $w.AutoFlush = $true
    $r = New-Object System.IO.StreamReader($pipe)
    function SendNier($json) {
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
        $tp = SendNier '{ "command": ["get_property", "time-pos"] }'
        $m = [regex]::Match($tp, '"data":([0-9.]+)')
        if ($m.Success -and ([double]$m.Groups[1].Value) -ge 2) { break }
        Start-Sleep -Milliseconds 500
    }
    $aid = SendNier '{ "command": ["get_property", "aid"] }'
    Check 'real720-nier audio is jpn (aid=1)' ($aid -match '"data":1')
    $slist = SendNier '{ "command": ["get_property", "track-list"] }'
    Check 'real720-nier carries spa subtitle track' ($slist -match '"lang":"spa"')
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
    if (-not $proc.WaitForExit(15000)) { $proc.Kill(); throw 'real nier tracks: mpv ignored quit' }
} finally { if (-not $proc.HasExited) { $proc.Kill() } }
$ipcText = Get-Content $ipcLog -Raw
Check 'real720-nier tracks log clean' (-not ($ipcText -match '\[fatal\]|\[error\]|lua error'))
# --- 6. real70: [ending] engages in last 60s of a real file (no loop: looped
# playback reports infinite time-remaining so [ending] never engages) ---
$log = PlayLog 'real70.mkv' 14 $false
# NOTE: ending engages mid-playback (~11.5s in, when remaining hits 60s), past
# PlayLog's t<5s steady-state window — assert on the full log like test-session.
Check 'real70 [ending] applies in-window' ($script:lastFull -match 'Applying auto profile: ending')
Check "real70 sets save-position=no" ($script:lastFull -match "Setting option 'save-position-on-quit' = 'no'")
Check 'real70 log clean' (-not ($script:lastFull -match '\[fatal\]|\[error\]|lua error'))
exit $fail
