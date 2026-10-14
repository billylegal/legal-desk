import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// "Move to desktop" picker: one popup with 1..5, opened from the title-bar desktop button (see ~/.local/bin/win-desktop-pick).
ShellRoot {
  id: dp
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) dp.bgC = c.bg
      if (c.acc) dp.accC = c.acc
      if (c.txt) dp.txtC = c.txt
      if (c.sel) dp.selC = c.sel
    }
  }
  readonly property string addr: Quickshell.env("DP_ADDR") || ""
  readonly property int curWs: parseInt(Quickshell.env("DP_WS") || "0")
  property int px: parseInt(Quickshell.env("DP_X") || "100")
  property int py: parseInt(Quickshell.env("DP_Y") || "100")
  property int sw: parseInt(Quickshell.env("DP_W") || "1920")
  property int sh: parseInt(Quickshell.env("DP_H") || "1080")
  property int target: 0

  Process {
    id: mover
    command: ["hyprctl", "dispatch", "hl.dsp.window.move({ workspace = \"" + dp.target + "\", window = \"address:" + dp.addr + "\", follow = false })"]
    onExited: Qt.quit()
  }
  Timer { interval: 20000; running: true; onTriggered: Qt.quit() }

  PanelWindow {
    anchors { top: true; left: true }
    margins { left: Math.max(6, Math.min(dp.sw - 268 - 6, dp.px - 134)); top: Math.max(6, Math.min(dp.sh - 92 - 6, dp.py + 14)) }
    implicitWidth: 268; implicitHeight: 92
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "deskpick"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent; radius: 14
      color: dp.bgC; border.color: dp.accC; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()
      Text {
        y: 10; anchors.horizontalCenter: parent.horizontalCenter
        text: "Move window to desktop"; color: dp.txtC; font.pixelSize: 13; font.bold: true
      }
      Row {
        y: 38; anchors.horizontalCenter: parent.horizontalCenter; spacing: 10
        Repeater {
          model: 5
          Rectangle {
            width: 38; height: 38; radius: 19
            color: ma.containsMouse ? dp.accC : (index + 1 === dp.curWs ? dp.selC : "transparent")
            border.color: dp.accC; border.width: 1
            Text { anchors.centerIn: parent; text: index + 1; font.pixelSize: 16; font.bold: true
                   color: ma.containsMouse ? dp.bgC : dp.txtC }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true
                        onClicked: { dp.target = index + 1; mover.running = true } }
          }
        }
      }
    }
  }
}
