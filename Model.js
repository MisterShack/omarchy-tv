// Pure helpers for the TV plugin. No QML types in here so the logic can be
// reasoned about (and unit-tested) on its own.
.pragma library

// Parse the JSON `tv` prints on stdout. Never throws — a broken payload
// becomes an empty, clearly-flagged result the panel can render.
function parsePayload(raw) {
  var empty = {
    ok: false,
    auth: { twitch: false, youtube: false },
    credentials: { twitch: false, youtube: false },
    streams: [],
    errors: [],
    query: ""
  }
  try {
    var data = JSON.parse(String(raw || ""))
    if (!data || typeof data !== "object") return empty
    if (data.error) {
      empty.errors = [String(data.error)]
      return empty
    }
    return {
      ok: true,
      auth: {
        twitch: !!(data.auth && data.auth.twitch),
        youtube: !!(data.auth && data.auth.youtube)
      },
      credentials: {
        twitch: !!(data.credentials && data.credentials.twitch),
        youtube: !!(data.credentials && data.credentials.youtube)
      },
      streams: Array.isArray(data.streams) ? data.streams : [],
      errors: Array.isArray(data.errors) ? data.errors : [],
      query: String(data.query || "")
    }
  } catch (e) {
    return empty
  }
}

// 12345 -> "12.3K", 1200000 -> "1.2M"
function formatViewers(n) {
  var v = parseInt(n, 10)
  if (!isFinite(v) || v <= 0) return ""
  if (v < 1000) return String(v)
  if (v < 1000000) return (v / 1000).toFixed(v < 10000 ? 1 : 0) + "K"
  return (v / 1000000).toFixed(1) + "M"
}

// ISO timestamp -> "3h 12m" of uptime, "" when unknown.
function uptime(startedAt, nowMs) {
  if (!startedAt) return ""
  var start = new Date(startedAt).getTime()
  if (!isFinite(start)) return ""
  var mins = Math.floor((nowMs - start) / 60000)
  if (mins < 1) return "just now"
  if (mins < 60) return mins + "m"
  var hours = Math.floor(mins / 60)
  if (hours < 24) return hours + "h " + (mins % 60) + "m"
  return Math.floor(hours / 24) + "d " + (hours % 24) + "h"
}

function platformGlyph(platform) {
  return platform === "youtube" ? "" : ""   // nf-fa-youtube_play / nf-fa-twitch
}

// Bar-icon summary: number of live channels, capped so the pill stays small.
function badgeText(streams) {
  var live = 0
  for (var i = 0; i < streams.length; i++) if (streams[i] && streams[i].live) live++
  if (live <= 0) return ""
  return live > 99 ? "99+" : String(live)
}

function hasLiveFavorite(streams) {
  for (var i = 0; i < streams.length; i++) {
    if (streams[i] && streams[i].live && streams[i].favorite) return true
  }
  return false
}
