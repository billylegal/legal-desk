import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Tiny pill in the top-right corner while a window is in true full screen (the title bar is hidden then):
// one button back to a normal window, one to close it.
ShellRoot {
  id: root
  property bool full: false
  property color pBg: "#0B0818"
  property color pAcc: "#8B5CF6"
  property color pTxt: "#E6E1FA"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) root.pBg = c.bg
      if (c.acc) root.pAcc = c.acc
      if (c.txt) root.pTxt = c.txt
    }
  }
  Process {
    id: poll
    command: ["sh", "-c", "hyprctl activewindow -j 2>/dev/null | grep -o '\"fullscreen\": [0-9]' | head -n1"]
    stdout: StdioCollector { onStreamFinished: root.full = text.trim().endsWith("2") }
  }
  Timer { interval: 400; running: true; repeat: true; onTriggered: if (!poll.running) poll.running = true }
  Process { id: act }
  function run(cmd) { act.command = ["sh", "-c", cmd]; act.running = true }

  PanelWindow {
    visible: root.full
    anchors { top: true; right: true }
    margins { top: 8; right: 10 }
    implicitWidth: 96
    implicitHeight: 32
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "fsbar"
    Rectangle {
      anchors.fill: parent
      radius: 6
      color: root.pBg
      opacity: 0.92
      border.color: root.pAcc
      border.width: 1
      Row {
        anchors.centerIn: parent
        spacing: 10
        Rectangle {
          width: 36; height: 22; radius: 4; color: ma1.containsMouse ? root.pAcc : "transparent"
          Text { anchors.centerIn: parent; text: "⤡"; color: ma1.containsMouse ? root.pBg : root.pTxt; font.pixelSize: 15 }
          MouseArea { id: ma1; anchors.fill: parent; hoverEnabled: true
            onClicked: root.run("hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = \"fullscreen\" })'") }
        }
        Rectangle {
          width: 36; height: 22; radius: 4; color: ma2.containsMouse ? "#ff5f57" : "transparent"
          Text { anchors.centerIn: parent; text: "✕"; color: ma2.containsMouse ? "#4d0000" : root.pTxt; font.pixelSize: 14 }
          MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true
            onClicked: root.run("hyprctl dispatch 'hl.dsp.window.close()'") }
        }
      }
    }
  }
}
