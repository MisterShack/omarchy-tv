-- Bundled with the Omarchy "TV" plugin. mpv loads this ONLY for players the
-- plugin launches (via --script=), so it never affects your global mpv config.
--
--   c   toggle a chat window docked to the right of this player
--
-- When mpv quits, the chat window is closed too. The `tv` helper figures out
-- which chat to show (Twitch / YouTube / Kick / Rumble / …) from the stream URL
-- and positions the window next to mpv via hyprctl.

local mp = require 'mp'

local TV = os.getenv("TV_HELPER")

local function tv_chat(flag)
    local url = mp.get_property("path")
    if TV and url and url ~= "" then
        -- `run` is fire-and-forget and outlives mpv, so it still works from the
        -- shutdown handler.
        mp.commandv("run", "python3", TV, "chat", flag, url)
    end
end

mp.add_key_binding("c", "tv-toggle-chat", function() tv_chat("--toggle") end)
mp.register_event("shutdown", function() tv_chat("--close") end)
