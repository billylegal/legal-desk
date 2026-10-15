# Legal Desk

*Formerly Legal Dock.* By 5ive7 Development Labs. **Version 2.0: rebuilt around 10 skins and 10 icon sets.** **Legal Desk** is the whole suite: **Legal Dock** (the dock) and **Legal Zones** (window layouts), with Calendar, Notes and more. A desktop suite for Hyprland / Omarchy: the dock below, plus an **Apps** launcher, **Calendar**, **Notes**, **Clock** (world clock + timer), **Task Manager** and **Disk Management** (with formatting), all in the colours of your dock skin.

The dock is a dock for [Hyprland](https://hypr.land) / [Omarchy](https://omarchy.org) with three styles you can switch between with one click:

- **Classic** – the [nwg-dock-hyprland](https://github.com/nwg-piotr/nwg-dock-hyprland) dock.
- **Mac** – a magnifying, macOS-style dock built with [Quickshell](https://quickshell.org): running apps, right-click menu (windows / new window / pin / close), middle-click to pin, and hover name labels.
- **Rubik** – the Mac dock dressed as a Rubik's Cube: black cube-plastic frame, every app on a coloured sticker tile, and a quarter-turn twist when you click it.

Plus a menu (the grid button) with **Small / Medium / Large** icons (tight sizes, smooth wide magnification), **lock** icon order, **hide** (auto-hide), **full width** and **transparent** modes, an app drawer button, and a confirm-before-reboot button.

## Install

Get it from the [Omarchy Store](https://omarchystore.com) (search "Legal Desk"), or install the package from the [latest release](https://github.com/5ive7/legal-desk/releases/latest):

```bash
sudo pacman -U legal-desk-*-any.pkg.tar.zst
```

Add to `~/.config/hypr/autostart.lua` (or `hyprland.conf`: `exec-once = legal-desk start`):

```lua
o.exec_on_start("sleep 3 && (legal-desk start || nwg-dock-hyprland -r -x -i 56)")
```

Legal Desk takes over the dock: while it is active the classic nwg-dock is shut off. Remove it (`sudo pacman -R legal-desk`, or `legal-desk uninstall` first) and the classic dock comes back — the line above falls back to it at login.

Then open **Legal Desk** from your app launcher, or run `legal-desk menu`.

## Commands

```
legal-desk start      start the dock services (use this at login)
legal-desk menu       open the dock menu
legal-desk classic    switch to the classic dock
legal-desk uninstall  stop Legal Desk and bring the classic dock back
legal-desk mac        switch to the Mac-style dock
legal-desk rubik      switch to the Rubik's Cube style
legal-desk skin next|prev|N|auto     browse the dock skins
legal-desk theme      install + apply the Nebula desktop theme and dock skin
legal-desk small|medium|large
legal-desk restart
legal-desk status
```

Your pinned apps live in `~/.cache/nwg-dock-pinned` (one app class per line). Your dock colours live in `~/.config/nwg-dock-hyprland/style.css`; a default is copied there on first run and never overwritten.

**Install without root** (from a checkout): `tools/install-local.sh` copies the scripts to `~/.local/bin` and the QML to `~/.local/share/legal-desk`.

## Mac touches

- **Size and Zoom sliders** (Mac menu): resize the icons from 28 to 96 px and set the magnification from off to 2.4x, like macOS.
- **10 skins**, the same in Classic, Mac and Rubik: **Nebula** (the default), **Omarchy** (follows your Omarchy theme), **Emerald**, **Midnight**, **Glass**, **Neon**, **Sunset**, **Aluminum**, **Amber** and **Windows 11**. One skin recolours the dock, every menu, the Apps window, the drawer, the pointer and the window title bars. They all live in one file, `share/skins.json`. Browse with the ‹ › buttons in the menu (`legal-desk skin next|prev|N`). **Solid / Transparent** dock works in every style.
- **10 icon sets** (menu: **Icons** ‹ ›, `dock-icon-style next|prev|N`): **Tile** (the standard), **Outline**, **Glyph**, **Duotone**, **Glass**, **Neon**, **Flat**, **Pixel**, **Sticker** and **Cube**. A set changes how Legal Desk's own icons are drawn (Calendar, Notes, Tasks, Disks, Zones, Clock, Screenshot, Downloads, Trash, Mail) and how other apps' icons are dressed (real colours, monochrome, on plates, on blocks or on Rubik stickers). The own icons are drawn as SVG by `legal-icons` in the colours of the active skin, so every skin x every set works. Other apps keep their real colours; nothing is tinted into a blob any more.
- **Launcher icon:** the dock menu's **Launcher** row (‹ ›) changes the launcher button: the Rubik's Cube, or flat ones (Desk tile, Zones, Desk), 3D ones (3D Cube, 3D Layers, 3D Flip) and moving ones (Hop, Orbit, Pulse, Spark). `dock-launcher-icon next|prev|N` does the same from a terminal.
- The magnification wave tracks the icon under the pointer, so it flows without jitter.

- **Rubik's Cube launcher** (Mac dock): solved with no windows open, and it scrambles a little more with every window you open.
- **Right-click a browser** (Chrome, Chromium, Brave, Edge, Vivaldi, Firefox, Zen, LibreWolf, Helium) for **New incognito window**.
- **Launch bounce**: an app's icon bounces until its window appears.
- **Restart / Shut down** live in the dock menu (grid button) and always ask "Do you really want to ...?" first.
- **Mac-style window animations** (spring-open, shrink-and-fade close, minimize slides toward the dock). Hyprland cannot do a true genie effect. Copy `/usr/share/legal-desk/mac-animations.lua` into your Hyprland Lua config (or `source` it) to enable them.

## Nebula (special edition)

A purple-nebula desktop theme with a matching dock skin, in every dock style (Classic, Mac and Rubik). Run `legal-desk theme` to install and apply the Omarchy theme (wallpaper, window borders, panel colours) and switch the dock to its Nebula skin. Switch back any time with the Omarchy theme menu or the skin buttons in the dock menu. The dock menu also has a **Wallpaper** row (‹ ›) that cycles through every wallpaper on your system (all Omarchy themes plus your own).

The dock menus (the grid-button menu, the right-click app menu and the Reboot/Shut down popup) follow the chosen dock skin: change the skin and every menu changes colour with it. **Nebula is the standard** skin for a fresh install. The last skin, **Omarchy**, is the original look: its menus wear Omarchy's original colours (the Tokyo Night theme Omarchy installs with), so everyone knows it is the original look; the dock plate and icon tiles take their colours from the active Omarchy theme.

One line of the dock menu has three cycle buttons: the **look** (Transparent = icons float, Solid = one plate behind the icons, Block = every icon on its own block), the **dock style** (Classic, Mac, Rubik) and the **icon size** (Small, Medium, Large). Each shows the current choice with a ‹ › inside it: ‹ steps back, › (or the middle) steps forward, and the menu stays open while you try them. The **Icons** row ‹ › changes only the icons' look (see the 10 icon sets above), the Skin buttons change skin and icons together, and the small ↺ button resets everything to Nebula (`legal-desk reset`). 

The dock menu is one boxed square of solid buttons: Apps / Move Icons / Mouse / Shut Down; look / style / size cycle buttons; the Size and Zoom sliders; **Skin** / **Wallpaper** / **Icons** cycle buttons (each with ‹ › inside); and a bottom row of **Close**, **Hide** (hide bar), the padlock (lock bar), **Reboot** and the moon (reset to Nebula). The app drawer (Apps) wears the skin's colours too and is rewritten whenever the skin changes; press Apps again, the X, or Esc to close it.

The **lock** button (a padlock, bottom row of the dock menu) locks the dock's layout: while it is locked you can't move the icons, change the skin or change the icons, and those controls are dimmed in the menu. Everything else (wallpaper, size, look, ...) keeps working. Press the padlock again to unlock.

**Icons** (Mac and Rubik): the **Icons** button (third button of the skin line of the menu, with ‹ › inside) changes only the icons and leaves the skin and menus alone. Choosing a skin keeps your icon set. The small moon button resets everything to Nebula + Tile.

The menu's action buttons, **Move** (rearrange icons), **Mouse** (pointer settings) and **Shut Down** (plus **Hide** on the classic dock), are solid buttons on one line. The full-width bar is gone: Solid is the plate with a border around the icons.

The **Mouse** popup has a **Scroll** speed slider (0.2x to 3x, remembered) a pointer **Size** slider (16 to 64 px) and a **Pointer** row ‹ ›: **Original**, **Solid** (a filled pointer in the skin's colour) or **Outlined** (a hollow pointer with a skin-coloured outline). The pointer keeps matching the skin when you change it; hands, text cursors and resize cursors stay as your theme has them. `legal-desk pointer` also works from a terminal.

The menu is identical for Classic, Mac and Rubik: same buttons, same size, nothing moves when you change style. The few things the classic dock can't do (**Zoom** magnification and the **Icons** looks) are shown dimmed there.

**Clock:** the **CLOCK** button in the menu puts a small clock on the hard left or hard right edge of the screen (or off), level with the dock and never affected by the dock, in the skin's colours; **TIME** switches 12 / 24 hour. The date sits under the time, and a small camera button next to it takes a screenshot (Omarchy's screenshot tool). Works on Classic, Mac and Rubik.

## Minimize windows

Hyprland has no minimize, so Legal Desk adds one: `/usr/lib/legal-desk/win-minimize` parks a window on a hidden workspace and brings it back later. Clicking a minimized app in the **Mac dock** restores it. To use it elsewhere:

```lua
-- hyprbars title-bar button
hl.plugin.hyprbars.add_button({ bg_color = "rgb(111c18)", fg_color = "rgb(C1C497)", size = 16, icon = "–",
  action = "/usr/lib/legal-desk/win-minimize hide" })
-- keybinds
o.bind("SUPER + CTRL + ALT + H", "Minimize window", hl.dsp.exec_cmd("/usr/lib/legal-desk/win-minimize hide"))
o.bind("SUPER + CTRL + ALT + U", "Restore last minimized", hl.dsp.exec_cmd("/usr/lib/legal-desk/win-minimize restore"))
```

## Requirements

`hyprland`, `nwg-dock-hyprland`, `nwg-drawer`, `quickshell`, `inotify-tools`, `python`, `librsvg` and `imagemagick` (the icon sets).

## License

[MIT](LICENSE) © 2026 5ive7 Development Labs

## Legal Zones (window layouts, like FancyZones)

- **Drag to snap:** hold Super and drag a window to a screen edge or corner: every zone of the layout appears and the one under the pointer lights up. Let go and the window snaps in. (Needs the two `SUPER + mouse:272` binds `legal-zones dragstart` / `dragend`, see below.)
- **Top menu:** push the pointer to the top edge for a Legal Zones menu of all layouts; click a zone to snap the window you were using, or **+ Create my own**.
- **Editor:** drag ANY edge of ANY zone, inside or outside edges, to move it in or out.


Open **Legal Zones** from the Apps window (or `legal-desk zones`) to pick a layout (two or three columns, grid, priority grid, focus), edit zones (split, merge, drag the dividers), set the gap, and snap your open windows into the zones. Add these to `~/.config/hypr/bindings.lua` for the shortcuts:

```lua
o.bind("SUPER + SHIFT + Z", "Zones: pick a zone for this window", "legal-desk zones pick")
o.bind("SUPER + CTRL + Z", "Zones: open Legal Zones", "legal-desk zones manage")
o.bind("SUPER + mouse:272", "Zones: preview", "legal-desk zones dragstart", { non_consuming = true })
o.bind("SUPER + mouse:272", "Zones: snap", "legal-desk zones dragend", { release = true, non_consuming = true })
o.bind("SUPER + ALT + LEFT", "Zones: window to the zone on the left", "legal-desk zones dir left")
o.bind("SUPER + ALT + RIGHT", "Zones: window to the zone on the right", "legal-desk zones dir right")
```

Switch on "Auto-snap new windows" in Legal Zones to have every new window land in the next free zone.


## 1UP Radio

Legal Desk carries [1UP Radio](https://1upradio.com) in two forms, both in the **Nebula skin of 1upradio.com**, both driven by SnapDock's radio player (`sd-radio`):

- **Dock button + floating player:** the 1UP Radio button on the dock starts the radio and opens a compact player you can **drag anywhere on the screen** (the spot is remembered). Press the button again to step through the three sizes: **small** (one tight row: logo, track, meters, play), **medium** (artwork, progress, Live / Play / Stop / mute, volume) and **large** (adds Up next and Just played); a fourth press closes it. The header has a size button and an X too; Esc closes it. The footer reads "Sponsored by BillyLegal.com" followed by the Billy Legal sticker. Closing the player never stops the music. Right-click the button for Play / Pause, Live, Stop and the icon style (original logo with its own animated meter, or the drawn meters). Keep it in the dock from the Apps window (right-click, Keep in Dock).
- **Bar widget** (like Hertz Radio): `legal-desk radio-bar on` installs the plugin `legaldesk.oneup-radio` and adds it to the right side of the Omarchy bar (`radio-bar off` removes it). A waveform icon beats while it plays, the track scrolls next to it; click for the same Nebula player, middle-click Play/Pause, right-click Stop, scroll for volume. Options on its entry in `shell.json`: `"showTitle": false`, `"maxTitleWidth": 150`.

`legal-desk radio play|toggle|live|stop|volume N|mute|window` controls it from a terminal.
