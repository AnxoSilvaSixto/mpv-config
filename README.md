# mpv-config

> Portable mpv player configuration with uosc UI, HDR shaders, and automation.

[![GitHub](https://img.shields.io/badge/GitHub-AnxoSilvaSixto/mpv--config-181717?style=flat&logo=github)](https://github.com/AnxoSilvaSixto/mpv-config)
[![mpv](https://img.shields.io/badge/mpv-latest-48AA42?style=flat)](https://mpv.io)

> **Note:** Highly customized setup tuned for specific hardware (RTX 5080, Vulkan, 1440p). Use as reference and adjust for your own system.

## Features

- **uosc** — Modern, minimal player interface
- **HDR tone-mapping** — hdr-toys shader suite (tone-mapping, gamut-mapping, transfer functions)
- **Auto refresh rate** — Dynamic display refresh rate switching
- **Thumbnail preview** — thumbfast timeline thumbnails
- **Skip intro** — Automatic intro skipping
- **Subtitle selection** — sub-select menu
- **Auto-crop / Auto-deinterlace** — autocrop, autodeint

## Structure

```
C:\mpv\
├── portable_config/
│   ├── mpv.conf              # Main configuration
│   ├── hdr-toys.conf         # HDR profiles (auto-managed, do not edit directly)
│   ├── input.conf            # Keybindings (custom bindings only; defaults handled by uosc/mpv)
│   ├── scripts/
│   │   ├── uosc/             # uosc UI
│   │   ├── media/            # thumbfast, skip_intro, sub-select
│   │   ├── display/          # change-refresh
│   │   └── utilities/        # autocrop, autodeint
│   ├── script-opts/          # Script configs (uosc, thumbfast, sub-select, changerefresh)
│   ├── shaders/
│   │   ├── hdr-toys/         # HDR suite (~77 files, ~300 KB, plain text)
│   │   ├── ArtCNN_C4F32.glsl # AI upscaling (Git LFS)
│   │   ├── CfL_Prediction.glsl # Chroma reconstruction (Git LFS)
│   │   ├── nlmeans.glsl      # Denoising (Git LFS)
│   │   └── ravu-zoom-ar-r3.hook # Upscaling (Git LFS)
│   ├── fonts/                # uosc fonts
│   └── tools/                # Auto-update scripts
├── doc/                      # mpv manual
├── installer/
│   └── updater.ps1           # PowerShell updater logic
├── mpv/                      # mpv system files (fonts.conf)
├── updater.bat               # Entry point for updates
├── mpv-register.bat          # System integration (register)
├── mpv-unregister.bat        # System integration (unregister)
└── settings.xml              # Portable settings
```

## Shaders

Large binary-adjacent shaders are tracked via **Git LFS** (`portable_config/shaders/*.glsl`, `*.hook` at top level):

| Shader | Purpose | Storage |
|--------|---------|---------|
| `hdr-toys/` | HDR tone-mapping, gamut-mapping, transfer functions | Plain text (~300 KB) |
| `ArtCNN_C4F32` | AI upscaling | Git LFS (~761 KB) |
| `CfL_Prediction` | Chroma-from-luma prediction | Git LFS |
| `nlmeans` | Non-local means denoising | Git LFS |
| `ravu-zoom-ar-r3` | Adaptive upscaling | Git LFS |

> hdr-toys files are small text and stored directly in git. Only the four top-level shaders use LFS.

## Scripts & Tools

| Script | Description | Source |
|--------|-------------|--------|
| **uosc** | Modern UI with timeline, controls, menus | [tomasklaen/uosc](https://github.com/tomasklaen/uosc) |
| **thumbfast** | Thumbnail preview | [po5/thumbfast](https://github.com/po5/thumbfast) |
| **skip_intro** | Intro skipping | [Chinna95P/mpv-anime-build](https://github.com/Chinna95P/mpv-anime-build/blob/main/scripts/skip_intro.lua) |
| **sub-select** | Subtitle selection | [CogentRedTester/mpv-sub-select](https://github.com/CogentRedTester/mpv-sub-select) |
| **display/change-refresh** | Refresh rate switching | Custom |
| **utilities/autocrop** | Auto cropping | [kevmitch/mpv-autocrop](https://github.com/kevmitch/mpv-autocrop) |
| **utilities/autodeint** | Auto deinterlacing | [mpv-player/mpv](https://github.com/mpv-player/mpv) |
| **hdr-toys** | HDR shader suite | [natural-harmonia-gropius/hdr-toys](https://github.com/natural-harmonia-gropius/hdr-toys) |
| **ArtCNN** | Upscaling | [Artoriuz/ArtCNN](https://github.com/Artoriuz/ArtCNN) |
| **ravu** | Zoom prescaler | [bjin/mpv-prescalers](https://github.com/bjin/mpv-prescalers) |
| **nlmeans** | Denoising | [AN3223/dotfiles](https://github.com/AN3223/dotfiles) |

## Keybindings

Custom bindings defined in `portable_config/input.conf`. General playback, seeking, and volume are handled by uosc/mpv defaults.

| Key | Action | Menu |
|-----|--------|------|
| `MBTN_RIGHT` / `MENU` | Open uosc menu | — |
| `Ctrl+Shift+s` | Screenshot raw source frame | Diagnostics > Screenshot (raw source frame) |
| `Alt+d` | Toggle native deband (yes/no) | Diagnostics > Deband toggle |
| `Alt+g` | Apply classicjazz deband tuning (2:35:16:4) | — |
| `Alt+n` | Enable nlmeans denoise (prepend) | Diagnostics > Denoise > On |
| `Alt+Shift+n` | Disable nlmeans | Diagnostics > Denoise > Off |
| `Alt+h` | Disable hdr-toys, restore native tone-mapping | Diagnostics > HDR (use native tone-mapping) |
| `Alt+t` | Cycle tone-mapping `spline` / `bt.2446a` | — |

## Auto-Update

```batch
updater.bat                                      # Update mpv binaries (entry point)
installer/updater.ps1                            # PowerShell update logic
portable_config/tools/Register-MpvAutoupdate.ps1 # Register scheduled auto-update
portable_config/tools/Update-MpvEnvironment.ps1  # Sync hdr-toys.conf and environment
```

`hdr-toys.conf` is auto-managed by `Update-MpvEnvironment.ps1` — edit `mpv.conf` profiles instead.

## Installation

1. Download portable mpv from https://mpv.io and extract to `C:\mpv`
2. Back up existing `portable_config` if needed
3. Clone this repo:
   ```powershell
   git clone https://github.com/AnxoSilvaSixto/mpv-config.git C:\mpv-temp
   Copy-Item -Path C:\mpv-temp\portable_config -Destination C:\mpv\portable_config -Recurse -Force
   Copy-Item -Path C:\mpv-temp\installer, C:\mpv-temp\doc, C:\mpv-temp\*.bat, C:\mpv-temp\*.xml -Destination C:\mpv\ -Recurse -Force
   ```
   Or copy `portable_config/` directly over your existing `C:\mpv\portable_config\`
4. Ensure Git LFS is installed: `git lfs install`
5. Run `updater.bat` to fetch latest mpv binaries
6. Launch `mpv.com` (or `mpv.exe`)

> `mpv.exe` / `mpv.com` are ignored in git and managed by the updater.

## Documentation

- `AGENTS.md` — Repository guidelines
- `doc/manual.pdf` — mpv manual
- `portable_config/mpv.conf` — Main video/audio/output settings
- `portable_config/input.conf` — Keybindings

## License

Feel free to fork, use, modify, and adapt for your own tracking. No license restrictions — public domain equivalent, do whatever you want.
