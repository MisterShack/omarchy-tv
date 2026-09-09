# TV — Twitch for the Omarchy bar

One bar icon and one keyboard-friendly popup:

- The Twitch channels **you follow that are live right now**, live channels
  first, then your favorites, then by viewer count.
- **Search** Twitch channels.
- **Favorite** channels so they float to the top.
- **Watch** in `mpv` (via `yt-dlp`) with one click — falls back to the browser
  if `mpv` isn't installed.

All network, OAuth, and player work lives in the bundled `tv` Python script
(standard library only). The QML widget just renders what `tv` prints.

> YouTube ("subscriptions that are live") is included but **experimental** —
> it needs your own free Google OAuth client. See [YouTube](#youtube-experimental)
> at the bottom.

## Install

```bash
omarchy plugin add https://github.com/MisterShack/omarchy-tv --enable
```

Optionally move it in the bar:

```bash
omarchy bar move davidshack.tv --section right
```

## Connect Twitch

No developer account needed — a public Twitch application Client ID ships with
the plugin. Just authorize your machine:

```bash
~/.config/omarchy/plugins/davidshack.tv/tv auth twitch
```

It prints a short code and opens `twitch.tv/activate`; approve there and the
popup fills in. The only scope requested is `user:read:follows`.

> Prefer your own Twitch app? Register a **Public** client at
> <https://dev.twitch.tv/console/apps> (OAuth Redirect URL `http://localhost`),
> then `tv creds set --twitch-client-id <CLIENT_ID>` before `tv auth twitch`.

## Using the popup

Click the 󰠫 icon (middle-click force-refreshes). In the popup:

| Key            | Action                                   |
|----------------|------------------------------------------|
| `j` / `k`, ↑/↓ | move the cursor                          |
| `Enter`        | watch the selected channel               |
| `f`            | toggle favorite                          |
| `o`            | open the selected channel in the browser |
| `r`            | refresh                                  |
| `/`            | jump to the search box                   |
| `Esc`          | clear the search, then close             |

Middle-click a row to open it in the browser instead of `mpv`.

## Optional: Omarchy menu integration

`examples/omarchy-menu-tv.jsonc` adds a **TV** entry to the Omarchy menu
(Super+Space) with "Live now", "Search channels…", and an Accounts submenu.
Merge its keys into `~/.config/omarchy/extensions/omarchy-menu.jsonc` (the file
hot-reloads on save), then run `omarchy restart shell` once so the `live` /
`search` IPC methods register.

## How "who's live" works

- **Twitch** uses the official `streams/followed` Helix endpoint.
- **YouTube** (experimental) has no cheap "are my subscriptions live" endpoint,
  so `tv` reads each subscribed channel's public RSS feed (no API quota) for
  recent video ids, then makes one batched `videos.list` call to see which are
  currently live. The subscription list is cached for 6 hours.

## Settings

`omarchy` → Setup → Plugins, or edit the entry in `~/.config/omarchy/shell.json`:

```json
{ "id": "davidshack.tv", "refreshIntervalSec": 120 }
```

## Files

| Path                                          | What                          |
|-----------------------------------------------|-------------------------------|
| `~/.config/omarchy/tv/credentials.json`       | your own app client id/secret (only if you override the defaults) |
| `~/.local/state/omarchy/tv/twitch.json`       | Twitch OAuth tokens           |
| `~/.local/state/omarchy/tv/youtube.json`      | YouTube OAuth tokens          |
| `~/.local/state/omarchy/tv/favorites.json`    | favorited channels            |
| `~/.local/state/omarchy/tv/youtube-subs.json` | cached subscription list      |

`tv auth logout <twitch|youtube|all>` clears tokens.

## Commands

`--json` is a global flag and comes before the subcommand:

```
tv auth twitch
tv --json status
tv --json live [--platform twitch|youtube] [--no-cache]
tv --json search <query> [--live-only]
tv fav <list|add|remove|toggle> [twitch|youtube] [id]
tv watch <url|twitch-login>
tv open <url>
```

## YouTube (experimental)

"Who I'm subscribed to that's live" needs your own free Google OAuth client,
because YouTube's read scope can't be shipped in a public app without Google
verification.

1. <https://console.cloud.google.com/> → new project
2. **APIs & Services → Library** → enable *YouTube Data API v3*
3. **OAuth consent screen** → External → add your Google account as a *Test user*
4. **Credentials → Create credentials → OAuth client ID** →
   application type **"TVs and Limited Input devices"**
5. ```bash
   tv creds set --youtube-client-id <ID> --youtube-client-secret <SECRET>
   tv auth youtube
   ```

## License

MIT © David Shack
