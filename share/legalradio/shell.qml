import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk: 1UP Radio player in the Nebula skin of 1upradio.com. Compact, tight, and yours to move: drag it anywhere on the screen.
// Three sizes: press the 1UP Radio button on the dock again (or the size button in the header) to go small -> medium -> large -> closed.
// The size is kept in ~/.cache/dock-radio-size (0, 1, 2), the position in ~/.cache/dock-radio-pos. The music is SnapDock's player (sd-radio)
// and keeps playing when this window is closed. Esc or the X closes it.
ShellRoot {
  id: rd
  // Nebula palette (the same values as html[data-skin=nebula] on 1upradio.com)
  readonly property color bgC: "#07050F"
  readonly property color accC: "#8B5CF6"
  readonly property color acc2: "#CC8CFF"
  readonly property color dimC: "#8E86B0"
  readonly property color lineC: "#47ffffff"

  property int sz: 0                       // 0 small, 1 medium, 2 large
  property var info: ({ ok: false, playing: false, paused: false, track: {}, next: [], prev: [], volume: 50, muted: false, elapsed: 0, dur: 0, running: false })
  readonly property bool on: !!info.playing && !info.paused
  readonly property var tr: info.track || ({})
  readonly property real frac: info.dur > 0 ? Math.min(1, info.elapsed / info.dur) : 0
  property int volDrag: -1
  readonly property int vol: volDrag >= 0 ? volDrag : (info.volume === undefined ? 50 : info.volume)
  function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

  // ---------- live data + commands ----------
  Process {
    id: poll
    command: ["/usr/lib/legal-desk/legal-radio-info"]
    stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); if (r.ok) rd.info = r } catch (e) { } } }
  }
  Timer { interval: 1000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!poll.running) poll.running = true } }
  Process { id: act; property var cmd: []; command: cmd; onExited: { poll.running = false; poll.running = true } }
  function run(a) { act.cmd = ["/usr/lib/legal-desk/legal-radio"].concat(a); act.running = false; act.running = true }
  Process { id: opener; property var cmd: []; command: cmd }
  function open(url) { opener.cmd = ["xdg-open", url]; opener.running = false; opener.running = true }

  // ---------- size (written by legal-radio window each time the dock button is pressed) ----------
  FileView {
    id: szFile
    path: Quickshell.env("HOME") + "/.cache/dock-radio-size"
    printErrors: false
    onLoaded: { var n = parseInt(text()); rd.sz = (n >= 0 && n <= 2) ? n : 0 }
  }
  Timer { interval: 250; running: true; repeat: true; onTriggered: szFile.reload() }
  Process { id: szProc; property var cmd: []; command: cmd }
  function nextSize() { szProc.cmd = ["/usr/lib/legal-desk/legal-radio", "window"]; szProc.running = false; szProc.running = true }

  // ---------- position ----------
  property real px: -1
  property real py: -1
  FileView {
    id: posFile
    path: Quickshell.env("HOME") + "/.cache/dock-radio-pos"
    printErrors: false
    onLoaded: { var a = text().trim().split(/\s+/).map(parseFloat); if (a.length >= 2 && !isNaN(a[0]) && !isNaN(a[1])) { rd.px = a[0]; rd.py = a[1] } }
  }
  Process { id: posSave; property var cmd: []; command: cmd }
  function savePos() { posSave.cmd = ["bash", "-c", "mkdir -p \"$HOME/.cache\" && echo \"$0 $1\" > \"$HOME/.cache/dock-radio-pos\"", "" + Math.round(px), "" + Math.round(py)]; posSave.running = false; posSave.running = true }

  // The window itself never moves: it is a transparent full-screen layer that only takes input where the card is (mask),
  // and the card is dragged inside it. That keeps the drag perfectly smooth (no window being resized or re-placed under the pointer).
  PanelWindow {
    id: win
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region { item: card }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legalradio"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    readonly property real sw: width > 0 ? width : 1920
    readonly property real sh: height > 0 ? height : 1080
    property real pressX: 0
    property real pressY: 0
    property real startX: 0
    property real startY: 0

    Rectangle {
      id: card
      readonly property real cw: rd.sz === 0 ? 330 : (rd.sz === 1 ? 372 : 412)
      readonly property real ch: rd.sz === 0 ? 86 : body.implicitHeight + 20
      width: cw; height: ch
      // the remembered spot, else bottom centre above the dock; always kept on the screen
      x: Math.max(0, Math.min(win.sw - cw, rd.px >= 0 ? rd.px : (win.sw - cw) / 2))
      y: Math.max(0, Math.min(win.sh - ch, rd.py >= 0 ? rd.py : win.sh - ch - 130))
      radius: rd.sz === 0 ? 18 : 22; color: rd.bgC; clip: true
      border.color: rd.lineC; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()

      Image { anchors.fill: parent; source: Qt.resolvedUrl("nebula-bg.jpg"); fillMode: Image.PreserveAspectCrop; opacity: 0.75; smooth: true }
      Rectangle { anchors.fill: parent; color: "#9907050F" }
      Repeater {
        model: 9
        Rectangle {
          required property int index
          x: (index * 97 + 31) % Math.max(10, card.width - 6); y: (index * 61 + 17) % Math.max(10, card.height - 6); width: index % 3 === 0 ? 2.5 : 1.5; height: width; radius: width / 2; color: "white"
          SequentialAnimation on opacity { loops: Animation.Infinite
            NumberAnimation { from: 0.15; to: 0.9; duration: 1400 + index * 170; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: 0.15; duration: 1400 + index * 170; easing.type: Easing.InOutSine } }
        }
      }

      // the whole card is a drag handle (buttons sit on top and take their own clicks)
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton
        cursorShape: Qt.ArrowCursor
        onPressed: (m) => {
          var p = mapToItem(win.contentItem, m.x, m.y)
          win.pressX = p.x; win.pressY = p.y; win.startX = card.x; win.startY = card.y
        }
        onPositionChanged: (m) => {
          if (!pressed) return
          var p = mapToItem(win.contentItem, m.x, m.y)
          rd.px = Math.max(0, Math.min(win.sw - card.width, win.startX + (p.x - win.pressX)))
          rd.py = Math.max(0, Math.min(win.sh - card.height, win.startY + (p.y - win.pressY)))
        }
        onReleased: rd.savePos()
      }

      // ---------------- small: one tight row ----------------
      Item {
        visible: rd.sz === 0
        anchors.fill: parent
        Image { x: 10; y: 10; width: 44; height: 44; source: Qt.resolvedUrl("logo.png"); fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true }
        Column {
          x: 64; y: 10; width: parent.width - 64 - 112; spacing: 2
          Text { width: parent.width; text: rd.tr.title ? rd.tr.title : "Press play to tune in"; color: "white"; font.pixelSize: 12; font.weight: Font.Medium; elide: Text.ElideRight }
          Text { width: parent.width; text: rd.tr.artist ? rd.tr.artist : "1UP Radio"; color: rd.acc2; font.pixelSize: 10; font.capitalization: Font.AllUppercase; font.letterSpacing: 1.4; elide: Text.ElideRight }
          Row { spacing: 2; height: 14
            Repeater { model: 16
              Item { required property int index; width: 3; height: 14
                Rectangle { anchors.bottom: parent.bottom; width: 3; radius: 1.5; color: rd.accC; height: rd.on ? 3 : 2
                  SequentialAnimation on height { running: rd.on; loops: Animation.Infinite
                    NumberAnimation { to: 4 + ((index * 53) % 11); duration: 260 + (index * 37) % 340; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 2 + ((index * 29) % 5); duration: 280 + (index * 41) % 300; easing.type: Easing.InOutSine } } } } }
          }
        }
        // thin progress along the bottom
        Rectangle { x: 10; y: parent.height - 12; width: parent.width - 20; height: 2; radius: 1; color: "#2effffff" }
        Rectangle { x: 10; y: parent.height - 12; width: (parent.width - 20) * rd.frac; height: 2; radius: 1; color: rd.accC }
        Rectangle {
          x: parent.width - 100; y: 17; width: 42; height: 42; radius: 21
          color: spma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.32) : Qt.rgba(0.545, 0.36, 0.96, 0.16); border.color: Qt.rgba(0.545, 0.36, 0.96, 0.85); border.width: 1
          Canvas { anchors.centerIn: parent; width: 18; height: 18; property bool pl: rd.on; onPlChanged: requestPaint(); Component.onCompleted: requestPaint()
            onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = "#8B5CF6"
              if (pl) { c.fillRect(3, 2, 4, 14); c.fillRect(11, 2, 4, 14) } else { c.beginPath(); c.moveTo(4, 2); c.lineTo(16, 9); c.lineTo(4, 16); c.closePath(); c.fill() } } }
          MouseArea { id: spma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run([rd.info.running ? "toggle" : "play"]) }
        }
        Rectangle {
          x: parent.width - 50; y: 22; width: 32; height: 32; radius: 16
          color: sbma.containsMouse ? rd.accC : "#0dffffff"; border.color: "#4dffffff"; border.width: 1
          Text { anchors.centerIn: parent; text: "⤢"; color: "white"; font.pixelSize: 14 }
          MouseArea { id: sbma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.nextSize() }
        }
        Rectangle {
          x: parent.width - 24; y: 6; width: 18; height: 18; radius: 9
          color: sxma.containsMouse ? rd.accC : "#0dffffff"; border.color: "#4dffffff"; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 9 }
          MouseArea { id: sxma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
        }
      }

      // ---------------- medium + large ----------------
      Column {
        id: body
        visible: rd.sz > 0
        x: 12; y: 10; width: parent.width - 24; spacing: 8

        // header
        Item {
          width: parent.width; height: 34
          Image { width: 32; height: 32; anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl("logo.png"); fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true }
          Row {
            x: 40; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Text { id: oneT; text: "1UP"; color: rd.accC; font.pixelSize: 20; font.bold: true; font.letterSpacing: 1.2 }
            Text { text: "RADIO"; color: "#E6E1FA"; font.pixelSize: 12; font.weight: Font.Light; font.letterSpacing: 5; anchors.baseline: oneT.baseline }
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 5
            Rectangle { width: 7; height: 7; radius: 3.5; anchors.verticalCenter: parent.verticalCenter; color: rd.on ? "#8dffc7" : "#46567a" }
            Text { text: rd.on ? "ON AIR" : "OFF AIR"; color: rd.on ? "#8dffc7" : rd.dimC; font.pixelSize: 9; font.bold: true; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
          }
          Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 30; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; radius: 12
            color: bma.containsMouse ? rd.accC : "#0dffffff"; border.color: "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "⤢"; color: "white"; font.pixelSize: 12 }
            MouseArea { id: bma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.nextSize() }
          }
          Rectangle {
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; width: 24; height: 24; radius: 12
            color: xma.containsMouse ? rd.accC : "#0dffffff"; border.color: "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 10 }
            MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
          }
        }

        // equaliser
        Row {
          id: eq
          width: parent.width; height: rd.sz === 2 ? 24 : 18; spacing: (width - 24 * 3) / 23
          Repeater {
            model: 24
            Item {
              required property int index
              width: 3; height: eq.height
              Rectangle {
                anchors.bottom: parent.bottom; width: 3; radius: 1.5; height: rd.on ? 5 : 3
                gradient: Gradient { orientation: Gradient.Vertical
                  GradientStop { position: 0; color: rd.accC } GradientStop { position: 1; color: "#008B5CF6" } }
                SequentialAnimation on height { running: rd.on; loops: Animation.Infinite
                  NumberAnimation { to: 5 + ((index * 53) % (eq.height - 6)); duration: 260 + (index * 37) % 340; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 3 + ((index * 29) % 7); duration: 280 + (index * 41) % 300; easing.type: Easing.InOutSine } }
              }
            }
          }
        }

        // now playing
        Row {
          width: parent.width; spacing: 10
          Rectangle {
            width: rd.sz === 2 ? 76 : 60; height: width; radius: 12; color: "#14ffffff"; clip: true; border.color: "#40ffffff"; border.width: 1
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
              source: rd.tr.id ? "https://i.ytimg.com/vi/" + rd.tr.id + "/mqdefault.jpg" : "" }
            Text { visible: !rd.tr.id; anchors.centerIn: parent; text: "♫"; color: rd.accC; font.pixelSize: 26 }
          }
          Column {
            width: parent.width - (rd.sz === 2 ? 86 : 70); spacing: 3
            Text { text: "NOW PLAYING"; color: rd.dimC; font.pixelSize: 9; font.bold: true; font.letterSpacing: 3.6 }
            Text { width: parent.width; text: rd.tr.title ? rd.tr.title : "Press play to tune in"; color: "white"; font.pixelSize: rd.sz === 2 ? 16 : 14; font.weight: Font.Light
              font.capitalization: Font.AllUppercase; font.letterSpacing: 0.8; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
            Text { width: parent.width; text: rd.tr.artist ? rd.tr.artist : "Deep house · melodic · electronic"; color: rd.acc2; font.pixelSize: 11
              font.capitalization: Font.AllUppercase; font.letterSpacing: 1.6; elide: Text.ElideRight }
          }
        }

        // progress
        Item {
          width: parent.width; height: 22
          Rectangle { y: 4; width: parent.width; height: 2; radius: 1; color: "#2effffff" }
          Rectangle { y: 4; height: 2; radius: 1; color: rd.accC; width: parent.width * rd.frac }
          Rectangle { y: 1; width: 8; height: 8; radius: 4; color: "white"; x: Math.max(0, parent.width * rd.frac - 4); visible: rd.info.dur > 0 }
          Text { y: 11; text: rd.mmss(rd.info.elapsed); color: rd.dimC; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }
          Text { y: 11; anchors.right: parent.right; text: rd.mmss(rd.info.dur); color: rd.dimC; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.2 }
        }

        // controls
        Item {
          width: parent.width; height: 52
          Row {
            anchors.centerIn: parent; spacing: 12
            Rectangle {
              width: 64; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
              color: lma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: lma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
              Text { anchors.centerIn: parent; text: "LIVE"; color: "white"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.4 }
              MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["live"]) }
            }
            Item {
              width: 48; height: 48; anchors.verticalCenter: parent.verticalCenter
              Rectangle { anchors.centerIn: parent; width: 58; height: 58; radius: 29; color: "transparent"; border.color: Qt.rgba(0.545, 0.36, 0.96, 0.5); border.width: 1
                RotationAnimation on rotation { from: 0; to: 360; duration: 16000; loops: Animation.Infinite; running: true } }
              Rectangle {
                anchors.fill: parent; radius: 24
                color: pma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.3) : Qt.rgba(0.545, 0.36, 0.96, 0.14); border.color: Qt.rgba(0.545, 0.36, 0.96, 0.85); border.width: 1
                Canvas { anchors.centerIn: parent; width: 20; height: 20; property bool pl: rd.on; onPlChanged: requestPaint(); Component.onCompleted: requestPaint()
                  onPaint: { var c = getContext("2d"); c.reset(); c.fillStyle = "#8B5CF6"
                    if (pl) { c.fillRect(3, 2, 5, 16); c.fillRect(12, 2, 5, 16) } else { c.beginPath(); c.moveTo(5, 2); c.lineTo(18, 10); c.lineTo(5, 18); c.closePath(); c.fill() } } }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run([rd.info.running ? "toggle" : "play"]) }
              }
            }
            Rectangle {
              width: 64; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
              color: sma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: sma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
              Text { anchors.centerIn: parent; text: "STOP"; color: "white"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 2.4 }
              MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["stop"]) }
            }
            Rectangle {
              width: 36; height: 28; radius: 14; anchors.verticalCenter: parent.verticalCenter
              color: mma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : (rd.info.muted ? Qt.rgba(0.545, 0.36, 0.96, 0.35) : "#0affffff")
              border.color: rd.info.muted || mma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
              Text { anchors.centerIn: parent; text: rd.info.muted ? "" : ""; color: "white"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12 }
              MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["mute"]) }
            }
          }
        }

        // volume
        Item {
          width: parent.width; height: 20
          Text { text: "VOL"; color: rd.accC; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.2; anchors.verticalCenter: parent.verticalCenter }
          Item {
            x: 36; width: parent.width - 36 - 32; height: parent.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1.5; color: "#2effffff" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 3; radius: 1.5; color: rd.accC; width: parent.width * rd.vol / 100 }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: "white"; x: parent.width * rd.vol / 100 - 6 }
            MouseArea {
              anchors.fill: parent
              function setV(mx) { rd.volDrag = Math.max(0, Math.min(100, Math.round(mx / width * 100))) }
              onPressed: (m) => setV(m.x)
              onPositionChanged: (m) => { if (pressed) setV(m.x) }
              onReleased: { rd.run(["volume", "" + rd.volDrag]); volClear.restart() }
            }
            Timer { id: volClear; interval: 1500; onTriggered: rd.volDrag = -1 }
          }
          Text { anchors.right: parent.right; text: rd.vol; color: rd.accC; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        // up next / just played (large only)
        Row {
          visible: rd.sz === 2
          width: parent.width; height: visible ? 138 : 0; spacing: 8
          Repeater {
            model: [{ h: "UP NEXT", k: "next" }, { h: "JUST PLAYED", k: "prev" }]
            Rectangle {
              required property var modelData
              width: (parent.width - 8) / 2; height: 138; radius: 16
              border.color: "#29ffffff"; border.width: 1; color: "#08ffffff"
              Text { x: 10; y: 8; text: modelData.h; color: rd.acc2; font.pixelSize: 9; font.bold: true; font.letterSpacing: 3 }
              Column {
                x: 10; y: 26; width: parent.width - 20
                Repeater {
                  model: rd.info[modelData.k] || []
                  Item {
                    required property var modelData
                    width: parent.width; height: 26
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#14ffffff" }
                    Text { width: parent.width - 2; anchors.verticalCenter: parent.verticalCenter; text: modelData.name ? modelData.name : modelData.title
                      color: "#eaf2ff"; font.pixelSize: 10; font.weight: Font.Light; elide: Text.ElideRight }
                  }
                }
              }
            }
          }
        }

        // footer: after the name comes the Billy Legal sticker
        Item {
          width: parent.width; height: 34
          Row {
            anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Text { anchors.verticalCenter: parent.verticalCenter; text: "Keep the volume up · Sponsored by"; color: rd.dimC; font.pixelSize: 9 }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "BillyLegal.com"; color: rd.acc2; font.pixelSize: 10; font.bold: true
              MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: rd.open("https://billylegal.com") } }
            Image { height: 32; width: 23; anchors.verticalCenter: parent.verticalCenter; source: Qt.resolvedUrl("billy-sticker.png"); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true
              MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: rd.open("https://billylegal.com") } }
          }
          Text { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: "1upradio.com"; color: rd.acc2; font.pixelSize: 9; font.letterSpacing: 1
            MouseArea { anchors.fill: parent; cursorShape: Qt.ArrowCursor; onClicked: rd.open("https://1upradio.com") } }
        }
      }
    }
  }
}
