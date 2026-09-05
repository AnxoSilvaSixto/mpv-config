# mpv Config — Project Guidelines

**ALWAYS read this file before making changes. This is a portable `mpv` config at `C:\mpv`.**

> Hardware context: Tuned for **RTX 5080 + Vulkan + 1440p + Zen 3 (x86_64-v3 / AVX2)**. Config philosophy is *faithful reconstruction of source, no stylization* (`portable_config/mpv.conf:2`). Advice as reference — adjust for other hardware. All paths below assume `C:\mpv` as root unless noted.

---

## 1. Directory Structure

```
C:\mpv\
├── portable_config/              # mpv portable expects EXACTLY this name — never rename
│   ├── mpv.conf                  # Main config — 141 lines (video/audio/output, profiles)
│   ├── hdr-toys.conf             # HDR profiles — 59 lines, AUTO-MANAGED, do not edit directly
│   ├── input.conf                # Keybindings — 51 lines (custom only; uosc/mpv defaults handle rest)
│   ├── scripts/
│   │   ├── thumbfast.lua         # Timeline thumbnails (po5/thumbfast) — 32,495 bytes
│   │   ├── uosc/                 # Modern UI (tomasklaen/uosc) — main.lua 43 KB + 40+ modules
│   │   │   ├── main.lua          # Entry (43,470 bytes)
│   │   │   ├── elements/         # Controls, Timeline, Menu, Volume, TopBar etc. (12 files)
│   │   │   ├── lib/              # ass, cursor, std, utils, text, menus etc. (10 files)
│   │   │   ├── intl/             # 10 locales (de, es, fr, it, pl, pt, ro, ru, tr, uk, zh*)
│   │   │   └── char-conv/        # zh.json (85 KB)
│   │   ├── media/
│   │   │   ├── sub-select.lua    # Smart subs (CogentRedTester) — 14,940 bytes
│   │   │   └── skip_intro.lua    # Intro skip (Chinna95P) — 6,123 bytes
│   │   ├── display/
│   │   │   └── change-refresh.lua # Refresh-rate switching (22,107 bytes) → tools/Set-RefreshRate.ps1
│   │   ├── utilities/
│   │   │   ├── autocrop.lua      # Auto crop (kevmitch) — 9,268 bytes
│   │   │   ├── autodeint.lua     # Auto deinterlace — 5,862 bytes
│   │   │   └── mpvSockets.lua    # IPC named pipe per PID — 1,373 bytes (NOT a shim)
│   │   ├── display/main.lua      # Shim — 116 bytes → require './change-refresh'
│   │   ├── media/main.lua        # Shim — 232 bytes → require skip_intro/sub-select
│   │   └── utilities/main.lua    # Shim — 208 bytes → require autocrop/autodeint/mpvSockets
│   ├── script-opts/
│   │   ├── uosc.conf             # 102 lines — NieR:Automata theme, floating bar
│   │   ├── thumbfast.conf        # 72 lines — 400x400, mobius, hwdec=yes
│   │   ├── changerefresh.conf    # 43 lines — rates=23;24;25;29;30;50;59;60;165, auto=yes
│   │   ├── sub_select.conf       # 14 lines — observe_audio_switches=yes
│   │   └── sub-select.json       # 200 bytes — 2-entry lang fallback (es → *)
│   ├── shaders/
│   │   ├── hdr-toys/             # 77 files, 298 KB plain text (NOT LFS) — see breakdown below
│   │   │   ├── tone-mapping/     # 8 files: astra, bt2390, bt2446a/c, reinhard, etc.
│   │   │   ├── gamut-mapping/    # 4 files: jedypod (active), bottosson, clip, false
│   │   │   ├── transfer-function/# 10 files: pq, hlg, bt1886, bt709, srgb (+ _inv)
│   │   │   │   └── log/          # 42 files: apple_log, arri_logc3/4, canon_clog2/3, sony_slog2/3, etc.
│   │   │   └── utils/            # 13 files: clip_both/black/alpha/white, exposure, lut, etc.
│   │   ├── ArtCNN_C4F32.glsl     # AI upscale — Git LFS 131-byte pointer (real ~761 KB)
│   │   ├── CfL_Prediction.glsl   # Chroma reconstruction — Git LFS 130-byte pointer
│   │   ├── nlmeans.glsl          # Denoise (opt-in Alt+n) — Git LFS 130-byte pointer
│   │   └── ravu-zoom-ar-r3.hook  # Adaptive upscale — Git LFS 132-byte pointer
│   ├── fonts/
│   │   ├── uosc_icons.ttf        # 1,206,668 bytes
│   │   ├── uosc_icons.otf        # 400,360 bytes
│   │   └── uosc_textures.ttf     # 38,228 bytes
│   ├── tools/
│   │   ├── Update-MpvEnvironment.ps1    # 263 lines — daily updater (mpv+hdr-toys+uosc+thumbfast)
│   │   ├── Register-MpvAutoupdate.ps1   # 27 lines — one-time Scheduled Task registration
│   │   ├── Set-RefreshRate.ps1          # 124 lines — Win32 ChangeDisplaySettingsEx wrapper
│   │   ├── update-state.json            # Last installed versions — DO NOT COMMIT
│   │   └── update-log.txt               # Run log — DO NOT COMMIT
│   └── cache/                    # shader cache + watch_later — DO NOT COMMIT
│       ├── shaders_cache/        # ~350+ shader cache files (auto-generated)
│       └── watch_later/          # 0 files currently, resume positions (auto-generated)
├── installer/
│   └── updater.ps1               # 796 lines — legacy mpv binary updater (zhongfly/mpv-winbuild)
├── doc/
│   ├── manual.pdf                # 1,043,359 bytes — mpv manual
│   └── mpbindings.png            # 190,376 bytes — keybindings diagram
├── mpv/
│   └── fonts.conf                # 103 lines — fontconfig system fonts
├── mpv.exe                       # 122,371,072 bytes — DO NOT COMMIT (managed by updater)
├── mpv.com                       # 3,584 bytes — console stub — DO NOT COMMIT
├── settings.xml                  # 8 lines — updater settings (arch, autodelete, getffmpeg, ytdlp channel, token)
├── updater.bat                   # 24 lines — entry point → installer/updater.ps1
├── mpv-register.bat              # 6 lines — calls `mpv --register` (file association)
├── mpv-unregister.bat            # 6 lines — calls `mpv --unregister`
├── .gitignore                    # 22 lines — ignores mpv.exe/com, cache/, update-state/log
├── .gitattributes                # 3 lines — Git LFS tracking for *.glsl/*.hook
└── README.md                     # 134 lines — public overview
```

**Critical:** `portable_config/` must stay exactly that name (mpv portable hard-requires it). No `C:\mpv\shaders\` at root — all shaders live under `portable_config/shaders/`. Legacy docs may reference root `shaders/` — ignore.

---

## 2. ABSOLUTE RULES

### 2.1 Never Commit Binaries
- **NEVER** commit `mpv.exe` (122 MB) or `mpv.com` (3,584 bytes) — `.gitignore:4-5`
- Managed by `updater.bat` / `installer/updater.ps1:573` (`Upgrade-Mpv`) via GitHub Releases from `zhongfly/mpv-winbuild`
- `settings.xml:2` selects `x86_64-v3` (AVX2) — Zen 3 5700X assumption. Revert to `x86_64` for non-v3 CPUs. Setting is read by `installer/updater.ps1:401` (`Check-Arch`) and hardcoded as `zhongfly` v3 pattern in `Update-MpvEnvironment.ps1:94`
- `mpv.com --version` currently `mpv v0.41.0-1017-g02a595ddc` / `libplacebo v7.371.0` / `FFmpeg N-126342-gf88b741db` (2026-08-31 build)

### 2.2 Never Commit Cache / State / Logs
- **NEVER** commit `portable_config/cache/` — `.gitignore:8` (shader cache + watch_later, auto-generated). Currently `shaders_cache/` holds ~350 files, `watch_later/` 0 files.
- **NEVER** commit `portable_config/tools/update-log.txt` or `update-state.json` — `.gitignore:10-11`
- Auto-cleanup in `portable_config/tools/Update-MpvEnvironment.ps1:237-247`: shader cache `>30d`, watch_later `>7d`, log rotation at `>500` lines (keeps last 400)
- `update-state.json:1` example: `{"mpv":"2026-08-31-02a595ddc1","hdrtoys":"78aa356...","uosc":"12b918f...","thumbfast":"0f711de..."}` — 4 SHAs/tags, one per component (`Update-MpvEnvironment.ps1:56-57`)

### 2.3 Never Edit Auto-Managed Files
- **NEVER** edit `portable_config/hdr-toys.conf` directly — header `hdr-toys.conf:1` says `AUTO-MANAGED by Update-MpvEnvironment.ps1` — will be overwritten on next daily run.
- To customize HDR: edit `mpv.conf` profiles or the transform rules in `Update-MpvEnvironment.ps1:217-224`
- Transforms applied on sync: `~~/shaders/hdr-toys/` → `C:/mpv/portable_config/shaders/hdr-toys/` (portable `~~/` sometimes fails) and `gamut-mapping/bottosson.glsl` → `gamut-mapping/jedypod.glsl` (upstream v2504 note). See `Update-MpvEnvironment.ps1:169-179`
- If you must change HDR, do it in `mpv.conf` target-prim/trc or add a new transform — never hand-edit `hdr-toys.conf` expecting it to stick

### 2.4 Preserve Portable Structure
- Don't rename `portable_config/` — mpv portable hard-requires this name
- Don't remove `updater.bat`, `installer/updater.ps1`, `mpv-register.bat`, `mpv-unregister.bat`
- Keep absolute paths `C:/mpv/...` in `mpv.conf:31`, `input.conf:35-36,44` and shader appends — `~~/` is documented to sometimes fail under `portable_config` (see `Update-MpvEnvironment.ps1:172` and `mpv.conf:31`). Only `mpv.conf:61-62` keeps `~~/` for cache dirs (the sole place it is known safe)
- Shim files (`display/main.lua:1`, `media/main.lua:1`, `utilities/main.lua:1`) are `require` re-exports — keep them, they bundle scripts per-folder. `utilities/mpvSockets.lua:1` is NOT a shim — it sets `input-ipc-server` to `\\.\pipe\mpvSockets_<PID>` on Windows

### 2.5 Git LFS
- `portable_config/shaders/*.glsl` and `*.hook` at top level are tracked via LFS — `.gitattributes:2-3` — only 4 files: `ArtCNN_C4F32.glsl` (131b pointer), `CfL_Prediction.glsl` (130b), `nlmeans.glsl` (130b), `ravu-zoom-ar-r3.hook` (132b). Real sizes ~761 KB, ~100s KB respectively when pulled.
- **`hdr-toys/` stays plain text** — 77 files, 298 KB total — do NOT LFS it. Only those 4 top-level shaders use LFS.
- Without `git lfs install`, those 4 files read as `version https://git-lfs.github.com/spec/v1` pointer text — `portable_config/shaders/*.glsl:1` will show pointer, not shader code. Before cloning/pulling LFS: `git lfs install` then `git lfs pull`
- Never `git add` a pointer file — ensure `git lfs ls-files` shows them as LFS objects

---

## 3. KEY FILES — Deep Reference

### 3.1 `portable_config/mpv.conf` — 141 lines
**Global (lines 1-67):**
- `vo=gpu-next`, `gpu-api=vulkan`, `hwdec=auto-safe`, `vd-lavc-dr=yes`, `hwdec-extra-frames=10` — modern pipeline, RTX 5080 verified (`mpv.conf:5-9`)
- `profile=high-quality`, `vulkan-async-compute/transfer=yes`, `vulkan-queue-count=1` — tested 1/2/3 all 0 drops (`mpv.conf:10-13`)
- `video-sync=display-vdrop` (`mpv.conf:14`) — UI responsiveness without audio pitch shift
- Downscaling: `dscale=hermite` globally (`mpv.conf:17`), `ewa_lanczos` only inside `[Res-Downscale]` (`mpv.conf:104-105`), `linear-downscaling=yes` (`mpv.conf:18`, disabled for downscale `mpv.conf:104`), `correct-downscaling=yes` (`mpv.conf:19`), `sigmoid-upscaling=yes` (`mpv.conf:20`)
- Antiringing `scale-antiring=0.7` (`mpv.conf:23`)
- Deband: `deband=yes`, `dither-depth=auto`, `temporal-dither=yes` (`mpv.conf:26-28`) — toggle via `Alt+d` in `input.conf:22`
- HDR: `include="C:/mpv/portable_config/hdr-toys.conf"` (`mpv.conf:31`) — loads before profiles; must stay before any `[profile]`
- Subs/audio: `sub-auto=fuzzy`, `sub-ass-override=no`, `sub-ass-style-overrides=Kerning=yes`, `sub-ass-scale-with-window=no`, `demuxer-mkv-subtitle-preroll=yes`, `slang=es,es-ES,es-419,en,eng,jpn,ja,und`, `alang=jpn,ja,eng,en`, `audio-normalize-downmix=yes` (`mpv.conf:34-41`)
- Screenshots: `png`, `screenshot-high-bit-depth=yes`, `screenshot-tag-colorspace=yes`, to `C:/Users/Anxo/Pictures/mpv` (`mpv.conf:44-47`)
- Behavior: `keep-open=yes`, `save-position-on-quit=yes`, `force-window=immediate`, `reset-on-next-file=audio-delay,sub-delay,video-aspect-override,video-pan-x,video-pan-y,video-rotate,video-zoom,volume,hue,vf,af`, `cursor-autohide=3000`, `fs=yes` (`mpv.conf:50-55`)
- Auto-playlist: `autocreate-playlist=filter` (`mpv.conf:58`) — auto-queues folder episodes
- Cache dirs: `gpu-shader-cache-dir="~~/cache/shaders_cache"`, `watch-later-dir="~~/cache/watch_later"` (`mpv.conf:61-62`) — only place `~~/` is kept
- uosc: `border=no`, `osd-bar=no` (`mpv.conf:65-66`) — uosc draws its own

**Profiles (lines 68-141) — order matters, `profile-restore=copy` isolates each:**
| Profile | Condition (`profile-cond`) | Shaders / Overrides | Notes |
|---------|----------------------------|---------------------|-------|
| `[Res-SD]` | `height~=nil and height<700` | `ravu-zoom + CfL` | SD/DVD |
| `[Res-720p-Clean2x]` | `700≤h<740` | `ArtCNN + CfL` | Exact 2× to 1440p — integer scale has no ringing |
| `[Res-Fractional]` | `740≤h<1340` | `ravu-zoom + CfL` | 1080p etc. — fractional scaling |
| `[Res-NearNative]` | `1340≤h<1440` | `CfL` only | Near 1440p — no upscaler needed |
| `[Res-Downscale]` | `h≥1440` | `CfL` + `dscale=ewa_lanczos` + `linear-downscaling=no` | Downscale profile overrides global dscale |
| `[Colorspace-BT709]` | `p["video-params/primaries"]=="bt.709" and p["video-params/gamma"]~="pq/hlg"` (negated) | `target-prim=bt.709, target-trc=bt.1886` | Modern SDR |
| `[Colorspace-NTSC]` | `bt.601-525` | `bt.601-525` | Pre-2000s NTSC |
| `[Colorspace-PAL]` | `bt.601-625` | `bt.601-625` | Euro PAL |
| `[gray]` | `p["video-params/pixelformat"]=="gray"` | *removes* CfL/ArtCNN/ravu, `dscale=gaussian` | B&W — skips chroma reconstruction |
| `[ending]` | `get("duration",0)>0 and get("time-remaining",0)<=60` | `save-position-on-quit=no` | Final 60s - do not save position |

- All profiles use `profile-restore=copy` so changes don't leak to next file. Never remove it.
- Conditions use `height~=nil and height OP` — nil guard required because `height` is nil at startup.
- Shader paths use `glsl-shaders-append=` (mpv.conf) vs `glsl-shader=` (hdr-toys.conf) — both valid; `append` is explicit about order.
- Test profiles: `mpv --show-profile=Res-SD` / `--show-profile=Colorspace-BT709` etc.

### 3.2 `portable_config/hdr-toys.conf` — 59 lines, auto-managed
Generated by `Update-MpvEnvironment.ps1:217-224` from upstream `natural-harmonia-gropius/hdr-toys` `hdr-toys.conf` with 2 text transforms.
- Global: `target-colorspace-hint=no`, `tone-mapping=clip`, `gamut-mapping-mode=clip` (`hdr-toys.conf:6-9`)
- `[bt.2100-pq]` (`hdr-toys.conf:11-21`) — `bt.2020+pq` → `clip_both + pq_inv + astra + jedypod + bt1886`, opts `auto_exposure_limit_positive=1.02`
- `[bt.2100-hlg]` (`hdr-toys.conf:23-32`) — `bt.2020+hlg` → `clip_both + hlg_inv + astra + jedypod + bt1886`
- `[bt.2020]` (`hdr-toys.conf:34-41`) — `bt.2020+bt.1886` → `bt1886_inv + jedypod + bt1886`
- `[linear]` (`hdr-toys.conf:43-58`) — `exr/hdr/tiff pipe` → `vf=format:gamma=linear`, `deband=no`, `scale=bilinear`, `target-prim=bt.2020 target-trc=linear`, plus `clip_black + clip_alpha + astra + jedypod + bt1886`, opts `spatial_stable_iterations=0 temporal_stable_duration=0 enable_metering=1`
- All use absolute `C:/mpv/...` after transform. `Alt+h` in `input.conf:44` must del **all 9** shaders across these 4 profiles to fully disable — fixed 2026-08-25 (was only 5 PQ shaders before).

### 3.3 `portable_config/input.conf` — 51 lines
Custom bindings only — everything else uses mpv/uosc defaults. `#!` syntax builds uosc right-click menu; without `MBTN_RIGHT` binding menu is empty.

- `MBTN_RIGHT` + `MENU` → `script-binding uosc/menu` (`input.conf:10-11`) — **required** for `#!` menu comments to attach. Do not remove either.
- `#  script-binding uosc/subtitles/audio/chapters/open-file` (`input.conf:12-15`) — menu-only entries, no key, appear as `Subtitles / Audio tracks / Chapters / Open file` in right-click.
- `Ctrl+Shift+s` → `no-osd set screenshot-sw yes; screenshot; set screenshot-sw no` (`input.conf:17`) — raw source-frame (pre-OSD) screenshot. Menu: `Diagnostics > Screenshot (raw source frame)`.
- `Alt+d` → `cycle-values deband "yes"/"no"` (`input.conf:22`) — toggle mpv built-in deband. Menu: `Diagnostics > Deband toggle`.
- `Alt+g` → `set deband-iterations 2; set deband-threshold 35; set deband-range 16; set deband-grain 4` (`input.conf:28`) — classicjazz tuning `2:35:16:4` — **rejected** (bare defaults scored 2.99 vs 25.57 banding), **not in menu**, reload file to reset. Kept for re-testing only.
- `Alt+n` / `Alt+Shift+n` → `change-list glsl-shaders pre/del nlmeans.glsl` (`input.conf:35-36`) — `pre` to run before upscaler chain (denoise must precede upscale). Menu: `Diagnostics > Denoise > On/Off`. Benefit confirmed SSIM 0.57→0.82 on synthetic noise, but opt-in only.
- `Alt+h` (`input.conf:44`) → del all 9 hdr-toys shaders + `set target-colorspace-hint yes; set tone-mapping spline; set gamut-mapping-mode auto` — manual fallback to native tone-mapping. Menu: `Diagnostics > HDR (use native tone-mapping)`. Lists all 9 even if some not loaded — `del` on non-loaded shader is harmless no-op. Reload file to restore hdr-toys.
- `Alt+t` → `cycle-values tone-mapping "spline"/"bt.2446a"` (`input.conf:51`) — unresolved HDR test (only visible on HDR like Dolby Vision remux). Not in menu, kept for comparison.
- Inline comments document rationale inline — preserve them if editing.

### 3.4 `portable_config/script-opts/`
- **`uosc.conf` — 102 lines** (`script-opts/uosc.conf:1`) — `timeline_style=line`, `timeline_size=40`, `progress_size=2`, `controls=menu,gap,<video,audio>subtitles,...` (`uosc.conf:16-17`), `volume=right`, `top_bar=no-border`. NieR:Automata palette `foreground=e8dcc7, foreground_text=3a3528, background=3a3528, background_text=e8dcc7, curtain=c8c2aa, success=6a9f3e, error=c44536, match=c9944b, heatmap=b8943e` (`uosc.conf:88`). `opacity=timeline=0.85,controls=0.85,border=0.5` (`uosc.conf:91`), `scale=1.2`, `scale_fullscreen=1.56` (`uosc.conf:50-51`), `chapter_ranges=openings:c9c2ab73,endings:af8f6a73,...` with multilingual `chapter_range_patterns=openings:opening, op ,...` (`uosc.conf:94-95`). `autoload=no`, `shuffle=no`, `languages=slang,en`, `subtitles_directory=~~/subtitles`.
- **`thumbfast.conf` — 72 lines** — `max_height=400`/`max_width=400` (`thumbfast.conf:17-18`, up from 200×200 default for RTX 5080 — single-frame decode trivial), `scale_factor=1`, `tone_mapping=mobius` (`thumbfast.conf:35` — NOT `auto`; `auto` would pick up mpv's sentinel `tone-mapping` placeholder literally when hdr-toys is active, `mobius` is real curve), `overlay_id=42`, `spawn_first=yes`, `quit_after_inactivity=0`, `network=no`, `audio=no`, `hwdec=yes` (thumbnail subprocess passes `--hwdec=auto`, isolated single-frame, safe), `direct_io=yes` (LuaJIT, fails safe if no FFI), `mpv_path=mpv` (resolves via `user-data/frontend/process-path` on Windows).
- **`changerefresh.conf` — 43 lines** — `rates=23;24;25;29;30;50;59;60;165` (`changerefresh.conf:10` — **165 must stay**, script's revert logic requires desktop native rate in list), `auto=yes` (`changerefresh.conf:14` — auto-match on file load; `Ctrl+f10` still reverts manually), `pause=3` (A/V desync avoidance), `bdepth=32`, `estimated_fps=no` (container-fps, not estimated, for source fidelity), `detect_display_resolution=yes` + `original_width=1920/height=1080/rate=0` (revert resolution too), `UHD_adaptive=no` (refresh-only, not resolution switching), `osd_output=yes`.
- **`sub_select.conf` — 14 lines** — `observe_audio_switches=yes` (`sub_select.conf:7` — only non-default; default is `no`. Makes Spanish-only rule reactive on mid-file JP→ES dub switch). Rest commented upstream defaults: `force_enable`, `select_audio`, `explicit_forced_subs`, `config=~~/script-opts`.
- **`sub-select.json` — 200 bytes** — companion data for `sub-select.lua`: `[{"alang":["es","es-ES","es-419","spa"],"slang":"no"}, {"alang":"*","slang":["es","es-ES","es-419","en","eng","jpn","ja","und"]}]` — first entry: if Spanish audio, no subs; else ES>EN>JA subs.

### 3.5 `settings.xml` — 8 lines
```xml
<arch>x86_64-v3</arch>        <!-- AVX2 build, for Zen 3 5700X; use x86_64 if non-v3 -->
<autodelete>true</autodelete> <!-- delete archives after extract -->
<getffmpeg>false</getffmpeg>  <!-- ffmpeg download toggle (installer/updater.ps1:462 Check-GetFFmpeg) -->
<getytdl>false</getytdl>      <!-- managed by updater.ps1:490 Check-GetYTDL — false means yt-dlp/youtube-dl disabled -->
<ytdlpchannel>unset</ytdlpchannel> <!-- stable/nightly/master for yt-dlp (installer/updater.ps1:538) -->
<githubtoken>unset</githubtoken>   <!-- optional GH token for API rate limits (installer/updater.ps1:76 Get-GitHubToken) -->
```
Used by `installer/updater.ps1:79` (`Get-GitHubToken` checks `settings.xml` → `GH_TOKEN` → `GITHUB_TOKEN` env). Also controls arch selection for mpv/ffmpeg asset regex.

### 3.6 `portable_config/shaders/` and `portable_config/scripts/` — Detailed
- **Shaders:** `hdr-toys/` 77 files, 298 KB plain text (see tree breakdown above). 4 top-level LFS pointers until `git lfs pull`: `ArtCNN_C4F32.glsl:1` shows `version https://git-lfs.github.com/spec/v1` (131 bytes), similarly CfL/nlmeans 130 bytes, ravu 132 bytes. Real files are binary-ish GLSL hooks, never hand-edit `hdr-toys/` — will be overwritten by `Update-MpvEnvironment.ps1:218`.
- **Scripts:** `uosc/main.lua` 43 KB + 40+ modules (elements/, lib/, intl/, char-conv/); top-level `portable_config/scripts/thumbfast.lua` 32 KB (po5), `sub-select.lua` 14 KB (CogentRedTester), `skip_intro.lua` 6 KB (Chinna95P); `display/change-refresh.lua` 22 KB (custom, base CogentRedTester + Set-RefreshRate.ps1 integration); `utilities/autocrop.lua` 9 KB (kevmitch), `autodeint.lua` 5 KB (mpv upstream). Loader shims are 116–209 byte `require` re-exports; `utilities/mpvSockets.lua` is 1,373 bytes full IPC logic (`mp.set_property("input-ipc-server", "\\\\.\\pipe\\mpvSockets_<pid>")` on Windows, `/tmp/mpvSockets/...sock` on unix). The three `main.lua` shims bundle per-folder so mpv's recursive loader groups them.
- **thumbfast path:** Upstream `po5/thumbfast` is installed at `portable_config/scripts/thumbfast.lua` at the top level of `scripts/`. `Update-MpvEnvironment.ps1:233` writes `Dest='scripts\\thumbfast.lua'`; mpv discovers the script directly, and `media/main.lua` does not require it.

### 3.7 Fonts — `portable_config/fonts/`
- `uosc_icons.ttf` 1,206,668 bytes + `uosc_icons.otf` 400,360 bytes (same icon set, two formats) + `uosc_textures.ttf` 38,228 bytes. Required for uosc UI. Copied by `Update-MpvEnvironment.ps1:228-230` from `uosc/src/fonts/`.

### 3.8 Other Root Files
- `mpv/fonts.conf` — 103 lines — system fontconfig. `WINDOWSFONTDIR`, `WINDOWSUSERFONTDIR`, `LOCAL_APPDATA_FONTCONFIG_CACHE`. Do not edit; upstream fontconfig template.
- `doc/manual.pdf` 1,043,359 bytes + `doc/mpbindings.png` 190,376 bytes — offline mpv manual and bindings diagram.
- `mpv-register.bat:4` / `mpv-unregister.bat:4` — `"%~dp0/mpv" --register` / `--unregister` (system file association). Need no admin notes? They attempt registration and `pause` on failure.
- `portable_config/cache/` — ignored, auto-generated. `shaders_cache/` currently ~350 `shader_<hash>` files, `watch_later/` 0 files.

---

## 4. TOOLS & AUTO-UPDATE SYSTEM

Two updaters coexist — **don't confuse them**:

| Tool | Purpose | When to run | Touches |
|------|---------|-------------|---------|
| `updater.bat` → `installer/updater.ps1` (796 lines) | **Legacy/full** mpv + yt-dlp/youtube-dl + ffmpeg + deno | Manual, interactive, 9s prompts | `mpv.exe`, `yt-dlp.exe`, `ffmpeg.exe`, `deno.exe`, `settings.xml` |
| `portable_config/tools/Update-MpvEnvironment.ps1` (263 lines) | **Daily preferred** mpv + hdr-toys + uosc + thumbfast | Every login (Scheduled Task) | `mpv.exe`, `shaders/hdr-toys/`, `scripts/uosc/`, `fonts/`, `scripts/thumbfast.lua`, `hdr-toys.conf` |

### 4.1 `updater.bat` — 24 lines
Thin wrapper: `pushd %~dp0`, detects `pwsh` vs `powershell` (`where pwsh`), runs `installer/updater.ps1` with `Bypass`, cleans stray `updater.ps1` in root if exists, `timeout 5`. Always use this as entry point, not calling `installer/updater.ps1` directly.

### 4.2 `installer/updater.ps1` — 796 lines — Legacy updater
- Source: `zhongfly/mpv-winbuild` releases (configurable via `settings.xml:arch`, or `shinchiro/mpv-winbuild-cmake` alternative comment `Update-MpvEnvironment.ps1:22-25`)
- 7-Zip handling: `Get-7z`/`Check-7z` (`updater.ps1:4-31`) — checks `Get-Command 7z.exe`, registry `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\7-Zip`, fallback to `7z\7zr.exe` downloaded from `https://www.7-zip.org/a/7zr.exe`
- GitHub API: `Invoke-GitHubApi` (`updater.ps1:114-130`) uses token from `Get-GitHubToken` (`updater.ps1:76`) → `settings.xml:githubtoken` → `GH_TOKEN` → `GITHUB_TOKEN`
- Functions: `Get-Latest-Mpv` (`updater.ps1:170-183`) regex `mpv-$Arch-[0-9]{8}` against `https://api.github.com/repos/zhongfly/mpv-winbuild/releases/latest`; `Get-Latest-Ytplugin` (`updater.ps1:185-214`) fetches RSS for yt-dlp stable/nightly/master or youtube-dl; `Get-Latest-FFmpeg` (`updater.ps1:216-227`); `ExtractGitFromFile` (`updater.ps1:291-297`) parses `mpv --no-config | select-string mpv` for `-g<hash>`; `ExtractGitFromURL` (`updater.ps1:299-304`) parses `-git-<hash>`; `Test-CommitEquivalent` (`updater.ps1:276-289`) prefix-match for short vs long hashes; `Upgrade-Mpv` (`updater.ps1:573-638`) compares `localgit/remotegit` + `localdate/remotedate` (LastWriteTimeUtc) before downloading; `Upgrade-Ytplugin` (`updater.ps1:640-684`), `Upgrade-FFmpeg` (`updater.ps1:686-740`), `Ensure-Deno` (`updater.ps1:321-380`) for yt-dlp EJS runtime; `Read-KeyOrTimeout` (`updater.ps1:742-771`) 9s prompt with progress bar
- Persists choices to `settings.xml`: arch (x86_64 vs x86_64-v3), autodelete, getffmpeg, getytdl (ytdlp/youtubedl/false), ytdlpchannel, githubtoken
- Handles 32-bit detection via `SysWow64` test, Deno only on x86_64 Windows

### 4.3 `portable_config/tools/Update-MpvEnvironment.ps1` — 263 lines — Daily updater (preferred)
- **Does:** mpv (x86_64-v3 asset only) + hdr-toys + uosc + thumbfast. Safe to run every login — unchanged day = 4 API calls, no downloads, just log line.
- **Never touches:** `mpv.conf`, `input.conf`, `script-opts/` — only paths in `Update-GitFolder` calls (`tools/Update-MpvEnvironment.ps1:217-235`): `shaders/hdr-toys` dir, `hdr-toys.conf` (with transforms), `scripts/uosc` dir + fonts, `scripts/thumbfast.lua`
- Config: `MpvRepo='zhongfly/mpv-winbuild'` (`Update-MpvEnvironment.ps1:26`), `MpvRoot='C:\mpv'`, `ConfigDir`, `ToolsDir`, `StateFile='tools/update-state.json'`, `LogFile='tools/update-log.txt'`, `WorkDir=$env:TEMP\mpv-autoupdate`
- State in `tools/update-state.json:1` (`mpv`, `hdrtoys`, `uosc`, `thumbfast` SHAs/tags) — skips download if SHA matches previous run. Backfills missing keys for older state files (`Update-MpvEnvironment.ps1:64-67`)
- mpv: `https://api.github.com/repos/$MpvRepo/releases/latest` → regex `^mpv-x86_64-v3-\d{8}-git-[0-9a-f]+\.7z$` (`Update-MpvEnvironment.ps1:94-96`) — if no v3 asset (seen 2026-08-27 release `2026-08-26-182fa6ca49`), **waits** rather than falling back to baseline (`Update-MpvEnvironment.ps1:97-103`): `Write-Log "no matching x86_64 asset ... skipping"`
- hdr-toys/uosc/thumbfast: `https://api.github.com/repos/<repo>/commits/<branch>` (`Update-MpvEnvironment.ps1:147`) → zip via `codeload.github.com/$Repo/zip/$sha` (`Update-MpvEnvironment.ps1:156`) → `Expand-Archive` → copy per `Paths` table. hdr-toys includes 2 text transforms. uosc uses `-RepoBranch 'main'` (others use `master` `Update-MpvEnvironment.ps1:39`)
- Requires 7-Zip on PATH or `ProgramFiles\7-Zip\7z.exe` for mpv step only (`Update-MpvEnvironment.ps1:107-115`) — if missing, logs and skips mpv, continues to hdr-toys/uosc (they need only `Expand-Archive`)
- Mutex `Global\mpv-autoupdate-lock` (`Update-MpvEnvironment.ps1:202`) prevents overlapping runs — if another instance holds lock, exits immediately. Pairs with Scheduled Task `MultipleInstances IgnoreNew`
- Cleanup + log rotation at end (`Update-MpvEnvironment.ps1:237-254`): `shaders_cache >30d`, `watch_later >7d`, `update-log.txt >500 lines` (keeps last 400)
- Current state (`update-state.json:1` 2026-08-31): `mpv 2026-08-31-02a595ddc1`, `hdrtoys 78aa356900e956f9347e4ada281092098a6d88a9`, `uosc 12b918fcbcae56ded0e073a965d769bb0c5d900e`, `thumbfast 0f711de3138c9bd6718209d819ac54022c23ded2`

### 4.4 `portable_config/tools/Register-MpvAutoupdate.ps1` — 27 lines
One-time: registers Scheduled Task `mpv-autoupdate` — `AtLogOn` + `Delay PT1M` (1min, lets networking come up), `powershell.exe -WindowStyle Hidden -File "...Update-MpvEnvironment.ps1"`, `StartWhenAvailable`, `ExecutionTimeLimit 15min`, `MultipleInstances IgnoreNew` (`Register-MpvAutoupdate.ps1:19`). Description: `Daily check/update for mpv, hdr-toys, and uosc`. Needs no admin (logon task in user context; startup trigger would fire pre-login before network). Test with `Start-ScheduledTask -TaskName 'mpv-autoupdate'`, check `tools/update-log.txt:1` last lines like `[2026-08-31 16:26:36] mpv: done, now on ...`.

### 4.5 `portable_config/tools/Set-RefreshRate.ps1` — 124 lines
Win32 `ChangeDisplaySettingsEx` via `Add-Type` C# `DisplayHelper` (`Set-RefreshRate.ps1:15-67`). Params: `Width`, `Height`, `Rate`, `DeviceName` (`\\.\DISPLAY1`), `BitDepth=32` (`Set-RefreshRate.ps1:7-13`). Struct `DEVMODE` must be exactly 156 bytes ANSI — hard check at `Set-RefreshRate.ps1:81-85` (`SizeOf == 156` else `Write-Error` and `exit 1`). Earlier bug: spurious 2-byte padding field shifted struct to 158 bytes → `DISP_CHANGE_BADMODE (-2)` on valid modes — fixed by removing padding, note at `Set-RefreshRate.ps1:41-46`. Called by `display/change-refresh.lua:1` (`require './change-refresh'` shim). Flow: `EnumDisplaySettings(ENUM_CURRENT_SETTINGS=-1)` read current → overwrite `dmPelsWidth/Height/Frequency/BitsPerPel` + `dmFields` bitmask → `ChangeDisplaySettingsEx` with `CDS_UPDATEREGISTRY=0x01`. Exit codes: `0 success`, `1 restart_required`, `-1 DISP_CHANGE_FAILED`, `-2 DISP_CHANGE_BADMODE`.

---

## 5. HOW TO WORK ON THIS REPO (Agent Instructions)

### 5.1 Before Any Edit — Checklist
1. Read the file you're editing + this `AGENTS.md` + `README.md:1` + `.gitignore:1` + `.gitattributes:1`
2. Check `hdr-toys.conf:1` header if touching HDR — likely need to edit `mpv.conf:31` or `Update-MpvEnvironment.ps1:217-224` instead
3. Run `git status` — verify `portable_config/cache/`, `portable_config/tools/update-state.json`, `update-log.txt`, `mpv.exe`, `mpv.com` are NOT staged (all ignored). Never `git add -A` without checking.
4. Check `git lfs ls-files` if touching `portable_config/shaders/*.glsl` — ensure pointers not committed
5. Note hardware context (RTX 5080, Vulkan, 1440p) — don't break `vo=gpu-next` + `gpu-api=vulkan` for "generic" advice

### 5.2 Editing Configs Safely
- **mpv.conf:** Keep `profile-restore=copy` on every profile (`mpv.conf:75` etc.); keep absolute `C:/mpv/...` shader paths; keep `include` before profiles (`mpv.conf:31` must precede `[Res-SD]`); test profile conditions with `mpv --show-profile=<name>`. Keep `profile-cond` nil guards (`height~=nil and ...`). Keep `reset-on-next-file` list (`mpv.conf:53`) — removing entries leaks state across playlist.
- **input.conf:** Preserve `MBTN_RIGHT` (`input.conf:10`) + `MENU` (`input.conf:11`) bindings or uosc menu breaks (right-click shows nothing). `#!` comments are menu items — syntax is `command #! Menu > Path`. `change-list glsl-shaders del` on non-loaded shader is no-op (safe to list all 9 for `Alt+h` `input.conf:44`). Don't reorder `Alt+h` shader list without verifying all 4 hdr-toys profiles.
- **script-opts:** Each file documents upstream defaults inline — only intentional divergences are `observe_audio_switches=yes` (`sub_select.conf:7`), `auto=yes` (`changerefresh.conf:14`), `max_height/width=400` + `tone_mapping=mobius` (`thumbfast.conf:17-35`), NieR palette (`uosc.conf:88`) + `timeline_size=40 opacity=0.85` etc. Keep comments explaining why each diverges.
- **shaders:** Never hand-edit `hdr-toys/` — will be overwritten by daily updater. For top-level LFS shaders, ensure `git lfs install` + `git lfs pull` or you'll commit 130-byte pointer text. Don't add `hdr-toys/` to LFS.
- **scripts:** `uosc/` is vendored upstream — prefer `Update-MpvEnvironment.ps1:226-230` sync over hand patches; local patches to `display/change-refresh.lua` (Set-RefreshRate integration) are intentional and must be preserved. Shims (`display/main.lua` etc.) are intentionally tiny — don't inline them.

### 5.3 Testing Changes
```powershell
# 1. Syntax check without config
.\mpv.com --config=no --no-terminal -v 2>&1 | Select-String "error|warning"

# 2. Load full config and verify profiles/shaders
.\mpv.com --log-file=mpv-test.log some-file.mkv
# Check log for: "Loading config", "Applying profile", "GLSL", "uosc", "thumbfast"
# Profiles applied appear as "Applying profile 'Res-Fractional'" etc.

# 3. Check effective profile
.\mpv.com --show-profile=Res-Fractional --show-profile=Colorspace-BT709 --show-profile=bt.2100-pq

# 4. Check keybindings
.\mpv.com --input-test  # press keys, verify MBTN_RIGHT menu, Alt+d/h/n etc.

# 5. Verify scripts loaded (mpv console with ` key)
# mp.get_property("script-list")  -- should include uosc, thumbfast, change-refresh, autocrop etc.

# 6. Verify no binaries/cache staged
git status --porcelain | Select-String "mpv\.exe|mpv\.com|cache/|update-"

# 7. If touching Set-RefreshRate.ps1, verify DEVMODE size and test
powershell -File portable_config/tools/Set-RefreshRate.ps1 -Width 1920 -Height 1080 -Rate 60 -DeviceName '\\.\DISPLAY1'
# Must print "Current mode before change" and "SUCCESS" or fail cleanly with struct size check
```

- Always re-read edited region after `edit` before finalizing
- Keep `~~/` vs `C:/` handling consistent — only cache dirs use `~~/`

### 5.4 Common Tasks
| Task | How | Risk if wrong |
|------|-----|---------------|
| Change video output | Edit `mpv.conf:5-13`, keep `vo=gpu-next` + `gpu-api=vulkan` for RTX 5080 | `vo=gpu` or `opengl` breaks Vulkan async queues |
| Adjust upscaling | Edit `mpv.conf:72-106` profile blocks — `Res-*` conditions are height-based; test with SD/720p/1080p/1440p files | Overlap/gap in conditions (e.g., `height<700` vs `>=700`) leaves gap |
| Change HDR | Edit shader choice in `Update-MpvEnvironment.ps1:220` transforms or `mpv.conf` target-*; **not** `hdr-toys.conf` | Hand-edit lost on next update |
| Add keybind | Edit `input.conf` — add `KEY command #! Menu > Path` for uosc menu, or plain `KEY command` for hidden bind. Preserve `MBTN_RIGHT` | Without `#!` bind won't appear in menu; without `MBTN_RIGHT` menu empty |
| Update/clean shaders | Run `Update-MpvEnvironment.ps1` or `updater.bat`; never `git add` LFS pointer files | Committing pointer breaks shader for others |
| Change update schedule | Edit `Register-MpvAutoupdate.ps1:16` (Trigger Delay) or `:19` Settings then re-run it to re-register | Must re-run to apply; old task persists with old schedule |
| Fix thumbfast not updating | Check `Update-MpvEnvironment.ps1:233` and the top-level `portable_config/scripts/thumbfast.lua` destination | Updater must refresh the script in the location mpv scans |
| Change refresh rates | Edit `changerefresh.conf:10` rates — keep `165` in list | Removing 165 breaks revert to desktop native |
| Change sub lang priority | Edit `mpv.conf:39` slang/alang and `sub-select.json:1` | Must keep both in sync (mpv.conf vs sub-select json) |

### 5.5 Commit Style
- This repo uses short, conventional commits: `docs: ...`, `chore: ...`, `fix: ...` — see `git log --oneline -10`. Keep messages under ~72 chars.
- Don't create `plan` files under `.opencode/` unless configuring opencode itself (opencode skill: `customize-opencode`)
- Keep `installer/` and `mpv-register/unregister.bat` — they are part of the portable distribution
- Always `git status` before `git add` — verify no `portable_config/cache/` or `mpv.exe` in diff
- For shader changes, `git lfs install` before commit, `git lfs ls-files` after

---

## 6. GOTCHAS & HISTORICAL LESSONS (Read Before Debugging — saves hours)

1. **v3 asset missing (2026-08-27):** `zhongfly` release `2026-08-26-182fa6ca49` shipped no `x86_64-v3` asset — updater correctly waited one day rather than downgrading to baseline. Don't add fallback to plain `x86_64` in `Update-MpvEnvironment.ps1:94` — v3-only is intentional.
2. **hdr-toys hand-port fell behind:** Bottosson stayed loaded days after upstream switched default to jedypod — hence `include` + auto-sync instead of hand-ported profiles (`Update-MpvEnvironment.ps1:212` comment). Hand-porting drifts.
3. **hdr-toys `~~/` path failure:** `~~/shaders/hdr-toys/` sometimes doesn't resolve under portable — hence `C:/` absolute rewrite (`Update-MpvEnvironment.ps1:172,221`). Don't revert to `~~/`.
4. **DEVMODE padding bug:** Spurious 2-byte alignment field shifted struct to 158 bytes → `DISP_CHANGE_BADMODE (-2)` on valid modes — fixed by removing padding, added 156-byte hard check (`Set-RefreshRate.ps1:41-46,81-85`). If you edit DEVMODE, keep the byte-count comment and verify `SizeOf == 156`.
5. **Alt+h incomplete del (2026-08-25):** Originally del'd only 5 PQ shaders, left HLG/bt.2020/linear shaders active — fixed to del all 9 (`input.conf:44` + `hdr-toys.conf:11,23,34,43` 4 profiles). Must list all 9 unconditionally (del is no-op if not loaded).
6. **thumbfast `tone_mapping=auto` trap:** Picks up mpv's sentinel `tone-mapping` value literally when hdr-toys is active — hence `mobius` explicit (`thumbfast.conf:27-35`). `auto` would use `clip` placeholder from `hdr-toys.conf:8`, not real curve.
7. **Mutex race (2026-08-16):** Two logon triggers overlapped and raced on `$WorkDir` — hence `Global\mpv-autoupdate-lock` mutex (`Update-MpvEnvironment.ps1:202`) + `Register-MpvAutoupdate.ps1:19` `MultipleInstances IgnoreNew`. Don't remove either.
8. **changerefresh `165` must stay:** Script's revert logic requires desktop native rate in `rates` list (`changerefresh.conf:8-10` comment). User confirmed 165 is native 1440p rate — removing it breaks revert.
9. **Git LFS 130-byte files:** If `ArtCNN_C4F32.glsl:1` etc. read as `version https://git-lfs.github.com/spec/v1` pointer text, LFS isn't pulled — `git lfs pull`, don't commit pointers. Check with `git lfs ls-files` and `Get-Content ... -First 1`.
10. **thumbfast is a top-level script:** `portable_config/scripts/thumbfast.lua` is updated directly by `Update-MpvEnvironment.ps1:233` and is discovered by mpv's recursive script loader. Keep it at the top level; do not restore a nested loader shim.
11. **Profile condition overlap:** `Res-*` ranges use `height<700`, `700≤h<740`, `740≤h<1340`, `1340≤h<1440`, `h≥1440` — exact 740 boundary matters for 720p vs 1080p. Changing one without adjusting neighbor creates gap/overlap where no profile applies.
12. **Settings.xml `getytdl=false`:** Means yt-dlp disabled in legacy updater (`installer/updater.ps1:490`). Don't flip to `ytdlp` without also setting `ytdlpchannel` — updater will prompt interactively (9s timeout) and may stall under Scheduled Task hidden window.

---

## 7. REFERENCE: External Sources

| Component | Upstream | Local path | Sync method |
|-----------|----------|------------|-------------|
| mpv | [mpv.io](https://mpv.io) / [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild) | `mpv.exe` (122 MB), `installer/updater.ps1` | `updater.bat` + `Update-MpvEnvironment.ps1` API + 7z |
| uosc | [tomasklaen/uosc](https://github.com/tomasklaen/uosc) | `portable_config/scripts/uosc/` (43 KB + 40 modules) + `fonts/uosc_*` | `Update-MpvEnvironment.ps1:226` via commit SHA → codeload zip |
| thumbfast | [po5/thumbfast](https://github.com/po5/thumbfast) | `portable_config/scripts/thumbfast.lua` (32 KB) | `Update-MpvEnvironment.ps1:233` |
| hdr-toys | [natural-harmonia-gropius/hdr-toys](https://github.com/natural-harmonia-gropius/hdr-toys) | `portable_config/shaders/hdr-toys/` (77 files, 298 KB) + `hdr-toys.conf:1` | `Update-MpvEnvironment.ps1:217` with 2 transforms |
| skip_intro | [Chinna95P/mpv-anime-build](https://github.com/Chinna95P/mpv-anime-build/blob/main/scripts/skip_intro.lua) | `portable_config/scripts/media/skip_intro.lua` (6 KB) | Manual vendored |
| sub-select | [CogentRedTester/mpv-sub-select](https://github.com/CogentRedTester/mpv-sub-select) | `portable_config/scripts/media/sub-select.lua` (14 KB) + `script-opts/sub_select.conf` + `sub-select.json` | Manual vendored |
| autocrop | [kevmitch/mpv-autocrop](https://github.com/kevmitch/mpv-autocrop) | `portable_config/scripts/utilities/autocrop.lua` (9 KB) | Manual |
| autodeint | [mpv-player/mpv](https://github.com/mpv-player/mpv) | `portable_config/scripts/utilities/autodeint.lua` (5 KB) | Manual |
| change-refresh | custom (CogentRedTester base + Set-RefreshRate) | `portable_config/scripts/display/change-refresh.lua` (22 KB) + `tools/Set-RefreshRate.ps1` | Local custom |
| mpvSockets | [Chinna95P/mpv-anime-build](https://github.com/Chinna95P/mpv-anime-build/blob/main/scripts/mpvSockets.lua) | `portable_config/scripts/utilities/mpvSockets.lua` (1373 bytes) | Manual, per-PID pipe |
| ArtCNN | [Artoriuz/ArtCNN](https://github.com/Artoriuz/ArtCNN) | `portable_config/shaders/ArtCNN_C4F32.glsl` (LFS pointer 131b) | Git LFS |
| ravu | [bjin/mpv-prescalers](https://github.com/bjin/mpv-prescalers) | `portable_config/shaders/ravu-zoom-ar-r3.hook` (132b) | Git LFS |
| nlmeans | [AN3223/dotfiles](https://github.com/AN3223/dotfiles) | `portable_config/shaders/nlmeans.glsl` (130b) | Git LFS |
| CfL | — | `portable_config/shaders/CfL_Prediction.glsl` (130b) | Git LFS |

---

## 8. GIT OPERATIONS

```powershell
cd "C:\mpv"
git status                    # verify no cache/binaries staged — must show only intended files
git diff                      # review changes, especially mpv.conf/input.conf/script-opts
git diff --staged             # if you already added
git log --oneline -10         # commit style reference: "docs: ...", "chore: ..."

# stage only what you intend — never `git add -A` blind
git add portable_config/mpv.conf portable_config/input.conf
git commit -m "fix: description"
git push

# LFS (required for shaders)
git lfs install               # once per machine
git lfs pull                  # fetch real shader blobs after clone
git lfs ls-files              # verify 4 shaders are LFS objects, not pointers
git lfs status
```

- Remote: `https://github.com/AnxoSilvaSixto/mpv-config.git`
- When referencing code, use `file_path:line_number` (e.g., `portable_config/mpv.conf:31`, `tools/Set-RefreshRate.ps1:82`)
- `.gitignore:4-11` ignores `mpv.exe`, `mpv.com`, `portable_config/cache/`, `tools/update-state.json`, `update-log.txt` — never force-add them
- `.gitattributes:2-3` tracks `portable_config/shaders/*.glsl` + `*.hook` via LFS — keep `hdr-toys/` out of LFS

---

## 9. AGENT VERIFICATION CHECKLIST (Run Before Finalizing Any Change)

- [ ] `git status` shows no `mpv.exe`, `mpv.com`, `cache/`, `update-state.json`, `update-log.txt`
- [ ] If edited `mpv.conf`, ran `mpv --show-profile=*` and checked profile conditions don't overlap/gap
- [ ] If edited `input.conf`, verified `MBTN_RIGHT` + `MENU` still bound to `uosc/menu` and `#!` menu comments intact
- [ ] If edited `hdr-toys.conf` — STOP, revert, edit `mpv.conf` or `Update-MpvEnvironment.ps1:217-224` instead
- [ ] If touched `Set-RefreshRate.ps1`, verified DEVMODE `SizeOf == 156` comment still accurate
- [ ] If touched shaders, verified `git lfs ls-files` and not committing pointer text
- [ ] If touched `thumbfast.conf`, confirmed `tone_mapping=mobius` not `auto`
- [ ] If touched `changerefresh.conf`, confirmed `165` still in `rates`
- [ ] Ran `mpv.com --config=no --no-terminal -v` smoke test if config syntax changed
- [ ] Updated this file's `Last updated` line below if file counts/lines changed

---

*Last updated: 2026-08-31 — synced with `Update-MpvEnvironment.ps1:263`, `installer/updater.ps1:796`, `mpv.conf:141`, `hdr-toys.conf:59`, `input.conf:51`, `uosc.conf:102`, `thumbfast.conf:72`, `changerefresh.conf:43`, `sub_select.conf:14`, `Set-RefreshRate.ps1:124`, `Register-MpvAutoupdate.ps1:27`, `updater.bat:24`, `settings.xml:8`, `mpv/fonts.conf:103`, shaders 77 files/298 KB, thumbfast 32 KB, uosc 43 KB+*
