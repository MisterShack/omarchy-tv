import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar widget: one icon that opens a keyboard-friendly popup listing the
// Twitch / YouTube channels you follow that are live right now, plus search
// and favorites. All network and player work happens in the bundled `tv`
// Python helper; this file only renders what it prints.
Panel {
  id: root
  moduleName: "davidshack.tv"
  ipcTarget: "davidshack.tv"
  manageIpc: false

  // ---- helper location --------------------------------------------------
  readonly property string pluginDir: {
    var u = String(Qt.resolvedUrl("."))
    if (u.indexOf("file://") === 0) u = u.substring(7)
    if (u.charAt(u.length - 1) !== "/") u += "/"
    return u
  }
  readonly property var helper: ["python3", pluginDir + "tv", "--json"]

  // ---- theme -----------------------------------------------------------
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color barIconColor: bar ? bar.barForeground : Color.foreground

  readonly property int refreshIntervalSec: {
    var n = parseInt(String(setting("refreshIntervalSec", 120)), 10)
    return isFinite(n) && n >= 30 ? n : 120
  }

  // ---- state ---------------------------------------------------------
  property var payload: Model.parsePayload("")
  readonly property var streams: payload.streams
  readonly property bool authedAny: payload.auth.twitch || payload.auth.youtube

  property string query: ""
  readonly property string mode: query.trim() !== "" ? "search" : "live"
  property bool loading: false
  property bool everLoaded: false
  property int cursor: 0
  property bool cursorActive: false
  property double nowMs: Date.now()

  readonly property string bannerText: {
    if (!authedAny)
      return "Run  tv auth twitch  in a terminal to connect your Twitch account."
    if (payload.errors.length > 0)
      return payload.errors.join("  •  ")
    return ""
  }

  // ---- data fetch ----------------------------------------------------
  function reload(force) {
    if (dataProc.running) {
      dataProc.pendingReload = true
      return
    }
    loading = true
    if (mode === "search")
      dataProc.command = root.helper.concat(["search", query.trim()])
    else
      dataProc.command = root.helper.concat(force ? ["live", "--no-cache"] : ["live"])
    dataProc.running = true
  }

  function applyPayload(text) {
    var parsed = Model.parsePayload(text)
    root.payload = parsed
    root.everLoaded = true
    if (root.cursor >= parsed.streams.length)
      root.cursor = Math.max(0, parsed.streams.length - 1)
  }

  Process {
    id: dataProc
    property bool pendingReload: false
    stdout: StdioCollector { id: dataOut; waitForEnd: true; onStreamFinished: root._dataText = text }
    stderr: StdioCollector { id: dataErr; waitForEnd: true; onStreamFinished: root._dataErr = text }
    onExited: function(exitCode) {
      root.loading = false
      var body = String(dataOut.text || root._dataText || "")
      if (body.trim() !== "") root.applyPayload(body)
      else if (String(dataErr.text || "").trim() !== "")
        console.warn("davidshack.tv", String(dataErr.text).trim())
      if (pendingReload) { pendingReload = false; Qt.callLater(function() { root.reload(false) }) }
    }
  }
  property string _dataText: ""
  property string _dataErr: ""

  // watch / favorite / open — fire and (mostly) forget
  Process {
    id: actionProc
    stderr: StdioCollector { waitForEnd: true; onStreamFinished: if (text.trim() !== "") console.warn("davidshack.tv", text.trim()) }
    onExited: function(exitCode) { if (root._reloadAfterAction) { root._reloadAfterAction = false; root.reload(true) } }
  }
  property bool _reloadAfterAction: false

  function watch(item) {
    if (!item || !item.url) return
    actionProc.command = ["python3", root.pluginDir + "tv", "watch", String(item.url)]
    actionProc.running = true
    root.close()
  }

  function openInBrowser(item) {
    if (!item || !item.url) return
    actionProc.command = ["python3", root.pluginDir + "tv", "open", String(item.url)]
    actionProc.running = true
  }

  function toggleFavorite(item) {
    if (!item || !item.fav_id) return
    root._reloadAfterAction = true
    actionProc.command = ["python3", root.pluginDir + "tv", "--json",
                          "fav", "toggle", String(item.platform), String(item.fav_id)]
    actionProc.running = true
  }

  // ---- cursor helpers ----------------------------------------------
  function selected() {
    if (streams.length === 0) return null
    return streams[Math.max(0, Math.min(cursor, streams.length - 1))]
  }

  function moveCursor(delta) {
    if (streams.length === 0) return
    if (!cursorActive) { cursorActive = true; return }
    if (delta < 0 && cursor === 0) { focusSearch(); return }
    cursor = Math.max(0, Math.min(streams.length - 1, cursor + delta))
    scrollCursorIntoView()
  }

  function focusSearch() {
    cursorActive = false
    Qt.callLater(function() { searchField.forceActiveFocus(); searchField.selectAll() })
  }

  function focusList() {
    cursorActive = true
    if (cursor >= streams.length) cursor = 0
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function scrollCursorIntoView() {
    if (!listColumn || cursor < 0 || cursor >= listColumn.children.length) return
    var item = listColumn.children[cursor]
    Qt.callLater(function() {
      if (!item || !flick) return
      var top = item.y
      var bottom = top + item.height
      var margin = Style.space(6)
      if (top < flick.contentY + margin)
        flick.contentY = Math.max(0, top - margin)
      else if (bottom > flick.contentY + flick.height - margin)
        flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height),
                                  bottom + margin - flick.height)
    })
  }

  // ---- lifecycle -------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: {
    if (opened) {
      cursorActive = false
      if (flick) flick.contentY = 0
      nowMs = Date.now()
      reload(true)
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    } else {
      query = ""
      searchField.text = ""
    }
  }

  Timer {
    id: poll
    interval: root.refreshIntervalSec * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (root.mode === "live") root.reload(false)
  }

  Timer {
    id: nowTick
    interval: 30000
    running: root.opened
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  Timer {
    id: searchDebounce
    interval: 350
    onTriggered: root.reload(true)
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.reload(true); return "ok" }
    // Entry points for the Omarchy menu ("Live now" / "Search channels…").
    function live(): string {
      root.query = ""; searchField.text = ""
      root.open(); root.reload(true)
      return "ok"
    }
    function search(): string {
      root.open()
      Qt.callLater(function() { root.focusSearch() })
      return "ok"
    }
  }

  // ---- bar button ----------------------------------------------
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf26c"   // nf-fa-television
    active: Model.hasLiveFavorite(root.streams)
    tooltipText: {
      var n = Model.badgeText(root.streams)
      return n === "" ? "TV — nothing live" : "TV — " + n + " live"
    }

    onPressed: function(b) {
      if (b === Qt.MiddleButton) root.reload(true)
      else root.toggle()
    }

    Rectangle {
      id: badge
      visible: Model.badgeText(root.streams) !== ""
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: Style.space(2)
      anchors.rightMargin: Style.space(1)
      width: Math.max(height, badgeLabel.implicitWidth + Style.space(4))
      height: Style.space(13)
      radius: height / 2
      color: root.urgent

      Text {
        id: badgeLabel
        anchors.centerIn: parent
        text: Model.badgeText(root.streams)
        color: Color.background
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  // ---- popup --------------------------------------------------
  readonly property real desiredContentHeight:
    headerColumn.implicitHeight + Style.space(10)
    + Math.min(Math.max(listColumn.implicitHeight, Style.space(60)), Style.space(420))

  KeyboardPanel {
    id: kpanel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: kpanel.fittedContentWidth(Style.space(400))
    contentHeight: kpanel.fittedContentHeight(root.desiredContentHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: searchField.activeFocus

      onMoveRequested: function(dx, dy) { if (dy !== 0) root.moveCursor(dy) }
      onActivateRequested: if (root.cursorActive) root.watch(root.selected())
      onCloseRequested: {
        if (root.query !== "") { root.query = ""; searchField.text = "" }
        else root.close()
      }
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "/" ) root.focusSearch()
        else if (t === "f" || t === "F") root.toggleFavorite(root.selected())
        else if (t === "r" || t === "R") root.reload(true)
        else if (t === "o" || t === "O") root.openInBrowser(root.selected())
      }

      Column {
        id: headerColumn
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(10)

        PanelHero {
          id: hero
          width: parent.width
          title: root.mode === "search" ? "Search" : "Live now"
          meta: {
            if (root.loading && !root.everLoaded) return "Loading…"
            if (root.mode === "search") return root.streams.length + " channels"
            var live = 0
            for (var i = 0; i < root.streams.length; i++) if (root.streams[i].live) live++
            return live === 0 ? "No followed channels are live" : live + " live"
          }
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconComponent: Component {
            Text {
              text: "\uf26c"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        TextField {
          id: searchField
          width: parent.width
          foreground: root.foreground
          placeholderText: "Search Twitch & YouTube channels…"
          hasCursor: false
          onTextChanged: {
            if (text === root.query) return
            root.query = text
            root.cursor = 0
            searchDebounce.restart()
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Down || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.focusList()
              event.accepted = true
            } else if (event.key === Qt.Key_Escape) {
              if (text !== "") { text = "" }
              else { root.close() }
              event.accepted = true
            }
          }
        }

        Text {
          id: banner
          width: parent.width
          visible: root.bannerText !== ""
          text: root.bannerText
          textFormat: Text.PlainText
          color: !root.authedAny ? root.foreground : root.urgent
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }
      }

      Flickable {
        id: flick
        anchors.top: headerColumn.bottom
        anchors.topMargin: Style.space(10)
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        contentWidth: width
        contentHeight: listColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: listColumn
          width: flick.width
          spacing: Style.space(6)

          Repeater {
            model: root.streams
            StreamRow {
              required property var modelData
              required property int index
              width: listColumn.width
              item: modelData
              rowIndex: index
            }
          }

          Text {
            visible: root.everLoaded && root.streams.length === 0 && root.bannerText === ""
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            topPadding: Style.space(24)
            text: root.mode === "search" ? "No channels found." : "Nobody you follow is live right now."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }
        }
      }
    }
  }

  // ---- one stream row ----------------------------------------
  component StreamRow: CursorSurface {
    id: streamRow
    property var item: null
    property int rowIndex: 0

    readonly property bool isLive: item && item.live
    readonly property string channel: item ? String(item.channel || item.login || "Unknown") : "Unknown"
    readonly property string subtitle: {
      if (!item) return ""
      var bits = []
      if (item.title) bits.push(String(item.title))
      return bits.join("")
    }
    readonly property string metaLine: {
      if (!item) return ""
      var bits = []
      var v = Model.formatViewers(item.viewers)
      if (v !== "") bits.push(v + " watching")
      if (item.category) bits.push(String(item.category))
      var up = Model.uptime(item.started_at, root.nowMs)
      if (up !== "") bits.push(up)
      return bits.join("  ·  ")
    }

    hasCursor: root.cursorActive && root.cursor === rowIndex
    foreground: root.foreground
    implicitHeight: rowInner.implicitHeight + Style.spacing.rowPaddingX

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) { root.cursorActive = true; root.cursor = streamRow.rowIndex }
      onClicked: function(mouse) {
        if (mouse.button === Qt.MiddleButton) root.openInBrowser(streamRow.item)
        else root.watch(streamRow.item)
      }
    }

    RowLayout {
      id: rowInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(9)

      // platform glyph + live dot
      Item {
        Layout.alignment: Qt.AlignVCenter
        implicitWidth: Style.space(20)
        implicitHeight: Style.space(20)

        Text {
          anchors.centerIn: parent
          text: Model.platformGlyph(streamRow.item ? streamRow.item.platform : "")
          color: streamRow.item && streamRow.item.platform === "youtube" ? "#ff0000" : "#9147ff"
          font.family: root.fontFamily
          font.pixelSize: Style.font.heading
          opacity: streamRow.isLive ? 1.0 : 0.55
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          textFormat: Text.PlainText
          text: streamRow.channel
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: streamRow.subtitle
          color: Qt.darker(root.foreground, 1.25)
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
        }

        Text {
          Layout.fillWidth: true
          visible: text !== ""
          textFormat: Text.PlainText
          text: streamRow.metaLine
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      // favorite toggle
      PanelActionButton {
        Layout.alignment: Qt.AlignVCenter
        iconText: streamRow.item && streamRow.item.favorite ? "\uf005" : "\uf006"
        tooltipText: streamRow.item && streamRow.item.favorite ? "Unfavorite" : "Favorite"
        foreground: streamRow.item && streamRow.item.favorite ? root.urgent : root.foreground
        fontFamily: root.fontFamily
        onClicked: root.toggleFavorite(streamRow.item)
      }
    }
  }
}
