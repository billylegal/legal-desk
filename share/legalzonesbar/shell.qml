import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Zones top flyout (like Windows 11 snap layouts): push the pointer to the top edge, a menu of layouts
// pulls down, click a zone and the window you were using snaps there. Stays running; costs nothing when closed.
ShellRoot {
  id: zr
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) zr.bgC = c.bg
      if (c.acc) zr.accC = c.acc
      if (c.txt) zr.txtC = c.txt
      if (c.sel) zr.selC = c.sel
    }
  }
  readonly property string core: "/usr/lib/legal-desk/legal-zones-core"
  readonly property string launcher: "/usr/lib/legal-desk/legal-zones"
  property var data: ({ layouts: [], active: "" })
  property string winTitle: ""
  property bool open: false

  Process {
    id: loader
    command: [zr.core, "list"]
    stdout: StdioCollector { onStreamFinished: { try { zr.data = JSON.parse(text); zr.open = zr.data.flyout !== false } catch (e) { } } }
  }
  Process {
    id: aw
    command: ["bash", "-c", "hyprctl -j activewindow | python3 -c \"import json,sys;d=json.load(sys.stdin);print(d.get('title','') if d.get('address') else '')\""]
    stdout: StdioCollector { onStreamFinished: zr.winTitle = text.trim() }
  }
  Process { id: runner; property var cmd: []; command: cmd }
  function run(a) { runner.cmd = a; runner.running = false; runner.running = true }

  function show() { closeT.stop(); if (!open) { loader.running = false; loader.running = true; aw.running = false; aw.running = true } }
  function hide() { open = false }

  PanelWindow {
    id: win
    anchors { top: true }
    implicitWidth: 860; implicitHeight: 230
    color: "transparent"; exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "legalzonesbar"
    mask: Region { item: zr.open ? card : strip }

    Timer { id: closeT; interval: 450; onTriggered: zr.hide() }

    // invisible hot strip on the very top edge
    Item {
      id: strip
      x: (parent.width - 340) / 2; y: 0; width: 340; height: 3
      HoverHandler { onHoveredChanged: if (hovered) zr.show() }
    }

    Rectangle {
      id: card
      width: parent.width - 20; height: 214
      x: 10; y: zr.open ? -2 : -height - 40
      radius: 0; color: zr.bgC; border.color: zr.accC; border.width: 2
      Behavior on y { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
      HoverHandler { onHoveredChanged: { if (hovered) closeT.stop(); else if (zr.open) closeT.restart() } }

      Text { x: 20; y: 14; text: "Legal Zones"; color: zr.txtC; font.pixelSize: 15; font.bold: true }
      Text { x: 134; y: 16; width: card.width - 134 - 390; elide: Text.ElideRight; text: zr.winTitle !== "" ? zr.winTitle : "no window selected"; color: zr.accC; font.pixelSize: 13 }
      Row {
        anchors { right: parent.right; rightMargin: 16 } y: 10; spacing: 8
        Rectangle { width: 140; height: 28; color: na.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "+ Create my own"; color: na.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 12 }
          MouseArea { id: na; anchors.fill: parent; hoverEnabled: true
            onClicked: { zr.run(["bash", "-c", "n=$(\"$1\" new) && exec \"$2\" edit \"$n\"", "x", zr.core, zr.launcher]); zr.hide() } } }
        Rectangle { width: 92; height: 28; radius: 0; color: ra.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "Release"; color: ra.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 12 }
          MouseArea { id: ra; anchors.fill: parent; hoverEnabled: true; onClicked: { zr.run([zr.core, "release"]); zr.hide() } } }
        Rectangle { width: 104; height: 28; radius: 0; color: ma2.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "Layouts…"; color: ma2.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 12 }
          MouseArea { id: ma2; anchors.fill: parent; hoverEnabled: true; onClicked: { zr.run([zr.launcher, "manage"]); zr.hide() } } }
      }

      ListView {
        id: lv
        x: 14; y: 52; width: card.width - 28; height: 140
        orientation: ListView.Horizontal; spacing: 12; clip: true
        model: zr.data.layouts
        delegate: Item {
          id: cell
          required property var modelData
          width: 150; height: 140
          Rectangle { id: thumb; x: 0; y: 0; width: 150; height: 96; radius: 0; color: zr.bgC
            border.color: cell.modelData.name === zr.data.active ? zr.accC : Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.4); border.width: cell.modelData.name === zr.data.active ? 2 : 1 }
          Repeater {
            model: cell.modelData.zones
            Rectangle {
              required property var modelData
              required property int index
              x: modelData[0] * thumb.width + 3; y: modelData[1] * thumb.height + 3
              width: Math.max(4, modelData[2] * thumb.width - 6); height: Math.max(4, modelData[3] * thumb.height - 6)
              radius: 0; color: za.containsMouse ? zr.accC : Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.25)
              border.color: zr.accC; border.width: 1
              MouseArea { id: za; anchors.fill: parent; hoverEnabled: true
                onClicked: { zr.run(["bash", "-c", "\"$1\" use \"$2\" && \"$1\" snap \"$3\"", "x", zr.core, cell.modelData.name, String(index)]); zr.hide() } }
            }
          }
          Text { x: 0; y: 102; width: 150; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter
            text: cell.modelData.name; color: zr.txtC; font.pixelSize: 13 }
        }
      }
      // credit
      Rectangle { z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 30; height: 22; width: cr.implicitWidth + 34; radius: 0; color: zr.bgC; border.color: zr.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
        Text { id: cr; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: zr.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 } }
    }
  }
}
