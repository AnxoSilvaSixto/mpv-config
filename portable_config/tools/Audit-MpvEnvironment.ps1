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

# hdr-toggle.lua: must exist and expose hdr-toys filtering via script-binding
$hdrTogglePath = Join-Path $Root 'portable_config/scripts/hdr-toggle.lua'
if (-not (Test-Path $hdrTogglePath)) {
    Fail 'missing path: portable_config/scripts/hdr-toggle.lua'
} else {
    Pass 'portable_config/scripts/hdr-toggle.lua'
    try {
        $hdrToggleRaw = Get-Content $hdrTogglePath -Raw
        if ($hdrToggleRaw -match 'hdr-toys') { Pass 'hdr-toggle.lua contains hdr-toys filter' }
        else { Fail 'hdr-toggle.lua missing hdr-toys filter (must :find(''hdr-toys'',1,true))' }
        if ($hdrToggleRaw -match 'hdr-toggle') { Pass 'hdr-toggle.lua contains hdr-toggle binding name' }
        else { Fail 'hdr-toggle.lua missing hdr-toggle binding name' }
        # script-binding style: must register script message or key binding so input.conf can do script-binding hdr-toggle/toggle
        if (($hdrToggleRaw -match "mp\.add_key_binding\s*\([^\)]*'hdr-toggle'") -or ($hdrToggleRaw -match 'mp\.add_key_binding\s*\([^\)]*"hdr-toggle"') -or ($hdrToggleRaw -match "register_script_message\s*\(\s*['\""]toggle['\""]")) {
            Pass 'hdr-toggle.lua registers script-binding hdr-toggle/toggle'
        } else { Fail 'hdr-toggle.lua missing script-binding hdr-toggle registration (expected mp.add_key_binding ... hdr-toggle and register_script_message toggle)' }
        # PowerShell syntax already checked above generically, but also ensure Lua is at least non-empty
        if ($hdrToggleRaw.Length -lt 200) { Fail 'hdr-toggle.lua unexpectedly small' }
    } catch { Fail "hdr-toggle.lua read failed: $($_.Exception.Message)" }
}

# input.conf: Alt+h must delegate to hdr-toggle, not old 9-del chain
$inputConfPath = Join-Path $Root 'portable_config/input.conf'
try {
    $inputRaw = Get-Content $inputConfPath -Raw
    $inputLines = Get-Content $inputConfPath
    $altHLines = @($inputLines | Where-Object { $_ -match '^\s*Alt\+h\b' })
    if ($altHLines.Count -eq 0) {
        Fail 'input.conf Alt+h binding missing'
    } else {
        $altHLine = $altHLines[0]
        if ($altHLine -match 'script-binding\s+hdr-toggle/toggle' -or $altHLine -match 'script-binding\s+hdr-toggle') {
            Pass 'input.conf Alt+h points to script-binding hdr-toggle/toggle'
        } else {
            Fail "input.conf Alt+h does not point to script-binding hdr-toggle/toggle: $altHLine"
        }
        # Must not still contain old 9-del chain (detect known hdr-toys shader names on Alt+h line)
        $hasOldChain = $false
        if ($altHLine -match 'change-list\s+glsl-shaders\s+del.*hdr-toys') { $hasOldChain = $true }
        if ($altHLine -match 'clip_both' -or $altHLine -match 'clip_black' -or $altHLine -match 'pq_inv.*hlg_inv' -or $altHLine -match 'bottosson') { $hasOldChain = $true }
        # Heuristic: old chain had 9 del occurrences on same line
        $delCount = ([regex]::Matches($altHLine, 'change-list\s+glsl-shaders\s+del')).Count
        if ($delCount -ge 3) { $hasOldChain = $true }
        if ($hasOldChain) { Fail "input.conf Alt+h still uses old 9-del chain (must be single script-binding hdr-toggle/toggle): $altHLine" }
        else { Pass 'input.conf Alt+h is not old 9-del chain' }
    }
    # Global guard: no Alt+h old chain anywhere even commented? Only check active (non-comment) lines for old chain
    $activeOldChain = @($inputLines | Where-Object { $_ -notmatch '^\s*#' -and $_ -match '^\s*Alt\+h' -and $_ -match 'change-list' })
    if ($activeOldChain.Count -gt 0) { Fail "input.conf has active Alt+h with change-list (should be script-binding only): $($activeOldChain -join '; ')" }
} catch { Fail "input.conf check failed: $($_.Exception.Message)" }

# fonts: ttf-only (uosc_icons.ttf + uosc_textures.ttf), no otf
$fontsDir = Join-Path $Root 'portable_config/fonts'
if (-not (Test-Path $fontsDir)) {
    Fail 'missing path: portable_config/fonts'
} else {
    $iconTtf = Join-Path $fontsDir 'uosc_icons.ttf'
    $texTtf = Join-Path $fontsDir 'uosc_textures.ttf'
    $iconOtf = Join-Path $fontsDir 'uosc_icons.otf'
    if (Test-Path $iconTtf) { Pass 'portable_config/fonts/uosc_icons.ttf exists' }
    else { Fail 'missing path: portable_config/fonts/uosc_icons.ttf' }
    if (Test-Path $texTtf) { Pass 'portable_config/fonts/uosc_textures.ttf exists' }
    else { Fail 'missing path: portable_config/fonts/uosc_textures.ttf' }
    if (Test-Path $iconOtf) { Fail 'portable_config/fonts/uosc_icons.otf must not exist (ttf-only, re-added otf is a regression)' }
    else { Pass 'portable_config/fonts contains ttf-only (uosc_icons.otf absent)' }
}

# .github/workflows/audit.yml exists and references audit script
$workflowPath = Join-Path $Root '.github/workflows/audit.yml'
if (-not (Test-Path $workflowPath)) {
    Fail 'missing path: .github/workflows/audit.yml'
} else {
    Pass '.github/workflows/audit.yml exists'
    try {
        $wfRaw = Get-Content $workflowPath -Raw
        if ($wfRaw -match 'Audit-MpvEnvironment') { Pass '.github/workflows/audit.yml contains Audit-MpvEnvironment' }
        else { Fail '.github/workflows/audit.yml missing Audit-MpvEnvironment reference' }
    } catch { Fail "audit.yml read failed: $($_.Exception.Message)" }
}

# Detect, but do not modify, LFS pointer files. Refined expectations:
# - ArtCNN/CfL/nlmeans/ravu are LFS (allowed pointers when not yet pulled)
# - SSim*.glsl are plain text (never LFS) - 5-6 KB each
# - hdr-toys/ is plain text (never LFS) - ~300 KB total
$gitattributesPath = Join-Path $Root '.gitattributes'
if (Test-Path $gitattributesPath) {
    $ga = Get-Content $gitattributesPath -Raw
    $lfsPatternsOk = $true
    foreach ($pat in @('ArtCNN', 'CfL', 'nlmeans', 'ravu')) {
        if ($ga -match ([regex]::Escape($pat) + '.*filter=lfs')) { Pass ".gitattributes tracks $pat as LFS" }
        else { Fail ".gitattributes missing LFS tracking for $pat (expected filter=lfs)"; $lfsPatternsOk = $false }
    }
    if ($ga -match 'SSim.*!filter') { Pass '.gitattributes keeps SSim as plain text (!filter)' }
    else { Fail '.gitattributes SSim must be plain text (!filter !diff !merge), not LFS' }
    if ($ga -match 'hdr-toys.*filter=lfs') { Fail '.gitattributes must not track hdr-toys as LFS (keep plain text)' }
    else { Pass '.gitattributes keeps hdr-toys plain text (not LFS)' }
} else { Fail 'missing path: .gitattributes' }

# Top-level shader LFS pointer refinement
$allowedLfsNames = @('ArtCNN_C4F32.glsl', 'CfL_Prediction.glsl', 'nlmeans.glsl', 'ravu-zoom-ar-r4.hook')
$lfsPointers = @()
$ssimPointerNames = @()
Get-ChildItem (Join-Path $Root 'portable_config/shaders') -File -ErrorAction SilentlyContinue | ForEach-Object {
    $first = Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue
    $isPointer = $first -match '^version https://git-lfs.github.com/spec/v1$'
    if ($isPointer) { $lfsPointers += $_.Name }
    if ($_.Name -like 'SSim*.glsl' -and $isPointer) { $ssimPointerNames += $_.Name }
}
if ($ssimPointerNames.Count -gt 0) {
    Fail "SSim shader(s) are LFS pointers but must be plain text: $($ssimPointerNames -join ', ')"
} else {
    # Verify SSim files exist and are plain (size check, not pointer)
    $ssimFiles = @('SSimSuperRes.glsl', 'SSimDownscaler.glsl')
    $allPlain = $true
    foreach ($sf in $ssimFiles) {
        $p = Join-Path (Join-Path $Root 'portable_config/shaders') $sf
        if (-not (Test-Path $p)) { Fail "missing SSim shader: portable_config/shaders/$sf"; $allPlain = $false }
        else {
            $firstLine = Get-Content $p -TotalCount 1 -ErrorAction SilentlyContinue
            if ($firstLine -match '^version https://git-lfs.github.com/spec/v1$') { $allPlain = $false }
            elseif ((Get-Item $p).Length -lt 1000) { Fail "SSim shader $sf unexpectedly small (<1KB, may be pointer/truncated)"; $allPlain = $false }
        }
    }
    if ($allPlain) { Pass 'SSim shaders are plain text (not LFS)' }
}

$unexpectedPointers = @($lfsPointers | Where-Object { $allowedLfsNames -notcontains $_ })
if ($unexpectedPointers.Count -gt 0) {
    Fail "found unexpected top-level shader LFS pointer(s) (only ArtCNN/CfL/nlmeans/ravu allowed as LFS): $($unexpectedPointers -join ', ')"
} else {
    if ($lfsPointers.Count -gt 0) {
        $message = "found $($lfsPointers.Count) Git LFS pointer file(s) ($($lfsPointers -join ', ')); run 'git lfs pull' before playback"
        if ($FailOnLfsPointer) { Fail $message } else { Warn $message }
    } else { Pass 'no top-level shader LFS pointers detected' }
}

# hdr-toys must be plain text, never LFS
$hdrToysDir = Join-Path $Root 'portable_config/shaders/hdr-toys'
if (Test-Path $hdrToysDir) {
    $hdrPointers = @()
    Get-ChildItem $hdrToysDir -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $first = Get-Content $_.FullName -TotalCount 1 -ErrorAction SilentlyContinue
        if ($first -match '^version https://git-lfs.github.com/spec/v1$') { $hdrPointers += $_.FullName.Replace($Root, '').TrimStart('\','/') }
    }
    if ($hdrPointers.Count -gt 0) {
        Fail "hdr-toys contains $($hdrPointers.Count) LFS pointer(s) but must be plain text: $($hdrPointers -join ', ')"
    } else { Pass 'hdr-toys shaders are plain text (not LFS)' }
} else { Fail 'missing path: portable_config/shaders/hdr-toys' }

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

# Validate that relocation-sensitive paths are derived from the active config root or kept portable.
$refreshScript = Get-Content (Join-Path $Root 'portable_config/scripts/display/change-refresh.lua') -Raw
$probeConfigDir = Join-Path $env:TEMP 'mpv-audit-portable_config'
$probePath = Join-Path $probeConfigDir 'shaders\hdr-toys'
$normalizedProbe = $probePath -replace '\\', '/'
$hasJedypodTransform = $updater -match 'bottosson.*jedypod'
$hasNoHardcodedMpv = ($updater -notmatch 'C:/mpv') -and ($updater -notmatch 'C:\\mpv')
# hdr-toys.conf should now keep portable ~~ paths (verified via config include test), not absolute C:/mpv rewrite
$hdrToysConf = Get-Content (Join-Path $Root 'portable_config/hdr-toys.conf') -Raw
$hdrUsesPortable = $hdrToysConf -match '~~/shaders/hdr-toys'
if ($hasJedypodTransform -and $hasNoHardcodedMpv -and $hdrUsesPortable -and ($normalizedProbe -eq (($probeConfigDir + '\shaders\hdr-toys') -replace '\\', '/'))) {
    Pass "hdr-toys updater keeps portable ~~ paths and applies jedypod mapping"
} else {
    Fail 'hdr-toys updater has a missing, hard-coded, or invalid shader path transform'
}
$hasLuaNormalizer = $refreshScript.Contains("gsub('\\', '/')")
$hasLuaAssignment = $refreshScript -match 'helper_script\s*=\s*default_helper_script\(\)'
if (($refreshScript -match "mp\.get_property\('config-dir'\)") -and $hasLuaNormalizer -and $hasLuaAssignment -and ($refreshScript -notmatch 'helper_script\s*=\s*["'']C:/mpv/')) {
    Pass 'refresh helper derives and normalizes its path from mpv config-dir'
} else {
    Fail 'refresh helper path is hard-coded, missing config-dir resolution, or not normalized'
}

Write-Host "Audit complete: $errors error(s), $warnings warning(s)."
if ($errors -gt 0) { exit 1 }
exit 0
