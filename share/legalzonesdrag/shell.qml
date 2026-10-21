import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Zones drag preview: while you drag a window to a screen edge or corner, every zone of the layout is drawn
// and the one you are over lights up. Let go and the window snaps in. The engine (legal-zones-core drag) writes the
// state file; this window only draws it and never takes the mouse.
ShellRoot {
  id: zr
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  // Colours follow the dock skin; re-read every second so a skin change shows up at once.
  FileView {
    id: colorsFile
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    blockLoading: true   // read before the window opens: no default-colour flash
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) zr.bgC = c.bg
      if (c.acc) zr.accC = c.acc
      if (c.txt) zr.txtC = c.txt
    }
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: colorsFile.reload() }
  property bool show: false
  property int hi: -1
  property var rects: []
  FileView {
    path: Quickshell.env("HOME") + "/.cache/legal-zones-drag.json"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { try { var s = JSON.parse(text()); zr.rects = s.rects || []; zr.hi = s.hi; zr.show = !!s.show } catch (e) { zr.show = false } }
  }
  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "legalzonesdrag"
    mask: Region { }
    visible: zr.show
    Repeater {
      model: zr.rects
      Rectangle {
        required property var modelData
        required property int index
        readonly property bool on: index === zr.hi
        x: modelData[0]; y: modelData[1]; width: modelData[2]; height: modelData[3]
        radius: 0
        color: Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, on ? 0.55 : 0.12)
        border.color: zr.accC; border.width: on ? 4 : 1
        Behavior on color { ColorAnimation { duration: 90 } }
        Text { anchors.centerIn: parent; text: index + 1; color: zr.txtC; opacity: on ? 1 : 0.35; font.pixelSize: Math.min(parent.height * 0.4, 120); font.bold: true }
      }
    }
  }
}
