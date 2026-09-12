<#
Master runner: audit + every tests/test-*.ps1 suite, linear on a single screen.
Presentation takes after cargo-pretty: a live view with a Running section
(spinner + per-suite timer), a Done (n/N) section with checkmarks, and a
pinned bottom bar with overall progress + elapsed. Falls back to plain
streaming lines when stdout is redirected (logs stay clean ASCII).
Pure ASCII on purpose: non-ASCII glyphs have caused encoding parse breaks
in Windows PowerShell 5.1 before, so color/markers stay in the ASCII set.
- Suites run in hidden child consoles (no window spam). mpv render windows
  still appear where a suite needs one (test-seek is timing-sensitive and
  keeps its fullscreen window by design).
- Exit code = number of failing suites (0 = everything green).
Run: powershell -NoProfile -ExecutionPolicy Bypass -File tests/run-all.ps1
#>
$ErrorActionPreference = 'Continue'
$live = -not [Console]::IsOutputRedirected
if ($live) { Clear-Host }
$esc = [char]27
function C($code, $text) {
    if ($live) { return ("$esc[{0}m{1}$esc[0m" -f $code, $text) }
    return $text
}
$DIM = '2'; $GREEN = '32'; $RED = '31'; $ORANGE = '38;5;208'
$SPIN = @('|', '/', '-', '\')
function Bar($done, $total, $width = 28) {
    $f = 0
    if ($total -gt 0) { $f = [int]([math]::Round($done * $width / $total)) }
    if ($f -gt $width) { $f = $width }
    if ($f -lt 0) { $f = 0 }
    $bar = ('#' * $f) + ('-' * ($width - $f))
    if ($live) { $bar = (C $ORANGE $bar) }
    return ('[' + $bar + ']')
}
Write-Output 'mpv test run'
# Refresh-rate guard: change-refresh (auto=yes) switches the display per clip
# and reverts on clean mpv exit - but killed mpvs never revert, stranding e.g.
# 23Hz. Snapshot here, repair strays after every step and at the end.
$mpvRoot = Split-Path $PSScriptRoot -Parent
$rateHelper = Join-Path $mpvRoot 'portable_config/tools/Set-RefreshRate.ps1'
Add-Type -AssemblyName System.Windows.Forms
$snapScreen = [System.Windows.Forms.Screen]::PrimaryScreen
$snap = @{
    W = $snapScreen.Bounds.Width; H = $snapScreen.Bounds.Height
    Rate = (Get-CimInstance Win32_VideoController | Select-Object -First 1).CurrentRefreshRate
    Dev = $snapScreen.DeviceName
}
if ($snap.Rate -ne 165) { Write-Output ("WARNING: display starts at {0}Hz, not 165Hz - restore it first for representative results" -f $snap.Rate) }
function Restore-Rate {
    $cur = (Get-CimInstance Win32_VideoController | Select-Object -First 1).CurrentRefreshRate
    if ($cur -ne $snap.Rate) {
        & $rateHelper -Width $snap.W -Height $snap.H -Rate $snap.Rate -DeviceName $snap.Dev | Out-Null
        Write-Output ("  (display rate repaired: {0}Hz -> {1}Hz)" -f $cur, $snap.Rate)
    }
}
# State guard: suites play real files through the real config, and scripts
# persist per-video state (track-selector overrides, watch_later). Snapshot
# before the run, restore after, so testing never rewrites your state.
$stateBak = Join-Path $env:TEMP 'mpv-run-statebak'
Remove-Item $stateBak -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $stateBak | Out-Null
$stateOv = Join-Path $mpvRoot 'portable_config/track-selector-overrides.json'
$stateWl = Join-Path $mpvRoot 'portable_config/cache/watch_later'
if (Test-Path $stateOv) { Copy-Item $stateOv (Join-Path $stateBak 'track-selector-overrides.json') }
if (Test-Path $stateWl) { Copy-Item $stateWl (Join-Path $stateBak 'watch_later') -Recurse }
function Restore-State {
    $bOv = Join-Path $stateBak 'track-selector-overrides.json'
    if (Test-Path $bOv) { Copy-Item $bOv $stateOv -Force }
    elseif (Test-Path $stateOv) { Remove-Item $stateOv -Force }
    $bWl = Join-Path $stateBak 'watch_later'
    if (Test-Path $bWl) {
        Remove-Item $stateWl -Recurse -Force -ErrorAction SilentlyContinue
        Copy-Item $bWl $stateWl -Recurse -Force
    }
}
$steps = @(
    @{ Name = 'audit'; File = (Join-Path $PSScriptRoot '../portable_config/tools/Audit-MpvEnvironment.ps1'); Args = '' }
)
$clips = Join-Path $PSScriptRoot 'clips'
if (-not ((Test-Path (Join-Path $clips 'sdr709.mp4')) -and (Test-Path (Join-Path $clips 'sdr20.mp4')) -and (Test-Path (Join-Path $clips 'sdr70.mp4')) -and (Test-Path (Join-Path $clips 'gray.mkv')) -and (Test-Path (Join-Path $clips 'duaudio.mkv')))) {
    $steps += @{ Name = 'make-test-clips'; File = (Join-Path $PSScriptRoot 'make-test-clips.ps1'); Args = '' }
}
foreach ($t in @('test-profiles.ps1', 'test-resolutions.ps1', 'test-colorspaces.ps1', 'test-hdrtoys.ps1', 'test-bindings.ps1', 'test-tracks.ps1', 'test-seek.ps1', 'test-session.ps1', 'test-config.ps1', 'test-realworld.ps1')) {
    $steps += @{ Name = $t; File = (Join-Path $PSScriptRoot $t); Args = '' }
}
# Perf smoke: bench-shaders on the real clips, stock preset only (informational;
# verdicts never fail the run — the rows stream live, full matrix stays manual).
$steps += @{ Name = 'bench-smoke'; File = (Join-Path $PSScriptRoot 'bench/bench-shaders.ps1'); Args = "-Clips real480-ntsc.mkv,real720-av1.mkv,real1080-dual.mkv,real2160-pq.mkv -Presets stock" }
$results = @()
$failedSuites = 0
$runId = '{0:x}-{1:HHmmss}' -f $PID, (Get-Date)
# Fresh slate: reap zombies from killed runs (they hold IPC pipes).
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
    $_.ProcessId -ne $PID -and $_.CommandLine -match 'tests[/\\]'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Stop-Process -Name mpv -Force -ErrorAction SilentlyContinue
$doneLines = @()
$runSw = [System.Diagnostics.Stopwatch]::StartNew()
$spinTick = 0
$script:maxView = 0
$script:feed = @()
function Feed($line) {
    $script:feed += $line
    if ($script:feed.Count -gt 5) { $script:feed = @($script:feed | Select-Object -Last 5) }
}
function Draw-View($curName, $curSecs) {
    if (-not $live) { return }
    [Console]::SetCursorPosition(0, 0)
    $w = 100
    $lines = @()
    $lines += 'mpv test run'
    $lines += (C $DIM ("Elapsed  {0:F1}s" -f $runSw.Elapsed.TotalSeconds))
    $lines += ''
    $lines += (C $DIM 'Running')
    $spin = $SPIN[$script:spinTick % $SPIN.Count]
    $lines += ("  {0} {1}  {2:F1}s" -f $spin, $curName, $curSecs)
    $lines += ''
    $lines += (C $DIM ("Done ({0}/{1})" -f $doneLines.Count, $steps.Count))
    foreach ($d in @($doneLines | Select-Object -Last 4)) { $lines += $d }
    $lines += ''
    $lines += (C $DIM 'Latest')
    foreach ($f in $script:feed) { $lines += $f }
    $lines += ''
    $pct = [int](($doneLines.Count / $steps.Count) * 100)
    $lines += ("Run  {0}  {1}%" -f (Bar $doneLines.Count $steps.Count), $pct)
    while ($lines.Count -lt $script:maxView) { $lines += '' }
    $script:maxView = $lines.Count
    foreach ($ln in $lines) {
        if ($ln.Length -lt $w) { Write-Output ($ln + (' ' * ($w - $ln.Length))) }
        else { Write-Output $ln }
    }
}
for ($i = 0; $i -lt $steps.Count; $i++) {
    $s = $steps[$i]
    $pct = [int](($i / $steps.Count) * 100)
    Write-Progress -Activity 'mpv tests' -Status ("[{0}/{1}] {2}" -f ($i + 1), $steps.Count, $s.Name) -PercentComplete $pct
    $out = Join-Path $env:TEMP (("mpv-run-{0}-{1}.log" -f ($s.Name -replace '[^A-Za-z0-9]', ''), $runId))
    Remove-Item $out -ErrorAction SilentlyContinue
    $done = "$out.done"
    Remove-Item $out -ErrorAction SilentlyContinue
    Remove-Item $done -ErrorAction SilentlyContinue
    $cmd = "powershell -NoProfile -ExecutionPolicy Bypass -File '" + $s.File + "' " + $s.Args + "; " + '$c=$LASTEXITCODE; if ([string]::IsNullOrEmpty("$c")) { $c=1 }; Set-Content ' + "'" + $done + "' `$c"
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $mpvBefore = @(Get-Process -Name mpv -ErrorAction SilentlyContinue | ForEach-Object { $_.Id })
    $p = Start-Process powershell -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $cmd) -WindowStyle Hidden -PassThru -RedirectStandardOutput $out -RedirectStandardError ($out + '.err')
    if (-not $live) { Write-Output ("> [{0}/{1}] {2} ..." -f ($i + 1), $steps.Count, $s.Name) }
    $shown = 0
    while (-not $p.HasExited) {
        Start-Sleep -Milliseconds 800
        $script:spinTick++
        Draw-View $s.Name $sw.Elapsed.TotalSeconds
        if (Test-Path $out) {
            $lines = @(Get-Content $out)
            for ($k = $shown; $k -lt $lines.Count; $k++) {
                $lk = $lines[$k]
                $disp = $null; $quiet = $false
                if ($s.Name -eq 'audit' -and $lk.Trim() -ne '') {
                    $disp = ("    [audit] {0}" -f $lk)
                    $quiet = $live
                }
                elseif ($lk -match '^PASS: (.*)') { $disp = ("    [{0}] [+] {1}" -f $s.Name, $Matches[1]) }
                elseif ($lk -match '^FAIL: (.*)') { $disp = ("    [{0}] [-] {1}" -f $s.Name, $Matches[1]) }
                elseif ($lk -match '^SKIP: (.*)') { $disp = ("    [{0}] [?] {1}" -f $s.Name, $Matches[1]) }
                elseif ($lk -match 'mistimed=') { $disp = ("    [{0}] [~] {1}" -f $s.Name, $lk.Trim()) }
                elseif ($lk -match '^bench matrix:') { $disp = ("    [{0}] {1}" -f $s.Name, $lk) }
                if ($null -ne $disp) {
                    Feed $disp
                    $isFail = $disp.Contains('[-]')
                    if ((-not $quiet) -and (($s.Name -eq 'audit') -or $isFail -or (-not $live))) { Write-Output $disp }
                }
            }
            $shown = $lines.Count
        }
    }
    if (-not $p.WaitForExit(60000)) {
        $p.Kill()
        Start-Sleep -Milliseconds 1000
        Get-Process -Name mpv -ErrorAction SilentlyContinue | Where-Object { $mpvBefore -notcontains $_.Id } | ForEach-Object { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue }
    }
    for ($w = 0; ($w -lt 10) -and (-not (Test-Path $done)); $w++) { Start-Sleep -Milliseconds 500 }
    Restore-Rate
    $sw.Stop()
    $text = ''
    if (Test-Path $out) {
        $t = Get-Content $out -Raw
        if ($null -ne $t) { $text = $t }
    }
    $pass = ([regex]::Matches($text, '(?m)^PASS:')).Count
    $fail = ([regex]::Matches($text, '(?m)^FAIL:')).Count
    $skip = ([regex]::Matches($text, '(?m)^SKIP:')).Count
    $completed = Test-Path $done
    $code = 1
    if ($completed) { $code = [int]((Get-Content $done -Raw).Trim()) }
    $ok = $completed -and ($code -eq 0) -and ($fail -eq 0)
    if (-not $ok) { $failedSuites++ }
    $state = if ($ok) { if ($skip -gt 0 -and ($pass + $fail) -eq 0) { 'SKIP' } else { 'ok' } } else { 'FAIL' }
    $mark = if ($ok) { '[ok]' } else { '[FAIL]' }
    $doneLines += ("  {0} {1,-22}  {2:F1}s" -f $mark, $s.Name, $sw.Elapsed.TotalSeconds)
    if (-not $live) {
        Write-Output ("  [{0}/{1}] {2,-22} {3}  ({4}s)" -f ($i + 1), $steps.Count, $s.Name, $state, [int]$sw.Elapsed.TotalSeconds)
    }
    $results += [pscustomobject]@{ Suite = $s.Name; Pass = $pass; Fail = $fail; Skip = $skip; Secs = [int]$sw.Elapsed.TotalSeconds; State = $state }
}
$runSw.Stop()
Restore-Rate
Restore-State
Write-Output 'player state restored (overrides + watch_later snapshot)'
Write-Progress -Activity 'mpv tests' -Completed
Write-Output ''
Write-Output ('{0,-22} {1,5} {2,5} {3,5} {4,6}  {5}' -f 'SUITE', 'PASS', 'FAIL', 'SKIP', 'SECS', 'STATE')
foreach ($r in $results) {
    Write-Output ('{0,-22} {1,5} {2,5} {3,5} {4,6}  {5}' -f $r.Suite, $r.Pass, $r.Fail, $r.Skip, $r.Secs, $r.State)
}
$tp = ($results | Measure-Object -Property Pass -Sum).Sum
$tf = ($results | Measure-Object -Property Fail -Sum).Sum
$ts = ($results | Measure-Object -Property Skip -Sum).Sum
$tt = ($results | Measure-Object -Property Secs -Sum).Sum
Write-Output ('{0,-22} {1,5} {2,5} {3,5} {4,6}' -f 'TOTAL', $tp, $tf, $ts, $tt)
Write-Output ('Tests passed: {0}, failed: {1}, skipped: {2} ({3}s total)' -f $tp, $tf, $ts, $tt)
if ($failedSuites -eq 0) { Write-Output 'ALL GREEN' } else { Write-Output ("*** {0} FAILING SUITE(S) ***" -f $failedSuites) }
exit $failedSuites
