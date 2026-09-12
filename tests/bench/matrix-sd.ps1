# SD rung matrix (real480-ntsc): prescaler candidates + CfL + SSimSuperRes.
# Sequential by design (concurrent mpv fullscreen runs contend for GPU).
$O = 'C:/mpv/portable_config/shaders'
$S = 'C:/mpv/tests/shader-stage'
$C = 'C:/mpv/tests/clips/real/real480-ntsc.mkv'
$H = 'C:/mpv/tests/bench/shootout.ps1'
$jobs = @(
    @('sd-incumbent', "$O/ravu-zoom-ar-r4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-artcnn16', "$S/ArtCNN/GLSL/ArtCNN_C4F16.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-ravu4', "$S/mpv-prescalers/ravu-r4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-ravulite', "$S/mpv-prescalers/ravu-lite-r4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-nnedi64', "$S/mpv-prescalers/nnedi3-nns64-win8x4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-cunny', "$S/CuNNy/mpv/soft/CuNNy-2x12-SOFT.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl")
)
foreach ($j in $jobs) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $C -Label $j[0] -Chain $j[1]
}
Write-Output '--- orphans ---'
tasklist 2>$null | Select-String -Pattern '^mpv' | ForEach-Object { $_.Line } | Out-String | Write-Output
Write-Output 'matrix-sd done'
