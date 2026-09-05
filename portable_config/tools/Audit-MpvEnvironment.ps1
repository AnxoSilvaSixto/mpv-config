<#
.SYNOPSIS
    Read-only audit for this portable mpv tree.
.DESCRIPTION
    Validates the portable layout, JSON/XML metadata, script registration,
    Git LFS pointer files, and a short mpv startup smoke test. It writes only
    its temporary startup log outside the repository and does not alter config,
    state, cache, or update logs.
    Compatible with Windows PowerShell 5.1.
#>

[CmdletBinding()]
param(
    [switch]$FailOnLfsPointer,
    [int]$StartupTimeoutSeconds = 15
)

$ErrorActionPreference = 'Stop'
$ToolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigDir = Split-Path -Parent $ToolsDir
$Root = Split-Path -Parent $ConfigDir
$Mpv = Join-Path $Root 'mpv.com'
if (-not (Test-Path $Mpv)) { $Mpv = Join-Path $Root 'mpv.exe' }
$TempLog = Join-Path $env:TEMP ('mpv-audit-{0}.log' -f ([guid]::NewGuid().ToString('N')))
$errors = 0
$warnings = 0

function Pass([string]$Message) { Write-Host "PASS: $Message" -ForegroundColor Green }
function Info([string]$Message) { Write-Host "INFO: $Message" -ForegroundColor Cyan }
function Warn([string]$Message) { $script:warnings++; Write-Host "WARN: $Message" -ForegroundColor Yellow }
function Fail([string]$Message) { $script:errors++; Write-Host "FAIL: $Message" -ForegroundColor Red }
function Check-Path([string]$RelativePath) {
    $path = Join-Path $Root $RelativePath
    if (Test-Path $path) { Pass $RelativePath }
    else { Fail "missing path: $RelativePath" }
}

Write-Host "Auditing portable mpv root: $Root"

# Required files and the standalone script layout.
@(
    'portable_config',
    'portable_config/mpv.conf',
    'portable_config/input.conf',
    'portable_config/hdr-toys.conf',
    'portable_config/scripts/thumbfast.lua',
    'portable_config/scripts/media/main.lua',
    'portable_config/scripts/media/skip_intro.lua',
    'portable_config/scripts/media/sub-select.lua',
    'portable_config/scripts/display/main.lua',
    'portable_config/scripts/display/change-refresh.lua',
    'portable_config/tools/Update-MpvEnvironment.ps1',
    'portable_config/tools/Set-RefreshRate.ps1',
    'settings.xml'
) | ForEach-Object { Check-Path $_ }

# Validator-only negative assertion: the obsolete media/thumbfast.lua path must
# remain absent; it is not part of the current portable layout documentation.
$legacyThumbfast = Join-Path (Join-Path (Join-Path (Join-Path $Root 'portable_config') 'scripts') 'media') 'thumbfast.lua'
if (Test-Path $legacyThumbfast) { Fail 'validator negative assertion: obsolete media/thumbfast.lua still exists; thumbfast must be top-level' }
else { Pass 'validator negative assertion: obsolete media/thumbfast.lua is absent' }

$mediaMain = Get-Content (Join-Path $Root 'portable_config/scripts/media/main.lua') -Raw
if ($mediaMain -match 'require\s+\S*thumbfast') { Fail 'media/main.lua still requires thumbfast' }
else { Pass 'media/main.lua does not require thumbfast' }

$updater = Get-Content (Join-Path $Root 'portable_config/tools/Update-MpvEnvironment.ps1') -Raw
if ($updater -match 'Dest\s*=\s*[''\"]scripts\\thumbfast\.lua[''\"]') { Pass 'updater destination is scripts/thumbfast.lua' }
else { Fail 'updater destination is not scripts/thumbfast.lua' }

$mpvConf = Get-Content (Join-Path $Root 'portable_config/mpv.conf') -Raw
if ($mpvConf -match 'profile-cond=get\("duration",0\)>0 and get\("time-remaining",0\)<=60') {
    Pass '[ending] profile has a positive duration guard'
} else { Fail '[ending] profile is not guarded against idle activation' }

# Parse PowerShell, JSON, and XML without executing updater side effects.
foreach ($script in @('portable_config/tools/Update-MpvEnvironment.ps1', 'portable_config/tools/Set-RefreshRate.ps1', 'portable_config/tools/Audit-MpvEnvironment.ps1')) {
    try {
        [void][scriptblock]::Create((Get-Content (Join-Path $Root $script) -Raw))
        Pass "PowerShell syntax: $script"
    } catch { Fail "PowerShell syntax: $script ($($_.Exception.Message))" }
}
try {
    [void](Get-Content (Join-Path $Root 'portable_config/tools/update-state.json') -Raw | ConvertFrom-Json)
    Pass 'update-state.json parses'
} catch {
    Warn "update-state.json was not parsed (it may be intentionally absent or ignored): $($_.Exception.Message)"
}
try {
    [void][xml](Get-Content (Join-Path $Root 'settings.xml') -Raw)
    Pass 'settings.xml parses'
} catch { Fail "settings.xml XML parse failed: $($_.Exception.Message)" }

# Detect, but do not modify, LFS pointer files. A clone without git-lfs is usable
# for metadata checks but cannot use those shaders correctly.
$lfsPointers = @()
Get-ChildItem (Join-Path $Root 'portable_config/shaders') -File -ErrorAction SilentlyContinue | ForEach-Object {
    if ((Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue) -match '^version https://git-lfs.github.com/spec/v1$') {
        $lfsPointers += $_.FullName
    }
}
if ($lfsPointers.Count -gt 0) {
    $message = "found $($lfsPointers.Count) Git LFS pointer file(s); run 'git lfs pull' before playback"
    if ($FailOnLfsPointer) { Fail $message } else { Warn $message }
} else { Pass 'no top-level shader LFS pointers detected' }

# Startup smoke test. Use temporary cache/watch-later locations and a temp log so
# this audit cannot modify generated repository state.
if (-not (Test-Path $Mpv)) {
    Warn 'mpv.com/mpv.exe not found; startup smoke test skipped'
} else {
    try {
        if (Test-Path $TempLog) { Remove-Item $TempLog -Force }
        $args = @(
            "--config-dir=$ConfigDir",
            '--idle=once', '--keep-open=no', '--force-window=no', '--no-terminal',
            "--log-file=$TempLog",
            "--gpu-shader-cache-dir=$(Join-Path $env:TEMP 'mpv-audit-shaders')",
            "--watch-later-dir=$(Join-Path $env:TEMP 'mpv-audit-watch-later')"
        )
        $process = Start-Process -FilePath $Mpv -ArgumentList $args -PassThru -WindowStyle Hidden
        $timedOut = -not $process.WaitForExit($StartupTimeoutSeconds * 1000)
        if ($timedOut) {
            if (-not $process.HasExited) { $process.Kill() }
            $process.WaitForExit()
        }
        if (-not (Test-Path $TempLog)) { Fail 'mpv produced no startup log' }
        else {
            $log = Get-Content $TempLog -Raw
            $scriptsLoaded = $log -match '(?m)^\s*\[[^\r\n\]]+\]\[v\]\[cplayer\]\s+Done loading scripts\.'
            if ($timedOut -and $scriptsLoaded) {
                Info "mpv completed script loading but remained active; stopped only audit-owned process PID $($process.Id) at $StartupTimeoutSeconds seconds"
                Pass 'mpv idle startup completed script loading before bounded timeout'
            } elseif ($timedOut) {
                Fail "mpv startup did not complete within $StartupTimeoutSeconds seconds"
            } else {
                Pass 'mpv idle startup completed within bounded timeout'
            }
            # Match only mpv records whose severity field is error or fatal. Do not
            # search arbitrary log text: verbose build configuration can contain
            # compiler flags such as -Wno-error=int-conversion.
            $bad = @($log -split "`r?`n" | Where-Object {
                $_ -match '(?i)^\s*\[[^\r\n\]]+\]\[(?:e|fatal)\]\[[^\r\n\]]+\]\s+'
            })
            if ($bad.Count -gt 0) {
                $bad | ForEach-Object { Fail "mpv log: $_" }
            } else { Pass 'mpv idle startup log has no known error markers' }
        }
    } catch { Fail "mpv startup test failed: $($_.Exception.Message)" }
    finally {
        if ($null -ne $process -and -not $process.HasExited) { $process.Kill(); $process.WaitForExit() }
        Remove-Item $TempLog -Force -ErrorAction SilentlyContinue
    }
}

# Validate that relocation-sensitive paths are derived from the active config root.
$refreshScript = Get-Content (Join-Path $Root 'portable_config/scripts/display/change-refresh.lua') -Raw
$expectedHdrRoot = ((Join-Path $ConfigDir 'shaders\hdr-toys') -replace '\\', '/')
$probePath = 'C:\portable_config\shaders\hdr-toys'
$normalizedProbe = $probePath -replace '\\', '/'
$hasPsNormalizer = [regex]::IsMatch($updater, "-replace\s+'\\\\'\s*,\s*'/'")
if (($updater -match '\$HdrShaderRoot') -and $hasPsNormalizer -and ($updater -notmatch 'C:/mpv/portable_config/shaders/hdr-toys') -and ($normalizedProbe -eq 'C:/portable_config/shaders/hdr-toys')) {
    Pass "hdr-toys updater derives normalized shader paths from config root ($expectedHdrRoot)"
} else {
    Fail 'hdr-toys updater has a missing, hard-coded, or invalid shader path transform'
}
$hasLuaNormalizer = $refreshScript.Contains("gsub('\\', '/')")
if (($refreshScript -match "mp\.get_property\('config-dir'\)") -and $hasLuaNormalizer -and ($refreshScript -notmatch 'helper_script\s*=\s*["'']C:/mpv/')) {
    Pass 'refresh helper derives and normalizes its path from mpv config-dir'
} else {
    Fail 'refresh helper path is hard-coded, missing config-dir resolution, or not normalized'
}

Write-Host "Audit complete: $errors error(s), $warnings warning(s)."
if ($errors -gt 0) { exit 1 }
exit 0
