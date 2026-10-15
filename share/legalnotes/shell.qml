import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Dock Notes: a small notes window (list on the left, editor on the right), saved to ~/.local/share/legal-dock/notes.json. Skin-coloured.
ShellRoot {
  id: nt
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) nt.bgC = c.bg
      if (c.acc) nt.accC = c.acc
      if (c.txt) nt.txtC = c.txt
      if (c.sel) nt.selC = c.sel
    }
  }
  readonly property string file: Quickshell.env("HOME") + "/.local/share/legal-dock/notes.json"
  property var notes: []      // [{id, text, t}]
  property int cur: 0
  property bool ready: false
  FileView {
    path: nt.file; printErrors: false
    onLoaded: { try { nt.notes = JSON.parse(text()) } catch (e) { nt.notes = [] } if (!nt.notes.length) nt.notes = [{ id: Date.now(), text: "", t: Date.now() }]; nt.ready = true }
    onLoadFailed: { nt.notes = [{ id: Date.now(), text: "", t: Date.now() }]; nt.ready = true }
  }
  Process { id: writer; stdinEnabled: true; command: ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat > \"$1.tmp\" && mv \"$1.tmp\" \"$1\"", "x", nt.file] }
  function save() { writer.running = false; writer.running = true; writer.write(JSON.stringify(nt.notes)); writer.stdinEnabled = false; writer.stdinEnabled = true }
  Timer { id: saveT; interval: 600; onTriggered: nt.save() }
  function titleOf(n) { var l = (n.text || "").split("\n")[0].trim(); return l.length ? l : "New note" }
  function newNote() { var a = nt.notes.slice(); a.unshift({ id: Date.now(), text: "", t: Date.now() }); nt.notes = a; nt.cur = 0; ed.text = ""; ed.forceActiveFocus(); saveT.restart() }
  function delNote() { var a = nt.notes.slice(); a.splice(nt.cur, 1); if (!a.length) a = [{ id: Date.now(), text: "", t: Date.now() }]; nt.notes = a; nt.cur = Math.min(nt.cur, a.length - 1); ed.text = a[nt.cur].text; saveT.restart() }
  function pick(i) { nt.cur = i; ed.text = nt.notes[i].text }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legalnotes"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }
    Rectangle {
      width: Math.min(820, parent.width - 40); height: Math.min(540, parent.height - 140)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 30
      radius: 16; color: nt.bgC; border.color: nt.accC; border.width: 2
      MouseArea { anchors.fill: parent }
      Keys.onEscapePressed: Qt.quit()

      Text { x: 24; y: 16; text: "Notes"; color: nt.txtC; font.pixelSize: 20; font.bold: true }
      Row {
        anchors.right: parent.right; anchors.rightMargin: 16; y: 14; spacing: 8
        Rectangle { width: 70; height: 30; radius: 10; color: nma.containsMouse ? nt.accC : nt.selC; border.color: nt.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "+ New"; color: nma.containsMouse ? nt.bgC : nt.txtC; font.pixelSize: 13 }
          MouseArea { id: nma; anchors.fill: parent; hoverEnabled: true; onClicked: nt.newNote() } }
        Rectangle { width: 70; height: 30; radius: 10; color: dma.containsMouse ? "#5a2a24" : nt.selC; border.color: nt.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "Delete"; color: nt.txtC; font.pixelSize: 13 }
          MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: nt.delNote() } }
        Rectangle { width: 30; height: 30; radius: 15; color: xma.containsMouse ? nt.accC : "transparent"; border.color: nt.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? nt.bgC : nt.txtC; font.pixelSize: 12 }
          MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }
      }
      ListView {
        id: list
        x: 16; y: 58; width: 230; height: parent.height - 74; clip: true; spacing: 4
        model: nt.notes
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: list.width; height: 48; radius: 10
          color: index === nt.cur ? nt.selC : (lma.containsMouse ? Qt.darker(nt.selC, 1.25) : "transparent")
          border.color: index === nt.cur ? nt.accC : "transparent"; border.width: 1
          Text { x: 12; y: 7; width: parent.width - 24; elide: Text.ElideRight; text: nt.titleOf(modelData); color: nt.txtC; font.pixelSize: 14; font.bold: true }
          Text { x: 12; y: 27; text: Qt.formatDateTime(new Date(modelData.t), "d MMM  h:mm ap"); color: nt.txtC; opacity: 0.55; font.pixelSize: 11 }
          MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: nt.pick(index) }
        }
      }
      Rectangle { x: 258; y: 58; width: 1; height: parent.height - 74; color: nt.accC; opacity: 0.35 }
      Flickable {
        x: 274; y: 58; width: parent.width - 274 - 16; height: parent.height - 74; clip: true
        contentHeight: Math.max(height, ed.paintedHeight + 20)
        TextEdit {
          id: ed
          width: parent.width; wrapMode: TextEdit.Wrap; color: nt.txtC; selectionColor: nt.accC; font.pixelSize: 15
          focus: true; Component.onCompleted: if (nt.ready) text = nt.notes[nt.cur].text
          Connections { target: nt; function onReadyChanged() { if (nt.ready) ed.text = nt.notes[nt.cur].text } }
          onTextChanged: {
            if (!nt.ready || !nt.notes[nt.cur] || nt.notes[nt.cur].text === text) return
            var a = nt.notes.slice(); a[nt.cur] = { id: a[nt.cur].id, text: text, t: Date.now() }; nt.notes = a; saveT.restart()
          }
          Keys.onEscapePressed: Qt.quit()
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: nt.bgC; border.color: nt.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-dock/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: nt.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
