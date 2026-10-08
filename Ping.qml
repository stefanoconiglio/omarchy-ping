import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Latency.js" as Latency

// Ping: the round trip to one host, inside a soft outline on the bar.
//
// The face reads a continuous `ping -n -O -i 1 <host>` of its own. Apart from
// it, one shell runs `ping <host> -i 1` at the user's prompt all the time, in
// a tmux session (ping-session.sh). Hovering the face shows that session's
// screen, live; a click opens a terminal attached to it in the same place, to
// stop the ping or type another command. The terminal closes when it loses
// the focus, or on a second click; the session goes on.
BarWidget {
  id: root

  moduleName: "coniglio.ping"

  readonly property string host: {
    var value = String(setting("host", "www.google.it")).trim()
    return Latency.validHost(value) ? value : ""
  }
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  visible: true
  implicitWidth: vertical ? barSize : pill.width + Style.space(10)
  implicitHeight: vertical ? pill.height + Style.space(10) : barSize

  // ---------- the face's ping ----------

  property real latencyMs: 0
  property bool hasReply: false
  property real lastHeard: Date.now()   // the last reply, or the start before any
  property real now: Date.now()
  readonly property string reading: host === "" ? "none" : Latency.status(latencyMs, hasReply, now - lastHeard)

  function startPing() {
    if (host === "" || pinger.running) return
    pinger.command = ["ping", "-n", "-O", "-i", "1", "--", host]
    pinger.running = true
  }

  Process {
    id: pinger
    // The reply lines are parsed: keep them in English.
    environment: ({ LC_ALL: "C" })
    stdout: SplitParser {
      onRead: function(line) {
        var ms = Latency.replyMs(line)
        if (ms === null) return
        root.latencyMs = ms
        root.hasReply = true
        root.lastHeard = Date.now()
        root.now = root.lastHeard
      }
    }
    // ping runs until stopped; it ends by itself only on an error (no name
    // resolution, no network at the start), so try again shortly.
    onExited: restartPing.restart()
  }

  Timer {
    id: restartPing
    interval: 2000
    onTriggered: root.startPing()
  }

  // The clock that turns a silence into "no net".
  Timer {
    interval: 1000
    repeat: true
    running: true
    onTriggered: root.now = Date.now()
  }

  onHostChanged: {
    hasReply = false
    lastHeard = Date.now()
    if (pinger.running) pinger.running = false   // exits, and restarts on the new host
    else startPing()
    ensureSession()
  }

  Component.onCompleted: {
    startPing()
    ensureSession()
  }

  // ---------- the face ----------

  // The outline and the text in the bar's colours; orange when slow, red when
  // bad or down (Attention.qml: the theme's own orange when it has one, always
  // readable on the bar).
  Attention { id: attention; bar: root.bar }

  function faceColor(reading) {
    if (reading === "bad" || reading === "down") return attention.red
    if (reading === "slow") return attention.orange
    if (reading === "waiting" || reading === "none") return attention.dim
    return attention.normal
  }

  Item {
    id: face
    anchors.fill: parent

    Component.onCompleted: if (root.bar && root.bar.registerClickTarget) root.bar.registerClickTarget(face)
    Component.onDestruction: if (root.bar && root.bar.unregisterClickTarget) root.bar.unregisterClickTarget(face)

    // Sized for the widest label, so the widgets beside it never move.
    TextMetrics {
      id: widest
      font: label.font
      text: root.vertical ? "888" : "888 ms"
    }

    // The ink of the label shown, to centre the glyphs rather than the line box.
    TextMetrics {
      id: ink
      font: label.font
      text: label.text
    }

    FontMetrics {
      id: lineMetrics
      font: label.font
    }

    Rectangle {
      id: pill
      anchors.centerIn: parent
      // An even width and a height of the bar's parity: centring leaves no
      // half pixel on either axis.
      width: {
        var w = Math.ceil(widest.width) + Style.space(14)
        return w % 2 === 0 ? w : w + 1
      }
      height: {
        var h = Math.min(root.barSize - Style.space(2), Math.ceil(lineMetrics.height) + Style.space(2))
        return (root.barSize - h) % 2 === 0 ? h : h - 1
      }
      radius: height / 2
      color: "transparent"
      border.width: Math.max(1, Math.round(Style.space(1.5)))
      border.color: attention.outline

      Text {
        id: label
        // Across, this label's ink is centred; down, that of the digits, so
        // every label sits on one baseline. tightBoundingRect is measured from
        // the baseline, which lies `ascent` below the top of the line.
        x: (pill.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x
        y: Math.round((pill.height - widest.tightBoundingRect.height) / 2
                      - widest.tightBoundingRect.y - lineMetrics.ascent)
        text: Latency.label(root.reading, root.latencyMs, root.vertical)
        color: root.faceColor(root.reading)
        font.family: root.fontFamily
        font.pixelSize: Style.font.title
        font.bold: true
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: if (root.terminalAddress === "") hoverDelay.restart()
      onExited: {
        hoverDelay.stop()
        root.peeking = false
      }
      onClicked: {
        root.peeking = false
        root.toggleTerminal()
      }
    }
  }

  // ---------- the session: hover view and attached terminal ----------

  readonly property string script: decodeURIComponent(Qt.resolvedUrl("ping-session.sh").toString().replace(/^file:\/\//, ""))
  readonly property string terminalClass: "coniglio.ping.terminal"

  // The hover view and the terminal share this rectangle, under the face. The
  // view's text has the terminal's size (9 pt) and padding.
  readonly property int viewWidth: 720
  readonly property int viewHeight: 300
  readonly property int viewGap: Style.gapsOut
  readonly property int viewPadding: 14
  readonly property int viewFontSize: 12
  readonly property int viewLines: Math.max(1, Math.floor(screenText.height / viewMetrics.lineSpacing))

  property bool peeking: false          // the pointer rests on the face
  property bool attaching: false        // a click is starting the terminal
  property string terminalAddress: ""   // its window, from Hyprland's events (no 0x)
  property bool terminalFocused: false
  property string screenCapture: ""

  // Up while hovered, and while a click starts the terminal that replaces it.
  readonly property bool viewShown: (peeking || attaching) && terminalAddress === "" && host !== ""

  function ensureSession() {
    if (host !== "") Util.execArgv([script, "session", host])
  }

  function showScreen(raw) {
    var lines = String(raw || "").replace(/\s+$/, "").split("\n")
    screenCapture = lines.slice(-viewLines).join("\n")
  }

  // Under the face (over it, on a bottom bar), inside the screen. `windowY` is
  // in the bar's coordinates, for the popup; `y` in the monitor's, for the
  // terminal's window rule.
  function viewPlace() {
    var win = face.QsWindow.window
    if (!win) return null
    var center = win.contentItem.mapFromItem(face, face.width / 2, 0)
    var x = Math.round(center.x - viewWidth / 2)
    x = Math.max(viewGap, Math.min(x, win.width - viewWidth - viewGap))
    var bottomBar = bar && bar.position === "bottom"
    var screenHeight = win.screen ? win.screen.height : 0
    return {
      x: x,
      windowY: bottomBar ? -viewHeight - viewGap : win.height + viewGap,
      y: bottomBar ? screenHeight - win.height - viewHeight - viewGap : win.height + viewGap
    }
  }

  function toggleTerminal() {
    if (terminalAddress !== "") { closeTerminal(); return }
    if (attaching || host === "") return
    var place = viewPlace()
    if (!place) return
    attaching = true
    attachTimeout.restart()
    Util.execArgv([script, "attach", host, String(place.x), String(place.y), String(viewWidth), String(viewHeight)])
  }

  // Closing the window only detaches it: the session goes on.
  function closeTerminal() {
    if (terminalAddress === "") return
    Quickshell.execDetached(["hyprctl", "dispatch", 'hl.dsp.window.close({ window = "address:0x' + terminalAddress + '" })'])
  }

  onViewShownChanged: if (viewShown) ensureSession()

  Timer {
    id: hoverDelay
    interval: 150
    onTriggered: root.peeking = true
  }

  Timer {
    interval: 500
    repeat: true
    triggeredOnStart: true
    running: root.viewShown
    onTriggered: if (!capture.running) capture.running = true
  }

  // A click that opened nothing gives the view back to the hover.
  Timer {
    id: attachTimeout
    interval: 4000
    onTriggered: root.attaching = false
  }

  // A terminal that never had the focus would never lose it either.
  Timer {
    id: focusFallback
    interval: 2000
    onTriggered: if (!root.terminalFocused) root.closeTerminal()
  }

  Process {
    id: capture
    command: ["tmux", "-L", "coniglio-ping", "capture-pane", "-p", "-J", "-t", "=ping:"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.showScreen(text)
    }
  }

  // The terminal is known from its first appearance (openwindow), focused
  // when Hyprland says so (activewindowv2), and closed as soon as the focus
  // goes anywhere else.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var data = String(event.data)
      if (event.name === "openwindow") {
        var fields = data.split(",")
        if (fields[2] !== root.terminalClass) return
        root.terminalAddress = fields[0]
        root.terminalFocused = false
        root.attaching = false
        focusFallback.restart()
      } else if (event.name === "activewindowv2") {
        if (root.terminalAddress === "") return
        if (data === root.terminalAddress) root.terminalFocused = true
        else if (root.terminalFocused) root.closeTerminal()
      } else if (event.name === "closewindow") {
        if (data !== root.terminalAddress) return
        root.terminalAddress = ""
        root.terminalFocused = false
      }
    }
  }

  // A popup of the bar of its own, not a PopupCard: those take the bar's one
  // popout slot, so passing over the face would close an open panel.
  PopupWindow {
    visible: root.viewShown && viewAnchor.window !== null
    color: "transparent"
    implicitWidth: root.viewWidth
    implicitHeight: root.viewHeight

    anchor {
      id: viewAnchor
      window: face.QsWindow.window
      edges: Edges.Top | Edges.Left
      gravity: Edges.Bottom | Edges.Right
      rect.width: 1
      rect.height: 1
      onAnchoring: {
        var place = root.viewPlace()
        if (!place) return
        viewAnchor.rect.x = place.x
        viewAnchor.rect.y = place.windowY
      }
    }

    BorderSurface {
      id: viewCard
      anchors.fill: parent
      color: Color.popups.background
      borderSpec: Border.localOrSurfaceSpec("popups", "border", Color.popups.border, Color.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius
      padding: root.viewPadding

      Text {
        id: screenText
        x: viewCard.contentLeftInset
        y: viewCard.contentTopInset
        width: viewCard.width - viewCard.contentLeftInset - viewCard.contentRightInset
        height: viewCard.height - viewCard.contentTopInset - viewCard.contentBottomInset
        clip: true
        textFormat: Text.PlainText
        wrapMode: Text.NoWrap
        text: root.screenCapture !== "" ? root.screenCapture : "starting ping " + root.host + " …"
        color: Color.popups.text
        font.family: root.fontFamily
        font.pixelSize: root.viewFontSize
      }

      FontMetrics {
        id: viewMetrics
        font: screenText.font
      }
    }
  }

  IpcHandler {
    target: "coniglio.ping"
    function open(): void { if (root.terminalAddress === "") root.toggleTerminal() }
    function close(): void { root.closeTerminal() }
    function toggle(): void { root.toggleTerminal() }
    function status(): string {
      return root.host === "" ? "no valid host" : root.host + " " + Latency.label(root.reading, root.latencyMs, false)
    }
  }
}
