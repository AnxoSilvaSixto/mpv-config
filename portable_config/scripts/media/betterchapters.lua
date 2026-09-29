-- betterchapters.lua
-- Seek to next/previous chapter. When no more chapters exist in that
-- direction, fall through to playlist_next / playlist_prev.
--
-- Keybind names: chapter_next, chapter_prev
-- Bind in input.conf:
--   z  script-binding media/chapter_next
--   Z  script-binding media/chapter_prev

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
