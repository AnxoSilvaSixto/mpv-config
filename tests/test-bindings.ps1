<#
Keybinding round-trip via IPC keypress on a looped SDR clip:
Alt+d (deband cycle), Alt+n / Alt+Shift+n (nlmeans on/off),
Alt+t (tone-mapping cycle), Alt+g (classicjazz deband tuning).
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
$pipeName = 'mpv-bindings-test'
$hdrLog = Join-Path $env:TEMP 'mpv-test-bindings.log'
Remove-Item $hdrLog -ErrorAction SilentlyContinue
$proc = Start-Process $mpv -ArgumentList @((Join-Path $clips 'sdr709.mp4'), '--loop-file=inf', '--vo=null', '--ao=null', '--force-window=no', '--no-resume-playback', '--no-autocreate-playlist', "--input-ipc-server=$pipeName", "--log-file=$hdrLog", '--msg-level=cplayer=v') -PassThru -WindowStyle Hidden -RedirectStandardOutput NUL
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
    function Key($name) {
        # Drain async events the same way: only a request_id line is the reply.
        $w.WriteLine("{ `"command`": [`"keypress`", `"$name`" ] }")
        $deadline = (Get-Date).AddSeconds(10)
        while ((Get-Date) -lt $deadline) {
            $line = $r.ReadLine()
            if ($line -match '"request_id"') { return $line }
        }
        throw "no reply to keypress $name"
    }
    function Get($prop) { return (Send "{ `"command`": [`"get_property`", `"$prop`" ] }") }
    Start-Sleep -Milliseconds 2000  # let profiles + scripts settle

    $d1 = Get 'deband'; Key 'Alt+d' | Out-Null; Start-Sleep -Milliseconds 500
    $d2 = Get 'deband'; Key 'Alt+d' | Out-Null; Start-Sleep -Milliseconds 500
    $d3 = Get 'deband'
    Check "Alt+d cycles deband ($d1 -> $d2 -> $d3)" (($d1 -ne $d2) -and ($d2 -ne $d3) -and ($d1 -eq $d3))

    Key 'Alt+n' | Out-Null; Start-Sleep -Milliseconds 500
    $sh = Get 'glsl-shaders'
    Check 'Alt+n prepends nlmeans' ($sh -match 'nlmeans')
    $off = Key 'Alt+Shift+n'
    if ($off -notmatch '"error":"success"') { $off = Key 'Alt+Shift+N' }  # shift-normalized form
    Start-Sleep -Milliseconds 500
    $sh2 = Get 'glsl-shaders'
    Check 'Alt+Shift+n removes nlmeans' ($sh2 -notmatch 'nlmeans')

    $t1 = Get 'tone-mapping'; Key 'Alt+t' | Out-Null; Start-Sleep -Milliseconds 500
    $t2 = Get 'tone-mapping'; Key 'Alt+t' | Out-Null; Start-Sleep -Milliseconds 500
    $t3 = Get 'tone-mapping'
    Check 'Alt+t cycles tone-mapping' (($t1 -ne $t2) -and ($t2 -ne $t3))

    Key 'Alt+g' | Out-Null; Start-Sleep -Milliseconds 500
    $it = Get 'deband-iterations'
    Check 'Alt+g sets classicjazz tuning (iterations=2)' ($it -match '"data":2')
    $w.WriteLine('{ "command": ["quit"] }')
    $pipe.Close()
} finally {
    if (-not $proc.HasExited) { $proc.Kill() }
}
$text = Get-Content $hdrLog -Raw
Check 'bindings log clean' (-not ($text -match '\[fatal\]|\[error\]|lua error|unknown script-binding'))
exit $fail
