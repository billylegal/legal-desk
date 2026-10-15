import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk: 1UP Radio window, dressed in the Nebula skin of 1upradio.com (purple space, glowing 1UP, dashed play ring, equaliser).
// It floats above the dock and stays open while you work; the music is SnapDock's player (sd-radio) and keeps playing when this window is closed.
// Live data comes from legal-radio-info once a second; the buttons run legal-radio. Esc or the X closes the window.
ShellRoot {
  id: rd
  // Nebula palette (the same values as html[data-skin=nebula] on 1upradio.com)
  readonly property color bgC: "#07050F"
  readonly property color accC: "#8B5CF6"
  readonly property color acc2: "#CC8CFF"
  readonly property color txtC: "#E6E1FA"
  readonly property color dimC: "#8E86B0"
  readonly property color lineC: "#47ffffff"
  readonly property string here: Qt.resolvedUrl(".").toString()

  property var info: ({ ok: false, playing: false, paused: false, track: {}, next: [], prev: [], volume: 50, muted: false, elapsed: 0, dur: 0 })
  readonly property bool on: info.playing && !info.paused
  readonly property var tr: info.track || ({})
  property int volDrag: -1
  readonly property int vol: volDrag >= 0 ? volDrag : (info.volume === undefined ? 50 : info.volume)
  function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }
  function clock(t) { var d = new Date(t * 1000); var h = d.getHours(); return ((h % 12) || 12) + ":" + ("0" + d.getMinutes()).slice(-2) + (h < 12 ? " AM" : " PM") }

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

  PanelWindow {
    id: win
    anchors { bottom: true }
    margins.bottom: 118
    implicitWidth: 470; implicitHeight: 640
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "legalradio"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      id: card
      anchors.fill: parent
      radius: 26; color: rd.bgC; clip: true
      border.color: rd.lineC; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()

      // space background
      Image { anchors.fill: parent; source: Qt.resolvedUrl("nebula-bg.jpg"); fillMode: Image.PreserveAspectCrop; opacity: 0.75; smooth: true }
      Rectangle { anchors.fill: parent; color: "#9907050F" }
      Rectangle { anchors.fill: parent; radius: 26; color: "transparent"; border.color: Qt.rgba(0.545, 0.36, 0.96, 0.35); border.width: 1 }

      // twinkling stars
      Repeater {
        model: 14
        Rectangle {
          required property int index
          x: (index * 97 + 31) % 450; y: (index * 61 + 17) % 620; width: index % 3 === 0 ? 2.5 : 1.5; height: width; radius: width / 2; color: "white"
          SequentialAnimation on opacity { loops: Animation.Infinite
            NumberAnimation { from: 0.15; to: 0.9; duration: 1400 + index * 170; easing.type: Easing.InOutSine }
            NumberAnimation { from: 0.9; to: 0.15; duration: 1400 + index * 170; easing.type: Easing.InOutSine } }
        }
      }

      // ---------------- header ----------------
      Item {
        id: head
        x: 0; y: 0; width: parent.width; height: 70
        Rectangle { anchors.fill: parent; color: "#6602030C" }
        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1fffffff" }
        Rectangle {
          x: 18; anchors.verticalCenter: parent.verticalCenter; width: 42; height: 42; radius: 21; color: "transparent"; clip: true
          border.color: "#66ffffff"; border.width: 1
          Image { anchors.fill: parent; source: Qt.resolvedUrl("logo.png"); fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true }
        }
        Row {
          x: 72; anchors.verticalCenter: parent.verticalCenter; spacing: 8
          Text { text: "1UP"; color: rd.accC; font.pixelSize: 26; font.bold: true; font.letterSpacing: 1.6
            layer.enabled: true }
          Text { text: "RADIO"; color: rd.txtC; font.pixelSize: 15; font.weight: Font.Light; font.letterSpacing: 7; anchors.baseline: parent.children[0].baseline }
        }
        Row {
          anchors.right: parent.right; anchors.rightMargin: 62; anchors.verticalCenter: parent.verticalCenter; spacing: 7
          Rectangle { width: 9; height: 9; radius: 4.5; anchors.verticalCenter: parent.verticalCenter; color: rd.on ? "#8dffc7" : "#46567a"
            SequentialAnimation on opacity { running: rd.on; loops: Animation.Infinite; NumberAnimation { to: 0.35; duration: 700 } NumberAnimation { to: 1; duration: 700 } } }
          Text { text: rd.on ? "ON AIR" : "OFF AIR"; color: rd.on ? "#8dffc7" : rd.dimC; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2.6; anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle {
          anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; width: 30; height: 30; radius: 15
          color: xma.containsMouse ? rd.accC : "#0dffffff"; border.color: "#4dffffff"; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: "white"; font.pixelSize: 12 }
          MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
        }
      }

      // ---------------- player ----------------
      Rectangle {
        id: player
        x: 16; y: 84; width: parent.width - 32; height: 330; radius: 26
        border.color: "#33ffffff"; border.width: 1
        gradient: Gradient { orientation: Gradient.Vertical
          GradientStop { position: 0; color: "#16ffffff" } GradientStop { position: 1; color: "#06ffffff" } }

        // equaliser
        Row {
          id: eq
          x: 18; y: 16; width: parent.width - 36; height: 34; spacing: (width - 24 * 3) / 23
          Repeater {
            model: 24
            Item {
              required property int index
              width: 3; height: eq.height
              Rectangle {
                id: bar
                anchors.bottom: parent.bottom; width: 3; radius: 1.5
                height: rd.on ? 6 : 4
                gradient: Gradient { orientation: Gradient.Vertical
                  GradientStop { position: 0; color: rd.accC } GradientStop { position: 1; color: "#008B5CF6" } }
                SequentialAnimation on height { running: rd.on; loops: Animation.Infinite
                  NumberAnimation { to: 8 + ((index * 53) % 26); duration: 260 + (index * 37) % 340; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 4 + ((index * 29) % 9); duration: 280 + (index * 41) % 300; easing.type: Easing.InOutSine } }
              }
            }
          }
        }

        // artwork + titles
        Row {
          x: 18; y: 62; width: parent.width - 36; spacing: 14
          Rectangle {
            width: 86; height: 86; radius: 14; color: "#14ffffff"; clip: true; border.color: "#40ffffff"; border.width: 1
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
              source: rd.tr.id ? "https://i.ytimg.com/vi/" + rd.tr.id + "/mqdefault.jpg" : "" }
            Text { visible: !rd.tr.id; anchors.centerIn: parent; text: "♫"; color: rd.accC; font.pixelSize: 36 }
          }
          Column {
            width: parent.width - 100; spacing: 6
            Text { text: "NOW PLAYING"; color: rd.dimC; font.pixelSize: 10; font.bold: true; font.letterSpacing: 4.4 }
            Text { width: parent.width; text: rd.tr.title ? rd.tr.title : "Press play to tune in"; color: "white"; font.pixelSize: 19; font.weight: Font.Light
              font.capitalization: Font.AllUppercase; font.letterSpacing: 1.2; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
            Text { width: parent.width; text: rd.tr.artist ? rd.tr.artist : "Deep house · melodic · electronic"; color: rd.acc2; font.pixelSize: 12
              font.capitalization: Font.AllUppercase; font.letterSpacing: 2.2; elide: Text.ElideRight }
          }
        }

        // progress
        Item {
          x: 18; y: 168; width: parent.width - 36; height: 30
          Rectangle { y: 6; width: parent.width; height: 2; radius: 1; color: "#2effffff" }
          Rectangle { y: 6; height: 2; radius: 1; color: rd.accC; width: parent.width * Math.min(1, (rd.info.dur > 0 ? rd.info.elapsed / rd.info.dur : 0)) }
          Rectangle { y: 2; height: 10; width: 10; radius: 5; color: "white"; x: Math.max(0, parent.width * Math.min(1, (rd.info.dur > 0 ? rd.info.elapsed / rd.info.dur : 0)) - 5); visible: rd.info.dur > 0 }
          Text { y: 14; text: rd.mmss(rd.info.elapsed); color: rd.dimC; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.5 }
          Text { y: 14; anchors.right: parent.right; text: rd.mmss(rd.info.dur); color: rd.dimC; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.5 }
        }

        // controls
        Row {
          x: 0; y: 210; width: parent.width; height: 84; spacing: 22
          leftPadding: (width - (92 + 74 + 92 + 44)) / 2
          Rectangle {
            width: 92; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
            color: lma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: lma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "LIVE"; color: "white"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3 }
            MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["live"]) }
          }
          Item {
            width: 74; height: 74; anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.centerIn: parent; width: 90; height: 90; radius: 45; color: "transparent"; border.color: Qt.rgba(0.545, 0.36, 0.96, 0.5); border.width: 1
              RotationAnimation on rotation { from: 0; to: 360; duration: 16000; loops: Animation.Infinite; running: true } }
            Rectangle {
              anchors.fill: parent; radius: 37
              color: pma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.3) : Qt.rgba(0.545, 0.36, 0.96, 0.14)
              border.color: Qt.rgba(0.545, 0.36, 0.96, 0.85); border.width: 1
              Canvas {
                anchors.centerIn: parent; width: 28; height: 28
                property bool pl: rd.on
                onPlChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                  var c = getContext("2d"); c.reset(); c.fillStyle = "#8B5CF6"
                  if (pl) { c.fillRect(5, 3, 6, 22); c.fillRect(17, 3, 6, 22) }
                  else { c.beginPath(); c.moveTo(7, 3); c.lineTo(25, 14); c.lineTo(7, 25); c.closePath(); c.fill() }
                }
              }
              MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true
                onClicked: rd.run([rd.info.running ? "toggle" : "play"]) }
            }
          }
          Rectangle {
            width: 92; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
            color: sma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: sma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "STOP"; color: "white"; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3 }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["stop"]) }
          }
          Rectangle {
            width: 44; height: 36; radius: 18; anchors.verticalCenter: parent.verticalCenter
            color: mma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : (rd.info.muted ? Qt.rgba(0.545, 0.36, 0.96, 0.35) : "#0affffff")
            border.color: rd.info.muted || mma.containsMouse ? rd.accC : "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: rd.info.muted ? "" : ""; color: "white"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14 }
            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true; onClicked: rd.run(["mute"]) }
          }
        }

        // volume
        Item {
          x: 18; y: 294; width: parent.width - 36; height: 26
          Text { text: "VOL"; color: rd.accC; font.pixelSize: 11; font.bold: true; font.letterSpacing: 2.6; anchors.verticalCenter: parent.verticalCenter }
          Item {
            id: vs
            x: 44; width: parent.width - 44 - 44; height: parent.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1.5; color: "#2effffff" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 3; radius: 1.5; color: rd.accC; width: parent.width * rd.vol / 100 }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 14; height: 14; radius: 7; color: "white"; x: parent.width * rd.vol / 100 - 7 }
            MouseArea {
              anchors.fill: parent
              function setV(mx) { rd.volDrag = Math.max(0, Math.min(100, Math.round(mx / width * 100))) }
              onPressed: (m) => setV(m.x)
              onPositionChanged: (m) => { if (pressed) setV(m.x) }
              onReleased: { var v = rd.volDrag; rd.run(["volume", "" + v]); volClear.restart() }
            }
            Timer { id: volClear; interval: 1500; onTriggered: rd.volDrag = -1 }
          }
          Text { anchors.right: parent.right; text: rd.vol; color: rd.accC; font.pixelSize: 11; font.bold: true; font.letterSpacing: 1.5; anchors.verticalCenter: parent.verticalCenter }
        }
      }

      // ---------------- up next / just played ----------------
      Row {
        x: 16; y: 428; width: parent.width - 32; height: 168; spacing: 12
        Repeater {
          model: [{ h: "UP NEXT", k: "next" }, { h: "JUST PLAYED", k: "prev" }]
          Rectangle {
            required property var modelData
            width: (parent.width - 12) / 2; height: parent.height; radius: 20
            border.color: "#29ffffff"; border.width: 1
            gradient: Gradient { orientation: Gradient.Vertical
              GradientStop { position: 0; color: "#0eFFFFFF" } GradientStop { position: 1; color: "#03FFFFFF" } }
            Text { x: 14; y: 12; text: modelData.h; color: rd.acc2; font.pixelSize: 11; font.bold: true; font.letterSpacing: 3.6 }
            Column {
              x: 14; y: 34; width: parent.width - 28; spacing: 0
              Repeater {
                model: rd.info[modelData.k] || []
                Item {
                  required property var modelData
                  width: parent.width; height: 32
                  Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#14ffffff" }
                  Text { width: parent.width - 4; anchors.verticalCenter: parent.verticalCenter
                    text: modelData.name ? modelData.name : modelData.title
                    color: "#eaf2ff"; font.pixelSize: 11; font.weight: Font.Light; elide: Text.ElideRight }
                }
              }
            }
          }
        }
      }

      // ---------------- footer ----------------
      Item {
        x: 16; y: 604; width: parent.width - 32; height: 24
        Text { text: "Keep the volume up · Sponsored by BillyLegal.com"; color: rd.dimC; font.pixelSize: 10; font.letterSpacing: 0.6; anchors.verticalCenter: parent.verticalCenter
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rd.open("https://billylegal.com") } }
        Text { anchors.right: parent.right; text: "1upradio.com"; color: rd.acc2; font.pixelSize: 10; font.letterSpacing: 1.2; anchors.verticalCenter: parent.verticalCenter
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: rd.open("https://1upradio.com") } }
      }
    }
  }
}
