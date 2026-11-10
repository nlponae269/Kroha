#!/bin/bash
# Полная сборка ISO Kroha OS. Запускается от root внутри Debian trixie
# (в CI — контейнер debian:trixie с --privileged).
#   scripts/build-iso.sh            → out/kroha-os-<версия>-amd64.iso
# Переменные: WORK (рабочий каталог), OUT (куда положить ISO),
#             KROHA_MIRROR (зеркало Debian), KROHA_CACHE (кэш пакетов live-build).
set -euo pipefail
KROHA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KROHA_ROOT/scripts/lib.sh"
kroha_load_vars

WORK="${WORK:-$KROHA_ROOT/work}"
OUT="${OUT:-$KROHA_ROOT/out}"
KROHA_CACHE="${KROHA_CACHE:-$KROHA_ROOT/.cache/live-build}"

[ "$(id -u)" -eq 0 ] || { echo "Нужен root (live-build делает chroot и mount)"; exit 1; }
for cmd in lb rsvg-convert grub-mkfont xorriso mksquashfs; do
	command -v "$cmd" >/dev/null || { echo "Не найдено: $cmd (apt-get install live-build librsvg2-bin grub-common xorriso squashfs-tools)"; exit 1; }
done

echo "==> Сборка $OS_PRETTY_NAME (Debian $DEBIAN_SUITE)"
if [ -d "$WORK" ]; then
	(cd "$WORK" && lb clean --purge >/dev/null 2>&1) || true
	rm -rf "$WORK"
fi
mkdir -p "$WORK" "$OUT" "$KROHA_CACHE"
cp -a "$KROHA_ROOT/build/." "$WORK/"
ln -sfn "$KROHA_CACHE" "$WORK/cache"

echo "==> Шаблоны (палитра + название)"
mkdir -p "$WORK/config/includes.chroot/usr/share/kroha"
cp "$KROHA_ROOT/design/palette.env" "$WORK/config/includes.chroot/usr/share/kroha/palette.env"
cp "$KROHA_ROOT/config/os-release.env" "$WORK/config/includes.chroot/usr/share/kroha/os-release.env"
kroha_render_tree "$WORK/config"

echo "==> Графика (обои, логотип, GRUB, Plymouth, Calamares)"
"$KROHA_ROOT/scripts/gen-assets.sh" "$WORK/config/includes.chroot" "$WORK/config/bootloaders/grub-pc"

echo "==> live-build"
cd "$WORK"
lb config
# Кэш иконок нужен: без него лаунчер с Papirus открывается заметно медленнее
rm -f config/hooks/normal/9000-remove-gnome-icon-cache.hook.chroot
lb build

iso_src="$(find "$WORK" -maxdepth 1 -name '*.iso' | head -n1)"
[ -n "$iso_src" ] || { echo "ISO не найден — смотри $WORK/build.log"; exit 1; }
iso="$OUT/${ISO_BASENAME}-${OS_VERSION}-amd64.iso"
mv "$iso_src" "$iso"
cp "$WORK"/*.packages "$OUT/${ISO_BASENAME}-${OS_VERSION}-amd64.packages" 2>/dev/null || true

size_mb=$(( $(stat -c %s "$iso") / 1024 / 1024 ))
echo "==> Готово: $iso (${size_mb} МБ)"
if [ "$size_mb" -gt 1536 ]; then
	echo "ВНИМАНИЕ: ISO больше 1.5 ГБ (цель ≤ 1536 МБ)"
fi
