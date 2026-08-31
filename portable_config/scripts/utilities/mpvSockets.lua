-- mpvSockets.lua
-- Sets a unique, per-process input-ipc-server path automatically so external
-- tools can connect to this specific mpv instance without manual config.
-- Source: Chinna95P/mpv-anime-build (scripts/mpvSockets.lua)

local utils = require "mp.utils"
local msg = require "mp.msg"

local platform = mp.get_property_native("platform") or ""
local pid = utils.getpid and utils.getpid() or tostring(os.time())

local function setup_windows_pipe()
    -- Named pipes need no directory and no external process to create - Windows
    -- creates them on first server bind. Nothing to clean up on exit either.
    local pipe_path = "\\\\.\\pipe\\mpvSockets_" .. pid
    mp.set_property("input-ipc-server", pipe_path)
    msg.info("IPC pipe: " .. pipe_path)
end

local function setup_unix_socket()
    -- Only reached on Linux/macOS - never runs on Windows.
    local socket_dir = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
    socket_dir = socket_dir .. "/mpvSockets"
    os.execute("mkdir -p '" .. socket_dir .. "' 2>/dev/null")
    local socket_path = socket_dir .. "/mpv_" .. pid .. ".sock"
    mp.set_property("input-ipc-server", socket_path)
    msg.info("IPC socket: " .. socket_path)

    mp.register_event("shutdown", function()
        os.remove(socket_path)
    end)
end

if platform == "windows" then
    setup_windows_pipe()
else
    setup_unix_socket()
end
