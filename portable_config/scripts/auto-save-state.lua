-- Save state in multiple scenarios and control deletion
local options = {
    timer_enabled = true,
    auto_save_interval = 1,
    delete_finished = true,
    delete_unloaded = false
}
mp.options = require 'mp.options'
mp.options.read_options(options, "auto-save-state")

-- Ending-window awareness (mirrors the [ending] auto-profile: last 60s of a
-- file). This script must not re-save position -- or re-enable core saving --
-- where [ending] deliberately disabled it. Marker: _ending_aware_patched
local function in_ending_window()
    local dur = mp.get_property_number("duration", 0)
    if dur <= 0 then return false end
    return mp.get_property_number("time-remaining", 9999) <= 60
end

if not in_ending_window() then mp.set_property("save-position-on-quit", "yes") end

local loaded_file_path
local idle
local eof_reached

local function save()
    -- [ending] owns the last 60s: freeze the entry (no writes) instead of
    -- refreshing it; core skips its own quit-save there via save-position=no.
    if in_ending_window() then return end
    if not idle and (not eof_reached or eof_reached and not options.delete_finished) then
        mp.command("write-watch-later-config")
    end
end

local timer = mp.add_periodic_timer(options.auto_save_interval, save)
timer:kill()

local function timer_state(active)
    if timer then
        if active and options.timer_enabled and not eof_reached then
            timer:resume()
        else
            timer:stop()
        end
    end
end

mp.register_event("file-loaded", function()
    loaded_file_path = mp.get_property("path")
    timer.timeout = options.auto_save_interval
    timer_state(true)
    save()
end)

mp.observe_property("core-idle", "bool", function(name, pause)
    if pause then
        timer_state(false)
        save()
    else
        timer_state(true)
    end
end)

mp.register_event("seek", save)

mp.observe_property("eof-reached", "bool", function(name, eof)
    if eof then
        eof_reached = true
        if options.delete_finished then
            print("Deleting state (eof-reached).")
            mp.commandv("delete-watch-later-config", loaded_file_path)
            mp.set_property("save-position-on-quit", "no")
        else
            save()
        end
        timer_state(false)
    else
        eof_reached = false
        if not in_ending_window() then mp.set_property("save-position-on-quit", "yes") end
        timer_state(true)
    end
end)

mp.add_hook("on_unload", 50, function()
    if not options.delete_unloaded then
        save()
    end
end)

mp.register_event("end-file", function(event)
    if options.delete_unloaded then
        if event["reason"] == "eof" or event["reason"] == "stop" then
            print("Deleting state (end-file " .. event["reason"] .. ").")
            mp.commandv("delete-watch-later-config", loaded_file_path)
        end
    end
end)

mp.observe_property("idle-active", "bool", function(name, idle)
    if idle then
        idle = true
        timer_state(false)
    else
        idle = false
        timer_state(true)
    end
end)
