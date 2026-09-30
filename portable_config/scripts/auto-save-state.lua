-- auto-save-state.lua - owned locally, frozen (not auto-synced). Saves position every 1s.
-- Respects [ending]: no writes in the last 60s.
local options = {
    timer_enabled = true,
    auto_save_interval = 1,
    delete_finished = true,
    delete_unloaded = false
}
mp.options = require 'mp.options'
mp.options.read_options(options, "auto-save-state")

-- Last 60s belong to [ending]: freeze writes there.
local function in_ending_window()
    local dur = mp.get_property_number("duration", 0)
    if dur <= 0 then return false end
    return mp.get_property_number("time-remaining", 9999) <= 60
end

if not in_ending_window() then mp.set_property("save-position-on-quit", "yes") end

local loaded_file_path
local idle = false
local eof_reached

local function save()
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
    local interval = tonumber(options.auto_save_interval) or 1
    if interval <= 0 then interval = 1 end
    timer.timeout = interval
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
            if loaded_file_path then
                mp.commandv("delete-watch-later-config", loaded_file_path)
            end
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
            if loaded_file_path then
                mp.commandv("delete-watch-later-config", loaded_file_path)
            end
        end
    end
end)

mp.observe_property("idle-active", "bool", function(name, is_idle)
    idle = is_idle and true or false
    if idle then
        timer_state(false)
    else
        timer_state(true)
    end
end)
