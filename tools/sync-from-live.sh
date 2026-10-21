#!/usr/bin/env bash
# sync-from-live.sh : back-port the live (home-installed) Legal Desk into this repo, ready for packaging.
#
#   tools/sync-from-live.sh
#
# The live install (~/.local/bin, ~/.local/share/legal-desk) is where daily fixes land first.
# This tool copies drifted files back into the repo, rewriting the home paths to the packaged
# FHS paths, so the repo always matches what actually runs on your machine:
#
#   /home/<you>/.local/bin              -> /usr/lib/legal-desk
#   /home/<you>/.local/share/legal-desk -> /usr/share/legal-desk
#   /home/<you>/.local/share/icons      -> /usr/share/icons
# (os.path.expanduser("~/.local/...") paths are kept as-is: they are user-data paths that
# must stay writable and home-relative in the packaged copies too - see the note below.)
#
# Deliberately NOT synced (personal, never packaged): legal-desk/legal-dock/legal-dock-vm
# (the packaged copy lives in repo root), legal-copland-* (your personal app launchers),
# *.bak* / *.new backups, grok-bot.svg / hermes.svg (one person's apps).
# The __copland_* token handling inside share/macdock/shell.qml is stripped at copy time
# (those launchers are not in the public package); the strip rules live in personal-strip.py.
set -euo pipefail
SRC="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
BIN="$HOME/.local/bin"; DATA="$HOME/.local/share/legal-desk"
HO="$(basename "$HOME")"
n=0
norm() { sed -e "s#/home/$HO/.local/share/legal-desk#/usr/share/legal-desk#g" \
              -e "s#/home/$HO/.local/bin#/usr/lib/legal-desk#g" \
              -e "s#/home/$HO/.local/share/icons#/usr/share/icons#g" \
              -e 's#os\.path\.expanduser("~/.local/share/legal-desk/radio-1up\.svg")#"/usr/share/legal-desk/radio-1up.svg"#g'   # shipped asset, not user data
}
# NOTE: os.path.expanduser("~/.local/...") paths are intentionally left alone - they are
# user-data / user-data fallbacks (saved-songs.json, skins.json search lists) that must stay
# writable and home-relative in the packaged copies too. Only literal /home/<you>/ paths are
# rewritten; those never appear in packaged files.
changed() { # changed <repo-file>  : candidate on stdin, written only when different (keeps runs idempotent)
  local dst="$1" tmp; tmp="$(mktemp)"; cat >"$tmp"
  if [ ! -f "$dst" ] || ! cmp -s "$tmp" "$dst"; then mv "$tmp" "$dst"; echo "  synced ${dst#"$SRC"/}"; n=$((n+1)); else rm -f "$tmp"; fi
}

# 1) every packaged lib script that also exists live
for f in "$SRC"/lib/*; do
  [ -f "$f" ] || continue
  b="$(basename "$f")"; case "$b" in *.bak*|*.new) continue;; esac
  [ -f "$BIN/$b" ] || { echo "  only in repo:  lib/$b"; continue; }
  norm <"$BIN/$b" | changed "$f"; chmod 755 "$f" 2>/dev/null || true
done
# 2) new live scripts missing from the repo (public dock commands only)
for f in "$BIN"/dock-* "$BIN"/legal-* "$BIN"/win-* "$BIN"/hypr-* "$BIN"/reboot-* "$BIN"/drawer-* "$BIN"/macdock-* "$BIN"/browser-* "$BIN"/up1-radio; do
  [ -f "$f" ] || continue; b="$(basename "$f")"
  case "$b" in *bak*|*.new|legal-desk|legal-dock|legal-dock-vm|legal-copland-*) continue;; esac
  if [ ! -f "$SRC/lib/$b" ]; then norm <"$f" >"$SRC/lib/$b" && chmod 755 "$SRC/lib/$b"; echo "  added   lib/$b"; n=$((n+1)); fi
done
# 3) share app folders (QML + assets) and top-level share files; macdock/shell.qml gets the personal strip
for d in "$DATA"/*/; do
  sn="$(basename "$d")"; [ -d "$SRC/share/$sn" ] || mkdir -p "$SRC/share/$sn"
  for f in "$d"*; do
    [ -f "$f" ] || continue; b="$(basename "$f")"; case "$b" in *.bak*|*.new|shell.qml.backup*|grok-bot.svg|hermes.svg) continue;; esac
    if [ "$sn/$b" = "macdock/shell.qml" ]; then
      norm <"$f" | python3 "$SRC/tools/personal-strip.py"
    else
      norm <"$f"
    fi | changed "$SRC/share/$sn/$b"
  done
done
[ -f "$DATA/radio-1up.svg" ] && { [ -f "$SRC/share/radio-1up.svg" ] || { cp "$DATA/radio-1up.svg" "$SRC/share/radio-1up.svg"; echo "  added   share/radio-1up.svg"; n=$((n+1)); }; }
# 4) safety: no home paths and no personal copland refs may leak into packaged files
if grep -rIl "/home/" "$SRC/lib" "$SRC/share" 2>/dev/null | grep -v '\.bak'; then echo "FAIL: home paths leaked into packaged files" >&2; exit 1; fi
if grep -q '__copland_' "$SRC/share/macdock/shell.qml" 2>/dev/null; then echo "FAIL: personal copland refs remain in the packaged macdock" >&2; exit 1; fi
[ "$n" -eq 0 ] && echo "  repo is up to date with the live install" || echo "  $n file(s) synced"
