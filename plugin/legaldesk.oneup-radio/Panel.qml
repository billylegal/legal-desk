import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

// 1UP Radio (Legal Desk): bar icon + now-playing ticker, and a popup player in the Nebula skin of 1upradio.com.
// Data: `legal-desk radio-info` (SnapDock's sd-radio state, once a second while the popup is open, every 4 s otherwise).
// Buttons: `legal-desk radio ...`. Left click opens the popup (and starts the radio if it is off), middle click = play/pause, right click = stop, wheel = volume.
// shell.json options on this widget: "showTitle": false, "maxTitleWidth": 150.
Panel {
  id: root
  moduleName: "legaldesk.oneup-radio"
  ipcTarget: "oneup-radio"

  // Nebula palette (html[data-skin=nebula] on 1upradio.com)
  readonly property color nBg: "#07050F"
  readonly property color nAcc: "#8B5CF6"
  readonly property color nAcc2: "#CC8CFF"
  readonly property color nDim: "#8E86B0"

  property var info: ({ ok: false, playing: false, paused: false, track: {}, next: [], prev: [], volume: 50, muted: false, elapsed: 0, dur: 0, running: false })
  readonly property bool on: !!info.playing && !info.paused
  readonly property var tr: info.track || ({})
  property int volDrag: -1
  readonly property int vol: volDrag >= 0 ? volDrag : (info.volume === undefined ? 50 : info.volume)
  function mmss(s) { s = Math.max(0, Math.floor(s || 0)); return Math.floor(s / 60) + ":" + ("0" + (s % 60)).slice(-2) }

  Process {
    id: poll
    command: ["legal-desk", "radio-info"]
    stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); if (r.ok) root.info = r } catch (e) { } } }
  }
  Timer { interval: root.opened ? 1000 : 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!poll.running) poll.running = true } }
  Process { id: act; property var cmd: []; command: cmd; onExited: { poll.running = false; poll.running = true } }
  function run(a) { act.cmd = ["legal-desk", "radio"].concat(a); act.running = false; act.running = true }
  function playPause() { run([info.running ? "toggle" : "play"]) }
  function setVolume(v) { volDrag = Math.max(0, Math.min(100, Math.round(v))); run(["volume", "" + volDrag]); volClear.restart() }
  Timer { id: volClear; interval: 1500; onTriggered: root.volDrag = -1 }
  Process { id: opener; property var cmd: []; command: cmd }
  function openUrl(u) { opener.cmd = ["xdg-open", u]; opener.running = false; opener.running = true }
  onOpenedChanged: { if (opened && !info.playing) run(["play"]) }

  // ---------------------------------------------------------------- bar
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property string barTitle: on && tr.title ? ((tr.artist ? tr.artist + " – " : "") + tr.title) : ""
  readonly property bool showBarTitle: setting("showTitle", true) && !vertical && barTitle !== ""
  readonly property real maxTitleWidth: Style.space(setting("maxTitleWidth", 150))
  implicitWidth: button.implicitWidth + (showBarTitle ? titleClip.width + Style.space(4) : 0)
  readonly property real openPanelIndicatorWidth: 0.4
  implicitHeight: button.implicitHeight

  Item {
    id: titleClip
    visible: root.showBarTitle
    anchors.right: parent.right
    anchors.rightMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(root.maxTitleWidth, titleText.implicitWidth)
    height: titleText.implicitHeight
    clip: true
    Text {
      id: titleText
      anchors.verticalCenter: parent.verticalCenter
      text: root.barTitle
      color: root.barForeground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: root.bar && root.bar.fontPixelSize ? root.bar.fontPixelSize : Style.space(12)
      x: 0
      SequentialAnimation on x {
        running: titleText.implicitWidth > titleClip.width && titleClip.visible && !root.opened
        loops: Animation.Infinite
        PauseAnimation { duration: 2500 }
        NumberAnimation { to: -(titleText.implicitWidth - titleClip.width); duration: Math.max(2000, (titleText.implicitWidth - titleClip.width) * 1000 / 38) }
        PauseAnimation { duration: 1500 }
        NumberAnimation { to: 0; duration: 400 }
      }
    }
    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
      onClicked: function(m) { if (m.button === Qt.MiddleButton) root.playPause(); else if (m.button === Qt.RightButton) root.run(["stop"]); else root.toggle() }
      onWheel: function(w) { root.setVolume(root.vol + (w.angleDelta.y > 0 ? 5 : -5)) }
    }
  }

  BarIconButton {
    id: button
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    bar: root.bar
    tooltipText: root.tr.title ? "1UP Radio · " + (root.on ? "" : "paused · ") + root.tr.title : "1UP Radio"
    iconComponent: Component {
      Item {
        id: glyph
        implicitWidth: 16; implicitHeight: 16
        property real phase: 0
        NumberAnimation on phase { running: root.on && glyph.visible; from: 0; to: Math.PI * 2; duration: 1500; loops: Animation.Infinite }
        Repeater {
          model: 5
          Rectangle {
            required property int index
            readonly property real base: [0.4, 0.75, 1.0, 0.65, 0.35][index]
            width: 2; radius: 1; x: index * 3.4
            height: 16 * base * (root.on ? 0.45 + 0.55 * Math.abs(Math.sin(glyph.phase + index * 1.3)) : 1)
            anchors.verticalCenter: parent.verticalCenter
            color: root.on ? root.nAcc2 : (root.bar ? root.bar.barForeground : "white")
          }
        }
      }
    }
    onPressed: function(b) { if (b === Qt.MiddleButton) root.playPause(); else if (b === Qt.RightButton) root.run(["stop"]); else root.toggle() }
    onWheelMoved: function(d) { root.setVolume(root.vol + (d > 0 ? 5 : -5)) }
  }

  // ---------------------------------------------------------------- popup
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keys
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(Style.space(508))

    PanelKeyCatcher {
      id: keys
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActivateRequested: root.playPause()
      onTextKey: function(t) {
        if (t === "s" || t === "S") root.run(["stop"])
        else if (t === "l" || t === "L") root.run(["live"])
        else if (t === "m" || t === "M") root.run(["mute"])
        else if (t === "+" || t === "=") root.setVolume(root.vol + 5)
        else if (t === "-" || t === "_") root.setVolume(root.vol - 5)
      }

      Rectangle {
        id: card
        anchors.fill: parent
        radius: 18; color: root.nBg; clip: true
        border.color: "#47ffffff"; border.width: 1

        Image { anchors.fill: parent; source: Qt.resolvedUrl("nebula-bg.jpg"); fillMode: Image.PreserveAspectCrop; opacity: 0.75; smooth: true }
        Rectangle { anchors.fill: parent; color: "#9907050F" }
        Repeater {
          model: 10
          Rectangle {
            required property int index
            x: (index * 97 + 31) % (card.width - 6); y: (index * 61 + 17) % (card.height - 6); width: index % 3 === 0 ? 2.5 : 1.5; height: width; radius: width / 2; color: "white"
            SequentialAnimation on opacity { running: root.opened; loops: Animation.Infinite
              NumberAnimation { from: 0.15; to: 0.9; duration: 1400 + index * 170; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.9; to: 0.15; duration: 1400 + index * 170; easing.type: Easing.InOutSine } }
          }
        }

        // header
        Item {
          x: 0; y: 0; width: parent.width; height: 54
          Rectangle { anchors.fill: parent; color: "#6602030C" }
          Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#1fffffff" }
          Image { x: 14; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 34; source: Qt.resolvedUrl("logo.png"); fillMode: Image.PreserveAspectCrop; smooth: true; mipmap: true }
          Row {
            x: 58; anchors.verticalCenter: parent.verticalCenter; spacing: 7
            Text { id: oneT; text: "1UP"; color: root.nAcc; font.pixelSize: 22; font.bold: true; font.letterSpacing: 1.4 }
            Text { text: "RADIO"; color: "#E6E1FA"; font.pixelSize: 13; font.weight: Font.Light; font.letterSpacing: 6; anchors.baseline: oneT.baseline }
          }
          Row {
            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 6
            Rectangle { width: 8; height: 8; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: root.on ? "#8dffc7" : "#46567a" }
            Text { text: root.on ? "ON AIR" : "OFF AIR"; color: root.on ? "#8dffc7" : root.nDim; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.4; anchors.verticalCenter: parent.verticalCenter }
          }
        }

        // equaliser
        Row {
          id: eq
          x: 18; y: 66; width: parent.width - 36; height: 26; spacing: (width - 20 * 3) / 19
          Repeater {
            model: 20
            Item {
              required property int index
              width: 3; height: eq.height
              Rectangle {
                anchors.bottom: parent.bottom; width: 3; radius: 1.5; height: root.on ? 5 : 3
                gradient: Gradient { orientation: Gradient.Vertical
                  GradientStop { position: 0; color: root.nAcc } GradientStop { position: 1; color: "#008B5CF6" } }
                SequentialAnimation on height { running: root.on && root.opened; loops: Animation.Infinite
                  NumberAnimation { to: 6 + ((index * 53) % 20); duration: 260 + (index * 37) % 340; easing.type: Easing.InOutSine }
                  NumberAnimation { to: 3 + ((index * 29) % 7); duration: 280 + (index * 41) % 300; easing.type: Easing.InOutSine } }
              }
            }
          }
        }

        // now playing
        Row {
          x: 18; y: 100; width: parent.width - 36; spacing: 12
          Rectangle {
            width: 72; height: 72; radius: 12; color: "#14ffffff"; clip: true; border.color: "#40ffffff"; border.width: 1
            Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop; smooth: true; asynchronous: true
              source: root.tr.id ? "https://i.ytimg.com/vi/" + root.tr.id + "/mqdefault.jpg" : "" }
            Text { visible: !root.tr.id; anchors.centerIn: parent; text: "♫"; color: root.nAcc; font.pixelSize: 30 }
          }
          Column {
            width: parent.width - 84; spacing: 5
            Text { text: "NOW PLAYING"; color: root.nDim; font.pixelSize: 9; font.bold: true; font.letterSpacing: 3.8 }
            Text { width: parent.width; text: root.tr.title ? root.tr.title : "Press play to tune in"; color: "white"; font.pixelSize: 15; font.weight: Font.Light
              font.capitalization: Font.AllUppercase; font.letterSpacing: 1; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight }
            Text { width: parent.width; text: root.tr.artist ? root.tr.artist : "Deep house · melodic · electronic"; color: root.nAcc2; font.pixelSize: 11
              font.capitalization: Font.AllUppercase; font.letterSpacing: 1.8; elide: Text.ElideRight }
          }
        }

        // progress
        Item {
          x: 18; y: 184; width: parent.width - 36; height: 26
          Rectangle { y: 5; width: parent.width; height: 2; radius: 1; color: "#2effffff" }
          Rectangle { y: 5; height: 2; radius: 1; color: root.nAcc; width: parent.width * Math.min(1, (root.info.dur > 0 ? root.info.elapsed / root.info.dur : 0)) }
          Text { y: 11; text: root.mmss(root.info.elapsed); color: root.nDim; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4 }
          Text { y: 11; anchors.right: parent.right; text: root.mmss(root.info.dur); color: root.nDim; font.pixelSize: 10; font.bold: true; font.letterSpacing: 1.4 }
        }

        // controls
        Row {
          y: 214; x: (parent.width - width) / 2; height: 64; spacing: 18
          Rectangle {
            width: 78; height: 32; radius: 16; anchors.verticalCenter: parent.verticalCenter
            color: lma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: lma.containsMouse ? root.nAcc : "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "LIVE"; color: "white"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.6 }
            MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: root.run(["live"]) }
          }
          Item {
            width: 60; height: 60; anchors.verticalCenter: parent.verticalCenter
            Rectangle { anchors.centerIn: parent; width: 74; height: 74; radius: 37; color: "transparent"; border.color: Qt.rgba(0.545, 0.36, 0.96, 0.5); border.width: 1
              RotationAnimation on rotation { from: 0; to: 360; duration: 16000; loops: Animation.Infinite; running: root.opened } }
            Rectangle {
              anchors.fill: parent; radius: 30
              color: pma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.3) : Qt.rgba(0.545, 0.36, 0.96, 0.14)
              border.color: Qt.rgba(0.545, 0.36, 0.96, 0.85); border.width: 1
              Canvas {
                anchors.centerIn: parent; width: 24; height: 24
                property bool pl: root.on
                onPlChanged: requestPaint()
                Component.onCompleted: requestPaint()
                onPaint: {
                  var c = getContext("2d"); c.reset(); c.fillStyle = "#8B5CF6"
                  if (pl) { c.fillRect(4, 3, 5, 18); c.fillRect(15, 3, 5, 18) }
                  else { c.beginPath(); c.moveTo(6, 3); c.lineTo(21, 12); c.lineTo(6, 21); c.closePath(); c.fill() }
                }
              }
              MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: root.playPause() }
            }
          }
          Rectangle {
            width: 78; height: 32; radius: 16; anchors.verticalCenter: parent.verticalCenter
            color: sma.containsMouse ? Qt.rgba(0.545, 0.36, 0.96, 0.22) : "#0affffff"; border.color: sma.containsMouse ? root.nAcc : "#4dffffff"; border.width: 1
            Text { anchors.centerIn: parent; text: "STOP"; color: "white"; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.6 }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: root.run(["stop"]) }
          }
        }

        // volume
        Item {
          x: 18; y: 284; width: parent.width - 36; height: 24
          Text { text: "VOL"; color: root.nAcc; font.pixelSize: 10; font.bold: true; font.letterSpacing: 2.4; anchors.verticalCenter: parent.verticalCenter }
          Item {
            x: 40; width: parent.width - 40 - 38; height: parent.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 3; radius: 1.5; color: "#2effffff" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 3; radius: 1.5; color: root.nAcc; width: parent.width * root.vol / 100 }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 13; height: 13; radius: 6.5; color: "white"; x: parent.width * root.vol / 100 - 6.5 }
            MouseArea {
              anchors.fill: parent
              onPressed: function(m) { root.volDrag = Math.max(0, Math.min(100, Math.round(m.x / width * 100))) }
              onPositionChanged: function(m) { if (pressed) root.volDrag = Math.max(0, Math.min(100, Math.round(m.x / width * 100))) }
              onReleased: root.setVolume(root.volDrag)
            }
          }
          Text { anchors.right: parent.right; text: root.vol; color: root.nAcc; font.pixelSize: 10; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
        }

        // up next / just played
        Row {
          x: 14; y: 322; width: parent.width - 28; height: 150; spacing: 10
          Repeater {
            model: [{ h: "UP NEXT", k: "next" }, { h: "JUST PLAYED", k: "prev" }]
            Rectangle {
              required property var modelData
              width: (parent.width - 10) / 2; height: parent.height; radius: 16
              border.color: "#29ffffff"; border.width: 1; color: "#08ffffff"
              Text { x: 12; y: 10; text: modelData.h; color: root.nAcc2; font.pixelSize: 10; font.bold: true; font.letterSpacing: 3.2 }
              Column {
                x: 12; y: 30; width: parent.width - 24
                Repeater {
                  model: root.info[modelData.k] || []
                  Item {
                    required property var modelData
                    width: parent.width; height: 28
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#14ffffff" }
                    Text { width: parent.width - 2; anchors.verticalCenter: parent.verticalCenter; text: modelData.name ? modelData.name : modelData.title
                      color: "#eaf2ff"; font.pixelSize: 10; font.weight: Font.Light; elide: Text.ElideRight }
                  }
                }
              }
            }
          }
        }

        // footer
        Item {
          x: 14; y: 482; width: parent.width - 28; height: 20
          Text { text: "Keep the volume up · Sponsored by BillyLegal.com"; color: root.nDim; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl("https://billylegal.com") } }
          Text { anchors.right: parent.right; text: "1upradio.com"; color: root.nAcc2; font.pixelSize: 9; anchors.verticalCenter: parent.verticalCenter
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openUrl("https://1upradio.com") } }
        }
      }
    }
  }
}
