import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk Disks: every drive and partition with its size and usage; Mount / Unmount / Eject and Format (or Erase a whole drive).
// Safety: the drive the system runs from can never be formatted or unmounted here, and a format needs the device name typed in.
ShellRoot {
  id: dk
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    blockLoading: true   // read before the window opens: no default-colour flash
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) dk.bgC = c.bg
      if (c.acc) dk.accC = c.acc
      if (c.txt) dk.txtC = c.txt
      if (c.sel) dk.selC = c.sel
    }
  }
  readonly property string bin: "/usr/lib/legal-desk/"
  property var disks: []
  property var fstypes: ["ext4", "exFAT", "FAT32"]
  property string status: ""
  property bool busy: false

  Process {
    id: lister
    command: [dk.bin + "legal-disks-list"]
    stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); dk.disks = r.disks; if (r.fstypes.length) dk.fstypes = r.fstypes } catch (e) { } } }
  }
  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!lister.running && !dk.busy) lister.running = true }
  Process {
    id: actor
    property var cmd: []
    command: cmd
    stdout: StdioCollector { onStreamFinished: { dk.busy = false; dk.status = text.trim() === "ok" ? "Done." : text.trim() } }
    stderr: StdioCollector { onStreamFinished: { if (text.trim()) { dk.busy = false; dk.status = text.trim().split("\n").pop() } } }
    onExited: { dk.busy = false; lister.running = false; lister.running = true }
  }
  function act(a, path, fs, label) {
    busy = true; status = a === "format" || a === "erase" ? "Working - please wait..." : ""
    actor.cmd = [dk.bin + "legal-disks-action", a, path].concat(fs ? [fs, label || ""] : [])
    actor.running = false; actor.running = true
  }
  function gb(b) { if (!b) return "-"; var g = b / 1e9; return g >= 1000 ? (g / 1000).toFixed(2) + " TB" : (g >= 10 ? Math.round(g) : g.toFixed(1)) + " GB" }

  // format dialog state
  property string fPath: ""
  property string fName: ""
  property bool fWhole: false
  property string fFs: "ext4"
  readonly property string confirmWord: fPath.replace("/dev/", "")
  readonly property bool dialog: fPath !== ""

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legaldisks"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill: parent; onClicked: if (!dk.dialog) Qt.quit() }

    Rectangle {
      id: card
      width: Math.min(780, parent.width - 40); height: Math.min(640, parent.height - 100)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 20
      radius: 16; color: dk.bgC; border.color: dk.accC; border.width: 2
      MouseArea { anchors.fill: parent }
      Keys.onEscapePressed: { if (dk.dialog) dk.fPath = ""; else Qt.quit() }

      Text { x: 24; y: 16; text: "Disks"; color: dk.txtC; font.pixelSize: 22; font.bold: true }
      Text { x: 100; y: 22; width: card.width - 190; elide: Text.ElideRight; text: dk.status; color: dk.status.indexOf("Done") === 0 ? dk.accC : "#E0705A"; font.pixelSize: 13 }
      Rectangle { x: card.width - 44; y: 14; width: 28; height: 28; radius: 14; color: xma.containsMouse ? dk.accC : "transparent"; border.color: dk.accC; border.width: 1
        Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? dk.bgC : dk.txtC; font.pixelSize: 12 }
        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }

      ListView {
        id: dl
        x: 20; y: 58; width: card.width - 40; height: card.height - 58 - 16; clip: true; spacing: 12
        model: dk.disks
        delegate: Rectangle {
          id: dc
          required property var modelData
          width: dl.width; height: 70 + modelData.parts.length * 62 + (modelData.parts.length ? 4 : 0); radius: 14
          color: Qt.rgba(dk.selC.r, dk.selC.g, dk.selC.b, 0.55); border.color: dk.accC; border.width: 1
          // drive header
          Text { x: 18; y: 12; text: (modelData.model || (modelData.type === "loop" ? "Disk image" : "Drive")) + (modelData.tran === "usb" ? "  ·  USB" : ""); color: dk.txtC; font.pixelSize: 16; font.bold: true }
          Text { x: 18; y: 36; text: modelData.path + "  ·  " + dk.gb(modelData.size); color: dk.accC; font.pixelSize: 12 }
          Rectangle { visible: modelData.system; x: 18; y: 50; width: 108; height: 18; radius: 9; color: dk.accC
            Text { anchors.centerIn: parent; text: "SYSTEM DRIVE"; color: dk.bgC; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.8 } }
          Row {
            visible: !modelData.system; anchors.right: parent.right; anchors.rightMargin: 14; y: 14; spacing: 8
            Rectangle { width: 96; height: 30; radius: 9; color: era.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
              Text { anchors.centerIn: parent; text: "Erase drive"; color: era.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 12 }
              MouseArea { id: era; anchors.fill: parent; hoverEnabled: true; onClicked: { dk.fPath = modelData.path; dk.fName = modelData.model || modelData.path; dk.fWhole = true; dk.fFs = dk.fstypes[0]; lab.text = ""; cf.text = "" } } }
            Rectangle { visible: modelData.tran === "usb" || modelData.hotplug; width: 70; height: 30; radius: 9; color: eja.containsMouse ? dk.accC : dk.selC; border.color: dk.accC; border.width: 1
              Text { anchors.centerIn: parent; text: "Eject"; color: eja.containsMouse ? dk.bgC : dk.txtC; font.pixelSize: 12 }
              MouseArea { id: eja; anchors.fill: parent; hoverEnabled: true; onClicked: dk.act("eject", modelData.path) } }
          }
          // partitions (or the drive itself when it holds a filesystem directly)
          Column {
            x: 12; y: 72; width: parent.width - 24; spacing: 4
            Repeater {
              model: modelData.parts
              Rectangle {
                required property var modelData
                readonly property bool sysP: modelData.system
                width: parent.width; height: 58; radius: 10; color: dk.bgC
                Text { x: 14; y: 8; text: (modelData.label || modelData.name) + "   " + (modelData.fstype || "no filesystem"); color: dk.txtC; font.pixelSize: 14; font.bold: true }
                Text { x: 14; y: 28; text: dk.gb(modelData.size) + (modelData.fsused ? "  ·  " + dk.gb(modelData.fsused) + " used" : "") + (modelData.mounts.length ? "  ·  " + modelData.mounts[0] : "  ·  not mounted"); color: dk.txtC; opacity: 0.65; font.pixelSize: 11; width: parent.width - 260; elide: Text.ElideRight }
                Rectangle { x: 14; y: 47; width: parent.width - 28 - 230; height: 5; radius: 2.5; color: dk.selC; visible: !!modelData.fsused
                  Rectangle { width: parent.width * Math.min(1, modelData.fsused / Math.max(1, modelData.size)); height: parent.height; radius: 2.5; color: modelData.fsused / modelData.size > 0.9 ? "#E0705A" : dk.accC } }
                Row {
                  anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                  Rectangle { visible: !sysP && !!modelData.fstype && modelData.fstype !== "swap"; width: 84; height: 30; radius: 9; color: mua.containsMouse ? dk.accC : dk.selC; border.color: dk.accC; border.width: 1
                    Text { anchors.centerIn: parent; text: modelData.mounts.length ? "Unmount" : "Mount"; color: mua.containsMouse ? dk.bgC : dk.txtC; font.pixelSize: 12 }
                    MouseArea { id: mua; anchors.fill: parent; hoverEnabled: true; onClicked: dk.act(modelData.mounts.length ? "unmount" : "mount", modelData.path) } }
                  Rectangle { visible: !sysP; width: 78; height: 30; radius: 9; color: fma.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
                    Text { anchors.centerIn: parent; text: "Format"; color: fma.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 12 }
                    MouseArea { id: fma; anchors.fill: parent; hoverEnabled: true; onClicked: { dk.fPath = modelData.path; dk.fName = modelData.label || modelData.name; dk.fWhole = false; dk.fFs = dk.fstypes[0]; lab.text = ""; cf.text = "" } } }
                  Text { visible: sysP; text: "in use by the system"; color: dk.txtC; opacity: 0.5; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                }
              }
            }
          }
        }
        Text { visible: dk.disks.length === 0; anchors.centerIn: parent; text: "Looking for drives..."; color: dk.txtC; opacity: 0.6; font.pixelSize: 15 }
      }

      // ---- format / erase dialog ----
      Rectangle { visible: dk.dialog; anchors.fill: parent; radius: 16; color: Qt.rgba(0, 0, 0, 0.6); z: 20; MouseArea { anchors.fill: parent } }
      Rectangle {
        visible: dk.dialog; z: 21; width: 460; height: 340; radius: 14; anchors.centerIn: parent
        color: dk.bgC; border.color: "#E0705A"; border.width: 2
        Text { x: 22; y: 16; text: dk.fWhole ? "Erase whole drive" : "Format partition"; color: dk.txtC; font.pixelSize: 18; font.bold: true }
        Text { x: 22; y: 44; width: parent.width - 44; wrapMode: Text.WordWrap; color: "#E0705A"; font.pixelSize: 13
          text: "All data on " + dk.fName + " (" + dk.fPath + ") will be permanently erased." + (dk.fWhole ? " The drive gets a new partition table and one partition." : "") }
        Text { x: 22; y: 96; text: "File system"; color: dk.txtC; opacity: 0.7; font.pixelSize: 12 }
        Row { x: 22; y: 116; spacing: 6
          Repeater { model: dk.fstypes
            Rectangle { width: 66; height: 30; radius: 15; color: dk.fFs === modelData ? dk.accC : (fsa.containsMouse ? dk.selC : "transparent"); border.color: dk.accC; border.width: 1
              Text { anchors.centerIn: parent; text: modelData; color: dk.fFs === modelData ? dk.bgC : dk.txtC; font.pixelSize: 12 }
              MouseArea { id: fsa; anchors.fill: parent; hoverEnabled: true; onClicked: dk.fFs = modelData } } } }
        Text { x: 22; y: 160; text: "Name (optional)"; color: dk.txtC; opacity: 0.7; font.pixelSize: 12 }
        Rectangle { x: 22; y: 180; width: parent.width - 44; height: 32; radius: 9; color: dk.selC; border.color: dk.accC; border.width: 1
          TextInput { id: lab; anchors.fill: parent; anchors.margins: 8; color: dk.txtC; font.pixelSize: 14; clip: true; maximumLength: 16; selectionColor: dk.accC } }
        Text { x: 22; y: 224; text: "To confirm, type  " + dk.confirmWord; color: dk.txtC; font.pixelSize: 13; font.bold: true }
        Rectangle { x: 22; y: 246; width: parent.width - 44; height: 32; radius: 9; color: dk.selC; border.color: cf.text === dk.confirmWord ? dk.accC : "#E0705A"; border.width: 1
          TextInput { id: cf; anchors.fill: parent; anchors.margins: 8; color: dk.txtC; font.pixelSize: 14; clip: true; selectionColor: dk.accC; focus: dk.dialog
            Keys.onEscapePressed: dk.fPath = "" } }
        Row { x: parent.width - 22 - 230; y: 292; spacing: 10
          Rectangle { width: 100; height: 34; radius: 10; color: cna.containsMouse ? dk.selC : "transparent"; border.color: dk.accC; border.width: 1
            Text { anchors.centerIn: parent; text: "Cancel"; color: dk.txtC; font.pixelSize: 14 }
            MouseArea { id: cna; anchors.fill: parent; hoverEnabled: true; onClicked: dk.fPath = "" } }
          Rectangle { width: 120; height: 34; radius: 10; opacity: cf.text === dk.confirmWord ? 1 : 0.35; color: gca.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
            Text { anchors.centerIn: parent; text: dk.fWhole ? "Erase" : "Format"; color: gca.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 14; font.bold: true }
            MouseArea { id: gca; anchors.fill: parent; hoverEnabled: true
              onClicked: if (cf.text === dk.confirmWord) { var p = dk.fPath; dk.fPath = ""; dk.act(dk.fWhole ? "erase" : "format", p, dk.fFs, lab.text) } } }
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: dk.bgC; border.color: dk.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: dk.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
