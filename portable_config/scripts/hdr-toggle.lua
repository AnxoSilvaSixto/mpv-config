-- hdr-toggle.lua - Alt+h: drop hdr-toys shaders, restore native tone-mapping.
-- Reload file to bring hdr-toys back.
local msg = require 'mp.msg'

local function disable_hdr_toys()
    local raw = mp.get_property('glsl-shaders', '')
    local shaders = mp.get_property_native('glsl-shaders')
    if type(shaders) ~= 'table' then
        shaders = {}
        if raw and raw ~= '' and raw ~= '[]' then
            for s in string.gmatch(raw, '([^;]+)') do
                shaders[#shaders + 1] = s
            end
        end
    end

    local filtered = {}
    for _, s in ipairs(shaders) do
        if type(s) ~= "string" or not s:find('hdr-toys', 1, true) then
            filtered[#filtered + 1] = s
        end
    end

    if #filtered ~= #shaders then
        if #filtered == 0 then
            mp.set_property_native('glsl-shaders', filtered)
        else
            mp.set_property('glsl-shaders', table.concat(filtered, ';'))
        end
        msg.verbose('hdr-toggle: removed ' .. (#shaders - #filtered) .. ' hdr-toys shader(s)')
    end

    local function try_set(prop, value)
        local ok, err = pcall(mp.set_property, prop, value)
        if not ok then msg.warn('hdr-toggle: failed to set ' .. prop .. ': ' .. tostring(err)) end
    end
    try_set('target-colorspace-hint', 'yes')
    try_set('tone-mapping', 'spline')
    try_set('gamut-mapping-mode', 'auto')
    try_set('target-prim', 'bt.709')
    try_set('target-trc', 'bt.1886')

    mp.osd_message('hdr-toys OFF -- native tone-mapping restored (reload file to bring hdr-toys back)')
end

mp.add_key_binding('Alt+h', 'hdr-toggle', disable_hdr_toys)
mp.register_script_message('toggle', disable_hdr_toys)
mp.register_script_message('disable', disable_hdr_toys)
