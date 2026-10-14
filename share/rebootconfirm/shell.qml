import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// "Do you really want to ...?" popup for Restart / Shut down. Centered on screen (from the dock menu) or just above a dock icon (RC_X set).
ShellRoot {
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
      anchors.fill: parent; radius: 14
      color: "#111c18"; border.color: "#C1C497"; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()

      Text {
        y: 16; anchors.horizontalCenter: parent.horizontalCenter
        text: question
        color: "#C1C497"; font.pixelSize: 15; font.bold: true
      }
      Row {
        y: 56; anchors.horizontalCenter: parent.horizontalCenter; spacing: 14
        Rectangle {
          width: 110; height: 34; radius: 8
          color: cma.containsMouse ? "#2a3a30" : "#16241f"; border.color: "#C1C497"; border.width: 1
          Text { anchors.centerIn: parent; text: "Cancel"; color: "#C1C497"; font.pixelSize: 14 }
          MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
        }
        Rectangle {
          width: 110; height: 34; radius: 8
          color: rma.containsMouse ? "#5a2a24" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
          Text { anchors.centerIn: parent; text: verb; color: "#E0705A"; font.pixelSize: 14 }
          MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: power.running = true }
        }
      }
    }
  }
}
