# mpv portable config

Portable mpv for Windows. Tuned for RTX 5080 / 1440p165 / Ryzen 7 5700X. Reference only, not universal.

## Layout

```
C:\mpv\
├── mpv.exe / mpv.com             # supplied by updater, never committed
├── portable_config/              # must keep this name, beside mpv.exe
│   ├── mpv.conf                  # main config, includes profiles/*.conf
│   ├── hdr-toys.conf             # auto-generated, never edit
│   ├── input.conf                # key bindings (Alt+h HDR, Alt+q quality)
│   ├── scripts/                  # uosc + thumbfast + owned helpers
│   ├── script-opts/              # uosc, thumbfast, refresh options
│   ├── shaders/                  # hdr-toys + upscalers (some Git LFS)
│   └── tools/                    # updater + audit
├── updater.bat                   # sole updater entry point
└── mpv-register.bat              # file associations (admin, re-run after move)
```

Binaries, `cache/`, logs, state, and `track-selector-overrides.json` are ignored. Never commit secrets.

## Update

Double-click `updater.bat`, or:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\mpv\portable_config\tools\Update-MpvEnvironment.ps1
```

Updates mpv (x86_64-v3), hdr-toys, uosc, thumbfast, anime-build scripts. Never touches `mpv.conf`, `input.conf`, or `script-opts/`. Local patches are re-applied by the updater. Rollback: restore file from backup and delete its entry in `tools/update-state.json`.

Optional logon task:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\mpv\portable_config\tools\Register-MpvAutoupdate.ps1
```

## Check

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File C:\mpv\portable_config\tools\Audit-MpvEnvironment.ps1
C:\mpv\mpv.com --version
```

`Alt+h` drops hdr-toys shaders for native tone-mapping comparison. Full clip/bench suite lives separately in `mpv-config-tests` (run `run-all.ps1` next to this repo).

## Sources

[mpv](https://mpv.io) / [manual](https://mpv.io/manual/master/) — [uosc](https://github.com/tomasklaen/uosc) — [thumbfast](https://github.com/po5/thumbfast) — [hdr-toys](https://github.com/natural-harmonia-gropius/hdr-toys) — [ArtCNN](https://github.com/Artoriuz/ArtCNN)
