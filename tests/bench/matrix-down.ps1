# Downscale rung (real2160 -> 1440p out): with/without SSimDownscaler.
$O = 'C:/mpv/portable_config/shaders'
$C = 'C:/mpv/tests/clips/real/real2160-pq.mkv'
$H = 'C:/mpv/tests/bench/shootout.ps1'
$jobs = @(
    @('dn-ssim', "$O/SSimDownscaler.glsl"),
    @('dn-none', "")
)
foreach ($j in $jobs) {
    if ($j[1] -eq "") {
        powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $C -Label $j[0]
    } else {
        powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $C -Label $j[0] -Chain $j[1]
    }
}
Write-Output 'matrix-down done'