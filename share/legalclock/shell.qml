import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Legal Desk Clock: World Clock (your cities, live) and Timer (keeps running when this window is closed; the clock in the corner shows what is left). Skin-coloured.
ShellRoot {
  id: ck
  property color bgC: "#0B0818"
  property color accC: "#8B5CF6"
  property color txtC: "#E6E1FA"
  property color selC: "#2A1B52"
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    blockLoading: true   // read before the window opens: no default-colour flash
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) ck.bgC = c.bg
      if (c.acc) ck.accC = c.acc
      if (c.txt) ck.txtC = c.txt
      if (c.sel) ck.selC = c.sel
    }
  }
  readonly property string home: Quickshell.env("HOME")
  property int tab: parseInt(Quickshell.env("CLOCK_TAB") || "0")
  property var now: new Date()
  Timer { interval: 250; running: true; repeat: true; onTriggered: { ck.now = new Date(); timerFile.reload() } }

  // ---------------- World Clock ----------------
  readonly property var cityList: [
    ["New York", "America/New_York"], ["Los Angeles", "America/Los_Angeles"], ["Chicago", "America/Chicago"], ["Toronto", "America/Toronto"], ["Vancouver", "America/Vancouver"],
    ["Mexico City", "America/Mexico_City"], ["Sao Paulo", "America/Sao_Paulo"], ["Buenos Aires", "America/Argentina/Buenos_Aires"], ["London", "Europe/London"], ["Dublin", "Europe/Dublin"],
    ["Lisbon", "Europe/Lisbon"], ["Paris", "Europe/Paris"], ["Madrid", "Europe/Madrid"], ["Rome", "Europe/Rome"], ["Berlin", "Europe/Berlin"], ["Amsterdam", "Europe/Amsterdam"],
    ["Athens", "Europe/Athens"], ["Istanbul", "Europe/Istanbul"], ["Moscow", "Europe/Moscow"], ["Cairo", "Africa/Cairo"], ["Lagos", "Africa/Lagos"], ["Johannesburg", "Africa/Johannesburg"],
    ["Dubai", "Asia/Dubai"], ["Mumbai", "Asia/Kolkata"], ["Bangkok", "Asia/Bangkok"], ["Singapore", "Asia/Singapore"], ["Hong Kong", "Asia/Hong_Kong"], ["Shanghai", "Asia/Shanghai"],
    ["Tokyo", "Asia/Tokyo"], ["Seoul", "Asia/Seoul"], ["Sydney", "Australia/Sydney"], ["Auckland", "Pacific/Auckland"], ["Honolulu", "Pacific/Honolulu"]
  ]
  property var chosen: [["New York", "America/New_York"], ["London", "Europe/London"], ["Athens", "Europe/Athens"], ["Tokyo", "Asia/Tokyo"]]
  property var offs: ({})
  property bool picking: false
  FileView {
    path: ck.home + "/.local/share/legal-desk/worldclock.json"; printErrors: false
    onLoaded: { try { var a = JSON.parse(text()); if (a.length) ck.chosen = a } catch (e) { } offProc.running = true }
    onLoadFailed: offProc.running = true
  }
  Process { id: wr; stdinEnabled: true; command: ["bash", "-c", "mkdir -p \"$(dirname \"$1\")\" && cat > \"$1\"", "x", ck.home + "/.local/share/legal-desk/worldclock.json"] }
  function saveCities() { wr.running = false; wr.running = true; wr.write(JSON.stringify(ck.chosen)); wr.stdinEnabled = false; wr.stdinEnabled = true; offProc.running = false; offProc.running = true }
  Process {
    id: offProc
    command: ["/usr/lib/legal-desk/legal-worldclock-sample"].concat(ck.chosen.map(c => c[1]))
    stdout: StdioCollector { onStreamFinished: { try { ck.offs = JSON.parse(text) } catch (e) { } } }
  }
  Timer { interval: 120000; running: true; repeat: true; onTriggered: { offProc.running = false; offProc.running = true } }
  function two(n) { return ("0" + n).slice(-2) }
  function cityTime(tz) {
    var o = offs[tz]; if (o === undefined) return { t: "--:--", d: "" }
    var d = new Date(now.getTime() + o * 1000), h = d.getUTCHours()
    var day = d.getUTCDate() === new Date(now.getTime() - now.getTimezoneOffset() * 60000).getUTCDate() ? "Today" : (d.getTime() > now.getTime() + (-now.getTimezoneOffset() * 60000) ? "Tomorrow" : "Yesterday")
    var diff = (o + now.getTimezoneOffset() * 60) / 3600
    return { t: ((h % 12) || 12) + ":" + two(d.getUTCMinutes()) + " " + (h < 12 ? "AM" : "PM"), d: day + ", " + (diff === 0 ? "same time" : (diff > 0 ? "+" : "") + (Math.abs(diff % 1) > 0 ? diff.toFixed(1) : diff) + "h"), hour: h }
  }

  // ---------------- Timer ----------------
  property string tState: "idle"       // idle | run | pause | done
  property real tEnd: 0
  property real tRemain: 0
  property real tTotal: 0
  FileView {
    id: timerFile
    path: ck.home + "/.cache/legal-timer"; printErrors: false
    onLoaded: {
      var p = text().trim().split(/\s+/)
      if (p[0] === "run") { ck.tState = "run"; ck.tEnd = parseInt(p[1]) * 1000; ck.tTotal = parseInt(p[2]) }
      else if (p[0] === "pause") { ck.tState = "pause"; ck.tRemain = parseInt(p[1]); ck.tTotal = parseInt(p[2]) }
      else if (p[0] === "done") { ck.tState = "done" }
      else ck.tState = "idle"
    }
    onLoadFailed: ck.tState = "idle"
  }
  property int setMin: 5
  property int setSec: 0
  readonly property real remainSec: tState === "run" ? Math.max(0, Math.ceil((tEnd - now.getTime()) / 1000)) : (tState === "pause" ? tRemain : (tState === "done" ? 0 : setMin * 60 + setSec))
  Process { id: tp; property var cmd: []; command: cmd }
  function tcmd(a) { tp.cmd = ["/usr/lib/legal-desk/legal-timer"].concat(a); tp.running = false; tp.running = true; reloadT.restart() }
  Timer { id: reloadT; interval: 300; onTriggered: timerFile.reload() }
  function fmt(s) { var h = Math.floor(s / 3600), m = Math.floor((s % 3600) / 60); return (h > 0 ? h + ":" + two(m) : two(m)) + ":" + two(s % 60) }

  PanelWindow {
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "legalclock"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    MouseArea { anchors.fill: parent; onClicked: Qt.quit() }

    Rectangle {
      id: card
      width: Math.min(560, parent.width - 40); height: Math.min(560, parent.height - 120)
      x: (parent.width - width) / 2; y: (parent.height - height) / 2 - 24
      radius: 16; color: ck.bgC; border.color: ck.accC; border.width: 2
      MouseArea { anchors.fill: parent }
      Keys.onEscapePressed: Qt.quit()

      Row {
        x: 20; y: 16; spacing: 6
        Repeater { model: ["World Clock", "Timer"]
          Rectangle { width: 120; height: 34; radius: 10; color: ck.tab === index ? ck.accC : (tma.containsMouse ? Qt.darker(ck.selC, 1.2) : ck.selC); border.color: ck.accC; border.width: 1
            Text { anchors.centerIn: parent; text: modelData; color: ck.tab === index ? ck.bgC : ck.txtC; font.pixelSize: 14; font.bold: ck.tab === index }
            MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true; onClicked: ck.tab = index } } }
      }
      Rectangle { x: card.width - 44; y: 16; width: 28; height: 28; radius: 14; color: xma.containsMouse ? ck.accC : "transparent"; border.color: ck.accC; border.width: 1
        Text { anchors.centerIn: parent; text: "✕"; color: xma.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 12 }
        MouseArea { id: xma; anchors.fill: parent; hoverEnabled: true; onClicked: Qt.quit() } }

      // ===== World Clock =====
      Item {
        visible: ck.tab === 0
        x: 20; y: 64; width: card.width - 40; height: card.height - 84
        ListView {
          id: wl
          width: parent.width; height: parent.height - 52; clip: true; spacing: 8
          model: [["Here", ""]].concat(ck.chosen)
          delegate: Rectangle {
            required property var modelData
            required property int index
            readonly property var ct: index === 0 ? { t: ((ck.now.getHours() % 12) || 12) + ":" + ck.two(ck.now.getMinutes()) + " " + (ck.now.getHours() < 12 ? "AM" : "PM"), d: Qt.formatDate(ck.now, "dddd d MMM"), hour: ck.now.getHours() } : ck.cityTime(modelData[1])
            width: wl.width; height: 62; radius: 12; color: ck.selC; border.color: ck.accC; border.width: 1
            Text { x: 16; y: 10; text: index === 0 ? "Local time" : modelData[0]; color: ck.txtC; font.pixelSize: 17; font.bold: true }
            Text { x: 16; y: 36; text: ct.d; color: ck.accC; font.pixelSize: 12 }
            Text { x: parent.width - width - (index === 0 ? 16 : 50); anchors.verticalCenter: parent.verticalCenter; text: ct.t; color: ck.txtC; font.pixelSize: 24; font.weight: Font.DemiBold }
            Text { visible: index > 0; x: parent.width - 34; anchors.verticalCenter: parent.verticalCenter; text: "✕"; color: ck.txtC; opacity: rma.containsMouse ? 1 : 0.4; font.pixelSize: 13
              MouseArea { id: rma; anchors.fill: parent; anchors.margins: -8; hoverEnabled: true
                onClicked: { var a = ck.chosen.slice(); a.splice(index - 1, 1); ck.chosen = a; ck.saveCities() } } }
          }
        }
        Rectangle { y: parent.height - 40; width: 150; height: 36; radius: 10; color: ama.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
          Text { anchors.centerIn: parent; text: "+ Add city"; color: ama.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 14 }
          MouseArea { id: ama; anchors.fill: parent; hoverEnabled: true; onClicked: ck.picking = !ck.picking } }
        // city picker
        Rectangle {
          visible: ck.picking; y: parent.height - 40 - 262; width: 250; height: 256; radius: 12; color: ck.bgC; border.color: ck.accC; border.width: 1; z: 5
          ListView { anchors.fill: parent; anchors.margins: 6; clip: true; model: ck.cityList.filter(c => !ck.chosen.some(x => x[1] === c[1]))
            delegate: Rectangle { required property var modelData; width: ListView.view.width; height: 30; radius: 8; color: pma.containsMouse ? ck.selC : "transparent"
              Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData[0]; color: ck.txtC; font.pixelSize: 14 }
              MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: { ck.chosen = ck.chosen.concat([modelData]); ck.picking = false; ck.saveCities() } } } }
        }
      }

      // ===== Timer =====
      Item {
        visible: ck.tab === 1
        x: 20; y: 64; width: card.width - 40; height: card.height - 84
        // progress ring + countdown
        Canvas {
          id: ring
          width: 230; height: 230; anchors.horizontalCenter: parent.horizontalCenter; y: 6
          readonly property real frac: ck.tState === "idle" ? 1 : (ck.tTotal > 0 ? Math.min(1, ck.remainSec / ck.tTotal) : 0)
          onFracChanged: requestPaint()
          Connections { target: ck; function onAccCChanged() { ring.requestPaint() } function onSelCChanged() { ring.requestPaint() } }
          onPaint: {
            var ctx = getContext("2d"); ctx.reset(); ctx.lineWidth = 10; ctx.lineCap = "round"
            ctx.strokeStyle = "" + ck.selC; ctx.beginPath(); ctx.arc(115, 115, 100, 0, 6.2832); ctx.stroke()
            if (frac > 0) { ctx.strokeStyle = ck.tState === "done" ? "#E0705A" : "" + ck.accC; ctx.beginPath(); ctx.arc(115, 115, 100, -1.5708, -1.5708 + 6.2832 * frac); ctx.stroke() }
          }
          Text { anchors.centerIn: parent; text: ck.tState === "done" ? "Time's up" : ck.fmt(ck.remainSec); color: ck.tState === "done" ? "#E0705A" : ck.txtC; font.pixelSize: ck.tState === "done" ? 30 : 44; font.weight: Font.DemiBold }
        }
        // set time (idle only)
        Row {
          visible: ck.tState === "idle"; anchors.horizontalCenter: parent.horizontalCenter; y: 246; spacing: 10
          Repeater { model: [{ l: "Min", k: "m" }, { l: "Sec", k: "s" }]
            Row { spacing: 6
              Rectangle { width: 30; height: 30; radius: 8; color: dma.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
                Text { anchors.centerIn: parent; text: "−"; color: dma.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 16 }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: { if (modelData.k === "m") ck.setMin = Math.max(0, ck.setMin - 1); else ck.setSec = (ck.setSec + 55) % 60 } } }
              Text { anchors.verticalCenter: parent.verticalCenter; width: 56; horizontalAlignment: Text.AlignHCenter; text: (modelData.k === "m" ? ck.setMin : ck.setSec) + " " + modelData.l; color: ck.txtC; font.pixelSize: 14 }
              Rectangle { width: 30; height: 30; radius: 8; color: uma.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
                Text { anchors.centerIn: parent; text: "+"; color: uma.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 16 }
                MouseArea { id: uma; anchors.fill: parent; hoverEnabled: true; onClicked: { if (modelData.k === "m") ck.setMin = Math.min(180, ck.setMin + 1); else ck.setSec = (ck.setSec + 5) % 60 } } } }
          }
        }
        Row {
          visible: ck.tState === "idle"; anchors.horizontalCenter: parent.horizontalCenter; y: 288; spacing: 8
          Repeater { model: [1, 5, 10, 15, 30, 60]
            Rectangle { width: 56; height: 30; radius: 15; color: pma2.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
              Text { anchors.centerIn: parent; text: modelData + "m"; color: pma2.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 13 }
              MouseArea { id: pma2; anchors.fill: parent; hoverEnabled: true; onClicked: { ck.setMin = modelData; ck.setSec = 0 } } } }
        }
        // buttons
        Row {
          anchors.horizontalCenter: parent.horizontalCenter; y: parent.height - 56; spacing: 12
          Rectangle { visible: ck.tState === "idle"; width: 150; height: 42; radius: 12; opacity: (ck.setMin * 60 + ck.setSec) > 0 ? 1 : 0.4; color: sma.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
            Text { anchors.centerIn: parent; text: "Start"; color: sma.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 16; font.bold: true }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; onClicked: if (ck.setMin * 60 + ck.setSec > 0) ck.tcmd(["start", String(ck.setMin * 60 + ck.setSec)]) } }
          Rectangle { visible: ck.tState === "run" || ck.tState === "pause"; width: 130; height: 42; radius: 12; color: pma3.containsMouse ? ck.accC : ck.selC; border.color: ck.accC; border.width: 1
            Text { anchors.centerIn: parent; text: ck.tState === "run" ? "Pause" : "Resume"; color: pma3.containsMouse ? ck.bgC : ck.txtC; font.pixelSize: 16; font.bold: true }
            MouseArea { id: pma3; anchors.fill: parent; hoverEnabled: true; onClicked: ck.tcmd([ck.tState === "run" ? "pause" : "resume"]) } }
          Rectangle { visible: ck.tState !== "idle"; width: 130; height: 42; radius: 12; color: rma3.containsMouse ? "#E0705A" : "#3a1f1b"; border.color: "#E0705A"; border.width: 1
            Text { anchors.centerIn: parent; text: ck.tState === "done" ? "Dismiss" : "Cancel"; color: rma3.containsMouse ? "#1a0a08" : "#E0705A"; font.pixelSize: 16; font.bold: true }
            MouseArea { id: rma3; anchors.fill: parent; hoverEnabled: true; onClicked: ck.tcmd(["reset"]) } }
        }
      }
      // Credit: the maker's logo and name sit on the bottom edge of the window
      Rectangle {
        z: 8; anchors.right: parent.right; anchors.rightMargin: 24; y: parent.height - 11
        height: 22; width: credit.implicitWidth + 34; radius: 10; color: ck.bgC; border.color: ck.accC; border.width: 1
        Image { x: 4; anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; sourceSize.width: 48; sourceSize.height: 48; smooth: true; source: "file:///usr/share/legal-desk/5ive7.png" }
        Text { id: credit; x: 26; anchors.verticalCenter: parent.verticalCenter; text: "5ive7 Development Labs"; color: ck.txtC; opacity: 0.85; font.pixelSize: 9; font.bold: true; font.letterSpacing: 0.4 }
      }
    }
  }
}
