-- skip_intro.lua v2.2 (Performance Fix - Cached Chapters)
-- Detects OP/ED/PV/Intro-type chapters by title pattern and shows a clickable
-- "SKIP <label>" button (or press Enter) to jump to the next chapter.
-- Source: https://github.com/Chinna95P/mpv-anime-build/blob/main/scripts/skip_intro.lua
-- Thanks to Chinna95P

local opts = {
    enabled = true,
    timeout = 6,        -- seconds the skip button stays visible once a matching chapter starts
    skip_key = "ENTER",
}
(require "mp.options").read_options(opts)

local msg = require "mp.msg"

-- Category -> list of lua-pattern / substring matches (case-insensitive), and the
-- on-screen label + button color (ASS &HBBGGRR& order) shown for that category.
local categories = {
    {
        name = "Opening",
        keys = {"opening", "op ", "♪ op", "♪op", "^op$", "op%d", "theme song", "main theme",
                "オープニング", "オープニングテーマ", "OPテーマ", "主題歌",
                "ncop", "creditless op", "creditless opening"},
        color = "abc2c9", -- Light warm beige (matches chapter_ranges "openings", NieR palette)
    },
    {
        name = "Ending",
        keys = {"ending", "ed ", "♪ ed", "♪ed", "^ed$", "ed%d", "credits", "outro", "end roll",
                "エンディング", "エンディングテーマ", "EDテーマ", "結び",
                "nced", "creditless ed", "creditless ending"},
        color = "6a8faf", -- Warm tan (matches chapter_ranges "endings", NieR palette)
    },
    {
        name = "Preview",
        keys = {"preview", "pv ", "^pv$", "pv%d", "trailer", "next episode",
                "予告", "次回予告", "特報", "プロモーション", "jikai", "yokoku"},
        color = "48628a", -- Warm brown (matches chapter_ranges "outros", NieR palette)
    },
    {
        name = "Intro",
        keys = {"intro", "introduction", "prologue", "cold open",
                "アバン", "アバンタイトル", "序章", "前説"},
        color = "3f5a9c", -- Muted rust accent (matches chapter_ranges "intros", NieR palette)
    },
}

local enabled = opts.enabled
local chapters_cache = nil
local active_chapter_index = nil
local active_category = nil
local button_visible = false
local skip_timer = nil

local function get_chapters()
    -- Cached per file-load instead of re-fetched every tick (perf fix noted in the version tag).
    if chapters_cache == nil then
        chapters_cache = mp.get_property_native("chapter-list") or {}
    end
    return chapters_cache
end

local function match_category(title)
    if not title then return nil end
    local lower = title:lower()
    for _, cat in ipairs(categories) do
        for _, key in ipairs(cat.keys) do
            -- Simplified 2026-08-23: the old pcall-in-`or` here always evaluated true (Lua
            -- truncates a multi-return pcall used inside `or` to just its first value -- "did it
            -- error", not the match result), so this outer check did nothing but redundant work.
            if lower:find(key:lower()) then
                return cat
            end
        end
    end
    return nil
end

local function current_chapter_index()
    local chapters = get_chapters()
    local pos = mp.get_property_number("playback-time")
    if not pos or #chapters == 0 then return nil end
    local idx = nil
    for i, ch in ipairs(chapters) do
        if ch.time <= pos then
            idx = i
        else
            break
        end
    end
    return idx
end

local function hide_button()
    if button_visible then
        mp.set_osd_ass(1920, 1080, "")
        button_visible = false
    end
    if skip_timer then
        skip_timer:kill()
        skip_timer = nil
    end
    mp.remove_key_binding("skip_intro-enter")
end

local function draw_button(label)
    local ass = string.format(
        "{\\an3\\bord2\\shad1\\c&H%s&\\alpha&H20&}SKIP %s ▶",
        active_category.color, label:upper())
    -- Bottom-right corner button on a virtual 1920x1080 canvas (scales with actual output res).
    mp.set_osd_ass(1920, 1080,
        string.format("{\\pos(1650,980)}%s", ass))
    button_visible = true
end

local function do_skip()
    mp.command("no-osd add chapter 1")
    hide_button()
end

local function check_mouse_hover()
    local mx, my = mp.get_mouse_pos()
    local scale_x = 1920 / mp.get_property_number("osd-width", 1920)
    local scale_y = 1080 / mp.get_property_number("osd-height", 1080)
    local bx, by = mx * scale_x, my * scale_y
    if bx >= 1550 and bx <= 1900 and by >= 950 and by <= 1010 then
        do_skip()
    end
end

local function on_tick()
    if not enabled then return end
    local idx = current_chapter_index()
    if idx == nil then
        if button_visible then hide_button() end
        active_chapter_index = nil
        return
    end

    if idx ~= active_chapter_index then
        active_chapter_index = idx
        local chapters = get_chapters()
        local title = chapters[idx] and chapters[idx].title
        active_category = match_category(title)

        if active_category then
            draw_button(active_category.name)
            mp.add_forced_key_binding(opts.skip_key, "skip_intro-enter", do_skip)
            if skip_timer then skip_timer:kill() end
            skip_timer = mp.add_timeout(opts.timeout, hide_button)
        else
            if button_visible then hide_button() end
        end
    end
end

mp.register_script_message("toggle-state", function(state)
    if state == "yes" then
        enabled = true
    elseif state == "no" then
        enabled = false
        hide_button()
    else
        enabled = not enabled
        if not enabled then hide_button() end
    end
end)

-- 0.1 -> 0.25: still 4 checks/second against a 6-second button window, imperceptible either way,
-- but 60% fewer wake-ups over the runtime of every file.
mp.add_periodic_timer(0.25, on_tick)
mp.register_event("file-loaded", function()
    chapters_cache = nil
    active_chapter_index = nil
end)
mp.register_event("end-file", hide_button)
mp.add_key_binding(nil, "skip_intro-click", check_mouse_hover, {complex = true})
