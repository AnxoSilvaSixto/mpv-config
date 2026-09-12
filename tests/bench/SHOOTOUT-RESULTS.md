# Shader shootout (Sep 2026 — RTX 5080, 1440p/165Hz)

Best faithful-reconstruction chain per rung, measured on real clips.
Method: perf gate (8s drop window, fullscreen) + SSIM vs incumbent +
spot vision. Tie = SSIM >= 0.99 (sub-visible). All perf OK unless noted.

## SD 480p (real480-ntsc) -> WINNER ArtCNN_C4F16
- ArtCNN_C4F16: winner (consensus fidelity + smallest + fast)
- ArtCNN_C4F32 on SD 0.998: tie, 4x compute for nothing visible
- ravu-zoom-ar 0.990: tie, stays fractional specialist
- ravu-r4/lite, nnedi64, CuNNy-S/D, Super-xBR ~0.993+: tie, no gain

## 720p (real720-av1) -> HOLDS ArtCNN_C4F32
- ravu-r4 0.994, CuNNy 0.996: tie. Anime4K-M 0.57: BLEACHES, out.

## Fractional 1080p (real1080) -> HOLDS ravu-zoom-ar
- ARNet 0.998, ACNet 0.998: tie. Anime4K-M 0.63: bleaches again, out.

## Chroma -> HOLDS CfL (Krig 0.997, Joint 0.996: tie)
## Post -> HOLDS SSimSuperRes (adap 0.984 unneeded energy; none 0.9997)
## Downscale 4K -> HOLDS SSimDownscaler (bare 0.998, ArtCNN-DS 0.998: ties)

## Denoise -> keep nlmeans on-demand (Bilateral ties 0.995; neither default-on)
## Not testable: FSRCNNX (no weights shipped), AnimeJaNai (custom build),
## Upscale-Hub (models only). FSR/CAS skipped (general tools, not anime).
## Applied: Res-SD -> ArtCNN_C4F16 (only change). Full run green 163/163.