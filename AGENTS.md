# mpv Config — Project Guidelines

**Read this before changing anything. Portable mpv at `C:\mpv`. SDR-only, faithful source, RTX 5080 + Vulkan + 1440p165 + x86_64-v3.**

`portable_config` must stay beside `mpv.exe`. Keep `~~/` paths everywhere. `screenshot-directory` is `~/Pictures/mpv` (intentional).

## Rules

- Never commit: `mpv.exe`/`mpv.com`, `cache/`, `tools/update-state.json`, `tools/update-log.txt`, `track-selector-overrides.json`.
- Never edit `hdr-toys.conf` (auto-managed). Customize via `mpv.conf` profiles.
- Don't rename `portable_config/`, don't remove `updater.bat`/`mpv-register.bat`.
- `scripts/thumbfast.lua` stays top-level (required for uosc). `display/main.lua`, `utilities/main.lua`, `media/main.lua` are bundle loaders, keep them.
- mpv asset is x86_64-v3 only. If a release has no v3 asset, wait — no baseline fallback.

## Git LFS

LFS (7 files): `ArtCNN_C4F32/C4F16/DN pair`, `CfL_Prediction`, `nlmeans`, `ravu-zoom-ar-r4.hook`.
Plain text (never LFS): `SSim*`, `KrigBilateral`, `FSRCNNX`, `hdeband`, `noise_static_luma.hook`, all of `hdr-toys/`.
After clone: `git lfs install && git lfs pull`. Never `git add` a pointer.

## Updater

Sole updater: `updater.bat` → `tools/Update-MpvEnvironment.ps1`. Safe to run every login; state in ignored `update-state.json`. Never touches `mpv.conf`/`input.conf`/`script-opts/`. Local patches (track-selector es-dub, uosc icons/menus, launchers) live as updater post-process blocks. `auto-save-state.lua` is frozen locally.

## Config

- `mpv.conf`: `vo=gpu-next`, `vulkan`, `hwdec=auto-safe`, `high-quality`. Scalers: `spline36`/`ewa_lanczossharp`/`hermite` (+`mitchell` in Downscale), antiring 0.7, `dither=fruit`, `rgba16hf`. Include order: hdr-toys → res → colorspace → maxquality. `[ending]` + auto-save-state co-own quit-save (last 60s = no save). `reset-on-next-file` includes `hue` + `sub-speed`.
- Res profiles (`profiles/res.conf`): SD (<700) ArtCNN_C4F16, 720p (700-739) ArtCNN_C4F32, fractional (740-1339) ravu, near-native (1340-1439) minimal, downscale (≥1440) mitchell. All `profile-restore=copy`, nil-guarded.
- `input.conf`: keep `MBTN_RIGHT`+`MENU` → `uosc/menu`. `#!` comments build the menu. `Alt+h` hdr-toggle, `Alt+q` MaxQuality, `Alt+n` nlmeans, `Alt+d` deband, `z/Z` chapters. `Alt+g` retired.
- `script-opts`: uosc NieR palette + `Material Symbols Rounded` (must match font), thumbfast 400px `mobius` `hwdec=yes`, changerefresh must keep `165` in `rates`.
- Shaders/scripts: never hand-edit `hdr-toys/`. uosc/thumbfast vendored via updater.

## Work

1. Read this + target file + `README.md` + `.gitignore` + `.gitattributes`.
2. `git status` — never `git add -A`.
3. Minimal edit, then verify:
   - `powershell -File portable_config/tools/Audit-MpvEnvironment.ps1` → 0 errors
   - `mpv.com --config-dir=portable_config --idle=once --force-window=no --no-terminal` → no `[e]`/`[fatal]`/`lua error`
   - `git status --porcelain` shows only intended files

## Gotchas

1. No v3 asset in a release → updater waits, don't add fallback.
2. Never hard-code `C:/mpv` in generated output — keep `~~/`.
3. `Set-RefreshRate.ps1` DEVMODE must be exactly 156 bytes.
4. `changerefresh.conf` must keep `165` or revert breaks.
