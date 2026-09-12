<#
Static structure + profile parse checks (no playback):
- mpv.conf include order (hdr-toys before res/colorspace), key bindings present
- every conditional profile restores + nil-guards height
- script-opts pins (165Hz, palette, thumbfast) and script layout
- every auto-profile parses via --show-profile
Exit 0 = all checks pass.
#>
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$mpv = Join-Path $root 'mpv.exe'   # .exe directly, never the .com wrapper: killing the wrapper orphans the real player
$pc = Join-Path $root 'portable_config'
$fail = 0
function Check($name, $cond) {
    if ($cond) { Write-Output "PASS: $name" } else { Write-Output "FAIL: $name"; $script:fail++ }
}
$conf = Get-Content (Join-Path $pc 'mpv.conf')
$li = @{ hdr = -1; res = -1; cs = -1 }
for ($i = 0; $i -lt $conf.Count; $i++) {
    if ($conf[$i] -match 'include="~~/hdr-toys.conf"') { $li.hdr = $i }
    if ($conf[$i] -match 'include="~~/profiles/res.conf"') { $li.res = $i }
    if ($conf[$i] -match 'include="~~/profiles/colorspace.conf"') { $li.cs = $i }
}
Check 'include order: hdr-toys < res < colorspace' (($li.hdr -ge 0) -and ($li.hdr -lt $li.res) -and ($li.res -lt $li.cs))
$input = Get-Content (Join-Path $pc 'input.conf') -Raw
foreach ($b in @('MBTN_RIGHT\s+script-binding uosc/menu', 'MENU\s+script-binding uosc/menu', 'Alt\+h\s+script-binding hdr-toggle\b(?!/)', 'Alt\+d\s+.*deband', 'Alt\+n\s+.*nlmeans', 'Alt\+t\s+.*tone-mapping')) {
    Check "input.conf binds $b" ($input -match $b)
}
foreach ($f in @('profiles/res.conf', 'profiles/colorspace.conf')) {
    $t = Get-Content (Join-Path $pc $f) -Raw
    $blocks = ([regex]::Matches($t, '^\[.+?\]', 'Multiline')).Count
    $restores = ([regex]::Matches($t, 'profile-restore=copy')).Count
    Check "$f every profile restores ($restores/$blocks)" (($blocks -gt 0) -and ($restores -eq $blocks))
}
$res = Get-Content (Join-Path $pc 'profiles/res.conf') -Raw
$conds = [regex]::Matches($res, '^profile-cond=.*$', 'Multiline') | ForEach-Object { $_.Value }
$guarded = @($conds | Where-Object { $_ -match '~=nil' }).Count
Check "res.conf all height conds nil-guarded ($guarded/$($conds.Count))" (($conds.Count -gt 0) -and ($guarded -eq $conds.Count))
Check 'changerefresh rates include 165' ((Get-Content (Join-Path $pc 'script-opts/changerefresh.conf') -Raw) -match '(?m)^rates=.*\b165\b')
$uosc = Get-Content (Join-Path $pc 'script-opts/uosc.conf') -Raw
Check 'uosc NieR palette' (($uosc -match 'e8dcc7') -and ($uosc -match '3a3528'))
Check 'uosc UI language pinned to en' ($uosc -match '(?m)^languages=en\s*$')
$tf = Get-Content (Join-Path $pc 'script-opts/thumbfast.conf') -Raw
Check 'thumbfast overlay_id=42 + mobius' (($tf -match 'overlay_id=42') -and ($tf -match 'tone_mapping=mobius'))
foreach ($s in @('scripts/thumbfast.lua', 'scripts/utilities/mpvSockets.lua', 'scripts/display/change-refresh.lua', 'scripts/media/main.lua', 'scripts/hdr-toggle.lua')) {
    Check "script present: $s" (Test-Path (Join-Path $pc $s))
}
# uosc icon family must resolve: ass.lua's requested family has to equal a family
# declared by fonts/uosc_icons.ttf, or ligature names render as raw text.
$assFam = ([regex]::Match((Get-Content (Join-Path $pc 'scripts/uosc/lib/ass.lua') -Raw), "opts\.font[^=]*=\s*'([^']+)'").Groups[1].Value)
$ttfFams = @(python (Join-Path $PSScriptRoot 'ttfnames.py') (Join-Path $pc 'fonts/uosc_icons.ttf') | ForEach-Object { ($_ -split '\|')[2] })
Check "uosc icon family resolves ($assFam)" (($assFam -ne '') -and ($ttfFams -contains $assFam))
$profiles = @('Res-SD', 'Res-720p-Clean2x', 'Res-Fractional', 'Res-NearNative', 'Res-Downscale', 'Colorspace-BT709', 'Colorspace-NTSC', 'Colorspace-PAL', 'gray', 'ending', 'bt.2100-pq', 'bt.2100-hlg', 'bt.2020', 'linear', 'high-quality')
foreach ($p in $profiles) {
    $pr = Start-Process $mpv -ArgumentList @("--show-profile=$p") -PassThru -NoNewWindow -Wait
    Check "profile parses: $p" ($pr.ExitCode -eq 0)
}
exit $fail
