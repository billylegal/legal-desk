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
legal-dock theme      install + apply the Nebula desktop theme and dock skin
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

## Nebula (special edition)

A purple-nebula desktop theme with a matching dock skin, in every dock style (Classic, Mac and Rubik). Run `legal-dock theme` to install and apply the Omarchy theme (wallpaper, window borders, panel colours) and switch the dock to its Nebula skin. Switch back any time with the Omarchy theme menu or the skin buttons in the dock menu. The dock menu also has a **Wallpaper** row (‹ ›) that cycles through every wallpaper on your system (all Omarchy themes plus your own).

The dock menus (the grid-button menu, the right-click app menu and the Reboot/Shut down popup) follow the chosen dock skin: change the skin and every menu changes colour with it. **Nebula is the standard** skin for a fresh install. The last skin, **Omarchy**, is the original look: its menus wear Omarchy's original colours (the Tokyo Night theme Omarchy installs with), so everyone knows it is the original look; the dock plate and icon tiles take their colours from the active Omarchy theme.

One line of the dock menu has three cycle buttons: the **look** (Transparent = icons float, Solid = one plate behind the icons, Block = every icon on its own block), the **dock style** (Classic, Mac, Rubik) and the **icon size** (Small, Medium, Large). Each shows the current choice with a ‹ › inside it: ‹ steps back, › (or the middle) steps forward, and the menu stays open while you try them. The **Icons** row ‹ › changes only the icons' look (any original skin's), the Skin buttons change skin and icons together, and the small ↺ button resets everything to Nebula (`legal-dock reset`). Nebula's icons are tinted purple like the Amber skin; **Nebula 2** is the plate look.

The dock menu is one boxed square of solid buttons: Apps / Move Icons / Mouse / Shut Down; look / style / size cycle buttons; the Size and Zoom sliders; **Skin** / **Wallpaper** / **Icons** cycle buttons (each with ‹ › inside); and a bottom row of **Close**, **Hide** (hide bar), the padlock (lock bar), **Reboot** and the moon (reset to Nebula). The app drawer (Apps) wears the skin's colours too and is rewritten whenever the skin changes; press Apps again, the X, or Esc to close it.

The **lock** button (a padlock, bottom row of the dock menu) locks the dock's layout: while it is locked you can't move the icons, change the skin or change the icons, and those controls are dimmed in the menu. Everything else (wallpaper, size, look, ...) keeps working. Press the padlock again to unlock.

**Icon colours** (Mac and Rubik): the **Icons** button (third button of the skin line of the menu, with ‹ › inside) changes only the icons and leaves the skin and menus alone. Mostly colour swaps: Match skin (tinted in the skin's colour), Nebula, Omarchy, Emerald, Sunset, Ocean, Neon, Amber, Rose, Gold and Mono; plus a few shapes: Pearls and Bubbles (circles), Blocks (each icon on a block in the skin's colours) and Cube (Rubik blocks). Picking a skin puts the icons back to Original.

The menu's action buttons, **Move** (rearrange icons), **Mouse** (pointer settings) and **Shut Down** (plus **Hide** on the classic dock), are solid buttons on one line. The full-width bar is gone: Solid is the plate with a border around the icons.

The **Mouse** popup has a **Scroll** speed slider (0.2x to 3x, remembered) a pointer **Size** slider (16 to 64 px) and a **Pointer** row ‹ ›: **Original**, **Solid** (a filled pointer in the skin's colour) or **Outlined** (a hollow pointer with a skin-coloured outline). The pointer keeps matching the skin when you change it; hands, text cursors and resize cursors stay as your theme has them. `legal-dock pointer` also works from a terminal.

The menu is identical for Classic, Mac and Rubik: same buttons, same size, nothing moves when you change style. The few things the classic dock can't do (**Zoom** magnification and the **Icons** looks) are shown dimmed there.

**Clock:** the **CLOCK** button in the menu puts a small clock on the hard left or hard right edge of the screen (or off), level with the dock and never affected by the dock, in the skin's colours; **TIME** switches 12 / 24 hour. The date sits under the time, and a small camera button next to it takes a screenshot (Omarchy's screenshot tool). Works on Classic, Mac and Rubik.

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
