# Gap coverage: Ultra, Super-xBR, CuNNy-DS, denoise rung (nlmeans vs Bilateral).
$O = 'C:/mpv/portable_config/shaders'
$S = 'C:/mpv/tests/shader-stage'
$H = 'C:/mpv/tests/bench/shootout.ps1'
$C720 = 'C:/mpv/tests/clips/real/real720-av1.mkv'
$C480 = 'C:/mpv/tests/clips/real/real480-ntsc.mkv'
$jobs = @(
    @('hd-ultra', $C720, "$S/Anime4K-Ultra/Anime4K-Ultra.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-xbr', $C480, "$S/super-xbr-luma.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('sd-cunnyds', $C480, "$S/CuNNy/mpv/ds/CuNNy-2x12-DS.glsl,$O/CfL_Prediction.glsl,$O/SSimSuperRes.glsl"),
    @('dnz-nlmeans', $C480, "$S/ArtCNN/GLSL/ArtCNN_C4F16.glsl,$O/CfL_Prediction.glsl,$O/nlmeans.glsl,$O/SSimSuperRes.glsl"),
    @('dnz-bilateral', $C480, "$S/ArtCNN/GLSL/ArtCNN_C4F16.glsl,$O/CfL_Prediction.glsl,$S/Anime4K/glsl/Denoise/Anime4K_Denoise_Bilateral_Mode.glsl,$O/SSimSuperRes.glsl")
)
foreach ($j in $jobs) {
    powershell -NoProfile -ExecutionPolicy Bypass -File $H -Clip $j[1] -Label $j[0] -Chain $j[2]
}
Write-Output 'matrix-gap done'