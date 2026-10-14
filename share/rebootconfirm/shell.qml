import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Small "Do you really want to reboot?" popup, placed just above the dock icon that was clicked.
ShellRoot {
  property int cx: parseInt(Quickshell.env("RC_X") || "960")

  Process { id: reboot; command: ["omarchy", "system", "reboot"]; onExited: Qt.quit() }

  PanelWindow {
    anchors { bottom: true; left: true }
    margins { left: Math.max(8, cx - 110); bottom: parseInt(Quickshell.env("RC_B") || "72") }
    implicitWidth: 220; implicitHeight: 84
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "rebootconfirm"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent; radius: 10
      color: "#111c18"; border.color: "#C1C497"; border.width: 1
      focus: true
      Keys.onEscapePressed: Qt.quit()

      Text {
        y: 10; anchors.horizontalCenter: parent.horizontalCenter
        text: "Do you really want to reboot?"
        color: "#C1C497"; font.pixelSize: 13
      }
      Row {
        y: 42; anchors.horizontalCenter: parent.horizontalCenter; spacing: 12
        Rectangle {
          width: 88; height: 30; radius: 6
          color: cma.containsMouse ? "#2a3a30" : "#16241f"; border.color: "#C1C497"; border.width: 1
          Text { anchors.centerIn: parent; text: "Cancel"; color: "#C1C497"; font.pixelSize: 13 }
          MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
        }
        Rectangle {
          width: 88; height: 30; radius: 6
          color: rma.containsMouse ? "#5a2a24" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
          Text { anchors.centerIn: parent; text: "Reboot"; color: "#E0705A"; font.pixelSize: 13 }
          MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: reboot.running = true }
        }
      }
    }
  }
}
