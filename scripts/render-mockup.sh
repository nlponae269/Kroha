#!/bin/bash
# Рендерит макет главного экрана Kroha OS в PNG (1366×768):
#   out/mockup/desktop.png   — рабочий стол
#   out/mockup/launcher.png  — открыт лаунчер
# Нужны: rsvg-convert, papirus-icon-theme (или ICON_ROOT=путь к /usr/share/icons),
# node + playwright (Chromium) для скриншота. Без node — только HTML.
set -euo pipefail
KROHA_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$KROHA_ROOT/scripts/lib.sh"
kroha_load_vars

ICON_ROOT="${ICON_ROOT:-/usr/share/icons}"
OUT="${1:-$KROHA_ROOT/out/mockup}"
PAP="$ICON_ROOT/Papirus-Dark"
mkdir -p "$OUT/icons/apps" "$OUT/icons/places" "$OUT/icons/panel"

kroha_render "$KROHA_ROOT/design/mockup/desktop.html.tmpl" "$OUT/desktop.html"
kroha_render "$KROHA_ROOT/design/logo.svg.tmpl" "$OUT/logo.svg"
kroha_render "$KROHA_ROOT/design/wallpaper.svg.tmpl" "$OUT/wallpaper.svg"
rsvg-convert -w 1366 -h 768 "$OUT/wallpaper.svg" -o "$OUT/wallpaper.png"

for n in firefox-esr system-file-manager utilities-terminal accessories-text-editor mpv \
	image-viewer qpdfview accessories-calculator xarchiver org.xfce.screenshooter synaptic \
	multimedia-volume-control blueman utilities-system-monitor; do
	cp -L "$PAP/64x64/apps/$n.svg" "$OUT/icons/apps/"
done
# Папки перекрашиваются в акцентный цвет так же, как в самой системе (hook 0300)
for n in user-home user-trash user-desktop folder-download folder-documents folder-pictures \
	folder-music folder-videos folder-templates folder-publicshare; do
	sed -e "s/#5294e2/$ACCENT/gI" -e "s/#4877b1/$ACCENT_DARK/gI" \
		"$(readlink -f "$PAP/48x48/places/$n.svg")" > "$OUT/icons/places/$n.svg"
done
for n in network-wireless-signal-good audio-volume-high battery-080 system-shutdown-panel; do
	cp -L "$PAP/22x22/panel/$n.svg" "$OUT/icons/panel/"
done
cat > "$OUT/icons/panel/search.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16"><circle cx="6.5" cy="6.5" r="5" fill="none" stroke="$TEXT" stroke-width="2"/><path d="M10.5 10.5 15 15" stroke="$TEXT" stroke-width="2" stroke-linecap="round"/></svg>
EOF

if command -v node >/dev/null; then
	node - "$OUT" <<'EOF'
const { chromium } = require('playwright');
const out = process.argv[2];
(async () => {
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: 1366, height: 768 }, deviceScaleFactor: Number(process.env.SCALE || 1) });
  for (const [hash, name] of [['', 'desktop'], ['#launcher', 'launcher']]) {
    await p.goto('file://' + out + '/desktop.html' + hash);
    await p.waitForTimeout(400);
    await p.screenshot({ path: `${out}/${name}.png` });
  }
  await b.close();
})();
EOF
	echo "Готово: $OUT/desktop.png, $OUT/launcher.png"
else
	echo "node не найден — открой $OUT/desktop.html в браузере"
fi
