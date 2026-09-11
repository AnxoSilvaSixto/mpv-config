# mpv Config — Project Guidelines

**ALWAYS read this file before making changes. This is a portable `mpv` config at `C:\mpv`.**

> Hardware context: Tuned for **RTX 5080 + Vulkan + 1440p 165 Hz + Zen 3 x86_64-v3** (Ryzen 7 5700X). Config is **SDR-only, faithful reconstruction of source, no stylization**. Use as reference — adjust for other hardware. All paths assume `C:\mpv` as root.

Paths shown use `C:\mpv` as an example — the actual root is auto-derived from wherever you place this folder.

---

## 1. Directory Structure

```
C:\mpv\
├── portable_config/              # mpv portable requires EXACTLY this name — never rename; must stay beside mpv.exe
│   ├── mpv.conf                  # main config (vo=gpu-next/Vulkan, profiles, HDR include)
│   ├── hdr-toys.conf             # AUTO-MANAGED by Update-MpvEnvironment.ps1 — never edit directly
│   ├── input.conf                # custom bindings only; uosc handles rest
│   ├── scripts/
│   │   ├── hdr-toggle.lua        # native tone-mapping fallback (Alt+h)
│   │   ├── auto-save-state.lua   # watch-later every 1s (owned locally, frozen; upstream kept as link only)
│   │   ├── track-selector.lua    # commentary-safe select (Chinna95P, es dub patch)
│   │   ├── thumbfast.lua         # top-level thumbfast (po5) — required for uosc thumbnails
│   │   ├── uosc/                 # UI (tomasklaen/uosc) — main.lua + elements/lib/intl/char-conv
│   │   ├── media/                # bundle loader + 5 handlers: skip_intro, sub-select (DISABLED), betterchapters, fix-sub-timing, Up_Next
│   │   ├── display/              # change-refresh.lua + loader shim
│   │   └── utilities/            # autocrop, autodeint, mpvSockets + bundle shim
│   ├── script-opts/
│   │   ├── uosc.conf             # NieR:Automata palette, floating bar
│   │   ├── thumbfast.conf        # 400×400, mobius, hwdec=yes
│   │   ├── changerefresh.conf    # rates include 165 (native), auto=yes
│   │   ├── sub_select.conf / sub-select.json  # Spanish-first fallback
│   │   └── ...
│   ├── shaders/
│   │   ├── hdr-toys/             # 77 files, ~300 KB plain text (NOT LFS)
│   │   ├── SSimSuperRes.glsl / SSimDownscaler.glsl  # plain text, 5-6 KB (NOT LFS)
│   │   ├── ArtCNN_C4F32.glsl / CfL_Prediction.glsl / nlmeans.glsl / ravu-zoom-ar-r4.hook  # Git LFS
│   │   └── ...
│   ├── fonts/                    # uosc_icons.ttf + uosc_textures.ttf (ttf only)
│   │                                # .otf removed (Apr 2024) — keep ttf only, never re-add .otf
│   ├── tools/
│   │   ├── Update-MpvEnvironment.ps1  # preferred daily updater
│   │   ├── Audit-MpvEnvironment.ps1   # read-only validation
│   │   ├── Register-MpvAutoupdate.ps1 # logon task registration
│   │   └── Set-RefreshRate.ps1        # Win32 display helper
│   └── cache/                    # shader cache + watch_later — ignored, auto-generated
├── updater.bat                   # primary entry → portable_config/tools/Update-MpvEnvironment.ps1
├── mpv.exe / mpv.com             # ignored binaries (managed by updater)
└── README.md / AGENTS.md / .gitignore / .gitattributes
```

**Critical:** No `C:\mpv\shaders\` at root. Keep portable `~~/` paths in mpv.conf/input.conf/shader appends (only cache dirs are known-safe for `~~/`; hdr-toys paths stay `~~/` after updater).

---

## 2. Essential Rules

- **Never commit binaries:** `mpv.exe`/`mpv.com` are ignored, managed by updater.
- **Never commit cache/state/logs:** `portable_config/cache/`, `tools/update-state.json`, `tools/update-log.txt`, `track-selector-overrides.json` are ignored. Updater rotates cache (>30d shaders, >7d watch_later) and log (>500 lines).
- **Never edit `hdr-toys.conf`:** auto-managed; customize via `mpv.conf` profiles or `Update-MpvEnvironment.ps1` transforms (jedypod mapping). Edits are lost on next sync.
- **Preserve portable structure:** don't rename `portable_config/`, don't remove `updater.bat`/`mpv-register.bat`, keep `~~/` shader paths.
- **Bundle shims stay:** `display/main.lua`, `utilities/main.lua`, `media/main.lua` are `require` re-exports that group scripts per folder. `mpvSockets.lua` is real IPC logic (per-PID pipe), not a shim. `thumbfast.lua` must stay top-level (`scripts/thumbfast.lua`), not nested.

---

## 3. Git LFS

- **LFS (4 files):** `ArtCNN_C4F32.glsl`, `CfL_Prediction.glsl`, `nlmeans.glsl`, `ravu-zoom-ar-r4.hook` — `.gitattributes` tracks `ArtCNN*`/`CfL*`/`nlmeans*`/`ravu*.hook`.
- **Plain text:** `SSimSuperRes.glsl` / `SSimDownscaler.glsl` (5-6 KB) and entire `hdr-toys/` (~300 KB) stay plain text — never add to LFS.
- Without `git lfs pull`, LFS files read as `version https://git-lfs.github.com/spec/v1` pointer text. Run `git lfs install && git lfs pull` after clone. Never `git add` a pointer.

---

## 4. Updaters

| Entry | Purpose | Touches |
|-------|---------|---------|
| `updater.bat` → `portable_config/tools/Update-MpvEnvironment.ps1` | **sole updater** (mpv + hdr-toys + uosc + thumbfast + animebuild scripts) | `mpv.exe`, `shaders/hdr-toys/`, `hdr-toys.conf`, `scripts/uosc/`, `fonts/`, `scripts/thumbfast.lua` |
> The sole updater is `updater.bat` → `Update-MpvEnvironment.ps1`.

- `Update-MpvEnvironment.ps1` is safe to run every login; unchanged day = API checks only, state in `tools/update-state.json` (ignored). Never touches `mpv.conf`/`input.conf`/`script-opts/`.
- Vendored-file local patches live as updater post-process blocks (track-selector es-dub guard, uosc icon family, launcher tweaks); auto-save-state.lua is frozen locally and no longer synced.
- mpv asset is **x86_64-v3 only** (Zen 3); if no v3 asset exists in a release, updater waits — no silent fallback to baseline.
- Scheduled task: `Register-MpvAutoupdate.ps1` registers `mpv-autoupdate` (AtLogOn + 1 min delay, mutex `Global\mpv-autoupdate-lock` prevents overlap).
- Updater arch is hard-coded to x86_64-v3 in the script (no settings file).

---

## 5. Key Config Notes

- **mpv.conf:** `vo=gpu-next` + `gpu-api=vulkan`, `hwdec=auto-safe`, `profile=high-quality`, `target` colorspace via profiles. All `Res-*` profiles use `profile-restore=copy` and nil-guarded `height` conditions; `include` for `hdr-toys.conf` must stay before any profile. Res profiles: SD (<700) → ravu/CfL/SSim, 720p 2× (700–739) → ArtCNN/CfL/SSim, fractional (740–1339) → ravu/CfL/SSim, near-native (1340–1439) → CfL/SSim, downscale (≥1440) → CfL/SSim + ewa_lanczos. Colorspace: BT.709/NTSC/PAL/gray + `[ending]` with `get("duration",0)>0` guard to avoid idle save; `[ending]` and auto-save-state.lua co-own save-position-on-quit (script freezes entry writes in the last 60s, profile forces no — verified by test-session).
- **HDR is local choice, not proof:** Windows/monitor path may still be SDR — test real HDR content separately. `hdr-toys` tone-mapping is optional tuning, `Alt+h` restores native.
- **input.conf:** Preserve `MBTN_RIGHT` + `MENU` → `uosc/menu` or right-click menu breaks. `#!` comments define menu paths. `Alt+h` is now `script-binding hdr-toggle` (filters any `hdr-toys` shader, reload file to restore). `Alt+d` toggles deband, `Alt+n`/`Alt+Shift+n` prepend/remove `nlmeans.glsl` (denoise before upscale).
- **script-opts:** `uosc.conf` — **NieR:Automata palette** (`foreground=e8dcc7/background=3a3528/curtain=c8c2aa/success=6a9f3e/error=c44536/match=c9944b`, `opacity 0.85`, `scale 1.2/1.56`, `timeline_size 40`, `chapter_ranges` with multilingual patterns, `autoload=no`, `languages=en` (UI pinned English; mpv.conf slang track prefs untouched), icon family `Material Symbols Rounded` (must match fonts/uosc_icons.ttf or ligatures render as raw text)). `thumbfast.conf` — `max 400×400`, `tone_mapping=mobius` (not `auto`), `hwdec=yes`, `overlay_id=42`. `changerefresh.conf` — `rates` must keep `165` (plus `144` for 24fps×6), `auto=yes`, `original_width/height/rate` for revert; findValidRate prefers even multiples (24→144, 25→50, 29.97→60) over closest-match.
- **shaders/scripts:** Never hand-edit `hdr-toys/`; SSim shaders use LFS-free plain text. uosc/thumbfast are vendored via updater — local patches only for `display/change-refresh.lua` (Set-RefreshRate integration; helper resolves from its own dir, CWD-independent). track-selector.lua ignores aid/sid changes with no active playback (EOF-teardown guard); auto-save-state.lua freezes saves in `[ending]`'s last 60s.

---

## 6. How to Work (Agent Instructions)

**One-at-a-time fix rule:** land one fix per iteration, verify before the next.

1. Read this file + target file + `README.md` + `.gitignore` + `.gitattributes`.
2. `git status` — ensure cache/binaries/state not staged; never `git add -A` blind.
3. Make the minimal edit.
4. Verify per fix:
   - `powershell -File portable_config/tools/Audit-MpvEnvironment.ps1` → 0 errors, 0 warnings (after `git lfs pull`)
   - `mpv.com --config-dir=portable_config --idle=once --force-window=no --no-terminal --log-file=$env:TEMP\mpv-test.log` → log has **shaderc 0 errors**, no `lua error`/`[e]`/`[fatal]`, profiles load
   - Check `mpv-test.log` for `Done loading scripts`, `Applying profile`, and `GLSL` without error markers
   - `git status --porcelain` shows only intended files (no `cache/`, `mpv.exe`, `update-state.json`)
5. Re-read edited region, then stage only intended files.

```powershell
.\mpv.com --config=no --no-terminal -v 2>&1 | Select-String "error|warning"
.\mpv.com --log-file=mpv-test.log some-file.mkv  # check: "Applying profile", "GLSL", no errors
.\mpv.com --show-profile=Res-Fractional --show-profile=Colorspace-BT709
git status --porcelain | Select-String "mpv\.exe|mpv\.com|cache/|update-"
```

- Keep `profile-restore=copy`, `~~/` paths, nil guards, and `reset-on-next-file` intact.
- `change-list glsl-shaders del` on non-loaded shader is a harmless no-op.

---

## 7. Gotchas (Saves Hours)

1. **v3 asset missing:** some `zhongfly` releases lack `x86_64-v3` — updater waits a day, don't add baseline fallback.
2. **hdr-toys drifts if hand-ported:** upstream switched bottosson→jedypod silently — always sync via updater, never hand-edit `hdr-toys.conf`.
3. **hdr-toys `~~/` vs absolute:** updater keeps `~~/` portable paths with jedypod transform — don't hard-code `C:/mpv` in generated output.
4. **DEVMODE struct is exactly 156 bytes:** `Set-RefreshRate.ps1` will fail with `DISP_CHANGE_BADMODE` if padded — it has a hard size check.
5. **Thumbfast must stay top-level:** `scripts/thumbfast.lua` is discovered directly by mpv and updated there by `Update-MpvEnvironment.ps1`; don't nest it or add a loader shim.
6. **Rates must keep 165:** `changerefresh.conf` revert logic requires native desktop rate in list.

---

## 8. Sources & Git

- Upstreams: [mpv](https://mpv.io) / [zhongfly/mpv-winbuild](https://github.com/zhongfly/mpv-winbuild), [uosc](https://github.com/tomasklaen/uosc), [thumbfast](https://github.com/po5/thumbfast), [hdr-toys](https://github.com/natural-harmonia-gropius/hdr-toys), [ArtCNN](https://github.com/Artoriuz/ArtCNN), [ravu](https://github.com/bjin/mpv-prescalers), [track-selector](https://github.com/Chinna95P/mpv-anime-build), [auto-save-state](https://github.com/popeyeurs/ulyssescaballes-mpv.config) (link only, frozen), SSim (Shiandow via Chinna95P).
- Commits: `docs:`/`chore:`/`fix:` style, ~72 chars. Don't create `plan` files under `.opencode/`.
- Docs budget: keep `AGENTS.md` <200 lines and `README.md` concise — remove stale refs and duplicate narration.

```powershell
cd "C:\mpv"
git status; git diff; git log --oneline -10
git add portable_config/mpv.conf portable_config/input.conf   # stage only intended
git lfs install; git lfs pull; git lfs ls-files               # for shaders
```

Last updated: 2026-09-09 — slimmed to ~180 lines; synced with mpv.conf 160, input.conf 67, hdr-toys auto-managed, fonts ttf-only, hdr-toggle.lua, SSim plain-text, LFS = ArtCNN/CfL/nlmeans/ravu.
