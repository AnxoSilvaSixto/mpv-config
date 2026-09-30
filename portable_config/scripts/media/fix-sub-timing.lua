-- fix-sub-timing.lua - two-point sub-delay/sub-speed solver.
-- Sync a line with Ctrl+z/Ctrl+x, mark with Ctrl+/ (twice); solves delay + speed.
-- sub_time = (vid_time - sub_delay) / sub_speed

sub_time_1 = nil
vid_time_1 = nil
sub_time_2 = nil
vid_time_2 = nil

function sub_set_time()
    local sub_delay = mp.get_property_native("sub-delay")
    local vid_time = mp.get_property_native("playback-time")
    local sub_speed = mp.get_property_native("sub-speed")
    local sub_time = (vid_time - sub_delay) / sub_speed

    if sub_time_1 == nil then
        vid_time_1 = vid_time
        sub_time_1 = sub_time
        mp.osd_message("Mark time 1")
        return
    end

    if sub_time_2 ~= nil then
        sub_time_1 = sub_time_2
        vid_time_1 = vid_time_2
    end

    if sub_time_1 == sub_time or vid_time_1 == vid_time then
        return
    end

    sub_time_2 = sub_time
    vid_time_2 = vid_time

    local new_speed = (vid_time_2 - vid_time_1) / (sub_time_2 - sub_time_1)
    local new_delay = vid_time_2 - sub_time_2 * new_speed

    print("delay=" .. tostring(new_delay) .. " speed=" .. tostring(new_speed))

    mp.set_property_native("sub-delay", new_delay)
    mp.set_property_native("sub-speed", new_speed)
end

-- input.conf owns the key; nil avoids a double-binding.
mp.add_key_binding(nil, "sub-set-time", sub_set_time)
