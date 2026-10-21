import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk Task Manager: live CPU / memory, every running process (yours by default), sort, search, End task / Force quit. Skin-coloured.
ShellRoot {
  id: tm
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    blockLoading: true   // read before the window opens: no default-colour flash
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) tm.bgC = c.bg
      if (c.acc) tm.accC = c.acc
      if (c.txt) tm.txtC = c.txt
      if (c.sel) tm.selC = c.sel
    }
  }
  readonly property string me: Quickshell.env("USER") || ""
  property var data: ({ cpu: 0, memUsed: 0, memTotal: 1, procs: [] })
  property string sortBy: "cpu"
  property bool allUsers: false
  property string query: ""
  property int selPid: -1

  Process {
    id: sampler
    command: ["/usr/lib/legal-desk/legal-tasks-sample"]
    stdout: StdioCollector { onStreamFinished: { try { tm.data = JSON.parse(text) } catch (e) { } } }
  }
  Timer { interval: 2200; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!sampler.running) sampler.running = true }
  Process { id: killer; property var cmd: []; command: cmd }
  function kill(sig) { if (selPid < 0) return; killer.cmd = ["kill", "-" + sig, String(selPid)]; killer.running = false; killer.running = true; sampler.running = false; sampler.running = true }

  readonly property var rows: {
    var q = query.trim().toLowerCase()
    var a = data.procs.filter(function (p) { return (allUsers || p.user === me) && (!q || p.name.toLowerCase().indexOf(q) >= 0 || String(p.pid).indexOf(q) >= 0) })
    a.sort(function (x, y) {
      if (sortBy === "name") return x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1
      if (sortBy === "mem") return y.mem - x.mem
      if (sortBy === "pid") return x.pid - y.pid
      return y.cpu - x.cpu
    })
    return a
  }
  function fmtMem(m) { return m >= 1024 ? (m / 1024).toFixed(1) + " GB" : Math.round(m) + " MB" }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legaltasks"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    Rectangle {
      id: card
      width: Math.min(900, parent.width - 40); height: Math.min(640, parent.height - 120)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 24
      radius: 16; color: tm.bgC; border.color: tm.accC; border.width: 2
      MouseArea { anchors.fill: parent }
      Keys.onEscapePressed: Qt.quit()

      Text { x: 24; y: 16; text: "Task Manager"; color: tm.txtC; font.pixelSize: 22; font.bold: true }
      Rectangle { x: card.width - 44; y: 14; width: 28; height: 28; radius: 14; color: xma.containsMouse ? tm.accC : "transparent"; border.color: tm.accC; border.width: 1
        Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? tm.bgC : tm.txtC; font.pixelSize: 12 }
        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }

      // CPU + memory meters
      Row {
        x: 24; y: 56; spacing: 16
        Repeater {
          model: [{ n: "CPU", v: tm.data.cpu / 100, t: tm.data.cpu.toFixed(0) + "%" },
                  { n: "Memory", v: tm.data.memUsed / Math.max(1, tm.data.memTotal), t: tm.fmtMem(tm.data.memUsed) + " of " + tm.fmtMem(tm.data.memTotal) }]
          Rectangle {
            width: (card.width - 48 - 16) / 2; height: 54; radius: 12; color: tm.selC; border.color: tm.accC; border.width: 1
            Text { x: 14; y: 8; text: modelData.n; color: tm.txtC; opacity: 0.7; font.pixelSize: 12 }
            Text { anchors.right: parent.right; anchors.rightMargin: 14; y: 8; text: modelData.t; color: tm.txtC; font.pixelSize: 13; font.bold: true }
            Rectangle { x: 14; y: 32; width: parent.width - 28; height: 8; radius: 4; color: tm.bgC
              Rectangle { width: parent.width * Math.max(0.01, Math.min(1, modelData.v)); height: parent.height; radius: 4; color: modelData.v > 0.85 ? "#E0705A" : tm.accC
                Behavior on width { NumberAnimation { duration: 400 } } } }
          }
        }
      }
      // toolbar: search, scope, actions
      Rectangle { x: 24; y: 122; width: 250; height: 34; radius: 10; color: tm.selC; border.color: tm.accC; border.width: 1
        TextInput { id: search; focus: true; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: tm.txtC; font.pixelSize: 14; clip: true; selectionColor: tm.accC
          onTextChanged: tm.query = text; Keys.onEscapePressed: Qt.quit()
          Text { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search"; color: tm.txtC; opacity: 0.5; font.pixelSize: 14 } } }
      Rectangle { x: 284; y: 122; width: 120; height: 34; radius: 10; color: scma.containsMouse ? tm.accC : tm.selC; border.color: tm.accC; border.width: 1
        Text { anchors.centerIn: parent; text: tm.allUsers ? "All users" : "My apps"; color: scma.containsMouse ? tm.bgC : tm.txtC; font.pixelSize: 13 }
        MouseArea { id: scma; anchors.fill: parent; hoverEnabled: true; onClicked: tm.allUsers = !tm.allUsers } }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 24; y: 122; spacing: 8
        Rectangle { width: 110; height: 34; radius: 10; opacity: tm.selPid >= 0 ? 1 : 0.4; color: ema.containsMouse ? tm.accC : tm.selC; border.color: tm.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "End task"; color: ema.containsMouse ? tm.bgC : tm.txtC; font.pixelSize: 13 }
          MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; onClicked: tm.kill("TERM") } }
        Rectangle { width: 110; height: 34; radius: 10; opacity: tm.selPid >= 0 ? 1 : 0.4; color: fma.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
          Text { anchors.centerIn: parent; text: "Force quit"; color: fma.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 13 }
          MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; onClicked: tm.kill("KILL") } }
      }
      // column headers
      Row {
        id: hdr
        x: 24; y: 170; width: card.width - 48; height: 28
        Repeater {
          model: [{ k: "name", t: "Name", w: 0.46 }, { k: "pid", t: "PID", w: 0.14 }, { k: "cpu", t: "CPU %", w: 0.18 }, { k: "mem", t: "Memory", w: 0.22 }]
          Rectangle {
            width: hdr.width * modelData.w; height: hdr.height; color: "transparent"
            Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.t + (tm.sortBy === modelData.k ? "  ▾" : ""); color: tm.sortBy === modelData.k ? tm.accC : tm.txtC; opacity: tm.sortBy === modelData.k ? 1 : 0.7; font.pixelSize: 12; font.bold: true }
            MouseArea { anchors.fill: parent; onClicked: tm.sortBy = modelData.k }
          }
        }
      }
      Rectangle { x: 24; y: 198; width: card.width - 48; height: 1; color: tm.accC; opacity: 0.4 }
      ListView {
        id: list
        x: 24; y: 202; width: card.width - 48; height: card.height - 202 - 16; clip: true; model: tm.rows; boundsBehavior: Flickable.StopAtBounds
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: list.width; height: 30; radius: 8
          color: modelData.pid === tm.selPid ? tm.selC : (rma.containsMouse ? Qt.darker(tm.selC, 1.3) : "transparent")
          border.color: modelData.pid === tm.selPid ? tm.accC : "transparent"; border.width: 1
          Row { anchors.fill: parent
            Text { width: parent.width * 0.46; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; text: modelData.name; color: tm.txtC; font.pixelSize: 13 }
            Text { width: parent.width * 0.14; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.pid; color: tm.txtC; opacity: 0.6; font.pixelSize: 13 }
            Text { width: parent.width * 0.18; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.cpu.toFixed(1); color: modelData.cpu > 50 ? "#E0705A" : tm.txtC; font.pixelSize: 13 }
            Text { width: parent.width * 0.22; leftPadding: 12; anchors.verticalCenter: parent.verticalCenter; text: tm.fmtMem(modelData.mem); color: tm.txtC; font.pixelSize: 13 }
          }
          MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: tm.selPid = modelData.pid }
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: tm.bgC; border.color: tm.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: tm.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
