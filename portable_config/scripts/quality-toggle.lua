-- quality-toggle.lua — MaxQuality opt-in toggle (Alt+q)
-- Holds toggle state in Lua (cycle-values is a no-op on undefined user-data
-- props) and mirrors it to user-data/maxq, which profiles/maxquality.conf
-- reads via get("user-data/maxq","no")=="yes". Initialized OFF at startup.
local msg = require 'mp.msg'

local enabled = false
mp.set_property('user-data/maxq', 'no')

local function toggle()
    enabled = not enabled
    mp.set_property('user-data/maxq', enabled and 'yes' or 'no')
    msg.info('MaxQuality: ' .. (enabled and 'ON (enhanced)' or 'OFF (faithful)'))
    mp.osd_message('MaxQuality: ' .. (enabled and 'ON' or 'OFF'))
end

mp.register_script_message('toggle-maxq', toggle)
