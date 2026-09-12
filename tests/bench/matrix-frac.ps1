# Fractional rung matrix (real1080-dual, 1080p->1440p): scaler + CfL + SSim.
$O = 'C:/mpv/portable_config/shaders'
$S = 'C:/mpv/tests/shader-stage'
$C = 'C:/mpv/tests/clips/real/real1080-dual.mkv'
$H = 'C:/mpv/tests/bench/shootout.ps1'
$A = "$S/Anime4K/glsl"
$jobs = @(
    @('fr-incumbent', "$O/ravu-zoom-ar-r4.hook,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('fr-a4k', "$A/Restore/Anime4K_Clamp_Highlights.glsl,$A/Restore/Anime4K_Restore_CNN_M.glsl,$A/Upscale/Anime4K_Upscale_CNN_x2_M.glsl,$A/Upscale/Anime4K_AutoDownscalePre_x2.glsl,$A/Upscale/Anime4K_Upscale_CNN_x2_S.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('fr-arnet', "$S/ACNetGLSL/glsl/arnet/arnet_f8b8.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl")
)
foreach ($j in $jobs) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $C -Label $j[0] -Chain $j[1]
}
Write-Output 'matrix-frac done'