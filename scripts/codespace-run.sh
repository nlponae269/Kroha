#!/bin/bash
# Запуск Kroha OS внутри GitHub Codespaces: скачивает ISO из последнего релиза,
# стартует QEMU и noVNC на порту 6080 (экран Kroha в браузере).
set -uo pipefail
D="$HOME/kroha"; mkdir -p "$D"; cd "$D" || exit 1
LOG="$D/run.log"; exec >>"$LOG" 2>&1
echo "=== $(date) запуск"

iso=$(find . -maxdepth 1 -name "kroha-os-*-amd64.iso" -printf "%f\n" | sort | tail -n1)
if [ -z "$iso" ]; then
	echo "Скачиваю ISO из последнего релиза…"
	gh release download --repo "${GITHUB_REPOSITORY:-nlponae269/Kroha}" --pattern 'kroha-os-*-amd64.iso' --clobber || exit 1
	iso=$(find . -maxdepth 1 -name "kroha-os-*-amd64.iso" -printf "%f\n" | sort | tail -n1)
fi
echo "ISO: $iso"

pkill -f qemu-system-x86_64 || true
pkill -f websockify || true
sleep 1

accel="-accel tcg,thread=multi"
if [ -e /dev/kvm ]; then sudo chmod 666 /dev/kvm 2>/dev/null; [ -w /dev/kvm ] && accel="-accel kvm -cpu host"; fi
echo "Ускорение: $accel"
cp /usr/share/OVMF/OVMF_VARS_4M.fd "$D/vars.fd"
[ -f "$D/disk.qcow2" ] || qemu-img create -f qcow2 "$D/disk.qcow2" 20G

# shellcheck disable=SC2086
nohup qemu-system-x86_64 $accel -machine q35 -m 4096 -smp "$(nproc)" \
	-drive if=pflash,format=raw,readonly=on,file=/usr/share/OVMF/OVMF_CODE_4M.fd \
	-drive if=pflash,format=raw,file="$D/vars.fd" \
	-drive file="$D/disk.qcow2",if=virtio \
	-drive file="$D/$iso",media=cdrom,readonly=on -boot d \
	-device virtio-vga,xres=1280,yres=720 -device qemu-xhci -device usb-tablet -device usb-kbd \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
	-vnc 127.0.0.1:1 >"$D/qemu.log" 2>&1 </dev/null &

# Страница: сразу открывает экран Kroha
W="$D/web"; rm -rf "$W"; cp -r /usr/share/novnc "$W"
cat > "$W/index.html" <<'HTML'
<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Kroha OS</title>
<meta http-equiv="refresh" content="0; url=vnc.html?autoconnect=true&resize=scale&reconnect=true&reconnect_delay=3000&path=websockify">
<p style="font-family:sans-serif">Подключаюсь к Kroha OS… <a href="vnc.html?autoconnect=true&resize=scale&reconnect=true&path=websockify">нажми, если не открылось</a></p>
HTML
nohup websockify --web "$W" 0.0.0.0:6080 127.0.0.1:5901 >"$D/websockify.log" 2>&1 </dev/null &
echo "Готово: открой вкладку «Порты» → 6080 (Kroha OS)"
