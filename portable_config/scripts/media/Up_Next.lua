-- =================================================================================
-- MPV-PC: "UP NEXT" INTERACTIVE (v3.0 — uosc Visual Identity)
-- Owned locally (no upstream sync): palette mirrors script-opts/uosc.conf NieR
-- tokens; geometry is fixed 1920x1080 ASS coords; poll 10Hz early-outs when
-- playlist-count==1. Re-check by hand occasionally (no updater coverage).
-- =================================================================================

local mp = require 'mp'

-- Helper function to convert RGB hex strings (RRGGBB) to ASS BGR (BBGGRR)
local function rgb_to_bgr(hex)
    hex = hex:gsub("#", "")
    if #hex ~= 6 then return hex end
    return hex:sub(5, 6) .. hex:sub(3, 4) .. hex:sub(1, 2)
end

-- NieR:Automata palette (exact uosc.conf tokens)
local opts = {
    enabled      = true,
    trigger_time = 10,
    wrap_limit   = 24,
    text_color   = rgb_to_bgr("e8dcc7"), -- uosc foreground: warm beige
    accent_color = rgb_to_bgr("c9944b"), -- uosc match: warm amber
    sub_color    = rgb_to_bgr("c8c2aa"), -- uosc curtain: mid beige
    hover_color  = rgb_to_bgr("c9944b"), -- uosc match: warm gold
    bg_color     = rgb_to_bgr("3a3528"), -- uosc background: dark brown
    bg_opacity   = "D9",                 -- 85%, matches uosc opacity
}

local state = {
    is_visible    = false,
    mouse_bound   = false,
    next_filename = nil,
    next_title    = nil,
    last_ass      = nil
}

-- Modern mpv overlay API to completely eliminate flickering
local upnext_overlay = mp.create_osd_overlay("ass-events")
upnext_overlay.res_x = 1920
upnext_overlay.res_y = 1080

function get_smart_details(filename, title)
    local display = nil

    if filename and filename ~= "" then
        display = filename:match("([^/\\]+)$") or filename
    end
    
    if (not display or display == "") and title and title ~= "" then
        display = title
    end

    if display then
        display = display:gsub("%.%w+$", "") 
        display = display:gsub("^%[%s*.-%s*%]%s*", "")
        display = display:gsub("%b[]", "")
        display = display:gsub("%b()", "")
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
        display = display:gsub("[._]", " ")
        display = display:gsub("%s*%-[A-Za-z0-9_]+%s*$", "")
        display = display:gsub("%-$", "")
    end

    if display then
        display = display:gsub("^%s+", ""):gsub("%s+$", "")
        display = display:gsub("%s+", " ")
    else
        display = "Unknown"
    end

    local name, ep = display:match("^(.*)%s+-%s+(.*)$")
    return name or display, ep or ""
end

function smart_wrap(text, limit)
    if not text or string.len(text) <= limit then return text end
    local result = ""
    local remaining = text

    while string.len(remaining) > limit do
        local chunk = string.sub(remaining, 1, limit + 5)
        local break_pos = string.match(chunk, ".*%s()")
        
        if break_pos and break_pos > 1 then
            result = result .. string.sub(remaining, 1, break_pos - 2) .. "\\N"
            remaining = string.sub(remaining, break_pos)
        else
            result = result .. string.sub(remaining, 1, limit) .. "\\N"
            remaining = string.sub(remaining, limit + 1)
        end
    end
    
    return result .. remaining
end

local function paint(ass_text)
    if state.last_ass ~= ass_text then
        state.last_ass = ass_text
        if ass_text == "" then
            upnext_overlay:remove()
        else
            upnext_overlay.data = ass_text
            upnext_overlay:update()
        end
    end
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

local function draw_ui(seconds, show_name, show_ep, is_hovering)
    local cx, cy = 1650, 850
    local ass = "{\\an5}{\\pos(" .. cx .. "," .. cy .. ")}"
    
    -- uosc visual identity: Default style, arial, no bold, thin border
    ass = ass .. "{\\rDefault}{\\fnArial}{\\fs32}"
    ass = ass .. "{\\bord1.2}{\\shad0}{\\blur0}{\\3c&H" .. opts.bg_color .. "&}{\\3a&H" .. opts.bg_opacity .. "&}"
    
    local main_c = is_hovering and opts.hover_color or opts.text_color
    local acc_c  = is_hovering and opts.hover_color or opts.accent_color
    local sub_c  = is_hovering and opts.hover_color or opts.sub_color
    
    -- Applied dynamic secondary color to prevent invisible text on bright backgrounds
    ass = ass .. "{\\1c&H" .. acc_c .. "&}▶ {\\1c&H" .. sub_c .. "&}{\\fs23}UP NEXT {\\1c&H" .. acc_c .. "&}(" .. seconds .. "s)"
    
    local wrapped_title = smart_wrap(show_name, opts.wrap_limit)
    ass = ass .. "\\N{\\1c&H" .. main_c .. "&}{\\fs36}" .. wrapped_title
    
    if show_ep ~= "" then 
        local ep_limit = math.floor(opts.wrap_limit * 1.4)
        local wrapped_ep = smart_wrap(show_ep, ep_limit)
        ass = ass .. "\\N{\\1c&H" .. sub_c .. "&}{\\fs25}" .. wrapped_ep
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

mp.register_script_message("toggle-state", function(val)
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