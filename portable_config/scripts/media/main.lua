-- Media scripts bundle entry point
-- thumbfast is a top-level script (portable_config/scripts/thumbfast.lua).
-- skip_intro: OP/ED/chapter skip
require './skip_intro'
-- sub-select: DISABLED in favor of track-selector.lua (commentary-safe, SDH fallback)
-- track-selector.lua (top-level scripts/track-selector.lua) now handles selection:
--   - respects slang/alang (es> en> ja) from mpv.conf
--   - skips commentary, prefers clean over SDH, falls back to SDH if needed
--   - preserves es dub -> no subs rule (patched)
--   - persists per-video manual overrides
-- keep sub-select.lua file for reference, but not loaded
-- require './sub-select'
-- betterchapters: chapter-next/prev with playlist fall-through at ends
require './betterchapters'
-- fix-sub-timing: two-point sub-delay/sub-speed solver (mark two synced points)
require './fix-sub-timing'
-- Up_Next: end-of-file next-episode card with filename-priority title cleanup
require './Up_Next'
