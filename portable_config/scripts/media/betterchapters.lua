-- betterchapters.lua - chapter seek with playlist fall-through at ends.
-- Binds: z/Z in input.conf (script-binding media/chapter_next/prev).

function chapter_seek(direction)
    local chapters = mp.get_property_number("chapters")
    local chapter  = mp.get_property_number("chapter")
    if chapter == nil then chapter = 0 end
    if chapters == nil then chapters = 0 end
    if chapter + direction < 0 then
        mp.command("playlist_prev")
    elseif chapter + direction >= chapters then
        mp.command("playlist_next")
    else
        mp.commandv("add", "chapter", direction)
    end
end

mp.add_key_binding("z", "chapter_next", function() chapter_seek(1) end)
mp.add_key_binding("Z", "chapter_prev", function() chapter_seek(-1) end)
