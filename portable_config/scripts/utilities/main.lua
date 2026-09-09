-- Utility scripts bundle entry point
-- autocrop: auto black-bar crop
require './autocrop'
-- autodeint: auto deinterlace
require './autodeint'
-- mpvSockets: auto IPC named pipe path
require './mpvSockets'
-- mpv-watch-history: optional local helper (AniVault) — pcall so fresh clones without the file don't error
pcall(require, './mpv-watch-history')
