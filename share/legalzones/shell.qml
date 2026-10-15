import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk Zones: a FancyZones for Hyprland.
//   manage - pick a layout, edit / duplicate / delete layouts, gap, auto-snap, "snap open windows now"
//   edit   - full-screen editor: split zones (click), merge, delete, drag the dividers, name and save
//   pick   - full-screen picker: click a zone (or press its number) to put the window you were using there
// Layouts live in ~/.local/share/legal-desk/zones.json (zones are fractions of the screen free of bar and dock).
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
  readonly property string home: Quickshell.env("HOME")
  readonly property string mode: Quickshell.env("ZONES_MODE") || "manage"
  readonly property string core: "/usr/lib/legal-desk/legal-zones-core"
  readonly property string launcher: "/usr/lib/legal-desk/legal-zones"
  readonly property var areaArr: (Quickshell.env("ZONES_AREA") || "0 26 1920 995").split(" ").map(Number)   // x y w h of the free screen area
  readonly property string pickAddr: Quickshell.env("PICK_ADDR") || ""

  // ---- data ----
  property var data: ({ layouts: [], active: "", gap: 8, auto: false })
  property string selName: Quickshell.env("ZONES_NAME") || ""
  Process {
    id: loader
    command: [zr.core, "list"]
    stdout: StdioCollector { onStreamFinished: { try { zr.data = JSON.parse(text); if (zr.selName === "" || !zr.byName(zr.selName)) zr.selName = zr.data.active } catch (e) { } } }
  }
  Component.onCompleted: loader.running = true
  Process { id: writer; stdinEnabled: true; command: ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "x", zr.home + "/.local/share/legal-desk/zones.json"] }
  function persist(d) { zr.data = d; writer.running = false; writer.running = true; writer.write(JSON.stringify(d)); writer.stdinEnabled = false; writer.stdinEnabled = true }
  Process { id: runner; property var cmd: []; command: cmd }
  function run(a) { runner.cmd = a; runner.running = false; runner.running = true }
  function byName(n) { for (var i = 0; i < data.layouts.length; i++) if (data.layouts[i].name === n) return data.layouts[i]; return null }
  function copyLayout(l) { return { name: l.name, zones: l.zones.map(z => z.slice()) } }
  readonly property var templates: [
    { name: "Two columns", zones: [[0, 0, .5, 1], [.5, 0, .5, 1]] },
    { name: "Three columns", zones: [[0, 0, 1 / 3, 1], [1 / 3, 0, 1 / 3, 1], [2 / 3, 0, 1 / 3, 1]] },
    { name: "Two rows", zones: [[0, 0, 1, .5], [0, .5, 1, .5]] },
    { name: "Grid", zones: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] },
    { name: "Priority grid", zones: [[0, 0, .6, 1], [.6, 0, .4, .5], [.6, .5, .4, .5]] },
    { name: "Focus", zones: [[.15, .08, .7, .84], [0, 0, .15, 1], [.85, 0, .15, 1]] }
  ]
  function uniqueName(base) { var n = base, i = 2; while (byName(n)) { n = base + " " + i; i++ } return n }

  // A small drawing of a layout (used in lists and the big preview).
  component Mini: Item {
    property var zones: []
    property bool numbers: false
    property color fillC: zr.selC
    Rectangle { anchors.fill: parent; color: zr.bgC; radius: 6; border.color: zr.accC; border.width: 1; opacity: 0.9 }
    Repeater {
      model: zones
      Rectangle {
        required property var modelData
        required property int index
        x: modelData[0] * parent.width + 2; y: modelData[1] * parent.height + 2
        width: Math.max(2, modelData[2] * parent.width - 4); height: Math.max(2, modelData[3] * parent.height - 4)
        radius: 4; color: Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.28); border.color: zr.accC; border.width: 1
        Text { visible: numbers; anchors.centerIn: parent; text: index + 1; color: zr.txtC; font.pixelSize: Math.min(parent.height * 0.5, 40); font.bold: true }
      }
    }
  }

  // ===================== MANAGE =====================
  Loader { active: zr.mode === "manage"; sourceComponent: manageWin }
  Component {
    id: manageWin
    PanelWindow {
      anchors { top: true; bottom: true; left: true; right: true }
      color: "transparent"; exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "legalzones"; WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
      Rectangle {
        id: card
        width: Math.min(960, parent.width - 40); height: Math.min(640, parent.height - 100)
        x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 20
        radius: 16; color: zr.bgC; border.color: zr.accC; border.width: 2
        MouseArea { anchors.fill: parent }
        Keys.onEscapePressed: Qt.quit()
        readonly property var sel: zr.byName(zr.selName)

        Text { x: 24; y: 16; text: "Desk Zones"; color: zr.txtC; font.pixelSize: 22; font.bold: true }
        Text { x: 168; y: 23; text: "Snap windows into zones"; color: zr.accC; font.pixelSize: 13 }
        Rectangle { x: card.width - 44; y: 14; width: 28; height: 28; radius: 14; color: xma.containsMouse ? zr.accC : "transparent"; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 12 }
          MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }

        // layout list
        ListView {
          id: ll
          x: 20; y: 60; width: 290; height: card.height - 60 - 76; clip: true; spacing: 8
          model: zr.data.layouts
          delegate: Rectangle {
            required property var modelData
            width: ll.width; height: 74; radius: 12
            color: modelData.name === zr.selName ? zr.selC : (lma.containsMouse ? Qt.darker(zr.selC, 1.25) : "transparent")
            border.color: modelData.name === zr.selName ? zr.accC : Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.3); border.width: 1
            Mini { x: 10; y: 9; width: 90; height: 56; zones: modelData.zones }
            Text { x: 116; y: 14; width: parent.width - 126; elide: Text.ElideRight; text: modelData.name; color: zr.txtC; font.pixelSize: 15; font.bold: true }
            Text { x: 116; y: 38; text: modelData.zones.length + " zones"; color: zr.txtC; opacity: 0.6; font.pixelSize: 12 }
            Text { visible: modelData.name === zr.data.active; x: 116; y: 54; text: "● in use"; color: zr.accC; font.pixelSize: 11; font.bold: true }
            MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: zr.selName = modelData.name }
          }
        }
        // new layout from a template
        Rectangle { x: 20; y: card.height - 60; width: 290; height: 38; radius: 10; color: nwa.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "+ New layout"; color: nwa.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 14; font.bold: true }
          MouseArea { id: nwa; anchors.fill: parent; hoverEnabled: true; onClicked: tplMenu.visible = !tplMenu.visible } }
        Rectangle {
          id: tplMenu; visible: false; z: 10; x: 20; y: card.height - 60 - 8 - height; width: 290; height: zr.templates.length * 34 + 12; radius: 12; color: zr.bgC; border.color: zr.accC; border.width: 1
          Column { x: 6; y: 6; width: parent.width - 12
            Repeater { model: zr.templates
              Rectangle { width: parent.width; height: 34; radius: 8; color: tma.containsMouse ? zr.selC : "transparent"
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Start from: " + modelData.name; color: zr.txtC; font.pixelSize: 14 }
                MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                  onClicked: { var d = zr.data, n = zr.uniqueName("My layout"); d.layouts = d.layouts.concat([{ name: n, zones: modelData.zones.map(z => z.slice()) }]); zr.persist(d); zr.selName = n; tplMenu.visible = false
                               zr.run([zr.launcher, "edit", n]); Qt.quit() } } } } }
        }

        // big preview + actions
        Rectangle { x: 330; y: 60; width: card.width - 330 - 24; height: 330; radius: 14; color: zr.selC; opacity: 0.35 }
        Mini { x: 346; y: 76; width: card.width - 330 - 24 - 32; height: 298; zones: card.sel ? card.sel.zones : []; numbers: true }
        Text { x: 330; y: 402; width: card.width - 330 - 24; elide: Text.ElideRight; text: card.sel ? card.sel.name : ""; color: zr.txtC; font.pixelSize: 18; font.bold: true }
        Row {
          x: 330; y: 434; spacing: 8
          Rectangle { width: 130; height: 36; radius: 10; color: usa.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
            Text { anchors.centerIn: parent; text: zr.selName === zr.data.active ? "In use ✓" : "Use this layout"; color: usa.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 13; font.bold: true }
            MouseArea { id: usa; anchors.fill: parent; hoverEnabled: true; onClicked: { var d = zr.data; d.active = zr.selName; zr.persist(d) } } }
          Rectangle { width: 80; height: 36; radius: 10; color: eda.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
            Text { anchors.centerIn: parent; text: "Edit"; color: eda.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 13; font.bold: true }
            MouseArea { id: eda; anchors.fill: parent; hoverEnabled: true; onClicked: { zr.run([zr.launcher, "edit", zr.selName]); Qt.quit() } } }
          Rectangle { width: 100; height: 36; radius: 10; color: dua.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
            Text { anchors.centerIn: parent; text: "Duplicate"; color: dua.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 13; font.bold: true }
            MouseArea { id: dua; anchors.fill: parent; hoverEnabled: true
              onClicked: { if (!card.sel) return; var d = zr.data, c = zr.copyLayout(card.sel); c.name = zr.uniqueName(c.name); d.layouts = d.layouts.concat([c]); zr.persist(d); zr.selName = c.name } } }
          Rectangle { visible: zr.data.layouts.length > 1; width: 80; height: 36; radius: 10; color: dea.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
            Text { anchors.centerIn: parent; text: "Delete"; color: dea.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 13; font.bold: true }
            MouseArea { id: dea; anchors.fill: parent; hoverEnabled: true
              onClicked: { var d = zr.data; d.layouts = d.layouts.filter(l => l.name !== zr.selName); if (d.active === zr.selName) d.active = d.layouts[0].name; zr.persist(d); zr.selName = d.active } } }
        }
        // settings
        Rectangle { x: 330; y: 486; width: card.width - 330 - 24; height: 1; color: zr.accC; opacity: 0.3 }
        Text { x: 330; y: 502; text: "Gap  " + Math.round(zr.data.gap) + " px"; color: zr.txtC; font.pixelSize: 13 }
        Rectangle { x: 440; y: 509; width: 200; height: 6; radius: 3; color: zr.selC
          Rectangle { width: parent.width * Math.min(1, zr.data.gap / 32); height: parent.height; radius: 3; color: zr.accC }
          Rectangle { x: parent.width * Math.min(1, zr.data.gap / 32) - 8; y: -5; width: 16; height: 16; radius: 8; color: zr.txtC; border.color: zr.accC; border.width: 2 }
          MouseArea { anchors.fill: parent; anchors.margins: -10
            onPressed: (m) => set(m.x); onPositionChanged: (m) => { if (pressed) set(m.x) }
            function set(x) { var d = zr.data; d.gap = Math.round(Math.max(0, Math.min(1, (x + 10 - 10) / 200)) * 32); zr.persist(d) } } }
        Rectangle { x: 670; y: 497; width: card.width - 670 - 24; height: 34; radius: 10; color: aua.containsMouse ? zr.selC : "transparent"; border.color: zr.accC; border.width: 1
          Text { anchors.centerIn: parent; text: (zr.data.auto ? "☑" : "☐") + "  Auto-snap new windows"; color: zr.txtC; font.pixelSize: 13 }
          MouseArea { id: aua; anchors.fill: parent; hoverEnabled: true; onClicked: { var d = zr.data; d.auto = !d.auto; zr.persist(d); zr.run([zr.launcher, "start"]) } } }
        Row {
          x: 330; y: 546; spacing: 8
          Rectangle { width: 210; height: 38; radius: 10; color: sna.containsMouse ? zr.accC : zr.selC; border.color: zr.accC; border.width: 1
            Text { anchors.centerIn: parent; text: "Snap my open windows now"; color: sna.containsMouse ? zr.bgC : zr.txtC; font.pixelSize: 13; font.bold: true }
            MouseArea { id: sna; anchors.fill: parent; hoverEnabled: true; onClicked: { var d = zr.data; d.active = zr.selName; zr.persist(d); zr.run(["bash", "-c", "sleep 0.5; \"$0\" apply", zr.core]); Qt.quit() } } }
          Text { anchors.verticalCenter: parent.verticalCenter; text: "Super+Shift+Z picks a zone for one window"; color: zr.txtC; opacity: 0.55; font.pixelSize: 12 }
        }
        // credit
        Rectangle { z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11; height: 22; width: cr.implicitWidth + 34; radius: 11; color: zr.bgC; border.color: zr.accC; border.width: 1
          Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
          Text { id: cr; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: zr.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 } }
      }
    }
  }

  // ===================== PICK =====================
  Loader { active: zr.mode === "pick"; sourceComponent: pickWin }
  Component {
    id: pickWin
    PanelWindow {
      anchors { top: true; bottom: true; left: true; right: true }
      color: Qt.rgba(0, 0, 0, 0.55); exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "legalzones"; WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      readonly property var lay: zr.byName(zr.data.active)
      function snapTo(i) { zr.run([zr.core, "snap", zr.pickAddr, String(i)]); Qt.quit() }
      MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
      Item {
        anchors.fill: parent; focus: true
        Keys.onEscapePressed: Qt.quit()
        Keys.onPressed: (e) => { var n = e.key - Qt.Key_1; if (lay && n >= 0 && n < lay.zones.length) snapTo(n) }
        Repeater {
          model: lay ? lay.zones : []
          Rectangle {
            required property var modelData
            required property int index
            readonly property real g: zr.data.gap / 2
            x: zr.areaArr[0] + modelData[0] * zr.areaArr[2] + g; y: zr.areaArr[1] + modelData[1] * zr.areaArr[3] + g
            width: modelData[2] * zr.areaArr[2] - 2 * g; height: modelData[3] * zr.areaArr[3] - 2 * g
            radius: 14; color: zma.containsMouse ? Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.55) : Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, 0.22)
            border.color: zr.accC; border.width: 3
            Text { anchors.centerIn: parent; text: index + 1; color: zr.txtC; font.pixelSize: Math.min(parent.height * 0.4, 140); font.bold: true }
            MouseArea { id: zma; anchors.fill: parent; hoverEnabled: true; onClicked: snapTo(index) }
          }
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: zr.areaArr[1] + 14; width: hint.implicitWidth + 40; height: 40; radius: 20; color: zr.bgC; border.color: zr.accC; border.width: 1
          Text { id: hint; anchors.centerIn: parent; text: "Click a zone or press its number  ·  Esc to cancel"; color: zr.txtC; font.pixelSize: 15 } }
      }
    }
  }

  // ===================== EDIT =====================
  Loader { active: zr.mode === "edit"; sourceComponent: editWin }
  Component {
    id: editWin
    PanelWindow {
      id: ew
      anchors { top: true; bottom: true; left: true; right: true }
      color: Qt.rgba(0, 0, 0, 0.62); exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay; WlrLayershell.namespace: "legalzones"; WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      property var zones: []
      property string lname: ""
      property var selected: []
      property string tool: "select"          // select | splitv | splith
      property int dragAxis: 0                 // 1 vertical divider, 2 horizontal divider
      property real dragPos: 0
      property var dragZ: []                   // [{i, side}] zones touching the divider being dragged
      readonly property real ax: zr.areaArr[0]
      readonly property real ay: zr.areaArr[1]
      readonly property real aw: zr.areaArr[2]
      readonly property real ah: zr.areaArr[3]
      Connections { target: zr; function onDataChanged() { if (ew.lname === "") ew.start() } }
      Component.onCompleted: if (zr.data.layouts.length) start()
      function start() { var l = zr.byName(zr.selName) || zr.byName(zr.data.active); if (!l) return; lname = l.name; zones = l.zones.map(z => z.slice()); selected = [] }
      function near(a, b) { return Math.abs(a - b) < 0.003 }
      function hit(fx, fy) { for (var i = 0; i < zones.length; i++) { var z = zones[i]; if (fx >= z[0] && fx <= z[0] + z[2] && fy >= z[1] && fy <= z[1] + z[3]) return i } return -1 }
      function split(i, v, at) {
        var z = zones[i], a = zones.slice(), minf = 0.06
        if (v) { var cx = Math.max(z[0] + minf, Math.min(z[0] + z[2] - minf, at)); a.splice(i, 1, [z[0], z[1], cx - z[0], z[3]], [cx, z[1], z[0] + z[2] - cx, z[3]]) }
        else { var cy = Math.max(z[1] + minf, Math.min(z[1] + z[3] - minf, at)); a.splice(i, 1, [z[0], z[1], z[2], cy - z[1]], [z[0], cy, z[2], z[1] + z[3] - cy]) }
        zones = a; selected = []
      }
      function mergeSel() {
        if (selected.length < 2) return
        var x0 = 9, y0 = 9, x1 = -1, y1 = -1
        selected.forEach(function (i) { var z = zones[i]; x0 = Math.min(x0, z[0]); y0 = Math.min(y0, z[1]); x1 = Math.max(x1, z[0] + z[2]); y1 = Math.max(y1, z[1] + z[3]) })
        var a = zones.filter((z, i) => selected.indexOf(i) < 0); a.push([x0, y0, x1 - x0, y1 - y0]); zones = a; selected = []
      }
      function delSel() { if (!selected.length || selected.length >= zones.length) return; zones = zones.filter((z, i) => selected.indexOf(i) < 0); selected = [] }
      function findDivider(fx, fy) {
        var tx = 9 / aw, ty = 9 / ah, best = null, bd = 1
        for (var i = 0; i < zones.length; i++) {
          var z = zones[i];
          [z[0], z[0] + z[2]].forEach(function (ex) { if (ex > 0.004 && ex < 0.996 && Math.abs(fx - ex) < tx && fy >= z[1] - ty && fy <= z[1] + z[3] + ty && Math.abs(fx - ex) < bd) { bd = Math.abs(fx - ex); best = [1, ex] } })
          ;[z[1], z[1] + z[3]].forEach(function (ey) { if (ey > 0.004 && ey < 0.996 && Math.abs(fy - ey) < ty && fx >= z[0] - tx && fx <= z[0] + z[2] + tx && Math.abs(fy - ey) < bd) { bd = Math.abs(fy - ey); best = [2, ey] } })
        }
        return best
      }
      function dragTo(p) {
        var minf = 0.06, a = zones.map(z => z.slice()), ok = true
        dragZ.forEach(function (d) {
          var z = a[d.i]
          if (dragAxis === 1) { if (d.side === 0) { var w = z[0] + z[2] - p; if (w < minf) ok = false; else { z[2] = w; z[0] = p } } else { var w2 = p - z[0]; if (w2 < minf) ok = false; else z[2] = w2 } }
          else { if (d.side === 0) { var h = z[1] + z[3] - p; if (h < minf) ok = false; else { z[3] = h; z[1] = p } } else { var h2 = p - z[1]; if (h2 < minf) ok = false; else z[3] = h2 } }
        })
        if (ok) { zones = a; dragPos = p }
      }
      function saveAndExit() {
        var d = zr.data, n = nameIn.text.trim() || lname
        var l = { name: n, zones: zones.map(z => z.map(v => Math.round(v * 1000) / 1000)) }
        var found = false
        d.layouts = d.layouts.map(function (x) { if (x.name === lname) { found = true; return l } return x })
        if (!found) d.layouts.push(l)
        if (d.active === lname) d.active = n
        zr.persist(d); zr.run([zr.launcher, "manage"]); Qt.quit()
      }
      function cancelExit() { zr.run([zr.launcher, "manage"]); Qt.quit() }

      Item {
        anchors.fill: parent; focus: true
        Keys.onEscapePressed: ew.cancelExit()
        Keys.onDeletePressed: ew.delSel()
        // zones
        Repeater {
          model: ew.zones
          Rectangle {
            required property var modelData
            required property int index
            readonly property bool sel: ew.selected.indexOf(index) >= 0
            x: ew.ax + modelData[0] * ew.aw + 3; y: ew.ay + modelData[1] * ew.ah + 3
            width: modelData[2] * ew.aw - 6; height: modelData[3] * ew.ah - 6
            radius: 10; color: Qt.rgba(zr.accC.r, zr.accC.g, zr.accC.b, sel ? 0.55 : 0.2); border.color: zr.accC; border.width: sel ? 4 : 2
            Text { anchors.centerIn: parent; text: index + 1; color: zr.txtC; font.pixelSize: Math.min(parent.height * 0.4, 120); font.bold: true; opacity: 0.9 }
          }
        }
        // split guide
        Rectangle {
          visible: ew.tool !== "select" && em.containsMouse
          x: ew.tool === "splitv" ? em.mouseX - 1 : ew.ax; y: ew.tool === "splith" ? em.mouseY - 1 : ew.ay
          width: ew.tool === "splitv" ? 2 : ew.aw; height: ew.tool === "splith" ? 2 : ew.ah; color: zr.txtC; opacity: 0.9
        }
        MouseArea {
          id: em
          x: ew.ax; y: ew.ay; width: ew.aw; height: ew.ah
          hoverEnabled: true
          cursorShape: ew.dragAxis === 1 || (ew.tool === "select" && ew.findDivider(mouseX / ew.aw, mouseY / ew.ah) && ew.findDivider(mouseX / ew.aw, mouseY / ew.ah)[0] === 1) ? Qt.SizeHorCursor
                     : (ew.dragAxis === 2 || (ew.tool === "select" && ew.findDivider(mouseX / ew.aw, mouseY / ew.ah) && ew.findDivider(mouseX / ew.aw, mouseY / ew.ah)[0] === 2)) ? Qt.SizeVerCursor : Qt.ArrowCursor
          onPressed: (m) => {
            var fx = m.x / ew.aw, fy = m.y / ew.ah
            if (ew.tool === "select") {
              var dv = ew.findDivider(fx, fy)
              if (dv) {
                ew.dragAxis = dv[0]; ew.dragPos = dv[1]; var dz = []
                ew.zones.forEach(function (z, i) {
                  if (dv[0] === 1) { if (ew.near(z[0], dv[1])) dz.push({ i: i, side: 0 }); else if (ew.near(z[0] + z[2], dv[1])) dz.push({ i: i, side: 1 }) }
                  else { if (ew.near(z[1], dv[1])) dz.push({ i: i, side: 0 }); else if (ew.near(z[1] + z[3], dv[1])) dz.push({ i: i, side: 1 }) }
                })
                ew.dragZ = dz; return
              }
              var i = ew.hit(fx, fy); if (i < 0) return
              var s = ew.selected.slice(), k = s.indexOf(i)
              if (m.modifiers & Qt.ShiftModifier) { if (k >= 0) s.splice(k, 1); else s.push(i); ew.selected = s } else ew.selected = (k >= 0 && s.length === 1) ? [] : [i]
            } else {
              var j = ew.hit(fx, fy); if (j >= 0) ew.split(j, ew.tool === "splitv", ew.tool === "splitv" ? fx : fy)
            }
          }
          onPositionChanged: (m) => { if (ew.dragAxis !== 0 && pressed) ew.dragTo(Math.max(0.02, Math.min(0.98, ew.dragAxis === 1 ? m.x / ew.aw : m.y / ew.ah))) }
          onReleased: { ew.dragAxis = 0; ew.dragZ = [] }
        }
        // toolbar
        Rectangle {
          id: tb
          anchors.horizontalCenter: parent.horizontalCenter; y: 14; width: tbr.implicitWidth + 28; height: 56; radius: 14; color: zr.bgC; border.color: zr.accC; border.width: 2
          Row {
            id: tbr; anchors.centerIn: parent; spacing: 8
            Rectangle { width: 190; height: 36; radius: 9; color: zr.selC; border.color: zr.accC; border.width: 1
              TextInput { id: nameIn; anchors.fill: parent; anchors.margins: 8; color: zr.txtC; font.pixelSize: 14; clip: true; selectionColor: zr.accC; text: ew.lname; onTextChanged: if (activeFocus) {} } }
            Repeater {
              model: [{ t: "Select", k: "select" }, { t: "Split | (click)", k: "splitv" }, { t: "Split ― (click)", k: "splith" }]
              Rectangle { width: modelData.k === "select" ? 74 : 120; height: 36; radius: 9; color: ew.tool === modelData.k ? zr.accC : (tla.containsMouse ? zr.selC : "transparent"); border.color: zr.accC; border.width: 1
                Text { anchors.centerIn: parent; text: modelData.t; color: ew.tool === modelData.k ? zr.bgC : zr.txtC; font.pixelSize: 13; font.bold: ew.tool === modelData.k }
                MouseArea { id: tla; anchors.fill: parent; hoverEnabled: true; onClicked: ew.tool = modelData.k } }
            }
            Rectangle { width: 80; height: 36; radius: 9; opacity: ew.selected.length > 1 ? 1 : 0.4; color: mga.containsMouse ? zr.selC : "transparent"; border.color: zr.accC; border.width: 1
              Text { anchors.centerIn: parent; text: "Merge"; color: zr.txtC; font.pixelSize: 13 }
              MouseArea { id: mga; anchors.fill: parent; hoverEnabled: true; onClicked: ew.mergeSel() } }
            Rectangle { width: 80; height: 36; radius: 9; opacity: ew.selected.length > 0 && ew.selected.length < ew.zones.length ? 1 : 0.4; color: dla.containsMouse ? "#5a2a24" : "transparent"; border.color: "#E0705A"; border.width: 1
              Text { anchors.centerIn: parent; text: "Delete"; color: "#E0705A"; font.pixelSize: 13 }
              MouseArea { id: dla; anchors.fill: parent; hoverEnabled: true; onClicked: ew.delSel() } }
            Rectangle { width: 80; height: 36; radius: 9; color: sva.containsMouse ? zr.txtC : zr.accC
              Text { anchors.centerIn: parent; text: "Save"; color: zr.bgC; font.pixelSize: 14; font.bold: true }
              MouseArea { id: sva; anchors.fill: parent; hoverEnabled: true; onClicked: ew.saveAndExit() } }
            Rectangle { width: 80; height: 36; radius: 9; color: cca.containsMouse ? zr.selC : "transparent"; border.color: zr.accC; border.width: 1
              Text { anchors.centerIn: parent; text: "Cancel"; color: zr.txtC; font.pixelSize: 13 }
              MouseArea { id: cca; anchors.fill: parent; hoverEnabled: true; onClicked: ew.cancelExit() } }
          }
        }
        Text { anchors.horizontalCenter: parent.horizontalCenter; y: 78; color: zr.txtC; opacity: 0.8; font.pixelSize: 14
          text: ew.tool === "select" ? "Click a zone to select it (Shift-click to add more)  ·  drag a divider to resize  ·  Split tools cut a zone where you click" : "Click inside a zone to cut it here  ·  switch back to Select when you are done" }
      }
    }
  }
}
