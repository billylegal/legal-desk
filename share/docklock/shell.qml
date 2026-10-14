import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Small lock/unlock button just right of the dock. Locked = icons can't be rearranged.
ShellRoot {
  id: ldr
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
    onLoaded: { var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*"(#[0-9a-fA-F]{6})"/); if (m) c[m[1]] = m[2] }); ldr.oc = c }
  }
  Timer { interval: 3000; running: true; repeat: true; onTriggered: omaFile.reload() }
  // Menu colours follow the chosen dock skin (~/.cache/dock-menu-colors, written by macdock-skin); default = Nebula.
  property color pBg: "#0B0818"
  property color pAcc: "#8B5CF6"
  property color pTxt: "#E6E1FA"
  property color pSel: "#2A1B52"
  // The Omarchy skin's menus use Omarchy's original colours (the Tokyo Night theme it installs with), so everyone can tell it is the original look.
  readonly property bool omaSkin: skinNames[skinIdx] === "Omarchy"
  readonly property color bgC: omaSkin ? "#1a1b26" : pBg
  readonly property color accC: omaSkin ? "#7aa2f7" : pAcc
  readonly property color txtC: omaSkin ? "#c0caf5" : pTxt
  readonly property color selC: omaSkin ? "#292e42" : pSel
  readonly property color hiC: Qt.lighter(selC, 1.6)
  FileView {
    id: themeColors
    path: Quickshell.env("HOME") + "/.cache/dock-menu-colors"
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      var c = {}; text().split("\n").forEach(function (l) { var m = l.match(/^\s*(\w+)\s*=\s*(#[0-9a-fA-F]{6})/); if (m) c[m[1]] = m[2] })
      if (c.bg) ldr.pBg = c.bg
      if (c.acc) ldr.pAcc = c.acc
      if (c.txt) ldr.pTxt = c.txt
      if (c.sel) ldr.pSel = c.sel
    }
  }
  property var dock: null
  property bool locked: false
  property bool hidden: false
  property bool transparent: false
  property bool menuOpen: false
  property bool mac: false
  property bool rubik: false
  property int sizePx: 46
  property real zoomRaw: 0
  property real launcherX: 0
  property real menuLine: 0
  property string skinTxt: "auto"
  property bool dragging: false
  readonly property real zoomEff: zoomRaw >= 1 ? zoomRaw : (sizePx >= 56 ? 2.3 : (sizePx <= 36 ? 2.8 : 2.5))
  readonly property var skinNames: rubik ? ["Cube", "Pastel", "Mono", "Neon", "Sunset", "Ocean", "Candy", "Jungle", "Circles", "Nebula", "Omarchy"]
    : (mac ? ["Emerald", "Glass", "Midnight", "Neon", "Aluminum", "Aqua", "Sunset", "Mono", "Paper", "Terminal", "Amber", "Blueprint", "Bubbles", "Pearls", "Windows 95", "Windows 98", "Windows 11", "Polybar", "Tint2", "Nebula", "Omarchy"]
           : ["Emerald", "Midnight", "Glass", "Mono", "Neon", "Aluminum", "Sunset", "Paper", "Windows 95", "Windows 98", "Windows 11", "Polybar", "Tint2", "Nebula", "Omarchy"])
  readonly property int skinIdx: { var n = parseInt(skinTxt); return (isNaN(n) || n < 0 || n >= skinNames.length) ? skinNames.indexOf("Nebula") : n }
  readonly property int menuH: 15 * 36 + 12
  function presetOn(k) { return Math.round(sizePx) === (k === "small" ? 34 : (k === "large" ? 58 : 46)) }
  // The menu is placed once when it opens and then stays put, so resizing the dock with the sliders can't push it around.
  property real frozenLeft: 0
  property real frozenTop: 0
  onMenuOpenChanged: if (menuOpen) { runner2.cmd = ["/usr/lib/legal-dock/dock-menu-close", "ctx"]; runner2.running = false; runner2.running = true; placeMenu(); wallProc.a = "name"; wallProc.running = false; wallProc.running = true }
  function screenH(mon) { var sc = Quickshell.screens.find(s => s.name === mon); return sc ? sc.height : 1080 }
  function placeMenu() {
    if (!lastDock) return
    var d = lastDock
    // centred over the last icon (the launcher): measured by the Mac dock itself, or the right end of the classic dock
    var cx = (mac && launcherX > 0) ? launcherX : d.x + d.w - cpitch / 2
    frozenLeft = Math.max(4, Math.min((d.mon && Quickshell.screens.find(s => s.name === d.mon) ? Quickshell.screens.find(s => s.name === d.mon).width : 1920) - 210, cx - 100))
    frozenTop = (mac && menuLine > 0) ? screenH(d.mon) - menuLine - menuH : d.y - menuH - 10
  }
  Timer { id: dragT; interval: 1500; onTriggered: dragging = false }
  Timer { id: writeT; interval: 50; onTriggered: { sizeW.running = false; sizeW.running = true; zoomW.running = false; zoomW.running = true } }
  Process { id: sizeW; command: ["bash", "-c", "echo \"$0\" > \"$HOME/.cache/dock-size\"", String(sizePx)] }
  Process { id: zoomW; command: ["bash", "-c", "echo \"$0\" > \"$HOME/.cache/dock-zoom\"", String(zoomRaw)] }
  Process { id: runner2; property var cmd: []; command: cmd }
  property int iconIdx: 0
  readonly property var iconNames: ["With skin", "Emerald", "Glass", "Midnight", "Neon", "Aluminum", "Aqua", "Sunset", "Mono", "Paper", "Terminal", "Amber", "Blueprint", "Bubbles", "Pearls", "Windows 95", "Windows 98", "Windows 11", "Polybar", "Tint2", "Nebula", "Omarchy", "Cube", "Pastel", "Ocean", "Candy", "Jungle", "Circles"]
  FileView {
    id: icoFile
    path: Quickshell.env("HOME") + "/.cache/dock-icon-style"
    printErrors: false
    onLoaded: { var n = parseInt(text()); ldr.iconIdx = (isNaN(n) || n < 0 || n >= ldr.iconNames.length) ? 0 : n }
    onLoadFailed: ldr.iconIdx = 0
  }
  Timer { interval: 1000; running: true; repeat: true; onTriggered: icoFile.reload() }
  Process { id: iconProc; property string a: "next"; command: ["/usr/lib/legal-dock/dock-icon-style", a]; onExited: icoFile.reload() }
  property string wallTxt: ""
  Process { id: wallProc; property string a: "name"; command: ["/usr/lib/legal-dock/dock-wallpaper", a]
    stdout: StdioCollector { onStreamFinished: wallTxt = text.trim() } }
  Process { id: skinProc; property string a: "next"; command: ["/usr/lib/legal-dock/macdock-skin", a]; onExited: poll.running = true }
  component SliderRow: Rectangle {
    id: sr
    property string label: ""
    property real from: 0
    property real to: 1
    property real value: 0
    property string shown: ""
    property color txtC: "#C1C497"
    property color accC: "#C1C497"
    property color selC: "#2a3a30"
    property color bgC: "#111c18"
    signal moved(real v)
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))
    height: 34; radius: 6; color: "transparent"
    Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: sr.label; color: sr.txtC; font.pixelSize: 12; width: 36 }
    Rectangle {
      id: trk; x: 50; width: sr.width - 50 - 54; height: 4; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: sr.selC
      Rectangle { width: parent.width * sr.frac; height: parent.height; radius: 2; color: sr.accC }
      Rectangle { x: parent.width * sr.frac - 7; y: -5; width: 14; height: 14; radius: 7; color: sr.accC; border.color: sr.bgC; border.width: 2 }
    }
    Text { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: 44; horizontalAlignment: Text.AlignRight; text: sr.shown; color: sr.txtC; font.pixelSize: 11 }
    MouseArea {
      x: trk.x - 8; width: trk.width + 16; height: parent.height
      function set(mx) { sr.moved(sr.from + Math.max(0, Math.min(1, (mx - 8) / trk.width)) * (sr.to - sr.from)) }
      onPressed: (m) => set(m.x)
      onPositionChanged: (m) => { if (pressed) set(m.x) }
    }
  }
  property bool full: false
  property string iconSize: "medium"
  property string dockJson: ""
  property var lastDock: null
  property int pinCount: 0
  // Every second word of a menu label gets a capital: "Lock dock" -> "Lock Dock".
  function cap2(s) { var w = String(s).split(" "); for (var i = 1; i < w.length; i += 2) if (w[i].length) w[i] = w[i].charAt(0).toUpperCase() + w[i].slice(1); return w.join(" ") }
  Timer { id: menuT; interval: 8000; running: menuOpen; repeat: false; onTriggered: menuOpen = false }
  IpcHandler { target: "dockmenu"; function toggle(): void { menuOpen = !menuOpen } function close(): void { menuOpen = false; mouseOpen = false } function mouse(): void { openMouse() } function moveDone(): void { endMove() } }
  readonly property int cpitch: iconSize === "small" ? 40 : (iconSize === "large" ? 69 : 53)

  Process {
    id: poll
    command: ["python3", "-c", `
import json, subprocess, os
d = json.loads(subprocess.run(["hyprctl","layers","-j"],capture_output=True,text=True).stdout or "{}")
out = None
for mon, v in d.items():
    for arr in v.get("levels", {}).values():
        for e in arr:
            if e["namespace"] == "nwg-dock": out = {"mon": mon, "x": e["x"], "y": e["y"], "w": e["w"], "h": e["h"]}
mac = os.path.exists(os.path.expanduser("~/.cache/dock-mac"))
def _rd(n, dflt=""):
    try: return open(os.path.expanduser("~/.cache/" + n)).read().strip()
    except Exception: return dflt
_s = _rd("dock-size", "medium")
px = max(24, min(110, int(_s) if _s.isdigit() else {"small": 34, "large": 58}.get(_s, 46)))
if out is None and mac:
    sz = open(os.path.expanduser("~/.cache/dock-size")).read().strip() if os.path.exists(os.path.expanduser("~/.cache/dock-size")) else "medium"
    base = px
    for mon, v in d.items():
        for arr in v.get("levels", {}).values():
            for e in arr:
                if e["namespace"] == "macdock":
                    cnt = max(1, round((e["w"] - 40 - base * 0.9 * 2.4) / (base + 8)))
                    w = cnt * (base + 8); h = base + 16
                    out = {"mon": mon, "x": e["x"] + e["w"] // 2 - w // 2, "y": e["y"] + e["h"] - h - 4, "w": w, "h": h}
                    if os.path.exists(os.path.expanduser("~/.cache/dock-full")):
                        sw = max([b["w"] for b in v.get("levels", {}).get("0", [])] or [1920])
                        out["x"] = 0; out["w"] = sw
ss = "org.omarchy.screensaver" in subprocess.run(["hyprctl","clients","-j"],capture_output=True,text=True).stdout
if ss: out = None
n=len([x for x in open(os.path.expanduser("~/.cache/nwg-dock-pinned")).read().split(chr(10)) if x.strip()])
_rk = os.path.exists(os.path.expanduser("~/.cache/dock-mac")) and _rd("dock-style") == "rubik"
print(json.dumps({"px": px, "zoom": _rd("dock-zoom", "0"), "lx": float((_rd("dock-launcher", "0") or "0").split()[0]), "ly": float(((_rd("dock-launcher", "0") or "0").split() + ["0"])[1]), "skin": _rd("dock-skin-" + ("classic" if not mac else ("rubik" if _rk else "mac")), "0"), "transparent": "background: transparent" in open(os.path.expanduser("~/.config/nwg-dock-hyprland/style.css")).read(), "hidden": (not ss) and os.path.exists(os.path.expanduser("~/.cache/dock-hidden")), "dock": out, "n": n, "mac": mac, "rubik": os.path.exists(os.path.expanduser("~/.cache/dock-mac")) and open(os.path.expanduser("~/.cache/dock-style")).read().strip() == "rubik" if os.path.exists(os.path.expanduser("~/.cache/dock-style")) else False, "locked": os.path.exists(os.path.expanduser("~/.cache/dock-locked")), "full": os.path.exists(os.path.expanduser("~/.cache/dock-full")), "size": (open(os.path.expanduser("~/.cache/dock-size")).read().strip() if os.path.exists(os.path.expanduser("~/.cache/dock-size")) else "medium")}))
`]
    stdout: StdioCollector {
      onStreamFinished: { try { var r = JSON.parse(text); var nd = JSON.stringify(r.dock); if (nd !== dockJson) { dockJson = nd; dock = r.dock; if (r.dock) lastDock = r.dock }; locked = r.locked; mac = r.mac; if (!dragging) { sizePx = r.px; zoomRaw = parseFloat(r.zoom) || 0 }; launcherX = r.lx; menuLine = r.ly; skinTxt = r.skin; rubik = r.rubik; full = r.full; iconSize = r.size; hidden = r.hidden; transparent = r.transparent; pinCount = r.n } catch (e) { } }
    }
  }
  Timer { interval: 3000; running: true; repeat: true; triggeredOnStart: true; onTriggered: if (!poll.running) poll.running = true }
  Process { id: mover; property int a: 0; property int b: 0
    command: ["/usr/lib/legal-dock/dock-move-pin", String(a), String(b)] }
  Process { id: toggle; command: ["/usr/lib/legal-dock/dock-lock-toggle"]; onExited: poll.running = true }

  // Edit mode (unlocked): drag an icon sideways and let go to move it.
  Variants {
    model: dock && !locked && !mac ? [dock] : []
    PanelWindow {
      id: ov
      required property var modelData
      screen: Quickshell.screens.find(s => s.name === modelData.mon) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { left: modelData.x + gpad; top: modelData.y }
      implicitWidth: pinCount * pitch; implicitHeight: modelData.h
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "dockedit"

      property real pitch: Math.max(24, modelData.w / (pinCount + 1))
      property int gpad: 0
      property int pad: 0
      property int fromSlot: -1
      property int toSlot: -1
      function slotAt(x) { return Math.max(0, Math.min(pinCount - 1, Math.floor((x - pad) / pitch))) }

      Rectangle { anchors.fill: parent; radius: 10; color: "#10E0A040"; border.color: "#E0A040"; border.width: 1 }
      // highlight of the icon being dragged
      Rectangle {
        visible: ov.fromSlot >= 0
        x: ov.pad + ov.fromSlot * ov.pitch; y: 4; width: ov.pitch; height: parent.height - 8; radius: 6
        color: "#40E0A040"
      }
      // drop marker
      Rectangle {
        visible: ov.fromSlot >= 0 && ov.toSlot !== ov.fromSlot
        x: ov.pad + ov.toSlot * ov.pitch + (ov.toSlot > ov.fromSlot ? ov.pitch - 2 : 0); y: 4; width: 3; height: parent.height - 8
        color: "#E0A040"
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: ov.fromSlot >= 0 ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        onPressed: (m) => { ov.fromSlot = ov.slotAt(m.x); ov.toSlot = ov.fromSlot }
        onPositionChanged: (m) => { if (ov.fromSlot >= 0) ov.toSlot = ov.slotAt(m.x) }
        onReleased: {
          if (ov.fromSlot >= 0 && ov.toSlot !== ov.fromSlot) { mover.a = ov.fromSlot; mover.b = ov.toSlot; mover.running = true }
          ov.fromSlot = -1; ov.toSlot = -1
        }
      }
    }
  }

  // ---- Mouse pointer panel: speed, scroll direction, left-handed buttons, acceleration (dock-mouse) ----
  property bool mouseOpen: false
  property real mSpeed: 0
  property bool mNatural: false
  property bool mLeft: false
  property bool mFlat: false
  readonly property int mouseH: 262
  function openMouse() { if (!menuOpen) placeMenu(); mouseTop = (mac && menuLine > 0 && lastDock) ? screenH(lastDock.mon) - menuLine - mouseH : (lastDock ? lastDock.y : 600) - mouseH - 10; mouseProc.running = false; mouseProc.running = true; mouseOpen = true; mouseT.restart() }
  property real mouseTop: 400
  Timer { id: mouseT; interval: 20000; onTriggered: mouseOpen = false }
  Process {
    id: mouseProc
    command: ["/usr/lib/legal-dock/dock-mouse", "show"]
    stdout: StdioCollector { onStreamFinished: { try { var r = JSON.parse(text); mSpeed = r.speed; mNatural = r.natural; mLeft = r.left; mFlat = r.flat } catch (e) { } } }
  }
  Process { id: mouseSet; property var a: []; command: ["/usr/lib/legal-dock/dock-mouse"].concat(a) }
  function mset(args) { mouseT.restart(); mouseSet.running = false; mouseSet.a = args; mouseSet.running = true }
  Process { id: mouseBoot; command: ["/usr/lib/legal-dock/dock-mouse", "apply"]; running: true }
  Variants {
    model: lastDock && mouseOpen ? [lastDock.mon] : []
    PanelWindow {
      required property var modelData
      screen: Quickshell.screens.find(s => s.name === modelData) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { left: Math.max(4, frozenLeft - 10); top: mouseTop }
      implicitWidth: 220; implicitHeight: mouseH
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "dockmouse"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
      Rectangle {
        anchors.fill: parent; radius: 10; color: bgC; border.color: accC; border.width: 1
        focus: true
        Keys.onEscapePressed: mouseOpen = false
        Column {
          anchors.fill: parent; anchors.margins: 6; spacing: 2
          Text { height: 24; width: parent.width; text: "\uf245   Mouse Pointer"; color: accC; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 13; font.bold: true; verticalAlignment: Text.AlignVCenter; leftPadding: 6 }
          SliderRow {
            txtC: ldr.txtC; accC: ldr.accC; selC: ldr.selC; bgC: ldr.bgC
            width: parent.width; label: "Speed"; from: -1; to: 1; value: mSpeed; shown: (mSpeed > 0 ? "+" : "") + mSpeed.toFixed(2)
            onMoved: (v) => { mSpeed = Math.round(v * 20) / 20; mouseT.restart(); speedT.restart() }
          }
          Timer { id: speedT; interval: 120; onTriggered: mset(["speed", String(mSpeed)]) }
          Repeater {
            model: [
              { l: "Scroll: Natural", l2: "Scroll: Traditional", k: "natural" },
              { l: "Left-Handed Buttons", l2: "Right-Handed Buttons", k: "left" },
              { l: "Acceleration: Flat", l2: "Acceleration: Adaptive", k: "flat" }
            ]
            Rectangle {
              required property var modelData
              readonly property bool on: modelData.k === "natural" ? mNatural : (modelData.k === "left" ? mLeft : mFlat)
              width: parent.width; height: 34; radius: 6
              color: mta.containsMouse ? selC : "transparent"
              Text { x: 10; anchors.verticalCenter: parent.verticalCenter; color: txtC; font.pixelSize: 13; text: parent.on ? cap2(modelData.l) : cap2(modelData.l2) }
              Text { anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; color: accC; font.pixelSize: 11; text: "\u21c4" }
              MouseArea {
                id: mta; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  var v = !parent.on
                  if (modelData.k === "natural") mNatural = v; else if (modelData.k === "left") mLeft = v; else mFlat = v
                  mset([modelData.k, v ? "on" : "off"])
                }
              }
            }
          }
          Rectangle {
            width: parent.width; height: 34; radius: 6; color: mra.containsMouse ? selC : "transparent"
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Reset To Default"; color: txtC; font.pixelSize: 13 }
            MouseArea { id: mra; anchors.fill: parent; hoverEnabled: true; onClicked: { mSpeed = 0; mNatural = false; mLeft = false; mFlat = false; mset(["reset"]) } }
          }
          Rectangle {
            width: parent.width; height: 34; radius: 6; color: mca.containsMouse ? selC : "transparent"
            Text { x: 10; anchors.verticalCenter: parent.verticalCenter; text: "Close"; color: txtC; font.pixelSize: 13 }
            MouseArea { id: mca; anchors.fill: parent; hoverEnabled: true; onClicked: mouseOpen = false }
          }
        }
      }
    }
  }

  // ---- Move Icons: unlock the order while moving, put the lock back when done ----
  property bool moving: false
  property bool wasLocked: false
  function startMove() { wasLocked = locked; if (locked) toggle.running = true; moving = true; if (mac) moveIpc("true") }
  function endMove() { if (!moving) return; moving = false; if (wasLocked) toggle.running = true; if (mac) moveIpc("false") }
  function moveIpc(v) { mvProc.running = false; mvProc.v = v; mvProc.running = true }
  Process { id: mvProc; property string v: "true"; command: ["quickshell", "-p", Quickshell.env("HOME") + "/.config/macdock", "ipc", "call", "macdock", "moveMode", v] }
  Process { id: hideToggle; command: ["/usr/lib/legal-dock/dock-hide-toggle"]; onExited: poll.running = true }
  Process { id: sizer; property string which: "medium"; command: ["/usr/lib/legal-dock/dock-size-set", which]; onExited: poll.running = true }
  Process { id: styler; property string which: "off"; command: ["/usr/lib/legal-dock/macdock-toggle", which]; onExited: poll.running = true }
  Process { id: appsProc; command: ["/usr/lib/legal-dock/drawer-only"] }
  Process { id: fullToggle; command: ["/usr/lib/legal-dock/dock-full-toggle"]; onExited: poll.running = true }
  // Restart / Shut down always ask first ("Do you really want to ...?"), popup centered on screen.
  Process { id: rebootProc; command: ["/usr/lib/legal-dock/reboot-confirm", "reboot", "center"] }
  Process { id: shutdownProc; command: ["/usr/lib/legal-dock/reboot-confirm", "shutdown", "center"] }
  Process { id: transToggle; command: ["/usr/lib/legal-dock/dock-transparent-toggle"]; onExited: poll.running = true }

  // One gear button at the right end of the dock; opens a small menu above it.
  Variants {
    model: []
    PanelWindow {
      required property var modelData
      screen: Quickshell.screens.find(s => s.name === modelData.mon) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { left: full ? modelData.x + modelData.w - 30 : modelData.x + modelData.w + 6; top: full ? modelData.y - 26 : modelData.y + modelData.h / 2 - 11 }
      implicitWidth: 22; implicitHeight: 22
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "dockgear"

      Rectangle {
        anchors.fill: parent; radius: 11
        color: gma.containsMouse || menuOpen ? selC : bgC
        border.color: accC; border.width: 1
        Text {
          anchors.centerIn: parent
          text: "\uf013"
          color: txtC
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
        }
        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onClicked: menuOpen = !menuOpen }
      }
    }
  }

  Variants {
    model: lastDock && menuOpen ? [lastDock.mon] : []
    PanelWindow {
      required property var modelData
      screen: Quickshell.screens.find(s => s.name === modelData) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { left: frozenLeft; top: frozenTop }
      implicitWidth: 200; implicitHeight: menuH
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "dockmenu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

      Rectangle {
        anchors.fill: parent; radius: 10
        color: bgC; border.color: accC; border.width: 1
        focus: true
        Keys.onEscapePressed: menuOpen = false
        Column {
          anchors.fill: parent; anchors.margins: 6; spacing: 2
          Repeater {
            model: [
              { label: "All apps", icon: "\uf00a", act: "apps" },
              { label: locked ? "Unlock dock" : "Lock dock", icon: locked ? "\uf09c" : "\uf023", act: "lock" },
              { label: moving ? "Done Moving" : "Move Icons", icon: "\uf0b2", act: "move" },
              { label: hidden ? "Keep dock up" : "Hide dock", icon: hidden ? "\uf077" : "\uf078", act: "hide" },
              { label: transparent ? "Solid dock" : "Transparent dock", icon: "\uf1fc", act: "trans" },
              { label: full ? "Floating dock" : "Full-width dock", icon: "\uf337", act: "full" },
              { label: "Mouse", icon: "\uf245", act: "mouse" },
              { label: "Reboot", icon: "\uf01e", act: "reboot" },
              { label: "Shut down", icon: "\uf011", act: "shutdown" },
              { label: "Close menu", icon: "\uf00d", act: "close" }
            ].filter(i => !mac || i.act === "close" || i.act === "move" || i.act === "mouse" || i.act === "trans" || i.act === "lock" || i.act === "apps" || i.act === "reboot" || i.act === "shutdown")
            Rectangle {
              required property var modelData
              width: parent.width; height: 34; radius: 6
              color: ima.containsMouse ? selC : "transparent"
              Row {
                anchors.verticalCenter: parent.verticalCenter; x: 10; spacing: 10
                Text { text: modelData.icon; color: txtC; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; width: 18 }
                Text { text: cap2(modelData.label); color: txtC; font.pixelSize: 13 }
              }
              MouseArea {
                id: ima; anchors.fill: parent; hoverEnabled: true
                onClicked: {
                  menuOpen = false
                  if (modelData.act === "apps") appsProc.running = true
                  else if (modelData.act === "lock") toggle.running = true
                  else if (modelData.act === "hide") hideToggle.running = true
                  else if (modelData.act === "full") fullToggle.running = true
                  else if (modelData.act === "trans") transToggle.running = true
                  else if (modelData.act === "mouse") openMouse()
                  else if (modelData.act === "move") { if (moving) endMove(); else startMove() }
                  else if (modelData.act === "reboot") rebootProc.running = true
                  else if (modelData.act === "shutdown") shutdownProc.running = true
                }
              }
            }
          }
          Row {
            width: parent.width; height: 34; spacing: 4
            Repeater {
              model: [ { l: "Classic", k: "off" }, { l: "Mac", k: "on" }, { l: "Rubik", k: "rubik" } ]
              Rectangle {
                required property var modelData
                width: (parent.width - 8) / 3; height: 34; radius: 6
                color: (modelData.k === "off" ? !mac : (modelData.k === "on" ? (mac && !rubik) : (mac && rubik))) ? hiC : (sta.containsMouse ? selC : "transparent")
                border.color: accC; border.width: (modelData.k === "off" ? !mac : (modelData.k === "on" ? (mac && !rubik) : (mac && rubik))) ? 1 : 0
                Text { anchors.centerIn: parent; text: modelData.l; color: txtC; font.pixelSize: 12 }
                MouseArea {
                  id: sta; anchors.fill: parent; hoverEnabled: true
                  onClicked: { menuOpen = false; styler.which = modelData.k; styler.running = true }
                }
              }
            }
          }
          Row {
            width: parent.width; height: 34; spacing: 4
            Repeater {
              model: [ { l: "Small", k: "small" }, { l: "Medium", k: "medium" }, { l: "Large", k: "large" } ]
              Rectangle {
                required property var modelData
                width: (parent.width - 8) / 3; height: 34; radius: 6
                color: presetOn(modelData.k) ? hiC : (sma.containsMouse ? selC : "transparent")
                border.color: accC; border.width: presetOn(modelData.k) ? 1 : 0
                Text { anchors.centerIn: parent; text: modelData.l; color: txtC; font.pixelSize: 12 }
                MouseArea {
                  id: sma; anchors.fill: parent; hoverEnabled: true
                  onClicked: { if (mac) menuT.restart(); else menuOpen = false; sizer.which = modelData.k; sizer.running = true }
                }
              }
            }
          }
          SliderRow {
            txtC: ldr.txtC; accC: ldr.accC; selC: ldr.selC; bgC: ldr.bgC
            visible: mac; width: parent.width; label: "Size"; from: 28; to: 96; value: sizePx; shown: Math.round(sizePx) + "px"
            onMoved: (v) => { dragging = true; dragT.restart(); menuT.restart(); sizePx = Math.round(v); writeT.restart() }
          }
          SliderRow {
            txtC: ldr.txtC; accC: ldr.accC; selC: ldr.selC; bgC: ldr.bgC
            visible: mac; width: parent.width; label: "Zoom"; from: 1.0; to: 3.2; value: zoomEff; shown: zoomEff < 1.03 ? "off" : zoomEff.toFixed(2) + "x"
            onMoved: (v) => { dragging = true; dragT.restart(); menuT.restart(); zoomRaw = Math.round(v * 20) / 20; if (zoomRaw < 1.03) zoomRaw = 1.0; writeT.restart() }
          }
          Row {
            width: parent.width; height: 34; spacing: 4
            Rectangle { width: 34; height: 34; radius: 6; color: spa.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u2039"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: spa; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); skinProc.a = "prev"; skinProc.running = false; skinProc.running = true } } }
            Rectangle { width: parent.width - 76; height: 34; radius: 6; color: "transparent"; border.color: accC; border.width: 1
              Text { anchors.centerIn: parent; text: "Skin: " + skinNames[skinIdx]; color: txtC; font.pixelSize: 12 } }
            Rectangle { width: 34; height: 34; radius: 6; color: sna.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u203a"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: sna; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); skinProc.a = "next"; skinProc.running = false; skinProc.running = true } } }
          }
          Row {
            visible: mac
            width: parent.width; height: mac ? 34 : 0; spacing: 4
            Rectangle { width: 34; height: 34; radius: 6; color: ipa.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u2039"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: ipa; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); iconProc.a = "prev"; iconProc.running = false; iconProc.running = true } } }
            Rectangle { width: parent.width - 76; height: 34; radius: 6; color: "transparent"; border.color: accC; border.width: 1
              Row { anchors.centerIn: parent; spacing: 8
                Grid { anchors.verticalCenter: parent.verticalCenter; columns: 2; spacing: 2
                  Repeater { model: ["#ef5350", "#66bb6a", "#42a5f5", "#ffa726"]
                    Rectangle { required property string modelData; width: 7; height: 7; radius: 2; color: modelData } } }
                Text { text: "Icons: " + iconNames[iconIdx]; color: txtC; font.pixelSize: 12 } } }
            Rectangle { width: 34; height: 34; radius: 6; color: ina.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u203a"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: ina; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); iconProc.a = "next"; iconProc.running = false; iconProc.running = true } } }
          }
          Row {
            visible: wallTxt !== "" && wallTxt.indexOf("0/0") !== 0
            width: parent.width; height: wallTxt !== "" && wallTxt.indexOf("0/0") !== 0 ? 34 : 0; spacing: 4
            Rectangle { width: 34; height: 34; radius: 6; color: wpa.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u2039"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: wpa; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); wallProc.a = "prev"; wallProc.running = false; wallProc.running = true } } }
            Rectangle { width: parent.width - 76; height: 34; radius: 6; color: "transparent"; border.color: accC; border.width: 1
              Text { anchors.centerIn: parent; width: parent.width - 8; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; text: "Wallpaper " + (wallTxt.split(" ")[0] || "..."); color: txtC; font.pixelSize: 12 } }
            Rectangle { width: 34; height: 34; radius: 6; color: wna.containsMouse ? selC : "transparent"
              Text { anchors.centerIn: parent; text: "\u203a"; color: txtC; font.pixelSize: 20 }
              MouseArea { id: wna; anchors.fill: parent; hoverEnabled: true; onClicked: { menuT.restart(); wallProc.a = "next"; wallProc.running = false; wallProc.running = true } } }
          }
        }
      }
    }
  }
}
