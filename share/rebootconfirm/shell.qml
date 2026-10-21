import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// "Do you really want to ...?" popup for Restart / Shut down. Centered on screen (from the dock menu) or just above a dock icon (RC_X set).
ShellRoot {
  id: rc
  // Colours follow the chosen dock skin (~/.cache/dock-menu-colors); default = Nebula.
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    blockLoading: true   // read before the window opens: no default-colour flash
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) rc.bgC = c.bg
      if (c.acc) rc.accC = c.acc
      if (c.txt) rc.txtC = c.txt
      if (c.sel) rc.selC = c.sel
    }
  }
  // Corner radius of the skin (~/.cache/drawer-shape, written by macdock-skin), the same shape the app drawer uses.
  property int shapeR: 14
  FileView {
    path: Quickshell.env("HOME") + "/.cache/drawer-shape"; printErrors: false; blockLoading: true
    onLoaded: { var v = parseInt(text().trim()); if (!isNaN(v)) rc.shapeR = Math.max(0, Math.min(v, 24)) }
  }
  readonly property string action: Quickshell.env("RC_ACTION") === "shutdown" ? "shutdown" : "reboot"
  readonly property bool nearIcon: (Quickshell.env("RC_X") || "") !== ""
  property int cx: parseInt(Quickshell.env("RC_X") || "960")
  readonly property string question: action === "shutdown" ? "Do you really want to shut down?" : "Do you really want to reboot?"
  readonly property string verb: action === "shutdown" ? "Shut down" : "Reboot"

  Process { id: power; command: ["omarchy", "system", action]; onExited: Qt.quit() }

  PanelWindow {
    anchors { bottom: nearIcon; left: nearIcon }
    margins { left: Math.max(8, cx - 150); bottom: parseInt(Quickshell.env("RC_B") || "72") }
    implicitWidth: 300; implicitHeight: 104
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rebootconfirm"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent; radius: rc.shapeR
      color: rc.bgC; border.color: rc.accC; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()

      Text {
        y: 16; anchors.horizontalCenter: parent.horizontalCenter
        text: question
        color: rc.txtC; font.pixelSize: 15; font.bold: true
      }
      Row {
        y: 56; anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
        Rectangle {
          width: 110; height: 34; radius: Math.min(rc.shapeR, 10)
          color: cma.containsMouse ? rc.selC : Qt.darker(rc.selC, 1.4); border.color: rc.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "Cancel"; color: rc.txtC; font.pixelSize: 14 }
          MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
        }
        Rectangle {
          width: 110; height: 34; radius: Math.min(rc.shapeR, 10)
          color: rma.containsMouse ? rc.accC : rc.selC; border.color: rc.accC; border.width: 1
          Text { anchors.centerIn: parent; text: verb; color: rma.containsMouse ? rc.bgC : rc.accC; font.pixelSize: 14; font.bold: true }
          MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: power.running = true }
        }
      }
    }
  }
}
