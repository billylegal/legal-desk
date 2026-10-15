import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// macOS-style dock: icons magnify (fisheye) as the mouse passes over them.
// Reads the same pinned list as nwg-dock-hyprland (~/.cache/nwg-dock-pinned).
// Test mode: run with MACDOCK_TEST=1 to float it higher so it doesn't overlap the old dock.
ShellRoot {
  id: root
  property var pinned: []
  // 3D Windows edge: light top/left, dark bottom/right
  component Bevel: Item {
    anchors.fill: parent
    Rectangle { width: parent.width; height: 1; color: "#ffffff" }
    Rectangle { width: 1; height: parent.height; color: "#ffffff" }
    Rectangle { y: parent.height - 1; width: parent.width; height: 1; color: "#404040" }
    Rectangle { x: parent.width - 1; width: 1; height: parent.height; color: "#404040" }
  }
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
  readonly property int reqBase: { var n = parseInt(sizeName); return isNaN(n) ? (sizeName === "small" ? 34 : (sizeName === "large" ? 58 : 46)) : Math.max(24, Math.min(110, n)) }
  // Never wider than the screen: shrink the icons (zoom room included) when the chosen size doesn't fit all of them.
  readonly property real screenW: win.screen ? win.screen.width : 1920
  readonly property int base: Math.max(24, Math.min(reqBase, Math.floor((screenW - 48 - items.length * gap) / (items.length + (maxScale - 1) * 3.6))))
  readonly property real maxScale: rubik ? 1.12 : (skin.nz ? 1.0 : (zoomVal >= 1 ? Math.min(3.2, zoomVal) : (reqBase >= 56 ? 2.3 : (reqBase <= 36 ? 2.8 : 2.5))))
  readonly property real radius: base * 3.6
  readonly property int gap: rubik ? 5 : 6
  property string skinTxt: "auto"
  readonly property int skinIdx: { var n = parseInt(skinTxt); return (isNaN(n) || n < 0 || n >= skins.length) ? skinDefault : n }
  // ic = how the icons look on that plate: "" as they are, "gray" black & white, "#rrggbb" tinted in one colour.
  // The 10 skins come from skins.json (one list for every dock style); "$name" colours follow the active Omarchy theme.
  FileView { id: skinsFile; path: "/usr/share/legal-desk/skins.json"; blockLoading: true; printErrors: false }
  readonly property var skinList: { try { return JSON.parse(skinsFile.text()).skins } catch (e) { return [{ name: "Nebula", mac: { c1: "#2a1466", c2: "#07050f", b: "#8B5CF6", r: 18 }, rubik: { c1: "#1a0f3d", c2: "#07050f", b: "#8B5CF6", r: 12, t: ["#8B5CF6", "#B061FF", "#6C8CFF", "#5CC8F5", "#CC8CFF", "#E6E1FA"] } }] } }
  function sub(v) {
    if (typeof v === "string" && v.charAt(0) === "$") {
      var k = v.substring(1)
      return k === "omaBg" ? "" + omaBg : k === "omaBg2" ? "" + omaBg2 : k === "omaAcc" ? "" + omaAcc : (oc[k] || "#888888")
    }
    return v
  }
  function skinOf(def, name) {
    var o = { n: name, ic: "", t: [] }
    for (var k in def) o[k] = Array.isArray(def[k]) ? def[k].map(sub) : sub(def[k])
    return o
  }
  readonly property var macSkins: skinList.map(function (s) { return skinOf(s.mac, s.name) })
  readonly property var rubikSkins: skinList.map(function (s) { return skinOf(s.rubik, s.name) })
  readonly property var skins: rubik ? rubikSkins : macSkins
  readonly property int skinDefault: { for (var i = 0; i < skins.length; i++) if (skins[i].n === "Nebula") return i; return 0 }
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
  // Dock order: apps, dividers (__sep__N), launcher/Downloads/trash. ~/.cache/macdock-layout remembers a custom order (drag in Move Icons); no file = the default order.
  property var layoutTokens: []
  property var ownTokens: []          // Legal Desk's own apps kept in the dock (~/.cache/macdock-own): __calendar__, __notes__
  FileView {
    path: Quickshell.env("HOME") + "/.cache/macdock-own"; watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: root.ownTokens = text().split("\n").map(x => x.trim()).filter(x => x)
  }
  property date nowD: new Date()
  Timer { interval: 20000; running: true; repeat: true; onTriggered: root.nowD = new Date() }
  function isSep(c) { return c.indexOf("__sep") === 0 }
  function fixedCls(c) { return c === "__sepfix__" || c === "__snap__" }   // the screenshot button + its divider always sit at the very end of the dock
  function dockItems(pin, run, lay, own) {
    var def = pin.slice(), low = {}
    run.forEach(function (c) { if (!pin.some(p => p.toLowerCase() === c.toLowerCase())) def.push(c) })
    def = def.concat(["__launcher__", "__folder__", "__trash__"])
    var li = def.indexOf("__launcher__")
    own.forEach(function (t) { if (def.indexOf(t) < 0) { def.splice(li, 0, t); li++ } })
    if (!lay.length) return def.concat(["__sepfix__", "__snap__"]).map(c => ({ cls: c }))
    def.forEach(function (c) { low[c.toLowerCase()] = c })
    var out = [], used = {}
    lay.forEach(function (t) {
      if (isSep(t)) { out.push(t); return }
      var k = t.toLowerCase(); if (low[k] && !used[k]) { out.push(low[k]); used[k] = 1 }
    })
    var extra = def.filter(c => !used[c.toLowerCase()])
    var at = out.indexOf("__launcher__"); if (at < 0) at = out.length
    extra = extra.filter(c => true)
    out.splice.apply(out, [at, 0].concat(extra.filter(c => !(c === "__launcher__" || c === "__folder__" || c === "__trash__"))))
    extra.filter(c => (c === "__launcher__" || c === "__folder__" || c === "__trash__")).forEach(c => out.push(c))
    return out.concat(["__sepfix__", "__snap__"]).map(c => ({ cls: c }))
  }
  property var items: dockItems(pinned, runCls, layoutTokens, ownTokens)
  FileView {
    path: Quickshell.env("HOME") + "/.cache/macdock-layout"
    watchChanges: true; printErrors: false
    onFileChanged: reload()
    onLoaded: root.layoutTokens = text().split("\n").map(s => s.trim()).filter(s => s.length > 0)
  }
  function saveLayout(order) {
    layoutTokens = order
    pinned = order.filter(c => pinned.some(p => p.toLowerCase() === c.toLowerCase()))
    sh(["/usr/lib/legal-desk/dock-layout-save"].concat(order))
  }
  function curOrder() { return items.map(i => i.cls).filter(c => !fixedCls(c) && (isSep(c) || c.indexOf("__") === 0 || isPinned(c))) }
  function addDivider() { var o = curOrder(), at = o.indexOf("__launcher__"); if (at < 0) at = o.length; o.splice(at, 0, "__sep__" + Date.now()); saveLayout(o) }
  function removeAt(i) { var o = curOrder(), c = items[i].cls; saveLayout(o.filter(x => x !== c)) }
  readonly property real sepW: 10                                  // a divider is a narrow cell, so icons sit close to it
  function restW(i) { return items[i] && isSep(items[i].cls) ? sepW : base }
  readonly property var restXs: { var a = [], x = 0; for (var i = 0; i < items.length; i++) { a.push(x); x += restW(i) + gap } return a }
  readonly property real baseTotal: items.length ? restXs[items.length - 1] + restW(items.length - 1) + gap : 0
  readonly property real panelW: baseTotal + base * (maxScale - 1) * 3.6 + 40
  readonly property real panelH: base * maxScale + 54

  FileView {
    path: Quickshell.env("HOME") + "/.cache/nwg-dock-pinned"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: root.pinned = text().split("\n").map(s => s.trim()).filter(s => s.length > 0)
  }
  // Omarchy theme colours (the "Omarchy" skin follows whichever Omarchy theme is active).
  property var oc: ({})
  readonly property color omaBg: oc.dark_background || oc.background || "#1a1b26"
  readonly property color omaBg2: oc.background || "#16161e"
  readonly property color omaAcc: oc.accent || "#7aa2f7"
  readonly property color omaTxt: oc.foreground || "#c0caf5"
  readonly property color omaSel: oc.selection || "#33467c"
  FileView {
    id: omaFile
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: { var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"/); if (m) c[m[1]] = m[2] }); root.oc = c }
  }
  Timer { interval: 3000; running: true; repeat: true; onTriggered: omaFile.reload() }
  // Menu colours follow the chosen dock skin (~/.cache/dock-menu-colors, written by macdock-skin); default = Nebula.
  property color pBg: "#0B0818"
  property color pAcc: "#8B5CF6"
  property color pTxt: "#E6E1FA"
  property color pSel: "#2A1B52"
  // The Omarchy skin's menus use Omarchy's original colours (the Tokyo Night theme it installs with), so everyone can tell it is the original look.
  readonly property bool omaSkin: skin.n === "Omarchy"
  readonly property color bgC: omaSkin ? "#1a1b26" : pBg
  readonly property color accC: omaSkin ? "#7aa2f7" : pAcc
  readonly property color txtC: omaSkin ? "#c0caf5" : pTxt
  readonly property color selC: omaSkin ? "#292e42" : pSel
  FileView {
    id: themeColors
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) root.pBg = c.bg
      if (c.acc) root.pAcc = c.acc
      if (c.txt) root.pTxt = c.txt
      if (c.sel) root.pSel = c.sel
    }
  }
  // Icon colours (menu: Icons < >), independent of the skin. Mostly colour swaps: the icons are tinted in one colour (Match skin = the skin's own colour).
  // A few shapes too: Pearls and Bubbles (circles), Blocks (every icon on a block in the skin's colours) and Cube (Rubik blocks). File: ~/.cache/dock-icon-style
  // Launcher icon (menu: Launcher < >): what the button at the right of the dock looks like. 0 is the Rubik's Cube; the rest are drawn here.
  // 1-3 flat, 4-6 3D, 7-10 moving. File: ~/.cache/dock-launcher-icon
  property int launcherIcon: 0
  readonly property var launcherNames: ["Cube", "Desk tile", "Zones", "Desk", "3D Cube", "3D Layers", "3D Flip", "Hop", "Orbit", "Pulse", "Spark"]
  FileView {
    id: launchFile
    path: Quickshell.env("HOME") + "/.cache/dock-launcher-icon"
    printErrors: false
    onLoaded: { var n = parseInt(text()); root.launcherIcon = (isNaN(n) || n < 0 || n >= root.launcherNames.length) ? 0 : n }
    onLoadFailed: root.launcherIcon = 0
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: launchFile.reload() }
  property real lPhase: 0
  NumberAnimation on lPhase { from: 0; to: 1; duration: 3200; loops: Animation.Infinite; running: root.launcherIcon >= 6 }
  // a 3 x 3 block of tiles (the Legal Desk logo's tile), optionally lighting up in a wave
  component LTiles: Item {
    property real ts: 44
    property real gp: 8
    property bool wave: false
    property real ph: 0
    readonly property var pal: ["#8B5CF6", "#E6E1FA", "#6C8CFF", "#CC8CFF", "#5CC8F5", "#B061FF", "#E6E1FA", "#8B5CF6", "#B8A2FF"]
    width: ts * 3 + gp * 2; height: width
    Repeater { model: 9
      Rectangle { required property int index
        x: (index % 3) * (parent.ts + parent.gp); y: Math.floor(index / 3) * (parent.ts + parent.gp); width: parent.ts; height: parent.ts
        color: parent.pal[index]; opacity: parent.wave ? 0.3 + 0.7 * (0.5 + 0.5 * Math.sin(parent.ph * 6.2832 - (index % 3 + Math.floor(index / 3)) * 0.9)) : 1 } }
  }
  // The 10 icon sets (menu: Icons < >). Each is a full look: the art of Legal Desk's own icons (drawn by legal-icons, see artDir below)
  // and how other apps' icons are dressed: ic = tinted ("gray" / "skin"), sk = on plates (see tileDefs), blk = on blocks in the skin's colours.
  property int iconStyle: 0
  readonly property var iconNames: ["Tile", "Outline", "Glyph", "Duotone", "Glass", "Neon", "Flat", "Pixel", "Sticker", "Cube"]
  readonly property var iconDefs: [
    {}, { ic: "gray" }, { ic: "skin" }, { blk: true }, { sk: "Glass" }, { ic: "skin", blk: true }, { sk: "Flat" }, { sk: "Pixel" }, { sk: "Sticker" }, { sk: "Cube" }
  ]
  readonly property var tileDefs: ({
    "Glass":   { c1: "#58ffffff", c2: "#22ffffff", b: "#aaffffff", r: 18, t: [] },
    "Flat":    { c1: Qt.darker(accC, 1.6), c2: Qt.darker(accC, 2.0), b: accC, r: 10, t: [] },
    "Pixel":   { c1: "#262636", c2: "#14141e", b: accC, r: 4, t: [] },
    "Sticker": { c1: "#ffffff", c2: "#e8e8f0", b: "#bdbdcc", r: 14, t: [] },
    "Cube":    { c1: "#0d0d0d", c2: "#0d0d0d", b: "#2a2a2a", r: 12, t: ["#ffd500", "#0b57d0", "#c41e3a", "#00a152", "#ff5a00", "#f4f4f4"] }
  })
  function styleSkin(n) { return tileDefs[n] || null }
  // Own icons: SVGs drawn by legal-icons for the chosen set + skin into ~/.cache/legal-desk/icons/<stamp>/ (pointer file: current).
  property string artDir: ""
  FileView {
    id: artFile
    path: Quickshell.env("HOME") + "/.cache/legal-desk/icons/current"
    printErrors: false
    onLoaded: { var t = text().trim(); root.artDir = t ? "file://" + Quickshell.env("HOME") + "/.cache/legal-desk/icons/" + t : "" }
    onLoadFailed: root.artDir = ""
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: artFile.reload() }
  function artName(cls) {
    return cls === "__calendar__" ? "calendar" : cls === "__notes__" ? "notes" : cls === "__tasks__" ? "tasks" : cls === "__disks__" ? "disks" : cls === "__zones__" ? "zones"
         : cls === "__snap__" ? "camera" : cls === "__radio__" ? "radio" : cls === "__folder__" ? "folder-download" : cls === "__trash__" ? (trashFull ? "trash-full" : "trash") : ""
  }
  property int artDay: -1
  Process { id: artProc; command: ["/usr/lib/legal-desk/legal-icons", "refresh"] }   // a new day: the Calendar icon shows the new date
  Connections { target: root; function onNowDChanged() { var d = root.nowD.getDate(); if (root.artDay >= 0 && d !== root.artDay) { artProc.running = false; artProc.running = true } root.artDay = d } }
  readonly property var idef: iconDefs[iconStyle] || iconDefs[0]
  readonly property var istyle: idef.sk ? styleSkin(idef.sk) : (idef.blk ? skin : null)
  readonly property bool iconTiles: !!istyle
  readonly property bool iconCircle: iconTiles && !!idef.sk && (istyle.tile === "circle" || (istyle.rr !== undefined && istyle.rr >= 0.5))
  readonly property bool iconPal: iconTiles && !!idef.sk && !!istyle.t && istyle.t.length >= 3
  readonly property string icEff: idef.ic ? (idef.ic === "skin" ? ("" + accC) : idef.ic) : (iconTiles ? "" : skin.ic)
  function icol(cls) { var h = 7; for (var i = 0; i < cls.length; i++) h = (h * 31 + cls.charCodeAt(i)) % 1000003; return istyle.t[h % istyle.t.length] }
  function tc1(cls) { if (!istyle) return "transparent"; return (iconCircle && !iconPal) ? (istyle.tc || "#f2f2f2") : iconPal ? icol(cls) : Qt.lighter(istyle.c1, 1.4) }
  function tc2(cls) { if (!istyle) return "transparent"; return (iconCircle && !iconPal) ? (istyle.tc || "#f2f2f2") : iconPal ? icol(cls) : Qt.lighter(istyle.c2, 1.4) }
  readonly property color tcb: iconCircle ? "#40000000" : iconPal ? "#33ffffff" : (istyle ? istyle.b : "transparent")
  FileView {
    id: icoFile
    path: Quickshell.env("HOME") + "/.cache/dock-icon-style"
    printErrors: false
    onLoaded: { var n = parseInt(text()); root.iconStyle = (isNaN(n) || n < 0 || n >= root.iconNames.length) ? 0 : n }
    onLoadFailed: root.iconStyle = 0
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: icoFile.reload() }
  // Full-width dock (menu: Full-width dock): the solid plate becomes a bar across the whole screen width (flag file ~/.cache/dock-full).
  property bool block: false
  FileView {
    id: blockFile
    path: Quickshell.env("HOME") + "/.cache/dock-full"
    printErrors: false
    onLoaded: root.block = true
    onLoadFailed: root.block = false
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: blockFile.reload() }
  // Block look (menu: Block): every icon sits on its own block in the skin's colours, no plate behind them (flag file ~/.cache/dock-block).
  property bool blocks: false
  readonly property bool ownPlate: blocks || iconTiles || (skin.tile || "") !== ""   // Calendar/Notes/etc. sit on a plate only when the other icons do
  readonly property real ownK: 0.94
  FileView {
    id: blocksFile
    path: Quickshell.env("HOME") + "/.cache/dock-block"
    printErrors: false
    onLoaded: root.blocks = true
    onLoadFailed: root.blocks = false
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: blocksFile.reload() }
  // ---- Clock beside the dock (menu: CLOCK / TIME): drawn here for the Mac and Rubik docks; files ~/.cache/dock-clock, dock-clock-fmt ----
  property string clockPos: "off"
  property bool clock24: false
  property string clockTxt: ""
  property string clockDate: ""
  Process { id: snapProc; command: ["omarchy-capture-screenshot"] }
  FileView {
    id: ckPosFile
    path: Quickshell.env("HOME") + "/.cache/dock-clock"
    printErrors: false
    onLoaded: { var t = text().trim(); root.clockPos = (t === "left" || t === "right") ? t : "off" }
    onLoadFailed: root.clockPos = "off"
  }
  FileView {
    id: ckFmtFile
    path: Quickshell.env("HOME") + "/.cache/dock-clock-fmt"
    printErrors: false
    onLoaded: root.clock24 = text().trim() === "24"
    onLoadFailed: root.clock24 = false
  }
  Timer {
    interval: 1000; running: true; repeat: true; triggeredOnStart: true
    onTriggered: {
      var d = new Date(), m = d.getMinutes(), h = d.getHours()
      root.clockTxt = root.clock24 ? (("0" + h).slice(-2) + ":" + ("0" + m).slice(-2)) : (((h % 12) || 12) + ":" + ("0" + m).slice(-2) + (h < 12 ? " AM" : " PM"))
      root.clockDate = Qt.formatDate(d, "ddd d MMM")
      ckPosFile.reload(); ckFmtFile.reload()
    }
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
    path: Quickshell.env("HOME") + "/.cache/dock-skin-" + (root.rubik ? "rubik" : "mac")
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
  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { if (hover.hovered || root.dragIdx >= 0) return; if (!poll.running) poll.running = true; if (!countProc.running) countProc.running = true; hidChk.running = true; lockChk.running = true } }

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
def favicon(c):
    # Web apps without a launcher file (chrome-<site>__path-Default): use the site's own icon, saved once in ~/.cache/macdock-icons.
    m = re.match(r'chrome-([a-z0-9.-]+?)(__.*)?-default$', c.lower())
    if not m or '.' not in m.group(1) or re.match(r'^[0-9.]+$', m.group(1)): return None
    host = m.group(1)
    d = os.path.expanduser('~/.cache/macdock-icons'); os.makedirs(d, exist_ok=True)
    for ext in ('png', 'ico', 'svg'):
        f = os.path.join(d, host + '.' + ext)
        if os.path.exists(f): return {'icon': f, 'id': '', 'name': (host.split('.')[1] if host.split('.')[0] in ('www', 'app', 'm') else host.split('.')[0]).capitalize()}
    if os.path.exists(os.path.join(d, host + '.none')): return None
    import urllib.request, urllib.parse
    def get(u):
        rq = urllib.request.Request(u, headers={'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) LegalDesk'})
        with urllib.request.urlopen(rq, timeout=5) as r: return r.read(), r.geturl()
    cands = []
    try:
        html, base = get('https://' + host + '/')
        html = html.decode('utf-8', 'ignore')
        for t in re.findall(r'<link[^>]+>', html, re.I):
            q = chr(34) + chr(39)
            rel = re.search('rel=[' + q + ']([^' + q + ']+)', t, re.I); hr = re.search('href=[' + q + ']([^' + q + ']+)', t, re.I)
            if rel and hr and 'icon' in rel.group(1).lower():
                sz = re.search('sizes=[' + q + '][0-9]+', t, re.I)
                cands.append((('apple' in rel.group(1).lower()) * 1000 + (int(sz.group(0)[7:]) if sz else 0), urllib.parse.urljoin(base, hr.group(1))))
    except Exception: pass
    cands.sort(reverse=True)
    urls = [u for _, u in cands] + ['https://' + host + '/favicon.ico']
    for u in urls:
        try:
            data, _ = get(u)
            ext = 'png' if data[1:4] == b'PNG' else 'ico' if data[:4] == bytes([0, 0, 1, 0]) else 'svg' if b'<svg' in data[:600] else None
            if ext and len(data) > 100:
                f = os.path.join(d, host + '.' + ext); open(f, 'wb').write(data)
                return {'icon': f, 'id': '', 'name': (host.split('.')[1] if host.split('.')[0] in ('www', 'app', 'm') else host.split('.')[0]).capitalize()}
        except Exception: continue
    open(os.path.join(d, host + '.none'), 'w').write('')
    return None
out = {}
for c in want:
    r = find(c) or favicon(c)
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

  // Trash can: shows full/empty, opens the trash, right-click Empty Trash; drag a pinned icon onto it to unpin
  property bool trashFull: false
  Timer { interval: 4000; running: true; repeat: true; triggeredOnStart: true; onTriggered: { trashChk.running = false; trashChk.running = true } }
  Process { id: trashChk; command: ["bash", "-c", "ls -A \"$HOME/.local/share/Trash/files\" 2>/dev/null | head -1"]
    stdout: StdioCollector { onStreamFinished: root.trashFull = text.trim().length > 0 } }
  function activate(cls) {
    if (cls === "__trash__") { launch(["gio", "open", "trash:///"]); return }
    if (cls === "__folder__") { launch(["xdg-open", Quickshell.env("HOME") + "/Downloads"]); return }
    if (cls === "__launcher__") { sh(["/usr/lib/legal-desk/drawer-toggle"]); return }
    if (cls === "__calendar__") { sh(["/usr/lib/legal-desk/legal-calendar"]); return }
    if (cls === "__notes__") { sh(["/usr/lib/legal-desk/legal-notes"]); return }
    if (cls === "__zones__") { sh(["/usr/lib/legal-desk/legal-zones"]); return }
    if (cls === "__disks__") { sh(["/usr/lib/legal-desk/legal-disks"]); return }
    if (cls === "__snap__") { sh(["omarchy-capture-screenshot"]); return }
    if (cls === "__tasks__") { sh(["/usr/lib/legal-desk/legal-tasks"]); return }
    if (cls === "__radio__") { sh(["/usr/lib/legal-desk/legal-radio", "toggle"]); return }
    if (cls === "reboot") { sh(["/usr/lib/legal-desk/reboot-confirm"]); return }
    if (running[cls.toLowerCase()]) { sh(["bash", "-c", "/usr/lib/legal-desk/win-minimize restore-class \"$1\"; a=$(hyprctl clients -j | python3 -c \"import json,sys;c=sys.argv[1].lower();print(next((w['address'] for w in json.load(sys.stdin) if w['class'].lower()==c),''))\" \"$1\"); [ -n \"$a\" ] && hyprctl dispatch \"hl.dsp.focus({window='address:$a'})\"", "x", cls]); return }
    markLaunch(cls)
    var r = appmap[cls]
    if (r) launch(["gtk-launch", r.id + ".desktop"])
    else launch(["bash", "-c", "gtk-launch \"$1\" || { command -v \"$1\" >/dev/null && setsid \"$1\"; }", "x", cls])
  }
  function iconFor(cls) {
    if (cls === "__launcher__") return "file:///usr/share/nwg-dock-hyprland/images/grid.svg"
    if (cls === "__trash__" || cls === "__folder__") return artDir !== "" ? artDir + "/" + artName(cls) + ".svg" : ""
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
    measurer.cmd = ["/usr/lib/legal-desk/dock-icon-scale"].concat(ps)
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
  Behavior on mag { SpringAnimation { spring: 5; damping: 0.3; epsilon: 0.002 } }
  property real umT: 0
  property real umS: 0
  // umS chases umT with our own per-frame spring. (A Behavior/SpringAnimation restarts on every mouse event and a mouse
  // reports faster than the screen refreshes, so it never got to advance: the wave froze and then jumped.)
  property real umV: 0
  FrameAnimation {
    running: root.mag > 0.01 && (Math.abs(root.umS - root.umT) > 0.05 || Math.abs(root.umV) > 0.05)
    onTriggered: {
      var dt = Math.min(frameTime, 0.05), n = Math.max(1, Math.ceil(dt / 0.006)), h = dt / n
      var x = root.umS, v = root.umV
      for (var i = 0; i < n; i++) { v += (-1000 * (x - root.umT) - 46 * v) * h; x += v * h }
      root.umV = v; root.umS = x
    }
  }
  property int hoverIdx: -1
  property int dragIdx: -1
  property int dropIdx: -1
  property real dragX: 0
  property bool locked: false
  // Move Icons mode (from the menu): icons wiggle, drag to rearrange, no zoom, Done button.
  property bool moveMode: false
  Process { id: lockChk; command: ["test", "-e", Quickshell.env("HOME") + "/.cache/dock-locked"]; onExited: (c) => root.locked = (c === 0) }

  function layoutFor(p, m, W) {
    var n = items.length, L0 = (W - baseTotal) / 2
    var xs = [], ws = [], tot = 0, mm = Math.max(0, m)
    if (dragIdx >= 0) {
      var o = []; for (var k = 0; k < n; k++) if (k !== dragIdx) o.push(k)
      o.splice(Math.max(0, Math.min(o.length, dropIdx)), 0, dragIdx)
      var xx = L0
      for (var j = 0; j < n; j++) { var wj = restW(o[j]); xs[o[j]] = xx; ws[o[j]] = wj; xx += wj + gap }
      return { xs: xs, ws: ws, tot: baseTotal - gap }
    }
    for (var i = 0; i < n; i++) {
      var d = Math.abs(p - (L0 + restXs[i] + restW(i) / 2))
      var sc = restW(i) < base ? 1 : d < radius ? 1 + (maxScale - 1) * mm * (0.5 + 0.5 * Math.cos(Math.PI * d / radius)) : 1
      ws[i] = restW(i) < base ? restW(i) : base * Math.max(0.9, sc); tot += ws[i]
    }
    tot += gap * (n - 1)
    var x = (W - tot) / 2
    for (var q = 0; q < n; q++) { xs[q] = x; x += ws[q] + gap }
    return { xs: xs, ws: ws, tot: tot }
  }
  readonly property var lay: layoutFor(umS, mag, win.width)
  // Where the last icon (the launcher) sits on the screen at rest; the menus above the dock line up with it.
  readonly property real launcherX: { var l = layoutFor(0, 0, win.width), k = items.findIndex(i => i.cls === "__launcher__"); return k < 0 ? 0 : Math.round(((win.screen ? win.screen.width : 1920) - win.width) / 2 + l.xs[k] + l.ws[k] / 2) }
  onLauncherXChanged: lxT.restart()
  Timer { id: lxT; interval: 400; onTriggered: lxW.running = true }
  // Menus open on one line just above the dock: its distance from the bottom of the screen goes next to the launcher position.
  readonly property int menuLine: base + 39
  onMenuLineChanged: lxT.restart()
  Process { id: lxW; command: ["bash", "-c", "echo \"$0 $1\" > \"$HOME/.cache/dock-launcher\"", String(root.launcherX), String(root.menuLine)] }

  // Mouse events can arrive at 1000 Hz; solve for the latest position at most every 8 ms.
  property real pmx: 0
  Timer { id: ptT; interval: 8; onTriggered: root.solvePointer(root.pmx) }
  function pointer(mx) { pmx = mx; if (!ptT.running) ptT.start() }
  function nearestIdx(rx) { var b = 0, bd = 1e9; for (var i = 0; i < items.length; i++) { var d = Math.abs(rx - (restXs[i] + restW(i) / 2)); if (d < bd) { bd = d; b = i } } return b }
  function solvePointer(mx) {
    var n = items.length; if (n < 1) return
    var L0 = (win.width - baseTotal) / 2
    var p = (mag > 0.15) ? umT : mx
    for (var it = 0; it < 10; it++) {
      var l = layoutFor(p, 1, win.width)
      var i = 0
      while (i < n - 1 && (p - L0) >= restXs[i + 1]) i++
      var off = (p - L0) - restXs[i]
      var sx = off < 0 ? l.xs[i] + off : (off <= restW(i) ? l.xs[i] + off / restW(i) * l.ws[i] : l.xs[i] + l.ws[i] + (off - restW(i)))
      p += (mx - sx) * 0.5
    }
    umT = p
    if (mag <= 0.15) { umS = p; umV = 0 }
    hoverIdx = nearestIdx(p - L0)
  }
  function moveTo(from, to) {
    var last = items.length - 3   // the last two cells (divider + screenshot) are fixed
    if (to > last) to = last
    if (from === to || from < 0 || to < 0 || from > last) return
    var o = items.map(i => i.cls); o.splice(to, 0, o.splice(from, 1)[0])
    saveLayout(o.filter(c => !fixedCls(c) && (isSep(c) || c.indexOf("__") === 0 || isPinned(c))))
  }

  PanelWindow {
    id: win
    anchors { bottom: true }
    margins { bottom: root.testMode ? 150 : (root.block ? 0 : 4) }
    implicitWidth: root.block ? (win.screen ? win.screen.width : 1900) : Math.min(root.panelW, win.screen ? win.screen.width : 1900)
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
      height: (hover.containsMouse || root.moveMode) ? parent.height : root.base + 16

      HoverHandler {
        id: hover
        onPointChanged: if (root.dragIdx < 0) root.pointer(point.position.x)
        onHoveredChanged: root.mag = (hovered && root.dragIdx < 0 && !root.moveMode) ? 1 : 0
        property real mx: point.position.x
        readonly property bool containsMouse: hovered
      }
    }

    // Solid dock: a plate behind the row (Rubik: black cube-plastic frame). Transparent dock: icons float.
    Rectangle {
      visible: root.solid || !!root.skin.plate || root.block
      opacity: rowArea.opacity
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: root.block ? 0 : 3
      width: root.block ? parent.width : root.lay.tot + 18; height: root.base + (root.block ? 16 : 10); radius: root.block ? 0 : root.skin.r
      gradient: Gradient { GradientStop { position: 0; color: root.skin.c1 } GradientStop { position: 1; color: root.skin.c2 } }
      border.color: root.skin.b; border.width: 1
      Bevel { visible: !!root.skin.bevel }
    }
    // Move Icons mode: a Done button above the dock
    Rectangle {
      visible: root.moveMode
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom; anchors.bottomMargin: root.base + 36
      width: 190; height: 30; radius: 15; color: dma.containsMouse ? "#3a5a44" : "#111c18"; border.color: "#C1C497"; border.width: 1
      Text { anchors.centerIn: parent; text: "Drag To Move  ·  Done \u2713"; color: "#C1C497"; font.pixelSize: 12 }
      MouseArea {
        id: dma; anchors.fill: parent; hoverEnabled: true
        onClicked: { root.moveMode = false; root.sh(["/usr/lib/legal-desk/dock-move-done"]) }
      }
    }
    Rectangle {
      visible: root.moveMode
      anchors.horizontalCenter: parent.horizontalCenter; anchors.horizontalCenterOffset: 190
      anchors.bottom: parent.bottom; anchors.bottomMargin: root.base + 36
      width: 130; height: 30; radius: 15; color: dvma.containsMouse ? "#3a5a44" : "#111c18"; border.color: "#C1C497"; border.width: 1
      Text { anchors.centerIn: parent; text: "+ Add divider"; color: "#C1C497"; font.pixelSize: 12 }
      MouseArea { id: dvma; anchors.fill: parent; hoverEnabled: true; onClicked: root.addDivider() }
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
          readonly property bool isSep: root.isSep(modelData.cls)
          readonly property bool ownIcon: modelData.cls === "__radio__" || modelData.cls === "__trash__" || modelData.cls === "__folder__" || modelData.cls === "__calendar__" || modelData.cls === "__notes__" || modelData.cls === "__tasks__" || modelData.cls === "__disks__" || modelData.cls === "__zones__" || modelData.cls === "__snap__"   // draw their own tile
          readonly property real lift: dragged ? 1.18 : 1
          width: (root.lay.ws[index] || root.base) * lift
          height: isSep ? root.base : width
          x: dragged ? root.dragX - width / 2 : (root.lay.xs[index] || 0)
          Behavior on x { enabled: root.dragIdx >= 0 && !cell.dragged; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
          z: dragged ? 10 : 0
          property real jig: 0
          rotation: root.moveMode && !dragged ? jig : 0
          SequentialAnimation on jig {
            running: root.moveMode; loops: Animation.Infinite
            NumberAnimation { to: -2.6; duration: 95 + (cell.index % 4) * 17 }
            NumberAnimation { to: 2.6; duration: 95 + (cell.index % 3) * 21 }
          }
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
          // Divider: a thin line between groups of icons (drag it anywhere; in Move Icons click it to remove it).
          Item {
            visible: cell.isSep; anchors.fill: parent
            Rectangle {
              anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.08
              width: root.moveMode ? 3 : 2; height: parent.height * 0.84; radius: 1
              color: root.moveMode ? root.accC : Qt.rgba(root.accC.r, root.accC.g, root.accC.b, 0.55)
            }
            Rectangle {
              visible: root.moveMode && !root.fixedCls(cell.modelData.cls); width: 16; height: 16; radius: 8; color: root.bgC; border.color: root.accC; border.width: 1
              anchors.horizontalCenter: parent.horizontalCenter; anchors.top: parent.top
              Text { anchors.centerIn: parent; text: "\u00d7"; color: root.txtC; font.pixelSize: 12 }
            }
          }
          Item {
            visible: !cell.isSep; anchors.fill: parent
          Rectangle {
            visible: root.rubik && cell.modelData.cls !== "__launcher__"
            anchors.fill: parent; radius: width * (root.skin.rr !== undefined ? root.skin.rr : 0.2)
            color: cell.ownIcon ? "#0d0d0d" : root.iconTiles ? root.tc1(cell.modelData.cls) : ((root.rpal && root.rpal.length) ? root.rpal[cell.index % root.rpal.length] : "#333333"); border.color: "#0d0d0d"; border.width: 2
            rotation: cell.twist
            Rectangle { anchors.fill: parent; radius: parent.radius; color: "transparent"; border.color: "#33ffffff"; border.width: 1 }
          }
          // Mac skins: circle / raised button / hover highlight behind each icon
          Rectangle {
            id: stile
            readonly property string kind: root.skin.tile || ""
            visible: !root.rubik && !cell.ownIcon && kind !== "" && (kind === "circle" || kind === "btn" || (hover.hovered && root.hoverIdx === cell.index && root.dragIdx < 0))
            anchors.centerIn: parent
            width: parent.width * (kind === "circle" ? 0.96 : 0.98); height: width
            radius: kind === "circle" ? width / 2 : (kind === "hpill" ? 8 : 0)
            color: kind === "circle" ? (root.iconTiles ? root.tc1(cell.modelData.cls) : (root.skin.t.length ? root.skin.t[cell.index % root.skin.t.length] : (root.skin.tc || "#33ffffff")))
                   : (kind === "hpill" ? "#2cffffff" : "#c0c0c0")
            border.color: kind === "circle" ? "#40000000" : "transparent"; border.width: kind === "circle" ? 1 : 0
            Bevel { visible: stile.kind === "btn" || stile.kind === "hbtn" }
          }
          // Icon style tiles (non-Rubik skins): a rounded plate behind the icon in the chosen skin's colours.
          Rectangle {
            visible: root.iconTiles && !root.rubik && (root.skin.tile || "") !== "circle" && cell.modelData.cls !== "__launcher__" && !cell.ownIcon
            anchors.centerIn: parent; width: parent.width * (root.iconCircle ? 0.96 : 0.98); height: width; radius: root.iconCircle ? width / 2 : width * 0.22
            gradient: Gradient { GradientStop { position: 0; color: root.tc1(cell.modelData.cls) } GradientStop { position: 1; color: root.tc2(cell.modelData.cls) } }
            border.color: root.tcb; border.width: 1
          }
          // Block look: each icon on its own block (skins that already have tiles keep theirs).
          Rectangle {
            visible: root.blocks && !root.rubik && !root.iconTiles && (root.skin.tile || "") === "" && cell.modelData.cls !== "__launcher__" && !cell.ownIcon
            anchors.centerIn: parent; width: parent.width * 0.98; height: width; radius: width * 0.22
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(root.skin.c1, 1.4) } GradientStop { position: 1; color: Qt.lighter(root.skin.c2, 1.4) } }
            border.color: root.omaSkin ? "transparent" : root.skin.b; border.width: root.omaSkin ? 0 : 1
          }
          Rectangle {
            visible: root.iconFor(cell.modelData.cls) === "" && !cell.ownIcon
            anchors.centerIn: parent; width: parent.width * 0.88; height: parent.height * 0.88; radius: width * 0.22
            color: root.tint(cell.modelData.cls)
            Text { anchors.centerIn: parent; text: root.letterOf(cell.modelData.cls); color: "white"; font.bold: true; font.pixelSize: parent.height * 0.55 }
          }
          Image {
            visible: cell.modelData.cls !== "__launcher__" && !cell.ownIcon && cell.modelData.cls !== "chrome-127.0.0.1__globe_-Default"
            anchors.fill: parent
            scale: root.scaleOf(cell.modelData.cls) * ((root.rubik || (root.blocks && (root.skin.tile || "") === "") || (root.iconTiles && (root.skin.tile || "") !== "circle")) ? (root.iconCircle ? 0.66 : 0.74) : (root.skin.ik || 1))
            rotation: cell.twist
            source: root.iconFor(cell.modelData.cls)
            sourceSize: Qt.size(256, 256)
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
            layer.enabled: root.icEff !== ""
            layer.smooth: true
            layer.effect: MultiEffect {
              saturation: root.icEff === "gray" ? -1 : 0
              colorization: root.icEff === "gray" ? 0 : 1
              colorizationColor: root.icEff === "gray" ? "#ffffff" : root.icEff
            }
          }
          // The other launcher icons (see launcherNames): all drawn on a 192 x 192 board and scaled to the cell
          Item {
            id: lnch
            visible: cell.modelData.cls === "__launcher__" && root.launcherIcon > 0
            width: 192; height: 192; anchors.centerIn: parent
            scale: cell.width / 192 * 0.92
            readonly property color c0: root.accC
            readonly property color c1: Qt.lighter(root.accC, 1.7)
            readonly property color c2: Qt.darker(root.accC, 1.45)
            Connections { target: root; function onAccCChanged() { cubeIso.requestPaint(); layers.requestPaint(); spark.requestPaint() } }
            // 1 Desk tile
            LTiles { visible: root.launcherIcon === 1; anchors.centerIn: parent; ts: 44; gp: 8 }
            // 2 Zones
            Item { visible: root.launcherIcon === 2; anchors.centerIn: parent; width: 150; height: 150
              Rectangle { x: 0; y: 0; width: 88; height: 150; color: lnch.c0 }
              Rectangle { x: 98; y: 0; width: 52; height: 70; color: lnch.c1 }
              Rectangle { x: 98; y: 80; width: 52; height: 70; color: lnch.c2 } }
            // 3 Desk (a monitor with two windows)
            Item { visible: root.launcherIcon === 3; anchors.centerIn: parent; width: 160; height: 140
              Rectangle { x: 0; y: 0; width: 160; height: 106; color: "transparent"; border.color: lnch.c1; border.width: 8
                Rectangle { x: 14; y: 14; width: 60; height: 78; color: lnch.c0 }
                Rectangle { x: 82; y: 14; width: 54; height: 34; color: lnch.c1 }
                Rectangle { x: 82; y: 56; width: 54; height: 36; color: lnch.c2 } }
              Rectangle { x: 70; y: 106; width: 20; height: 16; color: lnch.c1 }
              Rectangle { x: 40; y: 122; width: 80; height: 10; color: lnch.c1 } }
            // 4 3D cube
            Canvas { id: cubeIso; visible: root.launcherIcon === 4; anchors.fill: parent
              onVisibleChanged: if (visible) requestPaint()
              onPaint: {
                var g = getContext("2d"); g.reset()
                function face(a, b, c, d, col) {
                  g.beginPath(); g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.lineTo(c[0], c[1]); g.lineTo(d[0], d[1]); g.closePath(); g.fillStyle = col; g.fill()
                  g.strokeStyle = "rgba(0,0,0,0.35)"; g.lineWidth = 1.6
                  for (var k = 1; k < 3; k++) {
                    var t = k / 3
                    g.beginPath(); g.moveTo(a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t); g.lineTo(d[0] + (c[0] - d[0]) * t, d[1] + (c[1] - d[1]) * t); g.stroke()
                    g.beginPath(); g.moveTo(a[0] + (d[0] - a[0]) * t, a[1] + (d[1] - a[1]) * t); g.lineTo(b[0] + (c[0] - b[0]) * t, b[1] + (c[1] - b[1]) * t); g.stroke()
                  }
                }
                face([96, 20], [150, 52], [96, 84], [42, 52], "" + lnch.c1)
                face([42, 52], [96, 84], [96, 152], [42, 120], "" + lnch.c0)
                face([96, 84], [150, 52], [150, 120], [96, 152], "" + lnch.c2)
              } }
            // 5 3D layers (three stacked plates)
            Canvas { id: layers; visible: root.launcherIcon === 5; anchors.fill: parent
              onVisibleChanged: if (visible) requestPaint()
              onPaint: {
                var g = getContext("2d"); g.reset()
                var cols = ["" + lnch.c2, "" + lnch.c0, "" + lnch.c1]
                for (var k = 0; k < 3; k++) {
                  var cy = 138 - k * 34
                  g.fillStyle = "" + Qt.darker(cols[k], 1.5); g.beginPath(); g.moveTo(32, cy); g.lineTo(96, cy + 32); g.lineTo(96, cy + 46); g.lineTo(32, cy + 14); g.closePath(); g.fill()
                  g.fillStyle = "" + Qt.darker(cols[k], 1.25); g.beginPath(); g.moveTo(96, cy + 32); g.lineTo(160, cy); g.lineTo(160, cy + 14); g.lineTo(96, cy + 46); g.closePath(); g.fill()
                  g.fillStyle = cols[k]; g.beginPath(); g.moveTo(96, cy - 32); g.lineTo(160, cy); g.lineTo(96, cy + 32); g.lineTo(32, cy); g.closePath(); g.fill()
                }
              } }
            // 6 3D flip: the tile turns like a coin
            Item { visible: root.launcherIcon === 6; anchors.centerIn: parent; width: 148; height: 148
              transform: Rotation { origin.x: 74; origin.y: 74; axis { x: 0; y: 1; z: 0 }
                angle: { var p = root.lPhase; if (p > 0.45) return 0; var q = p / 0.45; return 360 * q * q * (3 - 2 * q) } }
              LTiles { anchors.fill: parent; ts: 44; gp: 8 }
              Rectangle { x: 6; y: 6; width: 148; height: 148; z: -1; color: lnch.c2 } }
            // 7 Hop: a small tile hopping, with motion lines
            Item { visible: root.launcherIcon === 7; anchors.fill: parent
              readonly property real hop: Math.abs(Math.sin(root.lPhase * 3.1416 * 2))
              Repeater { model: 3
                Rectangle { required property int index
                  x: 62 + index * 32; y: 30 - parent.hop * 24; width: 8; height: 22 - index % 2 * 8; color: lnch.c1; opacity: 0.25 + 0.6 * parent.hop } }
              LTiles { x: 38; y: 66 - parent.hop * 34; ts: 36; gp: 7 }
              Rectangle { x: 56; y: 182; width: 80 - parent.hop * 28; height: 6; color: lnch.c2; anchors.horizontalCenter: undefined } }
            // 8 Orbit: a satellite circling a core
            Item { visible: root.launcherIcon === 8; anchors.fill: parent
              Rectangle { anchors.centerIn: parent; width: 132; height: 132; radius: 66; color: "transparent"; border.color: lnch.c2; border.width: 4 }
              Rectangle { anchors.centerIn: parent; width: 56; height: 56; color: lnch.c0 }
              Rectangle { anchors.centerIn: parent; width: 26; height: 26; color: lnch.c1 }
              Item { anchors.centerIn: parent; width: 132; height: 132; rotation: root.lPhase * 360
                Rectangle { x: 56; y: -12; width: 24; height: 24; color: lnch.c1 } } }
            // 9 Pulse: the tiles light up in a wave
            LTiles { visible: root.launcherIcon === 9; anchors.centerIn: parent; ts: 44; gp: 8; wave: true; ph: root.lPhase }
            // 10 Spark: a four-point star turning and twinkling
            Canvas { id: spark; visible: root.launcherIcon === 10; anchors.fill: parent
              rotation: root.lPhase * 90; scale: 0.9 + 0.1 * Math.sin(root.lPhase * 6.2832)
              onVisibleChanged: if (visible) requestPaint()
              onPaint: {
                var g = getContext("2d"); g.reset()
                g.fillStyle = "" + lnch.c1; g.beginPath(); g.moveTo(96, 14); g.lineTo(112, 80); g.lineTo(178, 96); g.lineTo(112, 112); g.lineTo(96, 178); g.lineTo(80, 112); g.lineTo(14, 96); g.lineTo(80, 80); g.closePath(); g.fill()
                g.fillStyle = "" + lnch.c0; g.beginPath(); g.moveTo(96, 58); g.lineTo(106, 86); g.lineTo(134, 96); g.lineTo(106, 106); g.lineTo(96, 134); g.lineTo(86, 106); g.lineTo(58, 96); g.lineTo(86, 86); g.closePath(); g.fill()
              } }
          }
          // Rubik's Cube launcher: solved with no windows open, scrambles a little more with every window you open.
          Canvas {
            id: cube
            visible: cell.modelData.cls === "__launcher__" && root.launcherIcon === 0
            // Painted once at a fixed size and scaled as a texture, so the hover zoom never repaints it.
            width: 192; height: 192
            anchors.centerIn: parent
            property real pk: 1
            scale: cell.width / 192 * pk
            property int n: root.winCount
            readonly property bool nb: root.skin.n === "Nebula"   // Nebula skin: the cube wears the theme's purples
            onNbChanged: requestPaint()
            onNChanged: { requestPaint(); pop.restart() }
            Component.onCompleted: requestPaint()
            SequentialAnimation {
              id: pop
              NumberAnimation { target: cube; property: "pk"; to: 1.14; duration: 110; easing.type: Easing.OutQuad }
              NumberAnimation { target: cube; property: "pk"; to: 1.0; duration: 220; easing.type: Easing.OutBack }
            }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset()
              var S = Math.min(width, height), u = S * 0.148, cx = width / 2, cy = height / 2 + u * 0.1
              var pal = nb ? ["#E6E1FA", "#B8A2FF", "#8B5CF6", "#CC8CFF", "#6C8CFF", "#5CC8F5"] : ["#f4f4f4", "#ffd500", "#c41e3a", "#ff5a00", "#0b57d0", "#00a152"]   // W Y R O B G
              var solved = [0, 5, 2]                                                          // top white, left green, right red
              var ax = u * 0.866, ay = u * 0.5
              function poly(px, py, v1x, v1y, v2x, v2y, col) {
                ctx.beginPath(); ctx.moveTo(px, py); ctx.lineTo(px + v1x, py + v1y); ctx.lineTo(px + v1x + v2x, py + v1y + v2y); ctx.lineTo(px + v2x, py + v2y); ctx.closePath()
                ctx.fillStyle = col; ctx.fill(); ctx.lineWidth = Math.max(1, S * 0.012); ctx.strokeStyle = nb ? "#120b2b" : "#0d0d0d"; ctx.stroke()
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
          Rectangle {   // plate like the other icons' (skin colours) behind Calendar / Notes
            visible: false
            anchors.centerIn: parent; width: parent.width * 0.98; height: width; radius: width * 0.22
            gradient: Gradient { GradientStop { position: 0; color: Qt.lighter(root.skin.c1, 1.4) } GradientStop { position: 1; color: Qt.lighter(root.skin.c2, 1.4) } }
            border.color: root.omaSkin ? "transparent" : root.skin.b; border.width: root.omaSkin ? 0 : 1
          }
          // Legal Desk's own icons (Calendar, Notes, Tasks, Disks, Zones, Screenshot, Downloads, Trash): the art of the chosen icon set, in the skin's colours.
          Image {
            visible: cell.ownIcon && root.artName(cell.modelData.cls) !== "" && root.artDir !== ""
            anchors.centerIn: parent
            width: parent.width * root.ownK; height: width
            source: visible ? root.artDir + "/" + root.artName(cell.modelData.cls) + ".svg" : ""
            sourceSize: Qt.size(192, 192)
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true
            rotation: cell.twist
          }
          // A View From Space (Radio Globe): the app's bullseye + speaker, drawn once (no animation, no CPU) in the skin's colours
          Canvas {
            id: gb
            visible: cell.modelData.cls === "chrome-127.0.0.1__globe_-Default"
            width: 192; height: 192
            anchors.centerIn: parent
            scale: cell.width / 192
            Component.onCompleted: requestPaint()
            Connections { target: root; function onAccCChanged() { gb.requestPaint() } function onBgCChanged() { gb.requestPaint() } }
            onPaint: {
              var ctx = getContext("2d"); ctx.reset()
              var S = Math.min(width, height), cx = width / 2, cy = height / 2, now = 0
              var c = "" + Qt.lighter(root.accC, 1.45)   // the skin's accent (Nebula: soft violet)
              function rr(x, y, w, h, r) { ctx.beginPath(); ctx.moveTo(x + r, y); ctx.arcTo(x + w, y, x + w, y + h, r); ctx.arcTo(x + w, y + h, x, y + h, r); ctx.arcTo(x, y + h, x, y, r); ctx.arcTo(x, y, x + w, y, r); ctx.closePath() }
              var m = S * 0.03, W = S - 2 * m
              rr(m, m, W, W, W * 0.22); ctx.fillStyle = "" + Qt.darker(root.bgC, 1.2); ctx.fill()
              ctx.save(); rr(m, m, W, W, W * 0.22); ctx.clip()
              ctx.fillStyle = "#ffffff"
              var st = [[.14, .16, 1.2], [.82, .13, 1.4], [.9, .5, 1], [.1, .55, 1], [.18, .86, 1.1], [.86, .88, 1.3]]
              for (var i = 0; i < st.length; i++) { ctx.beginPath(); ctx.arc(st[i][0] * S, st[i][1] * S, st[i][2] * S * 0.007, 0, 6.2832); ctx.fill() }
              // ripples (as on the app's globe): three rings expanding from the speaker
              var R = S * 0.27, tt = 0.12
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
            color: Qt.rgba(root.bgC.r, root.bgC.g, root.bgC.b, 0.92); border.color: root.accC; border.width: 1
            Text { id: lbl; anchors.centerIn: parent; color: root.txtC; font.pixelSize: 12
              text: cell.modelData.cls === "__launcher__" ? "Legal Desk" : cell.modelData.cls === "__calendar__" ? "Calendar" : cell.modelData.cls === "__notes__" ? "Notes" : cell.modelData.cls === "__tasks__" ? "Task Manager" : cell.modelData.cls === "__snap__" ? "Screenshot" : cell.modelData.cls === "__radio__" ? "1UP Radio" : cell.modelData.cls === "__disks__" ? "Disk Management" : cell.modelData.cls === "__zones__" ? "Desk Zones" : cell.modelData.cls === "__trash__" ? (root.trashFull ? "Trash (full)" : "Trash") : cell.modelData.cls === "__folder__" ? "Downloads" : ((root.appmap[cell.modelData.cls] && root.appmap[cell.modelData.cls].name) || cell.modelData.cls.replace(/^chrome-/, "").replace(/-default$/, "")) }
          }
          // ring around the icon whose menu is open
          Rectangle { visible: root.ctx !== "" && root.ctx === cell.modelData.cls; anchors.fill: parent; anchors.margins: -2; radius: width * 0.24; color: "transparent"; border.color: root.accC; border.width: 2 }
          // running dot
          Rectangle {
            visible: cell.modelData.cls !== "__launcher__" && !!root.running[cell.modelData.cls.toLowerCase()]
            width: 4; height: 4; radius: 2
            color: "#dddddd"
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.bottom
            anchors.topMargin: 2
          }
          }
          MouseArea {
            id: cma
            anchors.fill: parent
            cursorShape: cell.dragged ? Qt.ClosedHandCursor : Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            property real px0: 0
            property bool moved: false
            readonly property bool canDrag: (!root.locked || root.moveMode) && !root.fixedCls(cell.modelData.cls)
            function rx(m) { return cma.mapToItem(rowArea, m.x, 0).x }
            onPressed: (m) => { px0 = rx(m); moved = false }
            onPositionChanged: (m) => {
              if (!(pressedButtons & Qt.LeftButton) || !canDrag) return
              var x = rx(m)
              if (!moved && Math.abs(x - px0) > 6) { moved = true; root.mag = 0; root.dragIdx = cell.index; root.dropIdx = cell.index; root.ctx = "" }
              if (moved && root.dragIdx === cell.index) {
                root.dragX = x
                var L0 = (win.width - root.baseTotal) / 2
                root.dropIdx = Math.min(root.items.length - 3, root.nearestIdx(x - L0))
              }
            }
            onReleased: {
              if (root.dragIdx === cell.index) {
                var f = root.dragIdx, t = root.dropIdx, fc = root.items[f].cls
                var ti = root.items.findIndex(i => i.cls === "__trash__"), tw = root.base, tx = (win.width - root.baseTotal) / 2 + (ti >= 0 ? root.restXs[ti] : 0)
                var over = ti >= 0 && fc !== "__trash__" && root.dragX > tx - tw * 0.2 && root.dragX < tx + tw * 1.2
                root.dragIdx = -1
                if (over && root.isSep(fc)) { root.removeAt(f); return }
                if (over && root.isPinned(fc)) { root.sh(["/usr/lib/legal-desk/dock-pin-toggle", fc]); return }
                root.moveTo(f, t)
                root.mag = (hover.hovered && !root.moveMode) ? 1 : 0
                root.pointer(hover.point.position.x)
              }
            }
            onClicked: (m) => {
              if (moved) { moved = false; return }
              if (cell.isSep) { if (root.moveMode && !root.fixedCls(cell.modelData.cls)) root.removeAt(cell.index); return }
              if (cell.modelData.cls === "__launcher__") { if (root.rubik) twistAnim.restart(); root.ctx = ""; root.activate("__launcher__"); return }
              if (m.button === Qt.LeftButton) { if (root.rubik) twistAnim.restart(); root.ctx = ""; root.closeMain(); root.activate(cell.modelData.cls) }
              else if (m.button === Qt.MiddleButton) { root.sh(["/usr/lib/legal-desk/dock-pin-toggle", cell.modelData.cls]) }
              else { root.ctxX = cell.mapToItem(null, cell.width / 2, 0).x; root.ctx = cell.modelData.cls }
            }
          }
        }
      }
    }
  }

  // Right-click menu on an icon: open windows, New window, Pin/Unpin, Close.
  IpcHandler { target: "macdockact"; function activate(cls: string): void { root.activate(cls) } }
  IpcHandler { target: "macdock"; function closeMenu(): void { root.ctx = "" } function menu(cls: string): void { root.ctxX = 800; root.ctx = cls } function moveMode(on: bool): void { root.moveMode = on; root.ctx = ""; root.mag = 0 } }
  property string ctx: ""
  // Opening a right-click menu, or clicking any icon, closes the grid-button menu if it is open.
  function closeMain() { sh([Quickshell.env("HOME") + "/.local/bin/dock-menu-close", "main"]) }
  property real ctxX: 0
  property var ctxWins: []
  onCtxChanged: { ctxWins = []; if (ctx !== "") { closeMain(); winsProc.cls = ctx; winsProc.running = false; winsProc.running = true } }
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
    if (ctx === "__trash__") return [{ l: "Trash", a: "hdr" }, { l: "Open trash", a: "open" }, { l: "Empty trash", a: "empty" }, { l: "Cancel", a: "cancel" }]
    if (ctx === "__folder__") return [{ l: "Downloads", a: "hdr" }, { l: "Open folder", a: "open" }, { l: "Cancel", a: "cancel" }]
    if (ctx === "__calendar__" || ctx === "__notes__" || ctx === "__tasks__" || ctx === "__disks__" || ctx === "__zones__") return [{ l: ctx === "__zones__" ? "Desk Zones" : ctx === "__calendar__" ? "Calendar" : ctx === "__notes__" ? "Notes" : ctx === "__disks__" ? "Disk Management" : "Task Manager", a: "hdr" }, { l: "Open", a: "open" }, { l: "Remove from dock", a: "unown" }, { l: "Cancel", a: "cancel" }]
    if (ctx === "__radio__") return [{ l: "1UP Radio", a: "hdr" }, { l: "Play / Pause", a: "open" }, { l: "Live (jump to now)", a: "rlive" }, { l: "Stop", a: "rstop" }, { l: "Remove from dock", a: "unown" }, { l: "Cancel", a: "cancel" }]
    if (ctx === "settings") return [{ l: "Settings", a: "hdr" }, { l: "Open settings", a: "open" }, { l: "Task manager", a: "tasks" }, { l: "Cancel", a: "cancel" }]
    if (ctx === "__snap__") return [{ l: "Screenshot", a: "hdr" }, { l: "Take screenshot", a: "open" }, { l: "Cancel", a: "cancel" }]
    var w = ctxWins
    rows.push({ l: ((appmap[ctx] && appmap[ctx].name) || ctx.replace(/^chrome-/, "").replace(/-Default$/, "")) + (w.length > 0 ? "  ·  " + w.length : ""), a: "hdr" })
    for (var i = 0; i < w.length && i < 6; i++) rows.push({ l: " " + (w[i].t.length > 20 ? w[i].t.substring(0, 19) + "…" : (w[i].t || "(untitled)")), a: "focus", addr: w[i].a })
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
      margins { bottom: root.menuLine; left: Math.max(4, (win.screen.width - win.width) / 2 + root.ctxX - 80) }
      implicitWidth: 160; implicitHeight: rows.length * 22 + 14
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "macdockmenu"
      Rectangle {
        anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; bottomMargin: 6 }
        radius: 7; color: root.bgC; border.color: root.accC; border.width: 1
        Rectangle { width: 10; height: 10; rotation: 45; x: parent.width / 2 - 5; y: parent.height - 9; color: root.bgC; border.color: root.accC; border.width: 1; z: -1 }
        Column {
          anchors.fill: parent; anchors.margins: 4; spacing: 0
          Repeater {
            model: pm.rows
            Rectangle {
              required property var modelData
              width: parent.width; height: 22; radius: 4
              color: modelData.a === "hdr" ? root.selC : ((ma.containsMouse) ? root.selC : "transparent")
              Image { visible: modelData.a === "hdr"; x: 4; width: 14; height: 14; anchors.verticalCenter: parent.verticalCenter; source: root.iconFor(root.ctx); sourceSize: Qt.size(32, 32); fillMode: Image.PreserveAspectFit }
              Text {
                x: modelData.a === "hdr" ? 22 : 7; width: parent.width - (modelData.a === "hdr" ? 28 : 12); elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter
                text: modelData.a === "hdr" ? "●  " + root.cap2(modelData.l) : (modelData.a === "focus" ? modelData.l : root.cap2(modelData.l))
                color: modelData.a === "hdr" ? root.txtC : root.txtC; font.pixelSize: 10
                font.bold: modelData.a === "hdr"
              }
              MouseArea {
                id: ma; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  var c = root.ctx, act = modelData.a, addr = modelData.addr
                  if (act === "hdr") return
                  if (act === "open") root.activate(c)
                  else if (act === "tasks") root.sh(["/usr/lib/legal-desk/legal-tasks"])
                  else if (act === "rlive") root.sh(["/usr/lib/legal-desk/legal-radio", "live"])
                  else if (act === "rstop") root.sh(["/usr/lib/legal-desk/legal-radio", "stop"])
                  else if (act === "unown") root.sh(["/usr/lib/legal-desk/dock-own-toggle", c])
                  else if (act === "empty") root.sh(["gio", "trash", "--empty"])
                  else if (act === "pin") root.sh(["/usr/lib/legal-desk/dock-pin-toggle", c])
                  else if (act === "close") root.sh(["/usr/lib/legal-desk/dock-close-app", c])
                  else if (act === "focus") root.sh(["hyprctl", "dispatch", "hl.dsp.focus({window='address:" + addr + "'})"])
                  else if (act === "incog") root.launch(["/usr/lib/legal-desk/browser-incognito", c])
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
