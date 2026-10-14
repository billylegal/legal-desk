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
  property int winCount: 0                  // open windows -> how scrambled the cube is
  property var launching: ({})              // apps that were just clicked -> their icon bounces until the window appears
  function markLaunch(c) { var o = Object.assign({}, launching); o[c.toLowerCase()] = true; launching = o; launchClear.restart() }
  Timer { id: launchClear; interval: 12000; onTriggered: root.launching = ({}) }
  Process {
    id: countProc
    command: ["python3", "-c", "import json,subprocess;print(sum(1 for c in json.loads(subprocess.run(['hyprctl','clients','-j'],capture_output=True,text=True).stdout or '[]') if c['class'] and not c['class'].lower().startswith('nwg-')))"]
    stdout: StdioCollector { onStreamFinished: { var n = parseInt(text); if (!isNaN(n)) root.winCount = n } }
  }
  property string sizeName: "medium"
  property string styleName: "mac"
  readonly property bool rubik: styleName === "rubik"
  property real zoomVal: 0      // 0 = automatic (depends on size); else the magnification chosen with the Zoom slider
  readonly property int base: { var n = parseInt(sizeName); return isNaN(n) ? (sizeName === "small" ? 34 : (sizeName === "large" ? 58 : 46)) : Math.max(24, Math.min(110, n)) }
  readonly property real maxScale: rubik ? 1.12 : (zoomVal >= 1 ? Math.min(2.6, zoomVal) : (base >= 56 ? 1.8 : (base <= 36 ? 2.2 : 2.0)))
  readonly property real radius: base * 3.2
  readonly property int gap: rubik ? 5 : 6
  property string skinTxt: "auto"
  readonly property int skinIdx: /^[0-7]$/.test(skinTxt) ? parseInt(skinTxt) : (rubik ? 7 : 0)
  readonly property var skins: [
    { n: "Emerald",  c1: "#111c18", c2: "#111c18", b: "#55C1C497", r: 16, t: ["#ffd500", "#0b57d0", "#c41e3a", "#00a152", "#ff5a00", "#f4f4f4"] },
    { n: "Glass",    c1: "#70ffffff", c2: "#30ffffff", b: "#aaffffff", r: 18, t: ["#ffffff", "#9fd8ff", "#ffc2d4", "#b8f5c8", "#ffe2a8", "#d9c8ff"] },
    { n: "Midnight", c1: "#0f1a4a", c2: "#04061a", b: "#554a7aff", r: 16, t: ["#5b7cff", "#8a5bff", "#2ad4ff", "#3b4bd6", "#a3b4ff", "#e8ecff"] },
    { n: "Neon",     c1: "#06080c", c2: "#06080c", b: "#39ff14", r: 14, t: ["#39ff14", "#00e5ff", "#ff2a2a", "#ffe066", "#d946ff", "#ff6a00"] },
    { n: "Aluminum", c1: "#f0f0f2", c2: "#a4a8b0", b: "#ffffff", r: 10, t: ["#f4f4f4", "#d8dadf", "#c2c6cd", "#eceef1", "#b6bac2", "#ffffff"] },
    { n: "Aqua",     c1: "#8fd0ff", c2: "#1565d0", b: "#d8eeff", r: 20, t: ["#ffffff", "#bfe3ff", "#7cc2ff", "#e6f4ff", "#a0d4ff", "#5aaaf0"] },
    { n: "Sunset",   c1: "#ff9a3d", c2: "#a8124a", b: "#ffd9b0", r: 18, t: ["#ffd500", "#ff5a00", "#c41e3a", "#ff8fb1", "#7a1fa2", "#fff1d6"] },
    { n: "Cube",     c1: "#0d0d0d", c2: "#0d0d0d", b: "#2a2a2a", r: 12, t: ["#ffd500", "#0b57d0", "#c41e3a", "#00a152", "#ff5a00", "#f4f4f4"] }
  ]
  readonly property var skin: skins[skinIdx]
  readonly property var rpal: skin.t
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
  readonly property real panelW: baseTotal + base * (maxScale - 1) * 3.2 + 40
  readonly property real panelH: base * maxScale + 54

  FileView {
    path: Quickshell.env("HOME") + "/.cache/nwg-dock-pinned"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.pinned = text().split("\n").map(s => s.trim()).filter(s => s.length > 0)
  }
  property bool solid: true
  FileView {
    path: Quickshell.env("HOME") + "/.config/nwg-dock-hyprland/style.css"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.solid = text().indexOf("background: transparent") < 0
  }
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-style"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.styleName = text().trim() === "rubik" ? "rubik" : "mac"
  }
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-skin"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.skinTxt = text().trim()
  }
  FileView {
    path: Quickshell.env("HOME") + "/.cache/dock-zoom"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { var z = parseFloat(text()); root.zoomVal = isNaN(z) ? 0 : z }
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
  Timer { interval: 1500; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (!poll.running) poll.running = true; if (!countProc.running) countProc.running = true; hidChk.running = true; lockChk.running = true } }

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
        rec = {'icon': e.get('Icon', ''), 'id': base, 'name': e.get('Name', '')}
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
    if (cls === "__launcher__") { sh(["/home/aigazoo/.local/bin/drawer-toggle"]); return }
    if (cls === "reboot") { sh(["/home/aigazoo/.local/bin/reboot-confirm"]); return }
    if (running[cls.toLowerCase()]) { sh(["bash", "-c", "/home/aigazoo/.local/bin/win-minimize restore-class \"$1\"; a=$(hyprctl clients -j | python3 -c \"import json,sys;c=sys.argv[1].lower();print(next((w['address'] for w in json.load(sys.stdin) if w['class'].lower()==c),''))\" \"$1\"); [ -n \"$a\" ] && hyprctl dispatch \"hl.dsp.focus({window='address:$a'})\"", "x", cls]); return }
    markLaunch(cls)
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
    measurer.cmd = ["/home/aigazoo/.local/bin/dock-icon-scale"].concat(ps)
    measurer.running = false; measurer.running = true
  }
  Process {
    id: measurer; property var cmd: []; command: cmd
    stdout: StdioCollector { onStreamFinished: { try { root.iscale = JSON.parse(text) } catch (e) { } } }
  }
  onAppmapChanged: remeasure()
  onItemsChanged: remeasure()

  // ---- Magnification (Apple-style) ----
  // Layout is computed from one number: um = the pointer position in the UNSCALED layout.
  // Each icon's scale is a cosine bump of its distance to um, positions are the running sum of scaled widths,
  // and um is solved so the icon under the pointer really stays under it (no feedback from the animated icons -> no jitter).
  // mag (0..1) and umS are spring-animated, which gives the elastic pop when the mouse arrives, moves and leaves.
  property real mag: 0
  Behavior on mag { SpringAnimation { spring: 3.2; damping: 0.2; epsilon: 0.002 } }
  property real umT: 0
  property real umS: 0
  Behavior on umS { enabled: root.mag > 0.15; SpringAnimation { spring: 7; damping: 0.6; epsilon: 0.05 } }
  property int hoverIdx: -1
  property int dragIdx: -1
  property int dropIdx: -1
  property real dragX: 0
  property bool locked: false
  Process { id: lockChk; command: ["test", "-e", Quickshell.env("HOME") + "/.cache/dock-locked"]; onExited: (c) => root.locked = (c === 0) }

  function layoutFor(p, m, W) {
    var n = items.length, step = base + gap, L0 = (W - baseTotal) / 2
    var xs = [], ws = [], tot = 0, mm = Math.max(0, m)
    if (dragIdx >= 0) {
      var o = []; for (var k = 0; k < n; k++) if (k !== dragIdx) o.push(k)
      o.splice(Math.max(0, Math.min(o.length, dropIdx)), 0, dragIdx)
      for (var j = 0; j < n; j++) { xs[o[j]] = L0 + j * step; ws[o[j]] = base }
      return { xs: xs, ws: ws, tot: baseTotal - gap }
    }
    for (var i = 0; i < n; i++) {
      var d = Math.abs(p - (L0 + i * step + base / 2))
      var sc = d < radius ? 1 + (maxScale - 1) * mm * (0.5 + 0.5 * Math.cos(Math.PI * d / radius)) : 1
      ws[i] = base * Math.max(0.9, sc); tot += ws[i]
    }
    tot += gap * (n - 1)
    var x = (W - tot) / 2
    for (var q = 0; q < n; q++) { xs[q] = x; x += ws[q] + gap }
    return { xs: xs, ws: ws, tot: tot }
  }
  readonly property var lay: layoutFor(umS, mag, win.width)

  function pointer(mx) {
    var n = items.length; if (n < 1) return
    var step = base + gap, L0 = (win.width - baseTotal) / 2
    var p = (mag > 0.15) ? umT : mx
    for (var it = 0; it < 10; it++) {
      var l = layoutFor(p, 1, win.width)
      var i = Math.max(0, Math.min(n - 1, Math.floor((p - L0) / step)))
      var off = (p - L0) - i * step
      var sx = off < 0 ? l.xs[i] + off : (off <= base ? l.xs[i] + off / base * l.ws[i] : l.xs[i] + l.ws[i] + (off - base))
      p += (mx - sx) * 0.5
    }
    umT = p; umS = p
    hoverIdx = Math.max(0, Math.min(n - 1, Math.round((p - L0 - base / 2) / step)))
  }
  function moveTo(from, to) {
    if (from === to || from < 0 || to < 0 || from >= pinned.length || to >= pinned.length) return
    var l = pinned.slice(); l.splice(to, 0, l.splice(from, 1)[0]); pinned = l
    sh(["/home/aigazoo/.local/bin/dock-reorder", String(from), String(to)])
  }

  PanelWindow {
    id: win
    anchors { bottom: true }
    margins { bottom: root.testMode ? 150 : 4 }
    implicitWidth: Math.min(root.panelW, win.screen ? win.screen.width : 1900)
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
        onPointChanged: if (root.dragIdx < 0) root.pointer(point.position.x)
        onHoveredChanged: root.mag = (hovered && root.dragIdx < 0) ? 1 : 0
        property real mx: point.position.x
        readonly property bool containsMouse: hovered
      }
    }

    // Solid dock: a plate behind the row (Rubik: black cube-plastic frame). Transparent dock: icons float.
    Rectangle {
      visible: root.solid
      opacity: rowArea.opacity
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: 3
      width: root.lay.tot + 18; height: root.base + 22; radius: root.skin.r
      gradient: Gradient { GradientStop { position: 0; color: root.skin.c1 } GradientStop { position: 1; color: root.skin.c2 } }
      border.color: root.skin.b; border.width: 1
    }
    // Row of icons, centred. Positions come from the cumulative scaled widths, so neighbours push apart.
    Item {
      id: rowArea
      opacity: (!root.hidden || hover.containsMouse) ? 1 : 0
      Behavior on opacity { NumberAnimation { duration: 160 } }
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 8
      width: parent.width
      height: parent.height - 8

      Repeater {
        id: rep
        model: root.items
        delegate: Item {
          id: cell
          required property var modelData
          required property int index
          readonly property bool dragged: root.dragIdx === index
          readonly property real lift: dragged ? 1.18 : 1
          width: (root.lay.ws[index] || root.base) * lift
          height: width
          x: dragged ? root.dragX - width / 2 : (root.lay.xs[index] || 0)
          Behavior on x { enabled: root.dragIdx >= 0 && !cell.dragged; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
          z: dragged ? 10 : 0
          opacity: dragged ? 0.92 : 1
          anchors.bottom: parent.bottom
          property real bounce: 0
          anchors.bottomMargin: bounce
          readonly property bool isLaunching: cell.modelData.cls !== "__launcher__" && !!root.launching[cell.modelData.cls.toLowerCase()] && !root.running[cell.modelData.cls.toLowerCase()]
          SequentialAnimation {
            running: cell.isLaunching; loops: Animation.Infinite
            NumberAnimation { target: cell; property: "bounce"; to: root.base * 0.55; duration: 240; easing.type: Easing.OutQuad }
            NumberAnimation { target: cell; property: "bounce"; to: 0; duration: 460; easing.type: Easing.OutBounce }
            onRunningChanged: if (!running) cell.bounce = 0
          }

          property real twist: 0
          SequentialAnimation { id: twistAnim
            NumberAnimation { target: cell; property: "twist"; from: 0; to: 90; duration: 260; easing.type: Easing.OutBack }
            PropertyAction { target: cell; property: "twist"; value: 0 } }
          Rectangle {
            visible: root.rubik && cell.modelData.cls !== "__launcher__"
            anchors.fill: parent; radius: width * 0.2
            color: root.rpal[cell.index % 6]; border.color: "#0d0d0d"; border.width: 2
            rotation: cell.twist
            Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.color: "#33ffffff"; border.width: 1 }
          }
          Rectangle {
            visible: root.iconFor(cell.modelData.cls) === ""
            anchors.centerIn: parent; width: parent.width * 0.88; height: parent.height * 0.88; radius: width * 0.22
            color: root.tint(cell.modelData.cls)
            Text { anchors.centerIn: parent; text: root.letterOf(cell.modelData.cls); color: "white"; font.bold: true; font.pixelSize: parent.height * 0.55 }
          }
          Image {
            visible: cell.modelData.cls !== "__launcher__" && cell.modelData.cls !== "chrome-127.0.0.1__globe_-Default"
            anchors.fill: parent
            scale: root.scaleOf(cell.modelData.cls) * (root.rubik ? 0.74 : 1)
            rotation: cell.twist
            source: root.iconFor(cell.modelData.cls)
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
          }
          // Rubik's Cube launcher: solved with no windows open, scrambles a little more with every window you open.
          Canvas {
            id: cube
            visible: cell.modelData.cls === "__launcher__"
            anchors.fill: parent
            property int n: root.winCount
            onNChanged: { requestPaint(); pop.restart() }
            onWidthChanged: requestPaint()
            Component.onCompleted: requestPaint()
            SequentialAnimation {
              id: pop
              NumberAnimation { target: cube; property: "scale"; to: 1.14; duration: 110; easing.type: Easing.OutQuad }
              NumberAnimation { target: cube; property: "scale"; to: 1.0; duration: 220; easing.type: Easing.OutBack }
            }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset()
              var S = Math.min(width, height), u = S * 0.148, cx = width / 2, cy = height / 2 + u * 0.1
              var pal = ["#f4f4f4", "#ffd500", "#c41e3a", "#ff5a00", "#0b57d0", "#00a152"]   // W Y R O B G
              var solved = [0, 5, 2]                                                          // top white, left green, right red
              var ax = u * 0.866, ay = u * 0.5
              function poly(px, py, v1x, v1y, v2x, v2y, col) {
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px + v1x, py + v1y); ctx.lineTo(px + v1x + v2x, py + v1y + v2y); ctx.lineTo(px + v2x, py + v2y); ctx.closePath()
                ctx.fillStyle = col; ctx.fill(); ctx.lineWidth = Math.max(1, S * 0.012); ctx.strokeStyle = "#0d0d0d"; ctx.stroke()
              }
              function colorOf(face, i, j) {
                var s = face * 9 + i * 3 + j
                var rank = (s * 11) % 27
                var k = Math.min(27, n * 5)
                var c = solved[face]
                if (rank < k) { c = (s * 5 + n) % 6; if (c === solved[face]) c = (c + 1) % 6 }
                return pal[c]
              }
              var Tx = cx, Ty = cy - 3 * u
              // top face: along (ax, ay) and (-ax, ay)
              for (var i = 0; i < 3; i++) for (var j = 0; j < 3; j++)
                poly(Tx + i * ax - j * ax, Ty + i * ay + j * ay, ax, ay, -ax, ay, colorOf(0, i, j))
              // left face: from the left corner, along (ax, ay) and straight down
              var Lx = Tx - 3 * ax, Ly = Ty + 3 * ay
              for (var i2 = 0; i2 < 3; i2++) for (var k2 = 0; k2 < 3; k2++)
                poly(Lx + i2 * ax, Ly + i2 * ay + k2 * u, ax, ay, 0, u, colorOf(1, i2, k2))
              // right face: from the right corner, along (-ax, ay) and straight down
              var Rx = Tx + 3 * ax, Ry = Ty + 3 * ay
              for (var j3 = 0; j3 < 3; j3++) for (var k3 = 0; k3 < 3; k3++)
                poly(Rx - j3 * ax, Ry + j3 * ay + k3 * u, -ax, ay, 0, u, colorOf(2, j3, k3))
            }
          }
          // A View From Space (Radio Globe): the app's bullseye + speaker, colour steps through the app's 8 themes every second, sound waves pulse
          Canvas {
            id: gb
            visible: cell.modelData.cls === "chrome-127.0.0.1__globe_-Default"
            anchors.fill: parent
            onWidthChanged: requestPaint()
            Timer { interval: 66; running: gb.visible; repeat: true; onTriggered: gb.requestPaint() }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset()
              var S = Math.min(width, height), cx = width / 2, cy = height / 2, now = Date.now()
              var cols = ["#39ff14", "#ffb000", "#ff2a2a", "#00e5ff", "#b4ff3c", "#ffe066", "#ff6a00", "#d946ff"]
              var c = cols[Math.floor(now / 1000) % 8]
              function rr(x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath() }
              var m = S * 0.03, W = S - 2 * m
              rr(m, m, W, W, W * 0.22); ctx.fillStyle = "#070a1c"; ctx.fill()
              ctx.save(); rr(m, m, W, W, W * 0.22); ctx.clip()
              ctx.fillStyle = "#ffffff"
              var st = [[.14, .16, 1.2], [.82, .13, 1.4], [.9, .5, 1], [.1, .55, 1], [.18, .86, 1.1], [.86, .88, 1.3]]
              for (var i = 0; i < st.length; i++) { ctx.beginPath(); ctx.arc(st[i][0] * S, st[i][1] * S, st[i][2] * S * 0.007, 0, 6.2832); ctx.fill() }
              // ripples (as on the app's globe): three rings expanding from the speaker
              var R = S * 0.27, tt = now / 1300
              ctx.lineWidth = Math.max(1, S * 0.018)
              for (var k = 0; k < 3; k++) {
                var t = ((tt + k / 3) % 1)
                ctx.globalAlpha = (1 - t) * 0.65; ctx.strokeStyle = c
                ctx.beginPath(); ctx.arc(cx, cy, R + t * S * 0.17, 0, 6.2832); ctx.stroke()
              }
              ctx.globalAlpha = 1
              // bullseye: four ticks + white ring
              ctx.strokeStyle = "#ffffff"; ctx.lineCap = "round"; ctx.lineWidth = Math.max(1.5, S * 0.03)
              var t1 = R + S * 0.02, t2 = S * 0.47
              ctx.beginPath()
              ctx.moveTo(cx, cy - t2); ctx.lineTo(cx, cy - t1); ctx.moveTo(cx, cy + t1); ctx.lineTo(cx, cy + t2)
              ctx.moveTo(cx - t2, cy); ctx.lineTo(cx - t1, cy); ctx.moveTo(cx + t1, cy); ctx.lineTo(cx + t2, cy)
              ctx.stroke()
              ctx.beginPath(); ctx.arc(cx, cy, R, 0, 6.2832); ctx.fillStyle = "#07101a"; ctx.fill(); ctx.stroke()
              ctx.lineWidth = Math.max(1, S * 0.012); ctx.strokeStyle = c; ctx.globalAlpha = 0.9
              ctx.beginPath(); ctx.arc(cx, cy, R * 0.86, 0, 6.2832); ctx.stroke(); ctx.globalAlpha = 1
              // speaker glyph (same shape as the app's) in the theme colour
              var kk = R / 14 * 1.15
              ctx.save(); ctx.translate(cx - S * 0.012, cy); ctx.scale(kk, kk)
              ctx.fillStyle = c; ctx.beginPath()
              ctx.moveTo(-7, -3); ctx.lineTo(-3, -3); ctx.lineTo(2, -7); ctx.lineTo(2, 7); ctx.lineTo(-3, 3); ctx.lineTo(-7, 3); ctx.closePath(); ctx.fill()
              ctx.strokeStyle = c; ctx.lineCap = "round"; ctx.lineWidth = 1.7
              var tw = now / 1000
              for (var j = 0; j < 2; j++) {
                ctx.globalAlpha = 0.45 + 0.55 * Math.abs(Math.sin((tw * 2.4 - j * 0.25) * Math.PI))
                ctx.beginPath(); ctx.arc(2.5, 0, 4 + j * 3.6, -0.85, 0.85); ctx.stroke()
              }
              ctx.restore(); ctx.restore()
            }
          }
          // name label above the hovered icon
          Rectangle {
            readonly property bool on: hover.containsMouse && root.dragIdx < 0 && root.hoverIdx === cell.index
            visible: on || opacity > 0
            opacity: on ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 120 } }
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top; anchors.bottomMargin: 6
            width: lbl.width + 16; height: lbl.height + 8; radius: 7
            color: "#e61a1a1a"; border.color: "#44ffffff"; border.width: 1
            Text { id: lbl; anchors.centerIn: parent; color: "#f2f2f2"; font.pixelSize: 12
              text: cell.modelData.cls === "__launcher__" ? "Apps" : ((root.appmap[cell.modelData.cls] && root.appmap[cell.modelData.cls].name) || cell.modelData.cls.replace(/^chrome-/, "").replace(/-default$/, "")) }
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
            id: cma
            anchors.fill: parent
            cursorShape: cell.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property real px0: 0
            property bool moved: false
            readonly property bool canDrag: !root.locked && cell.index < root.pinned.length
            function rx(m) { return cma.mapToItem(rowArea, m.x, 0).x }
            onPressed: (m) => { px0 = rx(m); moved = false }
            onPositionChanged: (m) => {
              if (!(pressedButtons & Qt.LeftButton) || !canDrag) return
              var x = rx(m)
              if (!moved && Math.abs(x - px0) > 6) { moved = true; root.mag = 0; root.dragIdx = cell.index; root.dropIdx = cell.index; root.ctx = "" }
              if (moved && root.dragIdx === cell.index) {
                root.dragX = x
                var L0 = (win.width - root.baseTotal) / 2
                root.dropIdx = Math.max(0, Math.min(root.pinned.length - 1, Math.round((x - L0 - root.base / 2) / (root.base + root.gap))))
              }
            }
            onReleased: {
              if (root.dragIdx === cell.index) {
                var f = root.dragIdx, t = root.dropIdx
                root.dragIdx = -1
                root.moveTo(f, t)
                root.mag = hover.hovered ? 1 : 0
                root.pointer(hover.point.position.x)
              }
            }
            onClicked: (m) => {
              if (moved) { moved = false; return }
              if (cell.modelData.cls === "__launcher__") { if (root.rubik) twistAnim.restart(); root.ctx = ""; root.activate("__launcher__"); return }
              if (m.button === Qt.LeftButton) { if (root.rubik) twistAnim.restart(); root.ctx = ""; root.activate(cell.modelData.cls) }
              else if (m.button === Qt.MiddleButton) { root.sh(["/home/aigazoo/.local/bin/dock-pin-toggle", cell.modelData.cls]) }
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
  // Every second word of a menu label gets a capital: "Lock dock" -> "Lock Dock".
  function cap2(s) { var w = String(s).split(" "); for (var i = 1; i < w.length; i += 2) if (w[i].length) w[i] = w[i].charAt(0).toUpperCase() + w[i].slice(1); return w.join(" ") }
  function isBrowser(c) { return /^(google-chrome|chromium|brave|microsoft-edge|vivaldi|helium|firefox|zen|librewolf)/i.test(c) }
  function ctxRows() {
    var rows = []
    var w = ctxWins
    if (w.length > 0) rows.push({ l: w.length + (w.length > 1 ? " windows open" : " window open"), a: "hdr" })
    for (var i = 0; i < w.length && i < 6; i++) rows.push({ l: "   " + (w[i].t.length > 26 ? w[i].t.substring(0, 25) + "…" : (w[i].t || "(untitled)")), a: "focus", addr: w[i].a })
    if (appmap[ctx]) rows.push({ l: "New window", a: "new" })
    if (isBrowser(ctx)) rows.push({ l: "New incognito window", a: "incog" })
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
                text: modelData.a === "hdr" ? "●  " + root.cap2(modelData.l) : (modelData.a === "focus" ? modelData.l : root.cap2(modelData.l))
                color: modelData.a === "hdr" ? "#8fd18f" : "#C1C497"; font.pixelSize: 13
                font.bold: modelData.a === "hdr"
              }
              MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  var c = root.ctx, act = modelData.a, addr = modelData.addr
                  if (act === "hdr") return
                  if (act === "pin") root.sh(["/home/aigazoo/.local/bin/dock-pin-toggle", c])
                  else if (act === "close") root.sh(["/home/aigazoo/.local/bin/dock-close-app", c])
                  else if (act === "focus") root.sh(["hyprctl", "dispatch", "hl.dsp.focus({window='address:" + addr + "'})"])
                  else if (act === "incog") root.launch(["/home/aigazoo/.local/bin/browser-incognito", c])
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
