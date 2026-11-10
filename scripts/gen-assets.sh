#!/bin/bash
# Генерирует всю графику Kroha OS из SVG-шаблонов design/*.svg.tmpl.
#   gen-assets.sh <includes.chroot> <bootloaders/grub-pc>
# Нужны: rsvg-convert (librsvg2-bin), grub-mkfont (grub-common), fonts-dejavu-core, fonts-inter.
set -euo pipefail
KROHA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KROHA_ROOT/scripts/lib.sh"
kroha_load_vars

CH="$1"     # includes.chroot
BL="$2"     # bootloaders/grub-pc
D="$KROHA_ROOT/design"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

svg() { kroha_render "$D/$1.svg.tmpl" "$TMP/$1.svg"; }
png() { rsvg-convert "$@"; }

for s in logo wallpaper install-icon welcome glow; do svg "$s"; done
# фон входа/GRUB: те же обои, приглушённые
sed 's|</svg>|<rect width="1920" height="1080" fill="'"$BG"'" opacity="0.38"/></svg>|' "$TMP/wallpaper.svg" > "$TMP/login.svg"

# Обои и фон входа
B="$CH/usr/share/backgrounds/kroha"; mkdir -p "$B"
cp "$TMP/wallpaper.svg" "$B/wallpaper.svg"
png -w 1920 -h 1080 "$TMP/wallpaper.svg" -o "$B/wallpaper.png"
png -w 1366 -h 768 "$TMP/wallpaper.svg" -o "$B/wallpaper-1366x768.png"
png -w 1920 -h 1080 "$TMP/login.svg" -o "$B/login.png"

# Логотип и значок установщика
for name in logo install-icon; do
	icon="kroha-logo"; [ "$name" = install-icon ] && icon="kroha-install"
	mkdir -p "$CH/usr/share/icons/hicolor/scalable/apps"
	cp "$TMP/$name.svg" "$CH/usr/share/icons/hicolor/scalable/apps/$icon.svg"
	for s in 16 22 24 32 48 64 128 256; do
		mkdir -p "$CH/usr/share/icons/hicolor/${s}x${s}/apps"
		png -w "$s" -h "$s" "$TMP/$name.svg" -o "$CH/usr/share/icons/hicolor/${s}x${s}/apps/$icon.png"
	done
done
mkdir -p "$CH/usr/share/pixmaps"
png -w 256 -h 256 "$TMP/logo.svg" -o "$CH/usr/share/pixmaps/kroha-logo.png"
cp "$TMP/logo.svg" "$CH/usr/share/pixmaps/kroha-logo.svg"

# Calamares
C="$CH/etc/calamares/branding/kroha"; mkdir -p "$C"
png -w 128 -h 128 "$TMP/logo.svg" -o "$C/logo.png"
(cd "$TMP" && rsvg-convert -w 640 -h 220 welcome.svg -o "$C/welcome.png")

# Plymouth
P="$CH/usr/share/plymouth/themes/kroha"; mkdir -p "$P"
png -w 120 -h 120 "$TMP/logo.svg" -o "$P/logo.png"
png -w 360 -h 360 "$TMP/glow.svg" -o "$P/glow.png"
bar() { echo "<svg xmlns='http://www.w3.org/2000/svg' width='$1' height='$2'><rect width='$1' height='$2' rx='$(( $2 / 2 ))' fill='$3' $4/></svg>" > "$TMP/b.svg"; png "$TMP/b.svg" -o "$5"; }
bar 240 4 "$SURFACE_HI" "" "$P/bar-bg.png"
bar 240 4 "$ACCENT" "" "$P/bar.png"
bar 360 40 "$SURFACE" "stroke='$BORDER' stroke-width='2'" "$P/entry.png"

# GRUB: общие картинки для установленной системы и ISO
grub_assets() {
	local dir="$1"; mkdir -p "$dir"
	png -w 1920 -h 1080 "$TMP/login.svg" -o "$dir/background.png"
	png -w 72 -h 72 "$TMP/logo.svg" -o "$dir/logo.png"
	echo "<svg xmlns='http://www.w3.org/2000/svg' width='8' height='40'><rect width='8' height='40' fill='$ACCENT'/></svg>" > "$TMP/c.svg"
	echo "<svg xmlns='http://www.w3.org/2000/svg' width='12' height='40'><rect width='24' height='40' rx='12' fill='$ACCENT'/></svg>" > "$TMP/w.svg"
	echo "<svg xmlns='http://www.w3.org/2000/svg' width='12' height='40'><rect x='-12' width='24' height='40' rx='12' fill='$ACCENT'/></svg>" > "$TMP/e.svg"
	png "$TMP/c.svg" -o "$dir/select_c.png"
	png "$TMP/w.svg" -o "$dir/select_w.png"
	png "$TMP/e.svg" -o "$dir/select_e.png"
	local ranges="-r 0x20-0x7E,0xA0-0x17F,0x400-0x45F,0x2010-0x2027,0x2190-0x2193,0x25CF-0x25CF"
	local dv=/usr/share/fonts/truetype/dejavu
	# shellcheck disable=SC2086
	{
		grub-mkfont $ranges -s 14 -o "$dir/dejavu-14.pf2" "$dv/DejaVuSans.ttf"
		grub-mkfont $ranges -s 16 -o "$dir/dejavu-16.pf2" "$dv/DejaVuSans.ttf"
		grub-mkfont $ranges -s 16 -o "$dir/dejavu-bold-16.pf2" "$dv/DejaVuSans-Bold.ttf"
		grub-mkfont $ranges -s 24 -o "$dir/dejavu-bold-24.pf2" "$dv/DejaVuSans-Bold.ttf"
		grub-mkfont $ranges -s 14 -o "$dir/dejavu-mono-14.pf2" "$dv/DejaVuSansMono.ttf"
	}
}
grub_assets "$CH/usr/share/grub/themes/kroha"
grub_assets "$BL/live-theme"
cp "$CH/usr/share/grub/themes/kroha/background.png" "$BL/splash.png"

echo "Графика сгенерирована."
