-- TV plugin — optional Hyprland window rule for the docked chat panel.
--
-- The plugin works without this. It only removes the brief flash of the chat
-- window tiling into your layout before the `tv` helper floats and positions it
-- next to mpv. Append this to ~/.config/hypr/hyprland.lua (or a file it
-- requires) and save — Hyprland reloads automatically.
--
-- The chat window is a Chromium `--app` window; on Wayland Chromium names it
-- `chrome-<url-slug>-<profile>` and ignores --class, so the regex matches the
-- chat-path slug. Firefox-based browsers get the plain `tv-chat` class.

o.window("^(tv-chat|[cC]hrome-.*(live_chat|_chat|chatroom).*)$", {
  float = true,
  tag = "-default-opacity",
  opacity = "1 1",
})
