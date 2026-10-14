# Legal Dock

A dock for [Hyprland](https://hypr.land) / [Omarchy](https://omarchy.org) with three styles you can switch between with one click:

- **Classic** – the [nwg-dock-hyprland](https://github.com/nwg-piotr/nwg-dock-hyprland) dock.
- **Mac** – a magnifying, macOS-style dock built with [Quickshell](https://quickshell.org): running apps, right-click menu (windows / new window / pin / close), middle-click to pin, and hover name labels.
- **Rubik** – the Mac dock dressed as a Rubik's Cube: black cube-plastic frame, every app on a coloured sticker tile, and a quarter-turn twist when you click it.

Plus a menu (the grid button) with **Small / Medium / Large** icons (tight sizes, smooth wide magnification), **lock** icon order, **hide** (auto-hide), **full width** and **transparent** modes, an app drawer button, and a confirm-before-reboot button.

## Install

Get it from the [Omarchy Store](https://omarchystore.com) (search "Legal Dock"), or install the package from the [latest release](https://github.com/5ive7/legal-dock/releases/latest):

```bash
sudo pacman -U legal-dock-*-any.pkg.tar.zst
```

Add to `~/.config/hypr/autostart.lua` (or `hyprland.conf`: `exec-once = legal-dock start`):

```lua
o.exec_on_start("sleep 3 && (legal-dock start || nwg-dock-hyprland -r -x -i 56)")
```

Legal Dock takes over the dock: while it is active the classic nwg-dock is shut off. Remove it (`sudo pacman -R legal-dock`, or `legal-dock uninstall` first) and the classic dock comes back — the line above falls back to it at login.

Then open **Legal Dock** from your app launcher, or run `legal-dock menu`.

## Commands

```
legal-dock start      start the dock services (use this at login)
legal-dock menu       open the dock menu
legal-dock classic    switch to the classic dock
legal-dock uninstall  stop Legal Dock and bring the classic dock back
legal-dock mac        switch to the Mac-style dock
legal-dock rubik      switch to the Rubik's Cube style
legal-dock skin next|prev|N|auto     browse the dock skins
legal-dock theme      install + apply the Purple Space desktop theme and dock skin
legal-dock small|medium|large
legal-dock restart
legal-dock status
```

Your pinned apps live in `~/.cache/nwg-dock-pinned` (one app class per line). Your dock colours live in `~/.config/nwg-dock-hyprland/style.css`; a default is copied there on first run and never overwritten.

## Mac touches

- **Size and Zoom sliders** (Mac menu): resize the icons from 28 to 96 px and set the magnification from off to 2.4x, like macOS.
- **8 skins** (Emerald, Glass, Midnight, Neon, Aluminum, Aqua, Sunset, Cube): browse with the ‹ › buttons in the menu. **Solid / Transparent** dock works in every style.
- The magnification wave tracks the icon under the pointer, so it flows without jitter.

- **Rubik's Cube launcher** (Mac dock): solved with no windows open, and it scrambles a little more with every window you open.
- **Right-click a browser** (Chrome, Chromium, Brave, Edge, Vivaldi, Firefox, Zen, LibreWolf, Helium) for **New incognito window**.
- **Launch bounce**: an app's icon bounces until its window appears.
- **Restart / Shut down** live in the dock menu (grid button) and always ask "Do you really want to ...?" first.
- **Mac-style window animations** (spring-open, shrink-and-fade close, minimize slides toward the dock). Hyprland cannot do a true genie effect. Copy `/usr/share/legal-dock/mac-animations.lua` into your Hyprland Lua config (or `source` it) to enable them.

## Purple Space (special edition)

A purple-nebula desktop theme with a matching dock skin, in every dock style (Classic, Mac and Rubik). Run `legal-dock theme` to install and apply the Omarchy theme (wallpaper, window borders, panel colours) and switch the dock to its Purple Space skin. Switch back any time with the Omarchy theme menu or the skin buttons in the dock menu.

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
