# mpv-config

> Portable mpv player configuration with uosc UI, HDR shaders, and automation

[![GitHub](https://img.shields.io/badge/GitHub-AnxoSilvaSixto/mpv--config-181717?style=flat&logo=github)](https://github.com/AnxoSilvaSixto/mpv-config)
[![mpv](https://img.shields.io/badge/mpv-latest-48AA42?style=flat&logo=video%20player&logoColor=white)](https://mpv.io)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

> **⚠️ Config-heavy** — This is a highly customized setup tuned for my specific hardware and preferences. Use as inspiration but expect to tweak settings for your own system.

## 🎬 Features

- **uosc** — Modern, gesture-based player interface
- **HDR tone-mapping** — hdr-toys shader suite with 50+ transfer functions
- **Auto-refresh rate** — Dynamic display refresh rate switching
- **Thumbnail preview** — thumbfast script for timeline thumbnails
- **Skip intro** — Automatic intro skipping
- **Subtitle selection** — Multi-subtitle support with sub-select
- **Auto-crop** — Automatic video cropping
- **Auto-update** — Automatic mpv binary updates

## 📁 Structure

```
mpv-config/
├── portable_config/
│   ├── mpv.conf              # Main configuration
│   ├── input.conf            # Keybindings
│   ├── scripts/              # Lua scripts
│   │   ├── uosc/             # uosc UI (main interface)
│   │   ├── media/            # thumbfast, skip_intro, sub-select
│   │   ├── display/          # Refresh rate switching
│   │   └── utilities/        # autocrop, autodeint
│   ├── script-opts/          # Script configuration
│   ├── shaders/              # GLSL shaders (Git LFS)
│   │   ├── hdr-toys/         # HDR tone-mapping suite
│   │   ├── ArtCNN_C4F32.glsl # AI upscaling
│   │   ├── CfL_Prediction.glsl # Color prediction
│   │   ├── nlmeans.glsl      # Noise reduction
│   │   └── ravu-zoom-ar-r3.hook # Zoom shader
│   ├── fonts/                # uosc custom fonts
│   └── tools/                # Auto-update scripts
├── doc/                      # Documentation
├── installer/                # Updater scripts
├── settings.xml              # Portable settings
└── updater.bat               # Auto-updater
```

## 🎮 Keybindings

| Key | Action |
|-----|--------|
| `Mouse Right` | Seek backward 10s |
| `Mouse Left` | Seek forward 10s |
| `Mouse Middle` | Toggle pause |
| `Scroll Up/Down` | Volume up/down |
| `Shift+Scroll` | Audio delay |
| `j` | Cycle sub tracks |
| `k` | Cycle audio tracks |
| `l` | Cycle video tracks |
| `f` | Toggle fullscreen |
| `q` | Quit player |

## 🎨 Shaders (Git LFS)

Shader files are tracked via **Git LFS** to keep repository size manageable.

| Shader | Purpose |
|--------|---------|
| **hdr-toys/** | HDR tone-mapping (Reinhard, Linear, BT.2446, etc.) |
| **ArtCNN_C4F32** | AI-powered upscaling |
| **CfL_Prediction** | Color space prediction |
| **nlmeans** | Non-local means denoising |
| **ravu-zoom-ar** | Adaptive resolution zoom |

## 📜 Scripts

| Script | Description |
|--------|-------------|
| **uosc** | Modern UI with menus, timeline, controls |
| **thumbfast** | Fast thumbnail preview generation |
| **skip_intro** | Automatic intro sequence skipping |
| **sub-select** | Subtitle track selection menu |
| **display/change-refresh** | Dynamic refresh rate switching |
| **utilities/autocrop** | Automatic video cropping |
| **utilities/autodeint** | Auto deinterlacing |

## 🔄 Auto-Update

```batch
updater.bat          # Update mpv binaries
tools/Register-MpvAutoupdate.ps1  # Register auto-updater
```

## 🛠️ Installation

1. Download latest mpv portable from https://mpv.io
2. Extract to `C:\mpv`
3. Clone this repo: `git clone https://github.com/AnxoSilvaSixto/mpv-config.git C:\mpv`
4. Run `updater.bat` to get latest binaries
5. Launch `mpv.com`

## 📚 Documentation

- `AGENTS.md` — Project guidelines and rules
- `doc/manual.pdf` — mpv manual

## 🔗 Related Projects

- **[AniVault](https://github.com/AnxoSilvaSixto/AniVault)** — Anime collection tracker & reference database
- **[OpenCode](https://opencode.ai)** — AI coding agent for terminal

## 📄 License

This project is licensed under the MIT License.

---

*Last updated: 2026-08-31*
