-- =================================================================================
-- MPV-PC: "UP NEXT" INTERACTIVE (v2.5 - Filename Priority + Advanced Parser)
-- =================================================================================
-- LOCAL DIVERGENCES (intentional, do not "sync" away -- styling only, card logic
-- and trigger_time identical to upstream):
--   * Card colors follow the repo NieR:Automata identity (uosc.conf:88
--     color=foreground/background/match/heatmap/curtain) converted RGB -> ASS
--     &HBBGGRR& order, consistent with skip_intro's NieR button palette:
--       text_color   upstream FFFF00 -> c7dce8 (warm beige, uosc e8dcc7)
--       accent_color upstream 50FF50 -> 4b94c9 (amber accent, uosc match c9944b)
--       hover_color  upstream 00FFFF -> 3e94b8 (warm gold, uosc heatmap b8943e)
--       bg_color     upstream 000000 -> 28353a (dark brown panel, uosc 3a3528)
--       label gray   AAAAAA -> aac2c8 (mid beige, uosc curtain c8c2aa)
--       episode gray BBBBBB -> c7dce8 (warm beige, uosc e8dcc7)
--     bg_opacity 80 and trigger_time 10 kept verbatim from upstream.
--   * FIX7 NieR identity unification (styling only, zero behavior change):
--     hover_color 3e94b8 (uosc heatmap b8943e) is the documented shared hover
--     with skip_intro (whose cyan FFFF00 was aligned to this value); fn Source
--     Sans Pro tag dropped here AND in skip_intro.lua (font not vendored in
--     portable_config/fonts, tag was a fallback no-op); chrome aligned to the
--     shared panel line (was bord8/shad8/blur8, now bord4/shad2/blur4 + black
--     4c shadow; panel 3c/3a kept live via bg_color/bg_opacity).
-- Upstream: https://github.com/Chinna95P/mpv-anime-build/blob/main/scripts/Up_Next.lua
-- Thanks to Chinna95P

local mp = require 'mp'

local opts = {
    enabled      = true,
    trigger_time = 10,
    wrap_limit   = 24,
    text_color   = "c7dce8",
    accent_color = "4b94c9",
    hover_color  = "3e94b8",
    bg_color     = "28353a",
    bg_opacity   = "80",
}

local state = {
    is_visible = false,
    mouse_bound = false,
    next_filename = nil,
    next_title = nil
}

-- [1] CLEANER FUNCTION (Upgraded with Filename Priority & Release Group Logic)
function get_smart_details(filename, title)
    local display = nil

    -- 1. Top Priority: Use the Filename
    if filename and filename ~= "" then
        display = filename:match("([^/\\]+)$") or filename
    end

    -- 2. Fallback: Use Embedded Title ONLY if filename is missing/empty
    if (not display or display == "") and title and title ~= "" then
        display = title
    end

    if display then
        -- 1. Remove the file extension first
        display = display:gsub("%.%w+$", "")

        -- 2. KAHARI LOGIC: Remove prefix release group e.g., "[Erai-raws] "
        display = display:gsub("^%[%s*.-%s*%]%s*", "")

        -- 3. Move bracket/parenthesis cleanup to the TOP so tags aren't left fragmented
        display = display:gsub("%b[]", "")
        display = display:gsub("%b()", "")

        -- 4. Standard metadata cleanup
        display = display:gsub("[%s._-][0-9]*[pP][%s._-]", " ")
        display = display:gsub("[%s._-][0-9]*[kK][%s._-]", " ")
        display = display:gsub("[%s._-][xX][2]6[45]", " ")
        display = display:gsub("[%s._-][hH][2]6[45]", " ")
        display = display:gsub("[%s._-][hH][eE][vV][cC]", " ")
        display = display:gsub("[%s._-][aA][vV]1", " ")
        display = display:gsub("[%s._-][fF][lL][aA][cC][%w%.]*", " ")
        display = display:gsub("[%s._-][aA][aA][cC][%w%.]*", " ")
        display = display:gsub("[%s._-][dD][dD][pP]?[%w%.]*", " ")
        display = display:gsub("[%s._-][aA][cC]3", " ")
        display = display:gsub("[%s._-][dD][tT][sS]", " ")
        display = display:gsub("[%s._-][tT][rR][uU][eE][hH][dD]", " ")
        display = display:gsub("[%s._-][bB]lu[rR]ay", " ")
        display = display:gsub("[%s._-][bB][dD][rR][iI][pP]", " ")
        display = display:gsub("[%s._-][wW][eE][bB].*", "")
        display = display:gsub("[%s._-][hH][dD][tT][vV]", " ")
        display = display:gsub("[%s._-][0-9]+[%s-]*[bB]it", " ")

        -- Replace remaining dots/underscores with spaces (leaving dashes intact for the suffix rule)
        display = display:gsub("[._]", " ")

        -- 5. KAHARI LOGIC: Remove suffix release groups e.g., "-YURASUKA" or "-SubsPlease"
        display = display:gsub("%s*%-[A-Za-z0-9_]+%s*$", "")

        -- Remove any hanging dashes left from the cleanup
        display = display:gsub("%-$", "")
    end

    if display then
        -- Final trim of multiple spaces and leading/trailing spaces
        display = display:gsub("^%s+", ""):gsub("%s+$", "")
        display = display:gsub("%s+", " ")
    else
        display = "Unknown"
    end

    -- Split name and episode (assuming "Name - Episode" format)
    local name, ep = display:match("^(.*)%s+-%s+(.*)$")
    return name or display, ep or ""
end

function smart_wrap(text, limit)
    if not text or string.len(text) <= limit then return text end
    local result = ""
    local remaining = text

    -- Keep wrapping as long as the remaining text is longer than our limit
    while string.len(remaining) > limit do
        -- Grab a chunk slightly larger than the limit to find the best space
        local chunk = string.sub(remaining, 1, limit + 5)
        local break_pos = string.match(chunk, ".*%s()")

        if break_pos and break_pos > 1 then
            -- Break at the last found space
            result = result .. string.sub(remaining, 1, break_pos - 2) .. "\\N"
            remaining = string.sub(remaining, break_pos)
        else
            -- If it's one massive word with no spaces, force a break at the limit
            result = result .. string.sub(remaining, 1, limit) .. "\\N"
            remaining = string.sub(remaining, limit + 1)
        end
    end

    -- Append whatever is left over
    return result .. remaining
end

local function paint(ass_text)
    mp.set_osd_ass(1920, 1080, ass_text)
end

local function check_mouse_hover()
    local mx, my = mp.get_mouse_pos()
    local osd_w, osd_h = mp.get_osd_size()
    if not osd_w or osd_w == 0 then return false end
    local scale_x = 1920 / osd_w
    local scale_y = 1080 / osd_h
    local tx, ty = mx * scale_x, my * scale_y
    if tx > 1450 and tx < 1850 and ty > 780 and ty < 920 then return true end
    return false
end

-- FIX7 shared NieR OSD chrome: same panel line as skip_intro.lua draw_button
-- (bord4/shad2/blur4, 3c = bg_color 28353a = uosc background, 3a = bg_opacity
-- 80, 4c black added). Title fs40/b1 matches skip_intro button role; x=1650
-- shared, cy=850 stacks above skip_intro cy=980 by design. No fn tag (header).
-- Hover = heatmap gold 3e94b8, identical to skip_intro hover.
local function draw_ui(seconds, show_name, show_ep, is_hovering)
    local cx, cy = 1650, 850
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    ass = ass .. "{\\fs35}{\\b1}"
    ass = ass .. "{\\bord4}{\\shad2}{\\blur4}{\\3c&H" .. opts.bg_color .. "&}{\\3a&H" .. opts.bg_opacity .. "&}{\\4c&H000000&}"

    local main_c = is_hovering and opts.hover_color or opts.text_color
    local acc_c  = is_hovering and opts.hover_color or opts.accent_color

    ass = ass .. "{\\1c&H" .. acc_c .. "&}▶ {\\1c&Haac2c8&}{\\fs25}UP NEXT {\\1c&H" .. acc_c .. "&}(" .. seconds .. "s)"

    -- Wrap the main title
    local wrapped_title = smart_wrap(show_name, opts.wrap_limit)
    ass = ass .. "\\N{\\1c&H" .. main_c .. "&}{\\fs40}" .. wrapped_title

    -- Wrap the episode title (using a slightly larger limit since the font is smaller)
    if show_ep ~= "" then
        local ep_limit = math.floor(opts.wrap_limit * 1.4)
        local wrapped_ep = smart_wrap(show_ep, ep_limit)
        ass = ass .. "\\N{\\1c&Hc7dce8&}{\\fs28}" .. wrapped_ep
    end

    paint(ass)
end

local function click_action()
    if state.is_visible and check_mouse_hover() then
        mp.command("playlist-next")
        paint("")
        state.is_visible = false
        if state.mouse_bound then
            mp.remove_key_binding("click_next")
            state.mouse_bound = false
        end
    end
end

local function on_tick()
    if not opts.enabled then return end

    -- [SAFETY] Don't run logic if we are just starting (avoids property spam)
    local time_pos = mp.get_property_number("time-pos")
    if not time_pos or time_pos < 5 then return end

    local time_remaining = mp.get_property_number("time-remaining")
    local pos = mp.get_property_number("playlist-pos")
    local count = mp.get_property_number("playlist-count")

    if not time_remaining or not pos or not count then
        if state.is_visible then paint(""); state.is_visible = false end
        return
    end

    if time_remaining <= opts.trigger_time and (pos + 1) < count then
        if not state.next_filename then
            -- [SAFETY] Only fetch string properties once per trigger
            state.next_filename = mp.get_property("playlist/" .. (pos + 1) .. "/filename")
            state.next_title = mp.get_property("playlist/" .. (pos + 1) .. "/title")
        end

        local show_name, show_ep = get_smart_details(state.next_filename, state.next_title)
        local seconds = math.floor(time_remaining)
        local is_hovering = check_mouse_hover()

        draw_ui(seconds, show_name, show_ep, is_hovering)
        state.is_visible = true

        if is_hovering and not state.mouse_bound then
            mp.add_forced_key_binding("MBTN_LEFT", "click_next", click_action)
            state.mouse_bound = true
        elseif not is_hovering and state.mouse_bound then
            mp.remove_key_binding("click_next")
            state.mouse_bound = false
        end
    else
        if state.is_visible then
            paint(""); state.is_visible = false; state.next_filename = nil
        end
        if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
    end
end

-- Renamed 2026-09-08: 'toggle-state' collided with skip_intro.lua under the shared media/ bundle Lua state (last registration wins); no in-repo callers so this rename is safe.
mp.register_script_message("toggle-up-next-state", function(val)
    opts.enabled = (val == "true")
    if not opts.enabled then
        paint("")
        state.is_visible = false
        if state.mouse_bound then mp.remove_key_binding("click_next"); state.mouse_bound = false end
    end
end)

mp.add_periodic_timer(0.1, on_tick)

mp.register_event("file-loaded", function()
    state.is_visible = false
    state.next_filename = nil
    paint("")
end)