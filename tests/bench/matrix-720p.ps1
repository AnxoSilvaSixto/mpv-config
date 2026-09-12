# 720p rung matrix (real720-av1, exact 2x): prescaler + CfL + SSimSuperRes.
$O = 'C:/mpv/portable_config/shaders'
$S = 'C:/mpv/tests/shader-stage'
$C = 'C:/mpv/tests/clips/real/real720-av1.mkv'
$H = 'C:/mpv/tests/bench/shootout.ps1'
$A = "$S/Anime4K/glsl"
$jobs = @(
    @('hd-incumbent', "$O/ArtCNN_C4F32.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('hd-ravu4', "$S/mpv-prescalers/ravu-r4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('hd-a4k', "$A/Restore/Anime4K_Clamp_Highlights.glsl,$A/Restore/Anime4K_Restore_CNN_M.glsl,$A/Upscale/Anime4K_Upscale_CNN_x2_M.glsl,$A/Upscale/Anime4K_AutoDownscalePre_x2.glsl,$A/Upscale/Anime4K_Upscale_CNN_x2_S.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('hd-cunny', "$S/CuNNy/mpv/soft/CuNNy-2x12-SOFT.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl")
)
foreach ($j in $jobs) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $C -Label $j[0] -Chain $j[1]
}
Write-Output 'matrix-720p done'