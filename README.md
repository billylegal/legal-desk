# Legal Dock

A dock for [Hyprland](https://hypr.land) / [Omarchy](https://omarchy.org) with two styles you can switch between with one click:

- **Classic** – the [nwg-dock-hyprland](https://github.com/nwg-piotr/nwg-dock-hyprland) dock.
- **Mac** – a magnifying, macOS-style dock built with [Quickshell](https://quickshell.org): running apps, right-click menu (windows / new window / pin / close), middle-click to pin.

Plus a menu (the grid button) with **Small / Medium / Large** icons, **lock** icon order, **hide** (auto-hide), **full width** and **transparent** modes, an app drawer button, and a confirm-before-reboot button.

## Install

```bash
yay -S legal-dock        # or any AUR helper
```

Add to `~/.config/hypr/autostart.lua` (or `hyprland.conf`: `exec-once = legal-dock start`):

```lua
o.exec_on_start("sleep 3 && legal-dock start")
```

Then open **Legal Dock** from your app launcher, or run `legal-dock menu`.

## Commands

```
legal-dock start      start the dock services (use this at login)
legal-dock menu       open the dock menu
legal-dock classic    switch to the classic dock
legal-dock mac        switch to the Mac-style dock
legal-dock small|medium|large
legal-dock restart
legal-dock status
```

Your pinned apps live in `~/.cache/nwg-dock-pinned` (one app class per line). Your dock colours live in `~/.config/nwg-dock-hyprland/style.css`; a default is copied there on first run and never overwritten.

## Minimize windows

Hyprland has no minimize, so Legal Dock adds one: `/usr/lib/legal-dock/win-minimize` parks a window on a hidden workspace and brings it back later. Clicking a minimized app in the **Mac dock** restores it. To use it elsewhere:

```lua
-- hyprbars title-bar button
hl.plugin.hyprbars.add_button({ bg_color = "rgb(111c18)", fg_color = "rgb(C1C497)", size = 16, icon = "–",
  action = "/usr/lib/legal-dock/win-minimize hide" })
-- keybinds
o.bind("SUPER + CTRL + ALT + H", "Minimize window", hl.dsp.exec_cmd("/usr/lib/legal-dock/win-minimize hide"))
o.bind("SUPER + CTRL + ALT + U", "Restore last minimized", hl.dsp.exec_cmd("/usr/lib/legal-dock/win-minimize restore"))
```

## Requirements

`hyprland`, `nwg-dock-hyprland`, `nwg-drawer`, `quickshell`, `inotify-tools`, `python`.

## License

[MIT](LICENSE) © 2026 5ive7 Development Labs
