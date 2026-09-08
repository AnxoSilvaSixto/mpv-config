<#
.SYNOPSIS
    Daily updater for mpv, hdr-toys, uosc, thumbfast, anime-build (mpvSockets, skip_intro, track-selector, SSim) and Ulysses auto-save-state.
.DESCRIPTION
    Checks each of the six against its upstream source and only downloads
    when something actually changed - safe to run on every login, since an
    unchanged day is just quick API calls and a log line.

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
# Derive the portable root from this script so the checkout can be relocated.
$ScriptRoot  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ConfigDir   = Split-Path -Parent $ScriptRoot
$MpvRoot     = Split-Path -Parent $ConfigDir
if (-not (Test-Path (Join-Path $MpvRoot 'portable_config'))) {
    throw "Cannot locate portable_config relative to updater: $ConfigDir"
}
$ToolsDir    = Join-Path $ConfigDir 'tools'
$StateFile   = Join-Path $ToolsDir 'update-state.json'         # remembers what version/commit is currently installed
$LogFile     = Join-Path $ToolsDir 'update-log.txt'
$WorkDir     = Join-Path $env:TEMP 'mpv-autoupdate'            # scratch space, cleaned up after each run
$HdrShaderRoot = ((Join-Path $ConfigDir 'shaders\hdr-toys') -replace '\\', '/')

$HdrToysRepo   = 'natural-harmonia-gropius/hdr-toys'              # matches the shaders already in shaders\hdr-toys\
$UoscRepo      = 'tomasklaen/uosc'                                # upstream uosc (fork was stale, last push 2026-08-17)
$ThumbfastRepo = 'po5/thumbfast'                                  # single file at the repo root - verified default branch below, 2026-08-19
$AnimeBuildRepo = 'Chinna95P/mpv-anime-build'                     # vendored mpvSockets.lua + skip_intro.lua + track-selector.lua + SSim shaders - branch 'main' (not $Branch)
$AnimeBuildBranch = 'main'                                        # Chinna95P default branch; kept separate so $Branch ('master') stays untouched
$UlyssesRepo = 'popeyeurs/ulyssescaballes-mpv.config'              # auto-save-state.lua - branch 'main'
$UlyssesBranch = 'main'
$Branch        = 'master'                                         # default branch for hdr-toys and thumbfast; uosc overrides via -RepoBranch 'main'

# ===== AGENTS.md: Chinna95P/mpv-anime-build vendored scripts (Fix 3, 2026-09-07) =====
# Syncs portable_config/scripts/utilities/mpvSockets.lua + portable_config/scripts/media/skip_intro.lua
# from https://raw.githubusercontent.com/Chinna95P/mpv-anime-build/main/scripts/<name>, tracked by commit
# SHA in update-state.json key 'animebuild' (backfilled with the other keys in Get-State).
# Transforms mirror the hdr-toys jedypod precedent: mpvSockets.lua syncs VERBATIM except its provenance
# comment ('-- Source: Chinna95P/mpv-anime-build (scripts/mpvSockets.lua)') is re-appended after download;
# skip_intro.lua gets a FAIL-LOUD color-swap of the upstream label hexes (verified 2026-09-07 via curl:
# Intro FF00FF->3f5a9c, OP 00FF00->abc2c9, PV 0099FF->48628a, ED FF8000->6a8faf)
# plus a managed header.
# Missing color block => warn + keep prior file, never half-write. Keywords are restructured/lowercased
# local sets, functionally near-equivalent to upstream under case-insensitive match; they mirror
# script-opts/uosc.conf chapter_range_patterns (openings/endings/outros/intros) - realign in uosc.conf,
# not here. Per-component all-or-nothing + atomic temp-file replace; mutex/log rotation untouched.

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
    $defaults = [pscustomobject]@{ mpv = ''; hdrtoys = ''; uosc = ''; thumbfast = ''; animebuild = ''; ulysses = '' }
    if (Test-Path $StateFile) {
        try {
            $loaded = Get-Content $StateFile -Raw | ConvertFrom-Json -ErrorAction Stop
            if (($null -eq $loaded) -or ($loaded -is [array]) -or ($loaded -isnot [psobject])) {
                throw 'state JSON must contain one object'
            }

            # Copy only known scalar fields. This backfills older state files and avoids
            # trusting arbitrary JSON members when the file was edited or truncated.
            # 'animebuild' (anime-build scripts, Fix 3) backfills here too when missing.
            foreach ($prop in $defaults.PSObject.Properties.Name) {
                $value = $loaded.PSObject.Properties[$prop]
                # Added 2026-09-06: on 2026-09-05 hdrtoys was found on disk as
                # '0000...0000' (git's own "no commit" sentinel - never a value this
                # script writes itself) between two otherwise-clean runs, causing a
                # pointless resync. Treat that one specific value the same as a missing
                # key instead of trusting it, whatever wrote it.
                if ($value -and ($null -ne $value.Value) -and ([string]$value.Value) -ne ('0' * 40)) {
                    $defaults.$prop = [string]$value.Value
                }
            }
            return $defaults
        } catch {
            Write-Log "state: invalid JSON, treating all components as needing an update - $($_.Exception.Message)"
            return $defaults
        }
    }
    return $defaults  # first-ever run: nothing recorded yet, everything updates once
}

function Save-State {
    param($State)
    $tempState = "$StateFile.$([guid]::NewGuid().ToString('N')).tmp"
    try {
        $json = $State | ConvertTo-Json -Depth 3
        [System.IO.File]::WriteAllText($tempState, $json, (New-Object System.Text.UTF8Encoding($false)))
        if (Test-Path $StateFile) {
            [System.IO.File]::Replace($tempState, $StateFile, $null)
        } else {
            [System.IO.File]::Move($tempState, $StateFile)
        }
    } finally {
        Remove-Item $tempState -Force -ErrorAction SilentlyContinue
    }
}

$State = Get-State

# ===== mpv itself: GitHub Releases, .7z asset =====
function Update-Mpv {
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$MpvRepo/releases/latest" -Headers $GhHeaders
        if ($release.tag_name -eq $State.mpv) {
            Write-Log "mpv: already on $($release.tag_name), nothing to do"
            return $true
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
            return $false
        }

        # 7-Zip lookup: PATH first, then the two standard install locations.
        $SevenZip = (Get-Command 7z.exe -ErrorAction SilentlyContinue).Source
        if (-not $SevenZip) {
            $SevenZip = @("$env:ProgramFiles\7-Zip\7z.exe", "${env:ProgramFiles(x86)}\7-Zip\7z.exe") |
                Where-Object { Test-Path $_ } | Select-Object -First 1
        }
        if (-not $SevenZip) {
            Write-Log "mpv: 7-Zip not found (install from https://www.7-zip.org) - skipping mpv update for now"
            return $false
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
        if ($LASTEXITCODE -ge 8) {
            throw "robocopy failed with exit code $LASTEXITCODE"
        }

        Remove-Item $archivePath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        $State.mpv = $release.tag_name
        Write-Log "mpv: done, now on $($release.tag_name)"
        return $true
    } catch {
        # Any failure here just skips this component for today; it never stops hdr-toys/uosc below.
        Write-Log "mpv: FAILED - $($_.Exception.Message)"
        return $false
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
        if ([string]::IsNullOrEmpty($sha) -or $sha -eq ('0' * 40)) {
            # Added 2026-09-06: belt-and-suspenders alongside the Get-State check above -
            # a healthy GitHub response should never give a null/empty sha or the all-zero
            # sentinel. If this ever fires, it points at the API/response side rather than
            # the on-disk state file.
            Write-Log "$Repo`: API returned an invalid commit reference ('$sha') - skipping this run, will retry next time"
            return $false
        }
        if ($sha -eq $State.$StateKey) {
            Write-Log "$Repo`: already on $sha, nothing to do"
            return $true
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
            if (-not (Test-Path $src)) {
                throw "source path not found in $Repo`: $($p.Source)"
            }
            if ($p.IsDir) {
                Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue   # wholesale replace, matching upstream's own update pattern
                Copy-Item $src $dst -Recurse -Force -ErrorAction Stop
            } elseif ($p.Transforms) {
                # Text transforms instead of a byte-for-byte copy (each: @{Find=...; Replace=...},
                # applied in order; optional Required=$true throws FAIL-LOUD when Find matches
                # nothing, since -replace otherwise silently no-ops on a missing pattern).
                # Added 2026-08-25 for hdr-toys.conf: one rule rewrites its ~~/ shader paths to a
                # normalized path under this config root
                # (~~/ is documented to sometimes not resolve correctly under a portable_config
                # setup specifically), the other keeps jedypod over bottosson since upstream's own
                # hdr-toys.conf hasn't caught up to its own v2504 release notes on that point.
                # Optional Header field prepends a comment block after transforms (hdr-toys.conf).
                New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
                $text = Get-Content $src -Raw -ErrorAction Stop
                foreach ($t in $p.Transforms) {
                    if ($t.Required -and ([regex]::Matches($text, $t.Find).Count -eq 0)) {
                        throw "transform pattern not found in $($p.Source): $($t.Find) - refusing to write $dst"
                    }
                    $text = $text -replace $t.Find, $t.Replace
                }
                if ($p.Header) { $text = $p.Header + $text }
                $text | Set-Content -Path $dst -NoNewline -ErrorAction Stop
            } else {
                New-Item -ItemType Directory -Force -Path (Split-Path $dst) | Out-Null
                Copy-Item $src $dst -Force -ErrorAction Stop
                if ($p.Header) { ($p.Header + (Get-Content $dst -Raw -ErrorAction Stop)) | Set-Content -Path $dst -NoNewline -ErrorAction Stop }
            }
        }

        Remove-Item $zipPath, $extractDir -Recurse -Force -ErrorAction SilentlyContinue
        $State.$StateKey = $sha
        Write-Log "$Repo`: done, now on $sha"
        return $true
    } catch {
        Write-Log "$Repo`: FAILED - $($_.Exception.Message)"
        return $false
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
                   @{ Find = [regex]::Escape('~~/shaders/hdr-toys/'); Replace = "$HdrShaderRoot/" }
                   @{ Find = [regex]::Escape('gamut-mapping/bottosson.glsl'); Replace = 'gamut-mapping/jedypod.glsl' }
               );
               Header = "# !!! AUTO-MANAGED by Update-MpvEnvironment.ps1 !!!`r`n# This file is synced from upstream hdr-toys on every update run.`r`n# Any manual edits will be LOST on the next update.`r`n# To customize HDR behavior, edit mpv.conf profiles instead.`r`n" }
)

Update-GitFolder -Repo $UoscRepo -StateKey 'uosc' -RepoBranch 'main' -Paths @(
    @{ Source = 'src\uosc';                    Dest = 'scripts\uosc';            IsDir = $true  }
    @{ Source = 'src\fonts\uosc_icons.ttf';     Dest = 'fonts\uosc_icons.ttf';    IsDir = $false }
    @{ Source = 'src\fonts\uosc_textures.ttf';  Dest = 'fonts\uosc_textures.ttf'; IsDir = $false }
)

# thumbfast: single file at the repo root, loaded by mpv as the top-level "thumbfast" script
Update-GitFolder -Repo $ThumbfastRepo -StateKey 'thumbfast' -Paths @(
    @{ Source = 'thumbfast.lua'; Dest = 'scripts\thumbfast.lua'; IsDir = $false }
)

# AnimeBuild (Fix 3, 2026-09-07): mpvSockets.lua syncs verbatim except its provenance
# header; skip_intro.lua gets the FAIL-LOUD NieR color-swap plus a managed header.
Update-GitFolder -Repo $AnimeBuildRepo -StateKey 'animebuild' -RepoBranch $AnimeBuildBranch -Paths @(
    @{ Source = 'scripts\mpvSockets.lua'; Dest = 'scripts\utilities\mpvSockets.lua'; IsDir = $false;
       Header = "-- Source: Chinna95P/mpv-anime-build (scripts/mpvSockets.lua)`r`n" }
    @{ Source = 'scripts\skip_intro.lua'; Dest = 'scripts\media\skip_intro.lua'; IsDir = $false;
       Transforms = @(
           @{ Find = 'FF00FF'; Replace = '3f5a9c'; Required = $true }
           @{ Find = '00FF00'; Replace = 'abc2c9'; Required = $true }
           @{ Find = '0099FF'; Replace = '48628a'; Required = $true }
           @{ Find = 'FF8000'; Replace = '6a8faf'; Required = $true }
       );
       Header = "-- !!! AUTO-MANAGED by Update-MpvEnvironment.ps1 !!!`r`n-- Synced from upstream Chinna95P/mpv-anime-build (scripts/skip_intro.lua) with local NieR palette; manual edits will be LOST.`r`n" }
    @{ Source = 'scripts\track-selector.lua'; Dest = 'scripts\track-selector.lua'; IsDir = $false;
       Header = "-- Source: Chinna95P/mpv-anime-build (scripts/track-selector.lua)`r`n" }
    @{ Source = 'shaders\SSimSuperRes.glsl'; Dest = 'shaders\SSimSuperRes.glsl'; IsDir = $false }
    @{ Source = 'shaders\SSimDownscaler.glsl'; Dest = 'shaders\SSimDownscaler.glsl'; IsDir = $false }
)

# Ulysses auto-save-state (2026-09-08): single file from popeyeurs config
Update-GitFolder -Repo $UlyssesRepo -StateKey 'ulysses' -RepoBranch $UlyssesBranch -Paths @(
    @{ Source = 'portable_config\scripts\auto-save-state.lua'; Dest = 'scripts\auto-save-state.lua'; IsDir = $false }
)

# Post-process track-selector to preserve es dub -> no subs patch (faithful to slang=es)
# If upstream overwrote our 5-line es block, re-inject it. Idempotent: only patches if marker missing.
$trackSelectorPath = Join-Path $ConfigDir 'scripts\track-selector.lua'
if (Test-Path $trackSelectorPath) {
    $trackContent = Get-Content $trackSelectorPath -Raw
    if ($trackContent -notmatch 'Spanish audio detected') {
        Write-Log "track-selector: re-applying es dub patch (Spanish audio -> no subs)"
        $trackContent = $trackContent -replace "local selected_audio_lang = mp.get_property\('audio-params/lang'\)", "local selected_audio_lang = mp.get_property('audio-params/lang')`r`n    -- faithful to user slang=es prioritization: if we selected Spanish audio, don't show subs`r`n    if selected_audio_lang and selected_audio_lang:find('^es') then`r`n        msg.info('Smart Sub: Spanish audio detected (' .. selected_audio_lang .. ') -> disabling subs per es dub rule')`r`n        local selected_sid = 'no'`r`n        mark_internal_change('sid', selected_sid)`r`n        msg.info('Smart Sub: Spanish audio ...')`r`n        return`r`n    end`r`n    local _es_patched = true"
        $trackContent | Set-Content -Path $trackSelectorPath -NoNewline
    }
}

# Added 2026-09-06: wrapped in try/catch. A run on 2026-09-06 12:20 checked every
# component successfully but never reached Save-State or the "finished" line below -
# nothing here logged why, so a hiccup in one of these three housekeeping steps
# (locked file, deleted directory, etc.) is the only thing left that explains it.
# None of this is essential to a successful update, so it must never be able to take
# Save-State down with it - and if it does throw again, we'll see it in the log this time.
try {
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
} catch {
    Write-Log "cleanup step failed, continuing anyway so state still gets saved - $($_.Exception.Message)"
}

Save-State $State
Write-Log "=== update run finished ==="
} finally {
    # Always release, even if something above threw - otherwise every future
    # run would find the lock held and exit immediately, forever.
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
