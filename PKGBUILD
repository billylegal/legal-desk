# Maintainer: 5ive7 Development Labs <5ive7@mail.com>
pkgname=legal-dock
pkgver=1.0.1
pkgrel=1
pkgdesc='Classic or Mac-style dock for Hyprland/Omarchy with size, lock, hide and transparency controls'
arch=('any')
url='https://github.com/5ive7/legal-dock'
license=('MIT')
install=legal-dock.install
depends=('hyprland' 'nwg-dock-hyprland' 'nwg-drawer' 'quickshell' 'inotify-tools' 'python' 'util-linux' 'procps-ng' 'bash')
source=("$pkgname-$pkgver.tar.gz::$url/archive/refs/tags/v$pkgver.tar.gz")
sha256sums=('285100416b34dd59a25c1dad2a4f98be7ee6e78cea6de117cb2186942af5ae6e')

package() {
  cd "$pkgname-$pkgver"
  install -Dm755 legal-dock "$pkgdir/usr/bin/legal-dock"
  install -d "$pkgdir/usr/lib/legal-dock" "$pkgdir/usr/share/legal-dock"
  find lib -maxdepth 1 -type f -exec install -m755 -t "$pkgdir/usr/lib/legal-dock/" {} +
  for d in docklock macdock rebootconfirm; do
    install -Dm644 "share/$d/shell.qml" "$pkgdir/usr/share/legal-dock/$d/shell.qml"
  done
  install -Dm644 share/style.css "$pkgdir/usr/share/legal-dock/style.css"
  install -Dm644 share/mac-animations.lua "$pkgdir/usr/share/legal-dock/mac-animations.lua"
  install -Dm644 legal-dock.desktop "$pkgdir/usr/share/applications/legal-dock.desktop"
  install -Dm644 logo/legal-dock.svg "$pkgdir/usr/share/icons/hicolor/scalable/apps/legal-dock.svg"
  install -Dm644 logo/legal-dock.png "$pkgdir/usr/share/icons/hicolor/512x512/apps/legal-dock.png"
  install -Dm644 LICENSE "$pkgdir/usr/share/licenses/$pkgname/LICENSE"
  install -Dm644 README.md "$pkgdir/usr/share/doc/$pkgname/README.md"
}
