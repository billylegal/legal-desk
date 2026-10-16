import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk first-run setup: says what will be changed, lets you untick things, and offers a way back (restore / remove Legal Desk).
// Logic lives in legal-desk-setup (plan / apply / restore); this window only shows the plan and runs it.
ShellRoot {
  id: root
  readonly property string tool: "/usr/lib/legal-desk/legal-desk-setup"
  readonly property color bg: "#0B0818"
  readonly property color acc: "#8B5CF6"
  readonly property color txt: "#E6E1FA"
  readonly property color dim: "#9d96c0"
  property var items: []
  property var on: ({})
  property string phase: "ask"        // ask | working | done | removing
  property string note: ""

  Process {
    id: planner; command: [root.tool, "plan"]; running: true
    stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); root.items = d.items; var o = {}; d.items.forEach(i => o[i.id] = i.on); root.on = o } catch (e) { root.note = "Could not read the plan." } } }
  }
  Process {
    id: applier; property string ids: ""
    command: [root.tool, "apply", ids]
    stdout: StdioCollector { onStreamFinished: { root.phase = "done"; try { var r = JSON.parse(text); root.note = r.errors.length ? "Done, with a problem in: " + r.errors.join("; ") : "All set. Legal Desk is ready." } catch (e) { root.note = "All set." } closer.start() } }
  }
  Process { id: restorer; command: [root.tool, "restore"]; stdout: StdioCollector { onStreamFinished: { root.note = "Your old setup is back."; if (root.phase === "removing") Quickshell.execDetached(["pkexec", "pacman", "-R", "--noconfirm", "legal-desk"]); closer.start() } } }
  Timer { id: closer; interval: 3500; onTriggered: Qt.quit() }

  function chosen() { var a = []; items.forEach(i => { if (on[i.id]) a.push(i.id) }); return a.join(",") }
  function toggle(id) { var o = Object.assign({}, on); o[id] = !o[id]; on = o }

  PanelWindow {
    id: win
    implicitWidth: 640; implicitHeight: Math.min(760, 230 + root.items.length * 82)
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legalsetup"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    Rectangle {
      anchors.fill: parent; anchors.margins: 8; radius: 14; color: root.bg; border.color: root.acc; border.width: 2
      focus: true
      Keys.onEscapePressed: { Quickshell.execDetached([root.tool, "later"]); Qt.quit() }

      Column {
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 } spacing: 6
        Text { text: "Welcome to Legal Desk"; color: root.txt; font.pixelSize: 24; font.bold: true }
        Text { width: parent.width; wrapMode: Text.WordWrap; color: root.dim; font.pixelSize: 13
          text: root.phase === "ask" ? "To work well, Legal Desk needs to change a few things on this computer. Untick anything you don't want. Every change is backed up and you can undo it all later."
              : root.phase === "working" ? "Setting things up…" : root.note }
      }

      Column {
        visible: root.phase === "ask"
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 104; leftMargin: 22; rightMargin: 22 } spacing: 8
        Repeater {
          model: root.items
          Rectangle {
            required property var modelData
            width: parent.width; height: 70; radius: 8; color: ma.containsMouse ? "#1a1433" : "transparent"; border.color: "#3a2f66"; border.width: 1
            Rectangle { id: box; x: 12; y: 12; width: 22; height: 22; radius: 5; color: root.on[modelData.id] ? root.acc : "transparent"; border.color: root.acc; border.width: 2
              Text { anchors.centerIn: parent; visible: !!root.on[modelData.id]; text: "✓"; color: "white"; font.pixelSize: 16; font.bold: true } }
            Text { x: 46; y: 8; width: parent.width - 58; text: modelData.title; color: root.txt; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight }
            Text { x: 46; y: 28; width: parent.width - 58; height: 40; text: modelData.why; color: root.dim; font.pixelSize: 11; wrapMode: Text.WordWrap; elide: Text.ElideRight }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: root.toggle(modelData.id) }
          }
        }
      }

      Row {
        visible: root.phase === "ask"
        anchors { bottom: parent.bottom; bottomMargin: 18; horizontalCenter: parent.horizontalCenter } spacing: 10
        Rectangle { width: 210; height: 36; radius: 8; color: root.acc
          Text { anchors.centerIn: parent; text: "Set up Legal Desk"; color: "white"; font.pixelSize: 14; font.bold: true }
          MouseArea { anchors.fill: parent; onClicked: { root.phase = "working"; applier.ids = root.chosen(); applier.running = true } } }
        Rectangle { width: 120; height: 36; radius: 8; color: "transparent"; border.color: root.acc; border.width: 2
          Text { anchors.centerIn: parent; text: "Not now"; color: root.txt; font.pixelSize: 13 }
          MouseArea { anchors.fill: parent; onClicked: { Quickshell.execDetached([root.tool, "later"]); Qt.quit() } } }
        Rectangle { width: 210; height: 36; radius: 8; color: "transparent"; border.color: "#ff5a5a"; border.width: 2
          Text { anchors.centerIn: parent; text: "I don't want it: remove"; color: "#ff7a7a"; font.pixelSize: 13 }
          MouseArea { anchors.fill: parent; onClicked: { root.phase = "removing"; root.note = "Removing Legal Desk…"; restorer.running = true } } }
      }
    }
  }
}
