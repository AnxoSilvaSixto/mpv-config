<#
.SYNOPSIS
    Updater for mpv, hdr-toys, uosc, thumbfast, anime-build scripts.
.DESCRIPTION
    Downloads only on change - safe to run every login.
    Never touches mpv.conf, input.conf, or script-opts/.
.NOTES
    Needs 7-Zip for the mpv step only. Without it, mpv step skips.
#>

# ===== User setting =====

# mpv build repo. Only other value understood: 'shinchiro/mpv-winbuild-cmake'.
$MpvRepo = 'zhongfly/mpv-winbuild'

# ===== Fixed paths (root auto-derived, folder is relocatable) =====
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

$HdrToysRepo   = 'natural-harmonia-gropius/hdr-toys'
$UoscRepo      = 'tomasklaen/uosc'
$ThumbfastRepo = 'po5/thumbfast'
$AnimeBuildRepo = 'Chinna95P/mpv-anime-build'
$AnimeBuildBranch = 'main'
$Branch        = 'master' # hdr-toys + thumbfast; uosc overrides with 'main'

# ===== Setup =====
New-Item -ItemType Directory -Force -Path $ToolsDir, $WorkDir | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue' # progress bar is very slow under Task Scheduler
$GhHeaders = @{ 'User-Agent' = 'mpv-autoupdate-script' } # GitHub API requires a User-Agent

function Write-Log {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Message
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

function Get-State {
    # Last-installed version per component, so unchanged days skip downloading.
    $defaults = [pscustomobject]@{ mpv = ''; hdrtoys = ''; uosc = ''; thumbfast = ''; animebuild = '' }
    if (Test-Path $StateFile) {
        try {
            $loaded = Get-Content $StateFile -Raw | ConvertFrom-Json -ErrorAction Stop
            if (($null -eq $loaded) -or ($loaded -is [array]) -or ($loaded -isnot [psobject])) {
                throw 'state JSON must contain one object'
            }

            # Copy only known fields; backfills older files, ignores unknown members.
            foreach ($prop in $defaults.PSObject.Properties.Name) {
                $value = $loaded.PSObject.Properties[$prop]
                # All-zero SHA is git's "no commit" sentinel - never trust it.
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
        # Move-Item is atomic enough for this single-writer (mutex-guarded) file.
        Move-Item -Path $tempState -Destination $StateFile -Force
    } finally {
        Remove-Item $tempState -Force -ErrorAction SilentlyContinue
    }
}

$State = Get-State

# ===== mpv: GitHub Releases .7z =====
function Update-Mpv {
    try {
        $release = Invoke-RestMethod "https://api.github.com/repos/$MpvRepo/releases/latest" -Headers $GhHeaders
        if ($release.tag_name -eq $State.mpv) {
            Write-Log "mpv: already on $($release.tag_name), nothing to do"
            return $true
        }

        # x86_64-v3 only (Zen 3). No fallback to baseline.
        $asset = $release.assets |
            Where-Object { $_.name -match '^mpv-x86_64-v3-\d{8}-git-[0-9a-f]+\.7z$' } |
            Select-Object -First 1
        if (-not $asset) {
            # v3-only is intentional; wait for the next release with a v3 asset.
            Write-Log "mpv: no matching x86_64 asset in release $($release.tag_name) - skipping this run"
            return $false
        }

        # 7-Zip: PATH first, then standard locations.
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

        # Never overwrite portable_config; skip upstream docs/installer/launchers.
        robocopy $extractDir $MpvRoot /E /XD portable_config doc installer /XF updater.bat mpv-register.bat mpv-unregister.bat settings.xml updater.ps1 /NFL /NDL /NJH /NJS | Out-Null
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

# ===== Git repos, tracked by commit SHA =====
function Update-GitFolder {
    param(
        [string]$Repo,
        [string]$StateKey,
        [hashtable[]]$Paths,   # @{ Source='repo\path'; Dest='config\path'; IsDir=$true/$false }
        [string]$RepoBranch = $Branch
    )
    try {
        $commit = Invoke-RestMethod "https://api.github.com/repos/$Repo/commits/$RepoBranch" -Headers $GhHeaders
        $sha = $commit.sha
        if ([string]::IsNullOrEmpty($sha) -or $sha -eq ('0' * 40)) {
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
                Remove-Item $dst -Recurse -Force -ErrorAction SilentlyContinue
                Copy-Item $src $dst -Recurse -Force -ErrorAction Stop
            } elseif ($p.Transforms) {
                # Text transforms (Find/Replace; Required fails loud on no match).
                # hdr-toys: bottosson -> jedypod per upstream v2504 notes.
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

# Mutex: a second instance exits immediately instead of racing on temp files.
$Mutex = New-Object System.Threading.Mutex($false, 'Global\mpv-autoupdate-lock')
if (-not $Mutex.WaitOne(0)) {
    Write-Log "another instance is already running - exiting"
    exit
}

try {
Write-Log "=== update run starting ==="

Update-Mpv

# hdr-toys.conf is synced (not hand-ported) so it can't fall behind upstream.
Update-GitFolder -Repo $HdrToysRepo -StateKey 'hdrtoys' -Paths @(
    @{ Source = 'shaders\hdr-toys'; Dest = 'shaders\hdr-toys'; IsDir = $true }
            @{ Source = 'hdr-toys.conf'; Dest = 'hdr-toys.conf'; IsDir = $false;
               Transforms = @(
                   @{ Find = [regex]::Escape('gamut-mapping/bottosson.glsl'); Replace = 'gamut-mapping/jedypod.glsl' }
               );
               Header = "# AUTO-MANAGED by Update-MpvEnvironment.ps1 - do not edit.`r`n" }
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

# AnimeBuild: mpvSockets + skip_intro (NieR palette) + track-selector + SSim.
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

# Manually-managed (never synced): KrigBilateral, FSRCNNX, ArtCNN DN, hdeband,
# noise_static_luma.hook - see AGENTS.md. auto-save-state.lua is frozen locally.
#
# To update a manual shader: download, verify //!HOOK, A/B test.

# Re-apply es dub patch if upstream overwrote it. Idempotent.
try {
    $trackSelectorPath = Join-Path $ConfigDir 'scripts\track-selector.lua'
    if (Test-Path $trackSelectorPath) {
        $trackContent = Get-Content $trackSelectorPath -Raw
        if (($trackContent -match 'Spanish audio detected') -or ($trackContent -match '_es_patched')) {
            # already patched, skip
        } else {
            Write-Log "track-selector: re-applying es dub patch (Spanish audio -> no subs)"
            $trackSelectorPatched = $false
            # Current layout: selected_audio_lang populated via loop; inject before CONTEXT DETECTION.
            if ($trackContent -match "-- 2\. CONTEXT DETECTION") {
                $esBlock = "    -- faithful to user slang=es-ES priority: if we selected Spanish audio, don't show subs`r`n    if selected_audio_lang and (selected_audio_lang:find('^es') or selected_audio_lang:find('^spa')) then`r`n        msg.info('Smart Sub: Spanish audio detected (' .. selected_audio_lang .. ') -> disabling subs per es dub rule')`r`n        if mp.get_property('sid') ~= 'no' then`r`n            mark_internal_change('subtitle', 'no')`r`n            mp.set_property('sid', 'no')`r`n        end`r`n        return`r`n    end`r`n    local _es_patched = true`r`n`r`n    -- 2. CONTEXT DETECTION"
                $trackContent = $trackContent -replace "-- 2\. CONTEXT DETECTION", $esBlock
                $trackSelectorPatched = $true
            } elseif ($trackContent -match "local selected_audio_lang = mp\.get_property\('audio-params/lang'\)") {
                # Legacy fallback for old file layout.
                $trackContent = $trackContent -replace "local selected_audio_lang = mp.get_property\('audio-params/lang'\)", "local selected_audio_lang = mp.get_property('audio-params/lang')`r`n    -- faithful to user slang=es-ES priority: if we selected Spanish audio, don't show subs`r`n    if selected_audio_lang and (selected_audio_lang:find('^es') or selected_audio_lang:find('^spa')) then`r`n        msg.info('Smart Sub: Spanish audio detected (' .. selected_audio_lang .. ') -> disabling subs per es dub rule')`r`n        local selected_sid = 'no'`r`n        mark_internal_change('sid', selected_sid)`r`n        msg.info('Smart Sub: Spanish audio ...')`r`n        return`r`n    end`r`n    local _es_patched = true"
                $trackSelectorPatched = $true
            } else {
                Write-Log "track-selector: patch skipped - no known anchor found (unexpected layout)"
            }
            if ($trackSelectorPatched) {
                $trackSelectorTmp = "$trackSelectorPath.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    [System.IO.File]::WriteAllText($trackSelectorTmp, $trackContent, (New-Object System.Text.UTF8Encoding($false)))
                    Move-Item -Path $trackSelectorTmp -Destination $trackSelectorPath -Force
                } finally {
                    Remove-Item $trackSelectorTmp -Force -ErrorAction SilentlyContinue
                }
            }
        }
    }
} catch {
    Write-Log "track-selector: patch failed, continuing anyway so state still gets saved - $($_.Exception.Message)"
}

# Re-apply Spanish-variant priority (es-ES > es/spa > es-419). Idempotent.
try {
    if (Test-Path $trackSelectorPath) {
        $tsLangContent = [System.IO.File]::ReadAllText($trackSelectorPath)
        if ($tsLangContent -match '_es_lang_priority_patched') {
            # already patched, skip
        } else {
            $tsLangOld = '-- Helper to check if a track language matches a preferred language
local function matches_lang(track_lang, pref_lang)
    if not track_lang then return false end
    return string.sub(track_lang, 1, string.len(pref_lang)) == pref_lang
end'
            $tsLangNew = '-- Spanish priority (_es_lang_priority_patched): es-ES > es/spa > es-419.
-- spa~es, eng~en, jpn~ja. Regional pref needs exact match; generic matches same base.
local function normalize_lang(lang)
    if not lang then return "" end
    lang = lang:lower():gsub("_", "-")
    local base = lang:match("^([a-z]+)")
    if base == "spa" then
        lang = "es" .. lang:sub(4)
    elseif base == "eng" then
        lang = "en" .. lang:sub(4)
    elseif base == "jpn" then
        lang = "ja" .. lang:sub(4)
    end
    return lang
end

local function lang_base(norm)
    return norm:match("^([a-z]+)") or norm
end

-- Helper to check if a track language matches a preferred language
local function matches_lang(track_lang, pref_lang)
    if not track_lang or not pref_lang then return false end
    local t = normalize_lang(track_lang)
    local p = normalize_lang(pref_lang)
    if t == p then return true end
    if not p:find("-", 1, true) then
        return lang_base(t) == p
    end
    return false
end

local function is_spanish_lang(lang)
    return lang_base(normalize_lang(lang or "")) == "es"
end

-- 0 = exact, 1 = base fallback, -1 = no match. Regional prefs never fuzzy-match.
local function match_tier(track_lang, pref_lang)
    local t = normalize_lang(track_lang)
    local p = normalize_lang(pref_lang)
    if t == "" or p == "" then return -1 end
    if t == p then return 0 end
    if not p:find("-", 1, true) and lang_base(t) == p then return 1 end
    return -1
end'
            if ($tsLangContent.Contains($tsLangOld)) {
                Write-Log 'track-selector: re-applying Spanish-variant priority (es-ES > es > es-419)'
                $tsLangContent = $tsLangContent.Replace($tsLangOld, $tsLangNew)
                # Also make the es-dub no-subs rule spa-aware on the fresh file
                $tsLangContent = $tsLangContent.Replace("selected_audio_lang:find('^es')", "selected_audio_lang:find('^es') or selected_audio_lang:find('^spa')")
                $tsLangContent = $tsLangContent.Replace('slang=es prioritization', 'slang=es-ES priority')
                $tsLangTmp = "$trackSelectorPath.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    [System.IO.File]::WriteAllText($tsLangTmp, $tsLangContent, (New-Object System.Text.UTF8Encoding($false)))
                    Move-Item -Path $tsLangTmp -Destination $trackSelectorPath -Force
                } finally {
                    Remove-Item $tsLangTmp -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Log 'track-selector: lang-priority skipped - old matches_lang anchor not found (unexpected layout)'
            }
        }
    }
} catch {
    Write-Log "track-selector: lang-priority patch failed, continuing anyway - $($_.Exception.Message)"
}

# Teardown guard: ignore aid/sid changes with no active playback. Idempotent.
try {
    if (Test-Path $trackSelectorPath) {
        $tsGuardContent = [System.IO.File]::ReadAllText($trackSelectorPath)
        if ($tsGuardContent -match '_eof_guard_patched') {
            # already patched, skip
        } else {
            $tsGuardOld = '    if not track_selector_enabled or ignore_track_changes or file_transition then
        return
    end'
            $tsGuardNew = '    if not track_selector_enabled or ignore_track_changes or file_transition then
        return
    end
    -- Teardown guard (_eof_guard_patched): ignore observer fire with no active file.
    if mp.get_property("path") == nil or mp.get_property_native("core-idle")
            or #(mp.get_property_native("track-list") or {}) == 0 then
        return
    end'
            $tsGuardHits = ([regex]::Matches($tsGuardContent, [regex]::Escape($tsGuardOld))).Count
            if ($tsGuardHits -eq 2) {
                Write-Log 'track-selector: adding teardown guard (aid/sid observers)'
                $tsGuardContent = $tsGuardContent.Replace($tsGuardOld, $tsGuardNew)
                $tsGuardTmp = "$trackSelectorPath.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    [System.IO.File]::WriteAllText($tsGuardTmp, $tsGuardContent, (New-Object System.Text.UTF8Encoding($false)))
                    Move-Item -Path $tsGuardTmp -Destination $trackSelectorPath -Force
                } finally {
                    Remove-Item $tsGuardTmp -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Log "track-selector: teardown-guard skipped - anchor found $tsGuardHits times, expected 2"
            }
        }
    }
} catch {
    Write-Log "track-selector: teardown-guard patch failed, continuing anyway - $($_.Exception.Message)"
}

# Warn if end-file mute is absent (teardown guard above is the primary defense).
try {
    if (Test-Path $trackSelectorPath) {
        $tsMuteContent = [System.IO.File]::ReadAllText($trackSelectorPath)
        if ($tsMuteContent -match '_teardown_mute_patched') {
            # already muted, skip
        } else {
            Write-Log 'track-selector: WARNING end-file mute missing'
        }
    }
} catch {
    Write-Log "track-selector: teardown-mute patch failed, continuing anyway - $($_.Exception.Message)"
}
# uosc icon font must match shipped ttf, else ligatures render as raw text. Idempotent.
try {
    $uoscAssPath = Join-Path $ConfigDir 'scripts\uosc\lib\ass.lua'
    if (Test-Path $uoscAssPath) {
        $assContent = [System.IO.File]::ReadAllText($uoscAssPath)
        if ($assContent -match "'Material Symbols Rounded'") {
            # already aligned, skip
        } elseif ($assContent -match "'MaterialIconsRound-Regular'") {
            Write-Log 'uosc: aligning icon font family with shipped uosc_icons.ttf'
            $assContent = $assContent.Replace("'MaterialIconsRound-Regular'", "'Material Symbols Rounded'")
            $assTmp = "$uoscAssPath.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                [System.IO.File]::WriteAllText($assTmp, $assContent, (New-Object System.Text.UTF8Encoding($false)))
                Move-Item -Path $assTmp -Destination $uoscAssPath -Force
            } finally {
                Remove-Item $assTmp -Force -ErrorAction SilentlyContinue
            }
        } else {
            Write-Log 'uosc: icon-family patch skipped - neither known family string found (unexpected layout)'
        }
    }
} catch {
    Write-Log "uosc: icon-family patch failed, continuing anyway - $($_.Exception.Message)"
}

# uosc track menu: friendly language names + SDH hint + title cleanup. Idempotent.
try {
    $uoscMenusPath = Join-Path $ConfigDir 'scripts\uosc\lib\menus.lua'
    if (Test-Path $uoscMenusPath) {
        $menusContent = [System.IO.File]::ReadAllText($uoscMenusPath)
        if ($menusContent -match '_uosc_lang_names_patched') {
            # already patched, skip
        } else {
            Write-Log 'uosc: re-applying track-menu language-names patch'
            # menus.lua is LF; normalize so multi-line anchors match.
            $menusContent = $menusContent -replace "`r`n", "`n"
            $T2 = "`t`t"
            $T4 = "`t`t`t`t"
            $T5 = "`t`t`t`t`t"
            $menusHelper = @'
		-- Readable language names (_uosc_lang_names_patched). Falls back to raw tag.
		local lang_names = {
			['es'] = 'Spanish', ['es-es'] = 'Spanish (Spain)', ['es-419'] = 'Spanish (Latin America)',
			['es-mx'] = 'Spanish (Mexico)', ['es-ar'] = 'Spanish (Argentina)', ['es-us'] = 'Spanish (US)',
			['en'] = 'English', ['en-us'] = 'English (US)', ['en-gb'] = 'English (UK)',
			['pt'] = 'Portuguese', ['pt-br'] = 'Portuguese (Brazil)', ['pt-pt'] = 'Portuguese (Portugal)',
			['fr'] = 'French', ['de'] = 'German', ['it'] = 'Italian', ['ar'] = 'Arabic',
			['ru'] = 'Russian', ['id'] = 'Indonesian', ['ms'] = 'Malay', ['vi'] = 'Vietnamese',
			['th'] = 'Thai', ['zh-hans'] = 'Chinese (Simplified)', ['zh-hant'] = 'Chinese (Traditional)',
			['zh'] = 'Chinese', ['pl'] = 'Polish', ['ja'] = 'Japanese', ['ko'] = 'Korean',
			['nl'] = 'Dutch', ['ca'] = 'Catalan', ['gl'] = 'Galician', ['eu'] = 'Basque',
			['hi'] = 'Hindi', ['tr'] = 'Turkish', ['uk'] = 'Ukrainian', ['sv'] = 'Swedish',
			['nb'] = 'Norwegian (Bokmal)', ['no'] = 'Norwegian', ['da'] = 'Danish', ['fi'] = 'Finnish',
			['cs'] = 'Czech', ['sk'] = 'Slovak', ['ro'] = 'Romanian', ['hu'] = 'Hungarian',
			['el'] = 'Greek', ['he'] = 'Hebrew', ['und'] = 'Undetermined',
		}
		local function friendly_lang(tag)
			if not tag or tag == '' then return tag end
			local key = tag:lower():gsub('_', '-')
			local base = key:match('^([a-z]+)') -- spa~es, eng~en, jpn~ja
			if base == 'spa' then key = 'es' .. key:sub(4)
			elseif base == 'eng' then key = 'en' .. key:sub(4)
			elseif base == 'jpn' then key = 'ja' .. key:sub(4)
			end
			return lang_names[key] or tag
		end

'@
            $menusHelper = $menusHelper -replace "`r`n", "`n"
            $menusOk = $true
            # 1. helper before the track loop (must hit exactly once)
            $menusLoopOld = "${T2}for _, track in ipairs(tracklist) do"
            if (([regex]::Matches($menusContent, [regex]::Escape($menusLoopOld))).Count -eq 1) {
                $menusContent = $menusContent.Replace($menusLoopOld, $menusHelper + "`n" + $menusLoopOld)
            } else {
                Write-Log 'uosc: menus patch skipped - track-loop anchor not unique (unexpected layout)'
                $menusOk = $false
            }
            # 2. friendly hint instead of raw lang tag
            $menusHintOld = "${T4}if track.lang then h(track.lang) end"
            if ($menusContent.Contains($menusHintOld)) {
                $menusContent = $menusContent.Replace($menusHintOld, "${T4}if track.lang then h(friendly_lang(track.lang)) end")
            } else {
                Write-Log 'uosc: menus patch skipped - hint anchor not found (unexpected layout)'
                $menusOk = $false
            }
            # 3. SDH hint next to forced/default
            $menusForcedOld = "${T4}if track.forced then h(t('forced')) end"
            if ($menusContent.Contains($menusForcedOld)) {
                $menusContent = $menusContent.Replace($menusForcedOld, "$menusForcedOld`n${T4}if track['hearing-impaired'] then h(t('sdh')) end")
            } else {
                Write-Log 'uosc: menus patch skipped - forced anchor not found (unexpected layout)'
                $menusOk = $false
            }
            # 4. underscore cleanup in display titles
            $menusTitleOld = "${T4}items[#items + 1] = {`n${T5}title = (track.title and track.title or t('Track %s', track.id)),"
            if ($menusContent.Contains($menusTitleOld)) {
                $menusTitleNew = "${T4}-- Display-only cleanup: strip CR tag, [group] prefix, _ -> space.`n${T4}local display_title = track.title or ''`n${T4}display_title = display_title:gsub('[%s_%-]+CR$', '')`n${T4}if display_title == 'CR' then display_title = '' end`n${T4}display_title = display_title:gsub('^%s*%[[^%]]+%]%s*', '')`n${T4}display_title = display_title:gsub('_', ' '):gsub('^%s+', ''):gsub('%s+$', '')`n${T4}if display_title == '' then`n${T5}display_title = friendly_lang(track.lang) or t('Track %s', track.id)`n${T4}end`n${T4}items[#items + 1] = {`n${T5}title = display_title,"
                $menusContent = $menusContent.Replace($menusTitleOld, $menusTitleNew)
            } else {
                Write-Log 'uosc: menus patch skipped - title anchor not found (unexpected layout)'
                $menusOk = $false
            }
            if ($menusOk) {
                $menusTmp = "$uoscMenusPath.$([guid]::NewGuid().ToString('N')).tmp"
                try {
                    [System.IO.File]::WriteAllText($menusTmp, $menusContent, (New-Object System.Text.UTF8Encoding($false)))
                    Move-Item -Path $menusTmp -Destination $uoscMenusPath -Force
                } finally {
                    Remove-Item $menusTmp -Force -ErrorAction SilentlyContinue
                }
            } else {
                Write-Log 'uosc: menus patch aborted - no changes written (partial patch would break the menu)'
            }
        }
    }
} catch {
    Write-Log "uosc: menus patch failed, continuing anyway - $($_.Exception.Message)"
}

# Launchers: safety net restoring sole-updater dispatch. Idempotent per file.
try {
    $launcherJobs = @(
        @{ File = 'updater.bat'; Marker = 'Update-MpvEnvironment' },
        @{ File = 'mpv-register.bat'; Marker = '%~dp0mpv' },
        @{ File = 'mpv-unregister.bat'; Marker = '%~dp0mpv' }
    )
    foreach ($job in $launcherJobs) {
        $lp = Join-Path $MpvRoot $job.File
        if (-not (Test-Path $lp)) { continue }
        $lt = [System.IO.File]::ReadAllText($lp)
        if ($lt.Contains($job.Marker)) { continue }  # already ours, skip
        $nl = "`n"; if ($lt.Contains("`r`n")) { $nl = "`r`n" }
        $lines = $lt -split "`r?`n"
        while ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq '') {
            if ($lines.Count -eq 1) { $lines = @(); break }
            $lines = $lines[0..($lines.Count - 2)]
        }
        function Find-Lines($want) {
            $idx = @()
            for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -ceq $want) { $idx += $i } }
            return $idx
        }
        $new = $null; $why = ''
        if ($job.File -eq 'updater.bat') {
            # Any updater.bat without our marker is stock legacy - replace wholesale.
            Write-Log 'updater.bat: restoring sole-updater dispatch (Update-MpvEnvironment.ps1)'
            $new = @(
                '@echo OFF',
                ':: Sole updater entry point -> portable_config/tools/Update-MpvEnvironment.ps1',
                'pushd %~dp0',
                'set updater_script="%~dp0portable_config\tools\Update-MpvEnvironment.ps1"',
                '',
                'where pwsh >nul 2>nul',
                'if %errorlevel% equ 0 (',
                '    pwsh -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%',
                ') else (',
                '    powershell -NoProfile -NoLogo -ExecutionPolicy Bypass -File %updater_script%',
                ')',
                '',
                'set updater_failed=%errorlevel%',
                '',
                'if exist "%~dp0updater.ps1" (',
                '    del "%~dp0updater.ps1"',
                ')',
                'if %updater_failed% neq 0 (',
                '    echo Update failed with error %updater_failed% - leaving window open.',
                '    pause',
                '    exit /b %updater_failed%',
                ')',
                '',
                'timeout 5'
            )
        } else {
            $verb = 'register'; if ($job.File -match 'unregister') { $verb = 'unregister' }
            $at = Find-Lines ("`"%~dp0/mpv`" --" + $verb)
            if ($at.Count -ne 1) {
                $why = 'anchor not unique/found'
            } else {
                $new = @()
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    if ($i -eq $at[0]) {
                        if ($verb -eq 'register') {
                            $new += ':: --register writes registry keys tied to the CURRENT folder path - re-run this'
                            $new += ":: after moving the portable install; this is the one piece that isn't portable by design."
                            $new += ':: Requires elevation (admin) for machine-wide file associations.'
                        } else {
                            $new += ':: --unregister removes registry keys tied to the CURRENT folder path - re-run'
                            $new += ":: mpv-register.bat after moving the portable install; this is the one piece that isn't portable by design."
                            $new += ':: Requires elevation (admin) if registration was machine-wide.'
                        }
                        $new += ($lines[$i] -replace '%~dp0/mpv', '%~dp0mpv.exe')
                    } else {
                        $new += $lines[$i]
                    }
                }
            }
        }
        if ($new -eq $null) {
            Write-Log "$($job.File): launcher patch skipped - $why"
        } else {
            Write-Log "$($job.File): re-applying local tweaks over mpv-extract version"
            $text = ($new -join $nl) + $nl
            $ltTmp = "$lp.$([guid]::NewGuid().ToString('N')).tmp"
            try {
                [System.IO.File]::WriteAllText($ltTmp, $text, (New-Object System.Text.UTF8Encoding($false)))
                Move-Item -Path $ltTmp -Destination $lp -Force
            } finally {
                Remove-Item $ltTmp -Force -ErrorAction SilentlyContinue
            }
        }
    }
} catch {
    Write-Log "launcher tweaks patch failed, continuing anyway - $($_.Exception.Message)"
}

# Housekeeping: never blocks state save.
try {
    # Shader cache >30d, watch-later >7d, log >500 lines.
    $shaderCacheDir = Join-Path $ConfigDir 'cache\shaders_cache'
    if (Test-Path $shaderCacheDir) {
        Get-ChildItem $shaderCacheDir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-30) } | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Clean watch-later >7d
    $watchLaterDir = Join-Path $ConfigDir 'cache\watch_later'
    if (Test-Path $watchLaterDir) {
        Get-ChildItem $watchLaterDir -File | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-7) } | Remove-Item -Force -ErrorAction SilentlyContinue
    }

    # Rotate log >500 lines, keep last 400
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
    $Mutex.ReleaseMutex()
    $Mutex.Dispose()
}
