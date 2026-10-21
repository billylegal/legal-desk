#!/usr/bin/env bash
# release-aur.sh : publish (or update) Legal Desk on the AUR, consistently, in one command.
#
#   tools/release-aur.sh [VERSION]
#
# Does, in order (stops at the first failure):
#   1. sync live fixes into the repo          tools/sync-from-live.sh   (run automatically)
#   2. VERSION: default = pkgver + 1 patch    (or pass e.g. 2.2.0); stamps legal-desk + PKGBUILD
#   3. QA gate                                tools/legal-dev all       (lint/build/install/verify/test)
#   4. commit + tag vX.Y.Z + push GitHub      (billylegal/legal-desk)
#   5. updpkgsums                             real sha256 of the GitHub tag tarball
#   6. makepkg --printsrcinfo > .SRCINFO      regenerates the AUR metadata
#   7. copy PKGBUILD/.SRCINFO/install into    ~/Work/legal-desk-aur and push to the AUR
#
# Prereqs (one-time): AUR account with ~/.ssh/aur_5ive7.pub registered on
# https://aur.archlinux.org/account/<user>/edit  (SSH Public Key field).
set -euo pipefail
SRC="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
AUR="${LEGAL_AUR_DIR:-$HOME/Work/legal-desk-aur}"
AUR_URL="ssh://aur@aur.archlinux.org/legal-desk.git"
GH_URL="https://github.com/billylegal/legal-desk"

cd "$SRC"
step() { printf '\n\033[1m== %s\033[0m\n' "$*"; }
die()  { printf '\033[31mFAIL:\033[0m %s\n' "$*" >&2; exit 1; }

step "1/7 sync live fixes into the repo"
[ -x tools/sync-from-live.sh ] && tools/sync-from-live.sh || echo "  (sync-from-live.sh not present, skipping)"

# 2/7 version
cur=$(sed -n 's/^pkgver=//p' PKGBUILD | head -1)
if [ $# -ge 1 ]; then ver="$1"; else
  ver=$(python3 - "$cur" <<'PY'
import sys
maj, mi, pa = (int(x) for x in sys.argv[1].split("."))
print(f"{maj}.{mi}.{pa+1}")
PY
)
fi
[ "$ver" != "$cur" ] || die "nothing to release: PKGBUILD is already $cur (pass a VERSION to force)"
step "2/7 version: $cur -> $ver"
sed -i "s/^pkgver=.*/pkgver=$ver/" PKGBUILD
sed -i "s/^VERSION=\"[^\"]*\"/VERSION=\"$ver\"/" legal-desk
grep -n "^VERSION=" legal-desk | head -1

step "3/7 QA gate (tools/legal-dev all)"
tools/legal-dev all >/dev/null || { tools/legal-dev all 2>&1 | tail -20; die "QA gate failed"; }
echo "  QA passed (lint, build, install, verify, test)"

step "4/7 commit + tag + push to GitHub"
git add -A
git diff --cached --quiet || git commit -m "v$ver: release" --quiet
git tag -a "v$ver" -m "Legal Desk $ver" 2>/dev/null || die "tag v$ver already exists"
git push origin HEAD --tags >/dev/null || die "git push to $GH_URL failed"
echo "  pushed $(git rev-parse --short HEAD) + tag v$ver"

step "5/7 real checksums (updpkgsums)"
updpkgsums >/dev/null 2>&1 || die "updpkgsums failed (is the v$ver tag visible on GitHub yet?)"
grep '^sha256sums' PKGBUILD

step "6/7 .SRCINFO"
makepkg --printsrcinfo > .SRCINFO
echo "  $(grep -c $'\t' .SRCINFO) fields; pkgver = $(sed -n 's/^\tpkgver = //p' .SRCINFO)"

step "7/7 push to the AUR"
if [ ! -d "$AUR/.git" ]; then
  mkdir -p "$AUR" && git -C "$AUR" init -q
  git -C "$AUR" remote add origin "$AUR_URL"
fi
cp PKGBUILD .SRCINFO legal-desk.install "$AUR/"
git -C "$AUR" add -A
git -C "$AUR" -c user.name='5ive7 Development Labs' -c user.email='5ive7@mail.com' \
   commit -m "Update to $ver" --quiet || echo "  (no changes for the AUR)"
git -C "$AUR" push -q origin HEAD:refs/heads/master 2>&1 | sed 's/^/  /' || \
  die "AUR push failed. Register $(cat ~/.ssh/aur_5ive7.pub) at https://aur.archlinux.org (My Account -> SSH Public Key), then: git -C $AUR push origin HEAD:refs/heads/master"
echo "  AUR: https://aur.archlinux.org/packages/legal-desk"
printf '\n\033[32mDone: legal-desk %s is on GitHub (tag v%s) and the AUR.\033[0m\n' "$ver" "$ver"
