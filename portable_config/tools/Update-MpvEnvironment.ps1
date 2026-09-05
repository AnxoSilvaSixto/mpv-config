<#
.SYNOPSIS
    Daily updater for mpv, hdr-toys, uosc, and thumbfast.
.DESCRIPTION
    Checks each of the four against its upstream source and only downloads
    when something actually changed - safe to run on every login, since an
    unchanged day is just four quick API calls and a log line.

    Never touches: mpv.conf, input.conf, script-opts\, or anything else in
    portable_config\ outside the paths listed in each Update-GitFolder call
    below - which, as of 2026-08-25, includes hdr-toys.conf itself.
.NOTES
    Requires 7-Zip (7z.exe) on PATH or in the default install location, for
    the mpv step only - hdr-toys and uosc are plain .zip and need nothing
    extra. Get 7-Zip from https://www.7-zip.org if you don't have it; the
    mpv step logs a message and skips itself (does not fail the run) until
    you do.
#>

# ===== Configuration you may want to change =====

# CHANGE THIS if your mpv build is not from zhongfly/mpv-winbuild. The only
# other value this script understands is 'shinchiro/mpv-winbuild-cmake' -
# both publish daily builds under the same mpv-x86_64-<date>-git-<hash>.7z
# naming, so this is the only line that differs between them.
$MpvRepo = 'zhongfly/mpv-winbuild'

# ===== Fixed configuration =====
$MpvRoot     = 'C:\mpv'                                        # must contain mpv.exe and portable_config\
$ConfigDir   = Join-Path $MpvRoot 'portable_config'
$ToolsDir    = Join-Path $ConfigDir 'tools'
$StateFile   = Join-Path $ToolsDir 'update-state.json'         # remembers what version/commit is currently installed
$LogFile     = Join-Path $ToolsDir 'update-log.txt'
$WorkDir     = Join-Path $env:TEMP 'mpv-autoupdate'            # scratch space, cleaned up after each run

$HdrToysRepo   = 'natural-harmonia-gropius/hdr-toys'              # matches the shaders already in shaders\hdr-toys\
$UoscRepo      = 'tomasklaen/uosc'                                # upstream uosc (fork was stale, last push 2026-08-17)
$ThumbfastRepo = 'po5/thumbfast'                                  # single file at the repo root - verified default branch below, 2026-08-19
$Branch        = 'master'                                         # default branch for hdr-toys and thumbfast; uosc overrides via -RepoBranch 'main'

# ===== Setup =====
New-Item -ItemType Directory -Force -Path $ToolsDir, $WorkDir | Out-Null   # ensure log/state/scratch folders exist
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12  # older PowerShell defaults to TLS 1.0, GitHub requires 1.2+
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest's progress-bar rendering is known to be extremely slow (can look like a hang) under Task Scheduler's hidden window
$GhHeaders = @{ 'User-Agent' = 'mpv-autoupdate-script' }        # GitHub's API rejects requests with no User-Agent

function Write-Log {
    # Timestamps every line so update-log.txt reads as a history, not just today's run.
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Get-State {
    # State = last-installed version/commit per component, so unchanged days do zero downloading.
    $defaults = [pscustomobject]@{ mpv = ''; hdrtoys = ''; uosc = ''; thumbfast = '' }
    if (Test-Path $StateFile) {
        $loaded = Get-Content $StateFile -Raw | ConvertFrom-Json
        # Backfill any key missing from an older state file - e.g. thumbfast (added 2026-08-19)
        # is absent from every state.json written before today. PSCustomObject throws if you
        # dot-assign a property that doesn't already exist, so this runs once here instead of
        # needing every Update-GitFolder call to guard itself.
        foreach ($prop in $defaults.PSObject.Properties.Name) {
            if ($loaded.PSObject.Properties.Name -notcontains $prop) {
                $loaded | Add-Member -NotePropertyName $prop -NotePropertyValue ''
            }
        }
        return $loaded
    }
    return $defaults  # first-ever run: nothing recorded yet, everything updates once
}

function Save-State {
    param($State)
    $State | ConvertTo-Json | Set-Content -Path $StateFile
}

$State = Get-State

# ===== mpv itself: GitHub Releases, .7z asset =====
function Update-Mpv {
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$MpvRepo/releases/latest" -Headers $GhHeaders
        if ($release.tag_name -eq $State.mpv) {
            Write-Log "mpv: already on $($release.tag_name), nothing to do"
            return
        }

        # Matches the AVX2 (x86-64-v3) player build. Changed 2026-08-23 from the plain
        # '^mpv-x86_64-...' pattern -- the 5700X (Zen 3) supports the full v3 feature set
        # (AVX2/BMI2/FMA), so this runs natively instead of the baseline codepath. Revert to
        # '^mpv-x86_64-\d{8}-git-[0-9a-f]+\.7z$' if this config ever moves to non-v3 hardware.
        $asset = $release.assets |
            Where-Object { $_.name -match '^mpv-x86_64-v3-\d{8}-git-[0-9a-f]+\.7z$' } |
            Select-Object -First 1
        if (-not $asset) {
            # Observed 2026-08-27: release 2026-08-26-182fa6ca49 shipped no v3 asset at all --
            # self-corrected on the next build the same day. Deliberately not falling back to the
            # plain build on days like this: v3-only was a considered choice (performance over
            # always-latest), so this just waits for the next release that has a v3 asset instead.
            Write-Log "mpv: no matching x86_64 asset in release $($release.tag_name) - skipping this run"
            return
        }

        # 7-Zip lookup: PATH first, then the two standard install locations.
        $SevenZip = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
        if (-not $SevenZip) {
            $SevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        }
        if (-not $SevenZip) {
            Write-Log "mpv: 7-Zip not found (install from https://www.7-zip.org) - skipping mpv update for now"
            return
        }

        Write-Log "mpv: updating '$($State.mpv)' -> '$($release.tag_name)'"
        $archivePath = Join-Path $WorkDir $asset.name
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $archivePath -UseBasicParsing

        $extractDir = Join-Path $WorkDir 'mpv-extract'
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        & $SevenZip x $archivePath "-o$extractDir" -y | Out-Null

        # /XD portable_config: even though these builds don't currently ship one, this
        # guarantees a future build never overwrites your live config by surprise.
        robocopy $extractDir $MpvRoot /E /XD portable_config /NFL /NDL /NJH /NJS | Out-Null

        Remove-Item $archivePath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        $State.mpv = $release.tag_name
        Write-Log "mpv: done, now on $($release.tag_name)"
    } catch {
        # Any failure here just skips this component for today; it never stops hdr-toys/uosc below.
        Write-Log "mpv: FAILED - $($_.Exception.Message)"
    }
}

# ===== hdr-toys / uosc / thumbfast: plain git repos, tracked by latest commit SHA =====
function Update-GitFolder {
    param(
        [string]$Repo,
        [string]$StateKey,
        [hashtable[]]$Paths,   # each: @{ Source = 'relative\path\in\repo'; Dest = 'relative\path\in\portable_config'; IsDir = $true/$false }
        [string]$RepoBranch = $Branch   # override default branch per-repo (uosc upstream uses 'main', others use 'master')
    )
    try {
        $commit = Invoke-RestMethod "https://api.github.com/repos/$Repo/commits/$RepoBranch" -Headers $GhHeaders
        $sha = $commit.sha
        if ($sha -eq $State.$StateKey) {
            Write-Log "$Repo`: already on $sha, nothing to do"
            return
        }

        Write-Log "$Repo`: updating '$($State.$StateKey)' -> '$sha'"
        $zipPath = Join-Path $WorkDir "$($Repo -replace '/', '-').zip"
        Invoke-WebRequest -Uri "https://codeload.github.com/$Repo/zip/$sha" -OutFile $zipPath -UseBasicParsing

        $extractDir = Join-Path $WorkDir ($Repo -replace '/', '-')
        Remove-Item $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        Expand-Archive -Path $zipPath -DestinationPath $extractDir -Force
        $repoRoot = Get-ChildItem $extractDir | Select-Object -First 1   # GitHub zips into one top-level "<repo>-<sha>" folder

        foreach ($p in $Paths) {
            $src = Join-Path $repoRoot.FullName $p.Source
            $dst = Join-Path $ConfigDir $p.Dest
            if ($p.IsDir) {
                Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue   # wholesale replace, matching upstream's own update pattern
                Copy-Item $src $dst -Recurse -Force
            } elseif ($p.Transforms) {
                # Text transforms instead of a byte-for-byte copy (each: @{Find=...; Replace=...},
                # applied in order). Added 2026-08-25, currently only used for hdr-toys.conf: one
                # rule rewrites its ~~/ shader paths to this config's C:/ absolute-path convention
                # (~~/ is documented to sometimes not resolve correctly under a portable_config
                # setup specifically), the other keeps jedypod over bottosson since upstream's own
                # hdr-toys.conf hasn't caught up to its own v2504 release notes on that point.
                # Optional Header field prepends a comment block after transforms (hdr-toys.conf).
                New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
                $text = Get-Content $src -Raw
                foreach ($t in $p.Transforms) { $text = $text -replace $t.Find, $t.Replace }
                if ($p.Header) { $text = $p.Header + $text }
                $text | Set-Content -Path $dst -NoNewline
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
                Copy-Item $src $dst -Force
            }
        }

        Remove-Item $zipPath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        $State.$StateKey = $sha
        Write-Log "$Repo`: done, now on $sha"
    } catch {
        Write-Log "$Repo`: FAILED - $($_.Exception.Message)"
    }
}

# ===== Run =====

# Prevents two triggers overlapping (e.g. the at-logon trigger firing while you've
# just manually run Start-ScheduledTask to test it) from racing on the same temp
# files - which is exactly what happened on 2026-08-16: two runs both grabbed
# 'mpv: updating', and the second one's cleanup stepped on the first one's
# in-progress download. If another instance already holds this lock, this one
# exits immediately rather than fighting over $WorkDir.
$Mutex = New-Object System.Threading.Mutex($false, 'Global\mpv-autoupdate-lock')
if (-not $Mutex.WaitOne(0)) {
    Write-Log "another instance is already running - exiting"
    exit
}

try {
Write-Log "=== update run starting ==="

Update-Mpv

# Changed 2026-08-25: hdr-toys.conf is now synced too, not just the shaders folder - mpv.conf
# includes it directly (include=) instead of hand-porting its profiles, after the hand-port
# silently fell a version behind once already (bottosson stayed loaded for days after upstream
# switched its default to jedypod). See mpv.conf's HDR handling comment for the full reasoning.
Update-GitFolder -Repo $HdrToysRepo -StateKey 'hdrtoys' -Paths @(
    @{ Source = 'shaders\hdr-toys'; Dest = 'shaders\hdr-toys'; IsDir = $true }
            @{ Source = 'hdr-toys.conf'; Dest = 'hdr-toys.conf'; IsDir = $false;
               Transforms = @(
                   @{ Find = [regex]::Escape('~~/shaders/hdr-toys/'); Replace = 'C:/mpv/portable_config/shaders/hdr-toys/' }
                   @{ Find = [regex]::Escape('gamut-mapping/bottosson.glsl'); Replace = 'gamut-mapping/jedypod.glsl' }
               );
               Header = "# !!! AUTO-MANAGED by Update-MpvEnvironment.ps1 !!!`r`n# This file is synced from upstream hdr-toys on every update run.`r`n# Any manual edits will be LOST on the next update.`r`n# To customize HDR behavior, edit mpv.conf profiles instead.`r`n" }
)

Update-GitFolder -Repo $UoscRepo -StateKey 'uosc' -RepoBranch 'main' -Paths @(
    @{ Source = 'src\uosc';                    Dest = 'scripts\uosc';            IsDir = $true  }
    @{ Source = 'src\fonts\uosc_icons.ttf';     Dest = 'fonts\uosc_icons.ttf';    IsDir = $false }
    @{ Source = 'src\fonts\uosc_textures.ttf';  Dest = 'fonts\uosc_textures.ttf'; IsDir = $false }
)

# thumbfast: single file at the repo root, no subfolder to manage
Update-GitFolder -Repo $ThumbfastRepo -StateKey 'thumbfast' -Paths @(
    @{ Source = 'thumbfast.lua'; Dest = 'scripts\media\thumbfast.lua'; IsDir = $false }
)

# Clean shader cache files older than 30 days
$shaderCacheDir = Join-Path $ConfigDir 'cache\shaders_cache'
if (Test-Path $shaderCacheDir) {
    Get-ChildItem $shaderCacheDir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Clean watch-later files older than 7 days
$watchLaterDir = Join-Path $ConfigDir 'cache\watch_later'
if (Test-Path $watchLaterDir) {
    Get-ChildItem $watchLaterDir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
}

# Rotate log if exceeding 500 lines
if ((Get-Content $LogFile).Count -gt 500) {
    $recent = Get-Content $LogFile -Tail 400
    $recent | Set-Content $LogFile
    Write-Log "log rotated (was >500 lines, kept last 400)"
}

Save-State $State
Write-Log "=== update run finished ==="
} finally {
    # Always release, even if something above threw - otherwise every future
    # run would find the lock held and exit immediately, forever.
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
