#!/bin/bash
# install-local.sh : install Legal Desk from this folder into your home (no root, no pacman).
#   scripts  -> ~/.local/bin            (the same place the hyprland keybinds already point at)
#   data     -> ~/.local/share/legal-desk (QML apps, skins.json, themes)
# The packaged paths (/usr/lib/legal-desk, /usr/share/legal-desk) are rewritten to those two folders.
set -e
SRC="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HOME/.local/bin"; DATA="$HOME/.local/share/legal-desk"
T="$(mktemp)"; trap 'rm -f "$T"' EXIT
put() { sed -e "s#/usr/lib/legal-desk#$BIN#g" -e "s#/usr/share/legal-desk#$DATA#g" "$1" > "$T"; install -m"$3" "$T" "$2"; }
mkdir -p "$BIN" "$DATA"
put "$SRC/legal-desk" "$BIN/legal-desk" 755
ln -sf legal-desk "$BIN/legal-dock"
for f in "$SRC"/lib/*; do [ -f "$f" ] && put "$f" "$BIN/$(basename "$f")" 755; done
rm -rf "$DATA/themes"; cp -r "$SRC/share/themes" "$DATA/themes"
for d in "$SRC"/share/*/; do
  n=$(basename "$d"); [ "$n" = themes ] && continue
  mkdir -p "$DATA/$n"; for f in "$d"*; do [ -f "$f" ] || continue; case "$f" in *.qml) put "$f" "$DATA/$n/$(basename "$f")" 644;; *) install -m644 "$f" "$DATA/$n/";; esac; done
done
mkdir -p "$DATA/plugin" && rm -rf "$DATA/plugin/legaldesk.oneup-radio" && cp -r "$SRC/plugin/legaldesk.oneup-radio" "$DATA/plugin/"
rm -rf "$DATA/phosphor"; cp -r "$SRC/share/phosphor" "$DATA/phosphor"   # Phosphor Icons (MIT): the free-standing icon sets
mkdir -p "$DATA/regular" && cp "$SRC"/share/regular/* "$DATA/regular/"   # Regular set: Grok + Hermes icons
mkdir -p "$HOME/.local/share/fonts" && install -m644 "$SRC/share/fonts/BebasNeue-Regular.ttf" "$HOME/.local/share/fonts/" && fc-cache "$HOME/.local/share/fonts" >/dev/null 2>&1   # the Type icon set
install -m644 "$SRC/share/skins.json" "$DATA/skins.json"
install -m644 "$SRC/share/config.schema.json" "$DATA/config.schema.json"   # rules for the strict settings validator (legal-config)
# the minimize daemon: a systemd user unit (set LEGAL_INSTALL_NO_SERVICE=1 to skip, e.g. in tests)
if [ -z "${LEGAL_INSTALL_NO_SERVICE:-}" ] && command -v systemctl >/dev/null; then
  mkdir -p "$HOME/.config/systemd/user"; put "$SRC/systemd/legal-minimized.service" "$HOME/.config/systemd/user/legal-minimized.service" 644
  systemctl --user daemon-reload 2>/dev/null; systemctl --user enable --now legal-minimized.service 2>/dev/null || true
fi
for f in 5ive7.png style.css mac-animations.lua; do install -m644 "$SRC/share/$f" "$DATA/$f"; done
mkdir -p "$HOME/.local/share/applications" "$HOME/.local/share/icons/hicolor/scalable/apps" "$HOME/.local/share/icons/hicolor/512x512/apps"
install -m644 "$SRC/legal-desk.desktop" "$HOME/.local/share/applications/legal-desk.desktop"
install -m644 "$SRC/logo/legal-desk.svg" "$HOME/.local/share/icons/hicolor/scalable/apps/legal-desk.svg"
install -m644 "$SRC/logo/legal-desk.png" "$HOME/.local/share/icons/hicolor/512x512/apps/legal-desk.png"
echo "Installed Legal Desk to $BIN and $DATA"
