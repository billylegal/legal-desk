import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Dock Calendar: month view with today highlighted, click a day to see / add its events. Saved to ~/.local/share/legal-dock/calendar.json. Skin-coloured.
ShellRoot {
  id: cal
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) cal.bgC = c.bg
      if (c.acc) cal.accC = c.acc
      if (c.txt) cal.txtC = c.txt
      if (c.sel) cal.selC = c.sel
    }
  }
  readonly property string file: Quickshell.env("HOME") + "/.local/share/legal-dock/calendar.json"
  property var events: []          // [{id, date: "YYYY-MM-DD", time: "HH:MM" or "", title}]
  FileView {
    path: cal.file; printErrors: false
    onLoaded: { try { cal.events = JSON.parse(text()) } catch (e) { cal.events = [] } }
  }
  Process { id: writer; stdinEnabled: true; command: ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "x", cal.file] }
  function save() { writer.running = false; writer.running = true; writer.write(JSON.stringify(cal.events)); writer.stdinEnabled = false; writer.stdinEnabled = true }

  function key(d) { return d.getFullYear() + "-" + ("0" + (d.getMonth() + 1)).slice(-2) + "-" + ("0" + d.getDate()).slice(-2) }
  readonly property var today: new Date()
  property int viewY: today.getFullYear()
  property int viewM: today.getMonth()
  property string sel: key(today)
  readonly property var monthNames: ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
  readonly property var days: {
    var first = new Date(viewY, viewM, 1), start = new Date(viewY, viewM, 1 - first.getDay()), a = []
    for (var i = 0; i < 42; i++) { var d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i); a.push({ d: d, k: key(d), inM: d.getMonth() === viewM }) }
    return a
  }
  function evOf(k) { return events.filter(e => e.date === k).sort(function (a, b) { return (a.time || "99") < (b.time || "99") ? -1 : 1 }) }
  function shift(n) { var d = new Date(viewY, viewM + n, 1); viewY = d.getFullYear(); viewM = d.getMonth() }
  function goToday() { viewY = today.getFullYear(); viewM = today.getMonth(); sel = key(today) }
  function addEv() {
    var t = titleIn.text.trim(); if (!t) return
    var tm = timeIn.text.trim(); if (!/^([01]?[0-9]|2[0-3]):[0-5][0-9]$/.test(tm)) tm = ""
    else if (tm.length === 4) tm = "0" + tm
    var a = events.slice(); a.push({ id: Date.now(), date: sel, time: tm, title: t }); events = a; save(); titleIn.text = ""; timeIn.text = ""
  }
  function delEv(id) { events = events.filter(e => e.id !== id); save() }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legalcalendar"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    Rectangle {
      id: card
      width: Math.min(980, parent.width - 40); height: Math.min(620, parent.height - 120)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 24
      radius: 16; color: cal.bgC; border.color: cal.accC; border.width: 2
      MouseArea { anchors.fill: parent }
      Keys.onEscapePressed: Qt.quit()
      readonly property real sideW: 270
      readonly property real gridW: width - sideW - 56

      // header
      Text { x: 24; y: 14; text: cal.monthNames[cal.viewM] + " "; color: cal.txtC; font.pixelSize: 24; font.bold: true
        Text { anchors.left: parent.right; anchors.baseline: parent.baseline; text: cal.viewY; color: cal.accC; font.pixelSize: 24 } }
      Row {
        x: card.gridW - 150 + 24; y: 14; spacing: 6
        Repeater {
          model: [{ t: "‹", n: -1 }, { t: "Today", n: 0 }, { t: "›", n: 1 }]
          Rectangle {
            width: modelData.n === 0 ? 64 : 34; height: 32; radius: 10
            color: hma.containsMouse ? cal.accC : cal.selC; border.color: cal.accC; border.width: 1
            Text { anchors.centerIn: parent; text: modelData.t; color: hma.containsMouse ? cal.bgC : cal.txtC; font.pixelSize: modelData.n === 0 ? 13 : 20 }
            MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; onClicked: modelData.n === 0 ? cal.goToday() : cal.shift(modelData.n) }
          }
        }
      }
      // weekday names
      Row {
        x: 24; y: 62; width: card.gridW
        Repeater { model: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
          Text { width: card.gridW / 7; horizontalAlignment: Text.AlignHCenter; text: modelData; color: cal.txtC; opacity: 0.6; font.pixelSize: 12 } }
      }
      // month grid
      Grid {
        id: mg
        x: 24; y: 84; columns: 7
        readonly property real cw: card.gridW / 7
        readonly property real ch: (card.height - 84 - 18) / 6
        Repeater {
          model: cal.days
          Rectangle {
            width: mg.cw; height: mg.ch
            color: modelData.k === cal.sel ? cal.selC : (dma.containsMouse ? Qt.darker(cal.selC, 1.3) : "transparent")
            border.color: modelData.k === cal.sel ? cal.accC : Qt.rgba(cal.accC.r, cal.accC.g, cal.accC.b, 0.18); border.width: 1
            readonly property var evs: cal.evOf(modelData.k)
            opacity: modelData.inM ? 1 : 0.4
            Rectangle {
              x: parent.width - 30; y: 4; width: 24; height: 24; radius: 12
              color: modelData.k === cal.key(cal.today) ? cal.accC : "transparent"
              Text { anchors.centerIn: parent; text: modelData.d.getDate(); font.pixelSize: 13; font.bold: modelData.k === cal.key(cal.today)
                color: modelData.k === cal.key(cal.today) ? cal.bgC : cal.txtC }
            }
            Column {
              x: 5; y: 32; width: parent.width - 10; spacing: 2
              Repeater {
                model: evs.slice(0, 2)
                Rectangle { width: parent.width; height: 16; radius: 4; color: Qt.rgba(cal.accC.r, cal.accC.g, cal.accC.b, 0.35)
                  Text { x: 4; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 8; elide: Text.ElideRight; color: cal.txtC; font.pixelSize: 10
                    text: (modelData.time ? modelData.time + " " : "") + modelData.title } }
              }
              Text { visible: evs.length > 2; text: "+" + (evs.length - 2) + " more"; color: cal.txtC; opacity: 0.6; font.pixelSize: 10 }
            }
            MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true
              onClicked: { cal.sel = modelData.k; if (!modelData.inM) { cal.viewY = modelData.d.getFullYear(); cal.viewM = modelData.d.getMonth() } titleIn.forceActiveFocus() } }
          }
        }
      }
      Rectangle { x: card.width - card.sideW - 16; y: 16; width: 1; height: card.height - 32; color: cal.accC; opacity: 0.35 }

      // selected day
      Item {
        x: card.width - card.sideW; y: 14; width: card.sideW - 16; height: card.height - 28
        readonly property var sd: { var p = cal.sel.split("-"); return new Date(+p[0], +p[1] - 1, +p[2]) }
        Text { text: Qt.formatDate(parent.sd, "dddd"); color: cal.accC; font.pixelSize: 13; font.bold: true }
        Text { y: 18; text: Qt.formatDate(parent.sd, "d MMMM yyyy"); color: cal.txtC; font.pixelSize: 19; font.bold: true }
        Rectangle { x: parent.width - 28; y: 0; width: 28; height: 28; radius: 14; color: xma.containsMouse ? cal.accC : "transparent"; border.color: cal.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? cal.bgC : cal.txtC; font.pixelSize: 12 }
          MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }
        ListView {
          id: evl
          y: 56; width: parent.width; height: parent.height - 56 - 112; clip: true; spacing: 6
          model: cal.evOf(cal.sel)
          delegate: Rectangle {
            width: evl.width; height: 44; radius: 10; color: cal.selC; border.color: cal.accC; border.width: 1
            Rectangle { x: 0; width: 4; height: parent.height; radius: 2; color: cal.accC }
            Text { x: 14; y: 6; text: modelData.time || "All day"; color: cal.accC; font.pixelSize: 11 }
            Text { x: 14; y: 22; width: parent.width - 50; elide: Text.ElideRight; text: modelData.title; color: cal.txtC; font.pixelSize: 14 }
            Text { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: "✕"; color: cal.txtC; opacity: dla.containsMouse ? 1 : 0.45; font.pixelSize: 13
              MouseArea { id: dla; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true; onClicked: cal.delEv(modelData.id) } }
          }
          Text { visible: evl.count === 0; anchors.horizontalCenter: parent.horizontalCenter; y: 20; text: "No events"; color: cal.txtC; opacity: 0.5; font.pixelSize: 14 }
        }
        // add form
        Column {
          y: parent.height - 104; width: parent.width; spacing: 8
          Rectangle { width: parent.width; height: 34; radius: 10; color: cal.selC; border.color: cal.accC; border.width: 1
            TextInput { id: titleIn; focus: true; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; verticalAlignment: TextInput.AlignVCenter; color: cal.txtC; font.pixelSize: 14; clip: true; selectionColor: cal.accC
              Keys.onReturnPressed: cal.addEv(); Keys.onEscapePressed: Qt.quit()
              Text { visible: titleIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "New event"; color: cal.txtC; opacity: 0.5; font.pixelSize: 14 } } }
          Row { spacing: 8
            Rectangle { width: 96; height: 34; radius: 10; color: cal.selC; border.color: cal.accC; border.width: 1
              TextInput { id: timeIn; anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; verticalAlignment: TextInput.AlignVCenter; color: cal.txtC; font.pixelSize: 14; clip: true; selectionColor: cal.accC; maximumLength: 5
                Keys.onReturnPressed: cal.addEv(); Keys.onEscapePressed: Qt.quit()
                Text { visible: timeIn.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "HH:MM"; color: cal.txtC; opacity: 0.5; font.pixelSize: 14 } } }
            Rectangle { width: parent.parent.width - 96 - 8; height: 34; radius: 10; color: ama.containsMouse ? cal.accC : cal.selC; border.color: cal.accC; border.width: 1
              Text { anchors.centerIn: parent; text: "+ Add event"; color: ama.containsMouse ? cal.bgC : cal.txtC; font.pixelSize: 14 }
              MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; onClicked: cal.addEv() } }
          }
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: cal.bgC; border.color: cal.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-dock/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: cal.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
