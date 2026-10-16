# Maintainer: 5ive7 Development Labs <5ive7@mail.com>
pkgname=legal-desk
pkgver=2.1.0
pkgrel=1
pkgdesc='Dock (skins, icon sets), minimize daemon, strict config validator, app launcher, calendar, notes, clock, task manager, disk management and window zones for Hyprland/Omarchy'
provides=('legal-dock')
replaces=('legal-dock')
conflicts=('legal-dock')
arch=('any')
url='https://github.com/5ive7/legal-desk'
license=('MIT')
install=legal-desk.install
depends=('hyprland' 'nwg-dock-hyprland' 'quickshell' 'inotify-tools' 'python' 'util-linux' 'procps-ng' 'bash'
         'glib2' 'gtk3' 'imagemagick' 'librsvg' 'xdg-utils' 'wtype' 'libnotify' 'pipewire' 'udisks2' 'polkit' 'python-numpy')
optdepends=('whitesur-icon-theme: the macOS look for every app icon (Regular and Apple icon sets)'
            'exfatprogs: format drives as exFAT' 'ntfs-3g: format drives as NTFS' 'btrfs-progs: format drives as Btrfs' 'xfsprogs: format drives as XFS' 'dosfstools: format drives as FAT32'
            'hyprland-plugins: title bars with Apple / Windows style window buttons (hyprbars)'
            'omarchy: desktop theme, web-app windows for Mail, screenshots')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')   # fill in with updpkgsums once the v2.1.0 tag is published

check() {
  cd "$pkgname-$pkgver"
  for f in legal-desk lib/*; do head -c 20 "$f" | grep -q 'bash' && bash -n "$f"; done      # every shell script parses
  python3 -m py_compile lib/legal-config lib/legal-minimized lib/legal-zones-core
  python3 -c 'import json; [json.load(open(f)) for f in ("share/skins.json", "share/config.schema.json")]'
  python3 lib/legal-config selftest                                                          # injection tests for the settings validator
}

package() {
  cd "$pkgname-$pkgver"
  install -Dm755 legal-desk "$pkgdir/usr/bin/legal-desk"
  ln -s legal-desk "$pkgdir/usr/bin/legal-dock"   # old command name keeps working (autostart lines, habits)
  install -d "$pkgdir/usr/lib/legal-desk" "$pkgdir/usr/share/legal-desk"
  find lib -maxdepth 1 -type f -exec install -m755 -t "$pkgdir/usr/lib/legal-desk/" {} +
  # every app folder under share/ (QML + its images), exactly what tools/install-local.sh installs
  for d in share/*/; do
    n=$(basename "$d"); case "$n" in themes|phosphor|fonts|regular) continue;; esac
    install -d "$pkgdir/usr/share/legal-desk/$n"
    for f in "$d"*; do [ -f "$f" ] && install -m644 "$f" "$pkgdir/usr/share/legal-desk/$n/"; done
  done
  install -d "$pkgdir/usr/share/legal-desk/plugin" && cp -r plugin/legaldesk.oneup-radio "$pkgdir/usr/share/legal-desk/plugin/"
  install -Dm644 share/regular/disks.svg share/regular/files.png -t "$pkgdir/usr/share/legal-desk/regular/"   # (Grok / Hermes / yt-audio icons stay out: they are one person's apps)
  cp -r share/phosphor "$pkgdir/usr/share/legal-desk/phosphor"
  install -Dm644 share/fonts/BebasNeue-Regular.ttf "$pkgdir/usr/share/fonts/TTF/BebasNeue-Regular.ttf"
  install -Dm644 share/fonts/OFL-BebasNeue.txt "$pkgdir/usr/share/licenses/$pkgname/OFL-BebasNeue.txt"
  cp -r share/themes "$pkgdir/usr/share/legal-desk/themes"
  install -Dm644 share/skins.json "$pkgdir/usr/share/legal-desk/skins.json"
  install -Dm644 share/config.schema.json "$pkgdir/usr/share/legal-desk/config.schema.json"
  install -Dm644 systemd/legal-minimized.service "$pkgdir/usr/lib/systemd/user/legal-minimized.service"
  install -Dm644 share/5ive7.png "$pkgdir/usr/share/legal-desk/5ive7.png"
  install -Dm644 share/style.css "$pkgdir/usr/share/legal-desk/style.css"
  install -Dm644 share/mac-animations.lua "$pkgdir/usr/share/legal-desk/mac-animations.lua"
  install -Dm644 /dev/stdin "$pkgdir/etc/xdg/autostart/legal-desk-setup.desktop" <<'EOT'
[Desktop Entry]
Type=Application
Name=Legal Desk setup
Comment=Asks once how Legal Desk should be set up
Exec=/usr/lib/legal-desk/legal-desk-setup first-run
NoDisplay=true
EOT
  install -Dm644 legal-desk.desktop "$pkgdir/usr/share/applications/legal-desk.desktop"
  install -Dm644 logo/legal-desk.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/legal-desk.svg"
  install -Dm644 logo/legal-desk.png "$pkgdir/usr/share/icons/hicolor/512x512/apps/legal-desk.png"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
