# mpv Config — Project Guidelines

**ALWAYS read this file before making changes to the mpv configuration.**

The mpv portable config is located at: `C:\mpv`

---

## 1. Directory Structure

```
C:\mpv\
├── portable_config/
│   ├── mpv.conf              → Main mpv configuration
│   ├── input.conf            → Keybindings
│   ├── scripts/              → Lua scripts (uosc, thumbfast, etc.)
│   ├── script-opts/          → Script configuration files
│   ├── shaders/              → GLSL shaders (hdr-toys, etc.)
│   ├── fonts/                → Custom fonts for uosc
│   └── tools/                → Auto-update scripts
├── doc/                      → mpv documentation
├── installer/                → Updater scripts
├── mpv.exe / mpv.com         → mpv binaries (ignored in git)
├── settings.xml              → Portable settings
├── updater.bat               → Auto-updater batch file
└── .gitignore
```

## 2. ABSOLUTE RULES

### 2.1 Never Commit Binaries
- **NEVER** commit `mpv.exe` or `mpv.com`
- These are managed by the auto-updater (`updater.bat`)
- They're in `.gitignore`

### 2.2 Never Commit Cache
- **NEVER** commit files in `portable_config/cache/`
- Cache is auto-generated (shader cache, etc.)
- It's in `.gitignore`

### 2.3 Preserve Existing Config Structure
- Don't rename `portable_config/` — mpv portable expects this name
- Don't remove `updater.bat` or `installer/` — they handle mpv updates
- Keep `mpv-register.bat` and `mpv-unregister.bat` for system integration

### 2.4 Always Test Config Changes
- Before committing config changes, test with: `.\mpv.com --config=no` then `.\mpv.com`
- Verify scripts load without errors
- Check that keybindings work as expected

---

## 3. KEY FILES

| File | Purpose |
|------|---------|
| `portable_config/mpv.conf` | Main config (video/audio/output settings) |
| `portable_config/input.conf` | Keybindings |
| `portable_config/scripts/uosc/` | uosc UI script (main player interface) |
| `portable_config/scripts/media/thumbfast.lua` | Thumbnail preview script |
| `portable_config/shaders/hdr-toys/` | HDR tone-mapping shaders |

## 4. SCRIPTS

- `updater.bat` — Downloads latest mpv build
- `installer/updater.ps1` — PowerShell updater logic
- `portable_config/tools/Register-MpvAutoupdate.ps1` — Auto-update registration

## 5. GIT OPERATIONS

```powershell
cd "C:\mpv"
git add -A
git commit -m "description"
git push
```

---

*Last updated: 2026-08-31*
