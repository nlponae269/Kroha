#!/bin/bash
# Смоук-тест ISO в QEMU: загружается с образа как с флешки/диска (через GRUB),
# ждёт отчёт службы kroha-smoketest в последовательном порту и делает скриншот.
#   scripts/test-qemu.sh <iso> [uefi|bios] [каталог-результатов]
# Код возврата 0 — рабочий стол поднялся (RESULT=PASS).
set -uo pipefail
ISO="${1:?укажи путь к ISO}"
MODE="${2:-uefi}"
RES="${3:-out/qemu-$MODE}"
TIMEOUT="${TIMEOUT:-900}"
mkdir -p "$RES"
LOG="$RES/serial.log"; MON="$RES/monitor.sock"
rm -f "$LOG" "$MON"

accel="-accel tcg,thread=multi"
if [ -w /dev/kvm ]; then accel="-accel kvm -cpu host"; echo "KVM есть — будет быстро"; else echo "KVM нет — эмуляция, это медленно"; fi

fw=()
if [ "$MODE" = uefi ]; then
	code=""
	for c in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd /usr/share/ovmf/OVMF.fd; do [ -f "$c" ] && { code="$c"; break; }; done
	[ -n "$code" ] || { echo "Нет OVMF (apt-get install ovmf)"; exit 2; }
	vars="$RES/OVMF_VARS.fd"
	for v in /usr/share/OVMF/OVMF_VARS_4M.fd /usr/share/OVMF/OVMF_VARS.fd; do [ -f "$v" ] && { cp "$v" "$vars"; break; }; done
	if [ -f "$vars" ]; then
		fw=(-drive "if=pflash,format=raw,readonly=on,file=$code" -drive "if=pflash,format=raw,file=$vars")
	else
		fw=(-bios "$code")
	fi
fi

# shellcheck disable=SC2086
qemu-system-x86_64 $accel -machine q35 -m 2048 -smp 2 \
	"${fw[@]}" \
	-drive "file=$ISO,media=cdrom,readonly=on" -boot d \
	-vga virtio -display none \
	-netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
	-device intel-hda -device hda-duplex \
	-serial "file:$LOG" -monitor "unix:$MON,server,nowait" &
QPID=$!

shot() {
	python3 - "$MON" "$1" <<'PY'
import socket, sys, time
s = socket.socket(socket.AF_UNIX); s.connect(sys.argv[1]); time.sleep(0.3); s.recv(65536)
s.sendall(("screendump %s\n" % sys.argv[2]).encode()); time.sleep(2); s.close()
PY
}

result="TIMEOUT"
for ((t = 0; t < TIMEOUT; t += 10)); do
	sleep 10
	kill -0 $QPID 2>/dev/null || { result="QEMU-DIED"; break; }
	if grep -q "KROHA-SMOKE: RESULT=" "$LOG" 2>/dev/null; then
		result=$(grep -o "RESULT=[A-Z]*" "$LOG" | tail -n1 | cut -d= -f2); break
	fi
	if [ $((t % 120)) -eq 0 ] && [ $t -gt 0 ]; then echo "... ждём ${t} с"; fi
done

[ -S "$MON" ] && shot "$PWD/$RES/screen.ppm" 2>/dev/null
if [ -f "$RES/screen.ppm" ]; then
	if command -v pnmtopng >/dev/null; then pnmtopng "$RES/screen.ppm" > "$RES/screen.png" && rm -f "$RES/screen.ppm"
	elif command -v convert >/dev/null; then convert "$RES/screen.ppm" "$RES/screen.png" && rm -f "$RES/screen.ppm"; fi
fi
kill $QPID 2>/dev/null; wait $QPID 2>/dev/null

echo "===== serial ($MODE) ====="
grep "KROHA-SMOKE" "$LOG" || tail -n 40 "$LOG"
echo "===== итог ($MODE): $result ====="
{
	echo "mode=$MODE result=$result"
	grep -o "used-mb=[0-9]*" "$LOG" | tail -n1
	grep "analyze: Startup finished" "$LOG" | tail -n1
} > "$RES/summary.txt"
cat "$RES/summary.txt"
[ "$result" = PASS ]
