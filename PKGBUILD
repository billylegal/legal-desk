# Maintainer: 5ive7 Development Labs <5ive7@mail.com>
pkgname=legal-desk
pkgver=2.0.0
pkgrel=1
pkgdesc='Dock (10 skins, 10 icon sets), app launcher, calendar, notes, clock, task manager, disk management and window zones for Hyprland/Omarchy'
provides=('legal-dock')
replaces=('legal-dock')
conflicts=('legal-dock')
arch=('any')
url='https://github.com/5ive7/legal-desk'
license=('MIT')
install=legal-desk.install
depends=('hyprland' 'nwg-dock-hyprland' 'quickshell' 'inotify-tools' 'python' 'util-linux' 'procps-ng' 'bash'
         'glib2' 'gtk3' 'imagemagick' 'librsvg' 'xdg-utils' 'wtype' 'libnotify' 'pipewire' 'udisks2' 'polkit')
optdepends=('exfatprogs: format drives as exFAT' 'ntfs-3g: format drives as NTFS' 'btrfs-progs: format drives as Btrfs' 'xfsprogs: format drives as XFS' 'dosfstools: format drives as FAT32'
            'hyprland-plugins: title bars with Apple / Windows style window buttons (hyprbars)'
            'omarchy: desktop theme, web-app windows for Mail, screenshots')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('SKIP')   # fill in with updpkgsums once the v2.0.0 tag is published

package() {
  cd "$pkgname-$pkgver"
  install -Dm755 legal-desk "$pkgdir/usr/bin/legal-desk"
  ln -s legal-desk "$pkgdir/usr/bin/legal-dock"   # old command name keeps working (autostart lines, habits)
  install -d "$pkgdir/usr/lib/legal-desk" "$pkgdir/usr/share/legal-desk"
  find lib -maxdepth 1 -type f -exec install -m755 -t "$pkgdir/usr/lib/legal-desk/" {} +
  for d in docklock macdock rebootconfirm appsmenu legalnotes legalcalendar legaltasks legalclock legaldisks legalzones legalzonesbar legalzonesdrag deskpick; do
    install -Dm644 "share/$d/shell.qml" "$pkgdir/usr/share/legal-desk/$d/shell.qml"
  done
  cp -r share/themes "$pkgdir/usr/share/legal-desk/themes"
  install -Dm644 share/skins.json "$pkgdir/usr/share/legal-desk/skins.json"
  install -Dm644 share/5ive7.png "$pkgdir/usr/share/legal-desk/5ive7.png"
  install -Dm644 share/style.css "$pkgdir/usr/share/legal-desk/style.css"
  install -Dm644 share/mac-animations.lua "$pkgdir/usr/share/legal-desk/mac-animations.lua"
  install -Dm644 legal-desk.desktop "$pkgdir/usr/share/applications/legal-desk.desktop"
  install -Dm644 logo/legal-desk.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/legal-desk.svg"
  install -Dm644 logo/legal-desk.png "$pkgdir/usr/share/icons/hicolor/512x512/apps/legal-desk.png"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
