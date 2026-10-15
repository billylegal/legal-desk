import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk "Apps": a tidy launcher window - categories on the left, search on top, an even grid of app icons on skin-coloured plates.
// Colours and plate shape follow the dock skin (~/.cache/dock-menu-colors, ~/.cache/drawer-shape). Esc, the ✕ or a click outside closes it.
ShellRoot {
  id: ap
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  property int plateR: 12
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) ap.bgC = c.bg
      if (c.acc) ap.accC = c.acc
      if (c.txt) ap.txtC = c.txt
      if (c.sel) ap.selC = c.sel
    }
  }
  FileView {
    path: Quickshell.env("HOME") + "/.cache/drawer-shape"; printErrors: false
    onLoaded: { var v = parseInt(text().trim()); if (!isNaN(v)) ap.plateR = v }
  }

  readonly property var cats: ["All", "Legal Desk", "Recent", "Accessories", "Games", "Graphics", "Internet", "Office", "Programming", "Sound & Video", "System", "Other"]
  // Apps kept in the dock (same list the docks use) and the last apps opened from here.
  property var dockList: []
  FileView {
    path: Quickshell.env("HOME") + "/.cache/nwg-dock-pinned"; watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: ap.dockList = text().split("\n").map(x => x.trim().toLowerCase()).filter(x => x)
  }
  property var recent: []
  FileView {
    path: Quickshell.env("HOME") + "/.cache/appsmenu-recent"; printErrors: false
    onLoaded: ap.recent = text().split("\n").filter(x => x)
  }
  property var ownList: []
  FileView {
    path: Quickshell.env("HOME") + "/.cache/macdock-own"; watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: ap.ownList = text().split("\n").map(x => x.trim()).filter(x => x)
  }
  // Legal Desk's own icons come from the chosen icon set (~/.cache/legal-desk/icons/<stamp>/, drawn by legal-icons in the skin's colours).
  property string artDir: ""
  FileView {
    path: Quickshell.env("HOME") + "/.cache/legal-desk/icons/current"; printErrors: false
    onLoaded: { var t = text().trim(); ap.artDir = t ? "file://" + Quickshell.env("HOME") + "/.cache/legal-desk/icons/" + t : "" }
  }
  readonly property bool neb: ("" + accC).toLowerCase() === "#8b5cf6"   // Nebula skin
  property date nowD: new Date()
  Timer { interval: 20000; running: true; repeat: true; onTriggered: ap.nowD = new Date() }
  function dockKey(e) { return e.own ? "" : (e.startupClass || e.id || "") }
  function inDock(e) { if (e.own) return !!e.token && ownList.indexOf(e.token) >= 0; return inDockApp(e) }
  function inDockApp(e) { var k = dockKey(e).toLowerCase(); return k !== "" && (dockList.indexOf(k) >= 0 || dockList.indexOf((e.id || "").toLowerCase()) >= 0) }
  property var ctxE: null
  property real ctxX: 0
  property real ctxY: 0
  property string cat: "All"
  property string query: ""

  function groupOf(e) {
    var c = e.categories || []
    function has(x) { return c.indexOf(x) >= 0 }
    if (has("Game")) return "Games"
    if (has("Development") || has("IDE")) return "Programming"
    if (has("AudioVideo") || has("Audio") || has("Video") || has("Music")) return "Sound & Video"
    if (has("Graphics")) return "Graphics"
    if (has("Network") || has("WebBrowser") || has("Email") || has("Chat")) return "Internet"
    if (has("Office")) return "Office"
    if (has("Settings") || has("System") || has("Monitor")) return "System"
    if (has("Utility") || has("Accessories")) return "Accessories"
    return "Other"
  }
  // Legal Desk's own apps: Calendar and Notes are built in; Mail opens your Outlook in an app window.
  readonly property var own: [
    { name: "Mail", art: "mail", glyph: "\u2709", own: true, cmd: ["/usr/lib/legal-desk/legal-mail"] },
    { name: "Calendar", art: "calendar", glyph: "\u25A6", own: true, token: "__calendar__", cmd: ["/usr/lib/legal-desk/legal-calendar"] },
    { name: "Legal Zones", art: "zones", glyph: "\u229E", own: true, token: "__zones__", cmd: ["/usr/lib/legal-desk/legal-zones"] },
    { name: "Disk Management", art: "disks", glyph: "\u26C1", own: true, token: "__disks__", cmd: ["/usr/lib/legal-desk/legal-disks"] },
    { name: "Clock", art: "clock", glyph: "\u25F7", own: true, cmd: ["/usr/lib/legal-desk/legal-clock"] },
    { name: "Task Manager", art: "tasks", glyph: "\u25A4", own: true, token: "__tasks__", cmd: ["/usr/lib/legal-desk/legal-tasks"] },
    { name: "1UP Radio", art: "radio", glyph: "\u266B", own: true, token: "__radio__", cmd: ["/usr/lib/legal-desk/legal-radio", "toggle"] },
    { name: "Notes", art: "notes", glyph: "\u270E", own: true, token: "__notes__", cmd: ["/usr/lib/legal-desk/legal-notes"] }
  ]
  readonly property var all: {
    var a = DesktopEntries.applications.values.filter(e => !e.noDisplay)
    a.sort(function (x, y) { return x.name.toLowerCase() < y.name.toLowerCase() ? -1 : 1 })
    return own.concat(a)
  }
  readonly property var shown: {
    var q = query.trim().toLowerCase()
    return all.filter(function (e) {
      if (!q && cat === "Recent") return recent.indexOf(e.name) >= 0
      if (!q && e.own) return cat === "All" || cat === "Legal Desk"
      if (!q && cat === "Legal Desk") return false
      if (q) return e.name.toLowerCase().indexOf(q) >= 0 || (e.genericName || "").toLowerCase().indexOf(q) >= 0 || (e.comment || "").toLowerCase().indexOf(q) >= 0
      return cat === "All" || groupOf(e) === cat
    })
  }
  Process { id: ownProc; property var cmd: []; command: cmd }
  readonly property var shownSorted: (cat === "Recent" && query.trim() === "") ? shown.slice().sort(function (a, b) { return recent.indexOf(a.name) - recent.indexOf(b.name) }) : shown
  Process { id: recProc; property var cmd: []; command: cmd }
  function noteRecent(e) {
    var r = [e.name].concat(recent.filter(x => x !== e.name)).slice(0, 12); recent = r
    recProc.cmd = ["bash", "-c", "printf '%s\\n' \"$@\" > \"$HOME/.cache/appsmenu-recent\"", "x"].concat(r); recProc.running = false; recProc.running = true
  }
  Process { id: ownPin; property var cmd: []; command: cmd }
  Process { id: pinProc; property var cmd: []; command: cmd }
  function togglePin(e) { var k = dockKey(e); if (!k) return; pinProc.cmd = ["/usr/lib/legal-desk/dock-pin-toggle", k]; pinProc.running = false; pinProc.running = true; ctxE = null }
  function run(e) {
    noteRecent(e)
    if (e.own) { ownProc.cmd = ["setsid", "-f"].concat(e.cmd); ownProc.running = true; Qt.quit(); return }
    e.execute(); Qt.quit()
  }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "appsmenu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    Rectangle {
      id: card
      width: Math.min(900, parent.width - 40); height: Math.min(600, parent.height - 140)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 30
      radius: Math.max(10, Math.min(20, ap.plateR)); color: ap.bgC; border.color: ap.accC; border.width: 2
      MouseArea { anchors.fill: parent }   // clicks inside don't close it
      Keys.onEscapePressed: Qt.quit()

      // ---- sidebar ----
      Column {
        id: side
        x: 14; y: 16; width: 176; spacing: 4
        Text { text: "Apps"; color: ap.txtC; font.pixelSize: 20; font.bold: true; leftPadding: 10; bottomPadding: 8 }
        Repeater {
          model: ap.cats
          Rectangle {
            width: side.width; height: 34; radius: Math.min(10, ap.plateR)
            color: (ap.cat === modelData && ap.query === "") ? ap.selC : (cma.containsMouse ? Qt.darker(ap.selC, 1.25) : "transparent")
            Rectangle { visible: ap.cat === modelData && ap.query === ""; width: 3; height: parent.height - 14; radius: 1.5; color: ap.accC; x: 3; anchors.verticalCenter: parent.verticalCenter }
            Text { anchors.verticalCenter: parent.verticalCenter; x: 16; text: modelData; color: ap.txtC; font.pixelSize: 14 }
            MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: { ap.cat = modelData; ap.query = ""; search.text = "" } }
          }
        }
      }
      Rectangle { x: 204; y: 16; width: 1; height: parent.height - 32; color: ap.accC; opacity: 0.35 }

      // ---- search + grid ----
      Rectangle {
        id: sbox
        x: 222; y: 16; width: parent.width - 222 - 56; height: 40; radius: Math.min(12, ap.plateR + 2)
        color: ap.selC; border.color: ap.accC; border.width: 1
        TextInput {
          id: search
          anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; verticalAlignment: TextInput.AlignVCenter
          color: ap.txtC; font.pixelSize: 15; selectionColor: ap.accC; clip: true; focus: true
          onTextChanged: ap.query = text
          Keys.onEscapePressed: Qt.quit()
          Keys.onReturnPressed: if (ap.shown.length) ap.run(ap.shown[0])
          Text { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search apps"; color: ap.txtC; opacity: 0.5; font.pixelSize: 15 }
        }
      }
      Rectangle {
        x: parent.width - 44; y: 16; width: 28; height: 40; color: "transparent"
        Rectangle { anchors.centerIn: parent; width: 28; height: 28; radius: 14; color: xma.containsMouse ? ap.accC : "transparent"; border.color: ap.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? ap.bgC : ap.txtC; font.pixelSize: 12 } }
        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() }
      }

      GridView {
        id: grid
        x: 222; y: 70; width: parent.width - 222 - 16; height: parent.height - 70 - 16
        cellWidth: Math.floor(width / 5); cellHeight: 112
        clip: true; model: ap.shownSorted; boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
          width: grid.cellWidth; height: grid.cellHeight
          required property var modelData
          Rectangle {
            anchors.fill: parent; anchors.margins: 4; radius: Math.min(14, ap.plateR + 2)
            color: ima.containsMouse ? ap.selC : "transparent"
            Rectangle {
              id: plate
              anchors.horizontalCenter: parent.horizontalCenter; y: 8; width: 62; height: 62
              radius: Math.min(31, ap.plateR + 4); color: "transparent"; border.width: 0
              Image {
                visible: !!modelData.art && ap.artDir !== ""
                anchors.centerIn: parent; width: 62; height: 62; sourceSize.width: 192; sourceSize.height: 192
                source: visible ? ap.artDir + "/" + modelData.art + ".svg" : ""; smooth: true; mipmap: true; fillMode: Image.PreserveAspectFit
              }
              Image {
                visible: !modelData.art
                anchors.centerIn: parent; width: 56; height: width; sourceSize.width: 112; sourceSize.height: 112
                source: modelData.glyph ? "" : Quickshell.iconPath(modelData.icon, "application-x-executable"); smooth: true; fillMode: Image.PreserveAspectFit
              }
            }
            Text {
              anchors.horizontalCenter: parent.horizontalCenter; y: 76; width: parent.width - 8
              horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.name
              color: ap.txtC; font.pixelSize: 12
            }
            // kept-in-dock marker
            Rectangle { visible: ap.inDock(modelData); x: parent.width - 18; y: 6; width: 8; height: 8; radius: 4; color: ap.accC }
            MouseArea { id: ima; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: (m) => {
                if (m.button === Qt.RightButton) { var p = ima.mapToItem(card, m.x, m.y); ap.ctxX = p.x; ap.ctxY = p.y; ap.ctxE = modelData }
                else { ap.ctxE = null; ap.run(modelData) }
              } }
          }
        }
        Text { visible: ap.shown.length === 0; anchors.centerIn: parent; text: "No apps found"; color: ap.txtC; opacity: 0.6; font.pixelSize: 15 }
      }
      // right-click menu on an app: Open, app actions (New window...), Keep in Dock / Remove from Dock
      MouseArea { visible: ap.ctxE !== null; anchors.fill: parent; z: 40; acceptedButtons: Qt.AllButtons; onClicked: ap.ctxE = null }
      Rectangle {
        id: cmenu
        visible: ap.ctxE !== null; z: 50
        readonly property var items: {
          var e = ap.ctxE; if (!e) return []
          var a = [{ t: "Open", f: function () { ap.run(e) } }]
          if (e.own && e.token) a.push({ t: ap.inDock(e) ? "Remove from Dock" : "Keep in Dock", f: function () { ownPin.cmd = ["/usr/lib/legal-desk/dock-own-toggle", e.token]; ownPin.running = false; ownPin.running = true; ap.ctxE = null }, sep: true })
          if (!e.own) {
            (e.actions || []).forEach(function (act) { a.push({ t: act.name, f: function () { ap.noteRecent(e); act.execute(); Qt.quit() } }) })
            a.push({ t: ap.inDock(e) ? "Remove from Dock" : "Keep in Dock", f: function () { ap.togglePin(e) }, sep: true })
          }
          return a
        }
        width: 190; height: items.length * 32 + 12; radius: 12
        x: Math.min(card.width - width - 8, ap.ctxX); y: Math.min(card.height - height - 8, ap.ctxY)
        color: ap.bgC; border.color: ap.accC; border.width: 1
        Column {
          x: 6; y: 6; width: parent.width - 12
          Repeater {
            model: cmenu.items
            Item {
              width: parent.width; height: 32
              Rectangle { visible: !!modelData.sep; width: parent.width - 12; x: 6; height: 1; color: ap.accC; opacity: 0.35 }
              Rectangle { anchors.fill: parent; anchors.topMargin: modelData.sep ? 2 : 0; radius: 8; color: cma2.containsMouse ? ap.selC : "transparent"
                Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: modelData.t; color: ap.txtC; font.pixelSize: 13 } }
              MouseArea { id: cma2; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.f() }
            }
          }
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: ap.bgC; border.color: ap.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: ap.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
