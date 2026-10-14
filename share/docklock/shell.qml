import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

// Small lock/unlock button just right of the dock. Locked = icons can't be rearranged.
ShellRoot {
  property var dock: null
  property bool locked: false
  property bool hidden: false
  property bool transparent: false
  property bool menuOpen: false
  property bool mac: false
  property bool full: false
  property string iconSize: "medium"
  property string dockJson: ""
  property var lastDock: null
  property int pinCount: 0
  // Every second word of a menu label gets a capital: "Lock dock" -> "Lock Dock".
  function cap2(s) { var w = String(s).split(" "); for (var i = 1; i < w.length; i += 2) if (w[i].length) w[i] = w[i].charAt(0).toUpperCase() + w[i].slice(1); return w.join(" ") }
  Timer { interval: 8000; running: menuOpen; repeat: false; onTriggered: menuOpen = false }
  IpcHandler { target: "dockmenu"; function toggle(): void { menuOpen = !menuOpen } }
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
if out is None and mac:
    sz = open(os.path.expanduser("~/.cache/dock-size")).read().strip() if os.path.exists(os.path.expanduser("~/.cache/dock-size")) else "medium"
    base = {"small": 32, "large": 80}.get(sz, 56)
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
print(json.dumps({"transparent": "background: transparent" in open(os.path.expanduser("~/.config/nwg-dock-hyprland/style.css")).read(), "hidden": (not ss) and os.path.exists(os.path.expanduser("~/.cache/dock-hidden")), "dock": out, "n": n, "mac": mac, "locked": os.path.exists(os.path.expanduser("~/.cache/dock-locked")), "full": os.path.exists(os.path.expanduser("~/.cache/dock-full")), "size": (open(os.path.expanduser("~/.cache/dock-size")).read().strip() if os.path.exists(os.path.expanduser("~/.cache/dock-size")) else "medium")}))
`]
    stdout: StdioCollector {
      onStreamFinished: { try { var r = JSON.parse(text); var nd = JSON.stringify(r.dock); if (nd !== dockJson) { dockJson = nd; dock = r.dock; if (r.dock) lastDock = r.dock }; locked = r.locked; mac = r.mac; full = r.full; iconSize = r.size; hidden = r.hidden; transparent = r.transparent; pinCount = r.n } catch (e) { } }
    }
  }
  Timer { interval: 500; running: true; repeat: true; onTriggered: if (!poll.running) poll.running = true }
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
        color: gma.containsMouse || menuOpen ? "#2a3a30" : "#111c18"
        border.color: "#C1C497"; border.width: 1
        Text {
          anchors.centerIn: parent
          text: "\uf013"
          color: "#C1C497"
          font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 11
        }
        MouseArea { id: gma; anchors.fill: parent; hoverEnabled: true; onClicked: menuOpen = !menuOpen }
      }
    }
  }

  Variants {
    model: lastDock && menuOpen ? [lastDock] : []
    PanelWindow {
      required property var modelData
      screen: Quickshell.screens.find(s => s.name === modelData.mon) ?? Quickshell.screens[0]
      anchors { top: true; left: true }
      margins { left: modelData.x + (mac ? modelData.w - 100 - (iconSize === "small" ? 40 : (iconSize === "large" ? 88 : 64)) / 2 : Math.max(0, (modelData.w - (pinCount + 1) * cpitch) / 2) + pinCount * cpitch - 100 + cpitch / 2); top: modelData.y - (mac ? 5 : 8) * 36 - 2 * 36 - 22 }
      implicitWidth: 200; implicitHeight: (mac ? 5 : 8) * 36 + 2 * 36 + 12
      color: "transparent"
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.namespace: "dockmenu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

      Rectangle {
        anchors.fill: parent; radius: 10
        color: "#111c18"; border.color: "#C1C497"; border.width: 1
        focus: true
        Keys.onEscapePressed: menuOpen = false
        Column {
          anchors.fill: parent; anchors.margins: 6; spacing: 2
          Repeater {
            model: [
              { label: "All apps", icon: "\uf00a", act: "apps" },
              { label: locked ? "Unlock dock" : "Lock dock", icon: locked ? "\uf09c" : "\uf023", act: "lock" },
              { label: hidden ? "Keep dock up" : "Hide dock", icon: hidden ? "\uf077" : "\uf078", act: "hide" },
              { label: transparent ? "Solid dock" : "Transparent dock", icon: "\uf1fc", act: "trans" },
              { label: full ? "Floating dock" : "Full-width dock", icon: "\uf337", act: "full" },
              { label: "Reboot", icon: "\uf01e", act: "reboot" },
              { label: "Shut down", icon: "\uf011", act: "shutdown" },
              { label: "Close menu", icon: "\uf00d", act: "close" }
            ].filter(i => !mac || i.act === "close" || i.act === "lock" || i.act === "apps" || i.act === "reboot" || i.act === "shutdown")
            Rectangle {
              required property var modelData
              width: parent.width; height: 34; radius: 6
              color: ima.containsMouse ? "#2a3a30" : "transparent"
              Row {
                anchors.verticalCenter: parent.verticalCenter; x: 10; spacing: 10
                Text { text: modelData.icon; color: "#C1C497"; font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 14; width: 18 }
                Text { text: cap2(modelData.label); color: "#C1C497"; font.pixelSize: 13 }
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
                  else if (modelData.act === "reboot") rebootProc.running = true
                  else if (modelData.act === "shutdown") shutdownProc.running = true
                }
              }
            }
          }
          Row {
            width: parent.width; height: 34; spacing: 4
            Repeater {
              model: [ { l: "Classic style", k: "off" }, { l: "Mac style", k: "on" } ]
              Rectangle {
                required property var modelData
                width: (parent.width - 4) / 2; height: 34; radius: 6
                color: (mac === (modelData.k === "on")) ? "#3a5a44" : (sta.containsMouse ? "#2a3a30" : "transparent")
                border.color: "#C1C497"; border.width: (mac === (modelData.k === "on")) ? 1 : 0
                Text { anchors.centerIn: parent; text: modelData.l; color: "#C1C497"; font.pixelSize: 12 }
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
                color: iconSize === modelData.k ? "#3a5a44" : (sma.containsMouse ? "#2a3a30" : "transparent")
                border.color: "#C1C497"; border.width: iconSize === modelData.k ? 1 : 0
                Text { anchors.centerIn: parent; text: modelData.l; color: "#C1C497"; font.pixelSize: 12 }
                MouseArea {
                  id: sma; anchors.fill: parent; hoverEnabled: true
                  onClicked: { menuOpen = false; sizer.which = modelData.k; sizer.running = true }
                }
              }
            }
          }
        }
      }
    }
  }
}
