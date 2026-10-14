import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// macOS-style dock: icons magnify (fisheye) as the mouse passes over them.
// Reads the same pinned list as nwg-dock-hyprland (~/.cache/nwg-dock-pinned).
// Test mode: run with MACDOCK_TEST=1 to float it higher so it doesn't overlap the old dock.
ShellRoot {
  id: root
  property var pinned: []
  property var running: ({})
  property string sizeName: "medium"
  readonly property int base: sizeName === "small" ? 32 : (sizeName === "large" ? 80 : 56)
  readonly property real maxScale: 1.9
  readonly property real radius: base * 2.6
  readonly property int gap: 8
  readonly property bool testMode: Quickshell.env("MACDOCK_TEST") === "1" || Quickshell.env("MACDOCK_TEST") === "2"
  property string bg: "#000000"
  property bool hidden: false
  Process { id: hidChk; command: ["test", "-e", Quickshell.env("HOME") + "/.cache/dock-hidden"]; onExited: (c) => root.hidden = (c === 0) }
  readonly property bool simMode: Quickshell.env("MACDOCK_TEST") === "2"
  property real simX: 150
  property real simDir: 1
  Timer { interval: 16; running: root.simMode; repeat: true
    onTriggered: { var x = root.simX + root.simDir * 6; if (x > 1150) root.simDir = -1; if (x < 150) root.simDir = 1; root.simX = x } }

  // items: launcher first, then pinned
  property var runCls: []
  property string runKey: ""
  function isPinned(c) { return pinned.some(p => p.toLowerCase() === c.toLowerCase()) }
  property var items: pinned.map(c => ({ cls: c })).concat(runCls.filter(c => !isPinned(c)).map(c => ({ cls: c }))).concat([{ cls: "__launcher__" }])
  readonly property real baseTotal: items.length * (base + gap)
  readonly property real panelW: baseTotal + base * (maxScale - 1) * 2.4 + 40
  readonly property real panelH: base * maxScale + 28

  FileView {
    path: Quickshell.env("HOME") + "/.cache/nwg-dock-pinned"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.pinned = text().split("\n").map(s => s.trim()).filter(s => s.length > 0)
  }
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-size"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.sizeName = text().trim()
  }

  Process {
    id: poll
    command: ["python3", "-c", "import json,subprocess;print(json.dumps(sorted({c['class'] for c in json.loads(subprocess.run(['hyprctl','clients','-j'],capture_output=True,text=True).stdout or '[]') if c['class'] and not c['class'].lower().startswith('nwg-')})))"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { var l = JSON.parse(text); var o = {}; l.forEach(c => o[c.toLowerCase()] = true); root.running = o
          var k = JSON.stringify(l); if (k !== root.runKey) { root.runKey = k; root.runCls = l; resolver.running = true } } catch (e) { }
      }
    }
  }
  Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!poll.running) poll.running = true; hidChk.running = true } }

  property var appmap: ({})
  Process {
    id: resolver
    command: ["python3", "-c", `
import os, json, glob, configparser, subprocess, re
dirs = [os.path.expanduser('~/.local/share/applications'), '/usr/share/applications', '/usr/local/share/applications']
want = [l.strip() for l in open(os.path.expanduser('~/.cache/nwg-dock-pinned')) if l.strip()]
try: want += [c['class'] for c in json.loads(subprocess.run(['hyprctl','clients','-j'],capture_output=True,text=True).stdout or '[]') if c['class']]
except Exception: pass
norm = lambda x: re.sub(r'[^a-z0-9]', '', x.lower())
idx = {}; nidx = {}; hosts = {}; execk = {}; names = {}
GENERIC = {'foot','xdg-terminal-exec','omarchy-launch-webapp','bash','sh','env','omarchy-launch-tui','xdg-open','uwsm','uwsm-app','gtk-launch'}
for d in dirs:
    for f in glob.glob(d + '/*.desktop'):
        cp = configparser.RawConfigParser(strict=False, interpolation=None)
        cp.optionxform = str
        try: cp.read(f, encoding='utf-8')
        except Exception: continue
        if 'Desktop Entry' not in cp: continue
        e = cp['Desktop Entry']
        base = os.path.basename(f)[:-8]
        ex = e.get('Exec', '')
        rec = {'icon': e.get('Icon', ''), 'id': base}
        for k in {base, e.get('StartupWMClass', ''), e.get('Name', '')}:
            if k and k.lower() not in idx: idx[k.lower()] = rec
            if k and norm(k) and norm(k) not in nidx: nidx[norm(k)] = rec
        if base.split('.')[-1].lower() not in idx and '.' in base: idx[base.split('.')[-1].lower()] = rec
        for m in re.finditer(r'--app-id=(\\S+)', ex): execk.setdefault(m.group(1).lower(), rec)
        for m in re.finditer(r'https?://([^/\\s"]+)', ex): hosts.setdefault(m.group(1).lower(), rec)
        toks = [t for t in ex.replace('"', ' ').split() if not t.startswith('%') and not t.startswith('-') and '=' not in t.split('/')[0]]
        if toks and os.path.basename(toks[0]).lower() not in GENERIC: execk.setdefault(os.path.basename(toks[0]).lower(), rec)
        nm = norm(e.get('Name', ''))
        if len(nm) >= 3: names.setdefault(nm, rec)
def find(c):
    k = c.lower()
    if k in idx: return idx[k]
    if norm(c) in nidx: return nidx[norm(c)]
    if k in execk: return execk[k]
    m = re.match(r'chrome-(.+?)__.*-default$', k) or re.match(r'chrome-(.+)-default$', k)
    if m:
        h = m.group(1)
        for hk, r in hosts.items():
            if hk == h or hk.endswith('.' + h) or h.endswith('.' + hk): return r
        for part in h.split('.'):
            if len(part) >= 3 and norm(part) in names: return names[norm(part)]
    return None
out = {}
for c in want:
    r = find(c)
    if r: out[c] = r
print(json.dumps(out))
`]
    stdout: StdioCollector {
      onStreamFinished: { try { root.appmap = JSON.parse(text) } catch (e) { } }
    }
  }
  onPinnedChanged: resolver.running = true
  Process { id: runner; property var cmd: []; command: cmd }
  function launch(args) { sh(["setsid", "-f", "bash", "-c", "\"$@\" >/dev/null 2>&1 </dev/null", "x"].concat(args)) }
  function sh(args) { runner.cmd = args; runner.running = false; runner.running = true }

  function activate(cls) {
    if (cls === "__launcher__") { sh(["/usr/lib/legal-dock/drawer-toggle"]); return }
    if (cls === "reboot") { sh(["/usr/lib/legal-dock/reboot-confirm"]); return }
    if (running[cls.toLowerCase()]) { sh(["bash", "-c", "/usr/lib/legal-dock/win-minimize restore-class \"$1\"; a=$(hyprctl clients -j | python3 -c \"import json,sys;c=sys.argv[1].lower();print(next((w['address'] for w in json.load(sys.stdin) if w['class'].lower()==c),''))\" \"$1\"); [ -n \"$a\" ] && /usr/lib/legal-dock/hypr-dispatch focus \"$a\"", "x", cls]); return }
    var r = appmap[cls]
    if (r) launch(["gtk-launch", r.id + ".desktop"])
    else launch(["bash", "-c", "gtk-launch \"$1\" || { command -v \"$1\" >/dev/null && setsid \"$1\"; }", "x", cls])
  }
  function iconFor(cls) {
    if (cls === "__launcher__") return "file:///usr/share/nwg-dock-hyprland/images/grid.svg"
    var r = appmap[cls]
    var n = r && r.icon ? r.icon : cls
    if (n.startsWith("/")) return "file://" + n
    var tries = [n, cls, cls.toLowerCase(), cls.toLowerCase().replace(/^chrome-/, "").replace(/-default$/, "")]
    for (var i = 0; i < tries.length; i++) {
      if (!tries[i]) continue
      var ip = Quickshell.iconPath(tries[i], true)
      if (ip) return ip
    }
    return ""
  }
  function letterOf(cls) { var m = cls.replace(/^chrome-/, "").replace(/^org\./, "").match(/[A-Za-z0-9]/); return m ? m[0].toUpperCase() : "?" }
  function tint(cls) { var h = 0; for (var i = 0; i < cls.length; i++) h = (h * 31 + cls.charCodeAt(i)) % 360; return Qt.hsla(h / 360, 0.45, 0.38, 1) }

  // Per-icon scale so every icon fills the same share of its square (measured by dock-icon-scale).
  property var iscale: ({})
  property string iconKey: ""
  function plainPath(s) { return s.startsWith("file://") ? s.substring(7) : s }
  function scaleOf(cls) { var s = iscale[plainPath(iconFor(cls))]; return s ? s : 1 }
  function remeasure() {
    var ps = []
    for (var i = 0; i < items.length; i++) { var u = iconFor(items[i].cls); if (u !== "") ps.push(plainPath(u)) }
    var k = ps.join("|")
    if (k === iconKey) return
    iconKey = k
    measurer.cmd = ["/usr/lib/legal-dock/dock-icon-scale"].concat(ps)
    measurer.running = false; measurer.running = true
  }
  Process {
    id: measurer; property var cmd: []; command: cmd
    stdout: StdioCollector { onStreamFinished: { try { root.iscale = JSON.parse(text) } catch (e) { } } }
  }
  onAppmapChanged: remeasure()
  onItemsChanged: remeasure()

  PanelWindow {
    id: win
    anchors { bottom: true }
    margins { bottom: root.testMode ? 150 : 4 }
    implicitWidth: root.panelW
    implicitHeight: root.panelH
    color: "transparent"
    exclusionMode: root.testMode ? ExclusionMode.Ignore : ExclusionMode.Normal
    exclusiveZone: (root.testMode || root.hidden) ? 0 : root.base + 12
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "macdock"
    mask: Region { item: (root.hidden && !hover.containsMouse) ? strip : hit }

    // Only this strip receives the mouse, so the rest of the screen stays clickable.
    Item { id: strip; anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; width: parent.width; height: 4 }
    Item {
      id: hit
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width
      height: hover.containsMouse ? parent.height : root.base + 16

      HoverHandler {
        id: hover
        property real mx: point.position.x
        readonly property bool containsMouse: hovered
      }
    }

    // Row of icons, centred. Positions come from the cumulative scaled widths, so neighbours push apart.
    Row {
      id: row
      opacity: (!root.hidden || hover.containsMouse) ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      spacing: root.gap
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      anchors.horizontalCenter: parent.horizontalCenter

      Repeater {
        model: root.items
        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          // centre of this icon in the UNSCALED layout, in window coordinates
          readonly property real unscaledCenter: (win.width - root.baseTotal) / 2 + index * (root.base + root.gap) + root.base / 2
          readonly property real dist: Math.abs((root.simMode ? root.simX : hover.mx) - unscaledCenter)
          readonly property real target: (hover.containsMouse || root.simMode) && dist < root.radius
            ? 1 + (root.maxScale - 1) * (0.5 + 0.5 * Math.cos(Math.PI * dist / root.radius))
            : 1
          property real s: target
          Behavior on s { NumberAnimation { duration: 90; easing.type: Easing.OutCubic } }

          width: root.base * s
          height: root.base * s
          anchors.bottom: parent.bottom

          Rectangle {
            visible: root.iconFor(cell.modelData.cls) === ""
            anchors.centerIn: parent; width: parent.width * 0.88; height: parent.height * 0.88; radius: width * 0.22
            color: root.tint(cell.modelData.cls)
            Text { anchors.centerIn: parent; text: root.letterOf(cell.modelData.cls); color: "white"; font.bold: true; font.pixelSize: parent.height * 0.55 }
          }
          Image {
            anchors.fill: parent
            scale: root.scaleOf(cell.modelData.cls)
            source: root.iconFor(cell.modelData.cls)
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }
          // running dot
          Rectangle {
            visible: cell.modelData.cls !== "__launcher__" && !!root.running[cell.modelData.cls.toLowerCase()]
            width: 4; height: 4; radius: 2
            color: "#dddddd"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 2
          }
          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: (m) => {
              if (cell.modelData.cls === "__launcher__") { root.ctx = ""; root.activate("__launcher__"); return }
              if (m.button === Qt.LeftButton) { root.ctx = ""; root.activate(cell.modelData.cls) }
              else if (m.button === Qt.MiddleButton) { root.sh(["/usr/lib/legal-dock/dock-pin-toggle", cell.modelData.cls]) }
              else { root.ctxX = cell.mapToItem(null, cell.width / 2, 0).x; root.ctx = cell.modelData.cls }
            }
          }
        }
      }
    }
  }

  // Right-click menu on an icon: open windows, New window, Pin/Unpin, Close.
  IpcHandler { target: "macdockact"; function activate(cls: string): void { root.activate(cls) } }
  IpcHandler { target: "macdock"; function menu(cls: string): void { root.ctxX = 800; root.ctx = cls } }
  property string ctx: ""
  property real ctxX: 0
  property var ctxWins: []
  onCtxChanged: { ctxWins = []; if (ctx !== "") { winsProc.cls = ctx; winsProc.running = false; winsProc.running = true } }
  Process {
    id: winsProc; property string cls: ""
    command: ["python3", "-c", "import json,subprocess,sys\nc=sys.argv[1].lower()\nprint(json.dumps([{'a':w['address'],'t':w['title']} for w in json.loads(subprocess.run(['hyprctl','clients','-j'],capture_output=True,text=True).stdout or '[]') if w['class'].lower()==c]))", cls]
    stdout: StdioCollector { onStreamFinished: { try { root.ctxWins = JSON.parse(text) } catch (e) { } } }
  }
  function ctxRows() {
    var rows = []
    var w = ctxWins
    if (w.length > 0) rows.push({ l: w.length + (w.length > 1 ? " windows open" : " window open"), a: "hdr" })
    for (var i = 0; i < w.length && i < 6; i++) rows.push({ l: "   " + (w[i].t.length > 26 ? w[i].t.substring(0, 25) + "…" : (w[i].t || "(untitled)")), a: "focus", addr: w[i].a })
    if (appmap[ctx]) rows.push({ l: "New window", a: "new" })
    rows.push({ l: isPinned(ctx) ? "Unpin from dock" : "Pin to dock", a: "pin" })
    if (w.length > 0) rows.push({ l: "Close app", a: "close" })
    rows.push({ l: "Cancel", a: "cancel" })
    return rows
  }
  Timer { interval: 9000; running: root.ctx !== ""; onTriggered: root.ctx = "" }
  Variants {
    model: root.ctx !== "" ? [root.ctx] : []
    PanelWindow {
      id: pm
      required property var modelData
      property var rows: root.ctxRows()
      anchors { bottom: true; left: true }
      margins { bottom: root.base + 24; left: Math.max(4, (win.screen.width - win.width) / 2 + root.ctxX - 115) }
      implicitWidth: 230; implicitHeight: rows.length * 34 + 12
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "macdockmenu"
      Rectangle {
        anchors.fill: parent; radius: 10; color: "#111c18"; border.color: "#C1C497"; border.width: 1
        Column {
          anchors.fill: parent; anchors.margins: 6; spacing: 0
          Repeater {
            model: pm.rows
            Rectangle {
              required property var modelData
              width: parent.width; height: 34; radius: 6
              color: (modelData.a !== "hdr" && ma.containsMouse) ? "#2a3a30" : "transparent"
              Text {
                x: 10; anchors.verticalCenter: parent.verticalCenter
                text: modelData.a === "hdr" ? "●  " + modelData.l : modelData.l
                color: modelData.a === "hdr" ? "#8fd18f" : "#C1C497"; font.pixelSize: 13
                font.bold: modelData.a === "hdr"
              }
              MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  var c = root.ctx, act = modelData.a, addr = modelData.addr
                  if (act === "hdr") return
                  if (act === "pin") root.sh(["/usr/lib/legal-dock/dock-pin-toggle", c])
                  else if (act === "close") root.sh(["/usr/lib/legal-dock/dock-close-app", c])
                  else if (act === "focus") root.sh(["/usr/lib/legal-dock/hypr-dispatch", "focus", addr])
                  else if (act === "new") { var r = root.appmap[c]; if (r) root.launch(["gtk-launch", r.id + ".desktop"]) }
                  root.ctx = ""
                }
              }
            }
          }
        }
      }
    }
  }
}
