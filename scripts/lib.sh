#!/bin/bash
# Общие функции сборки Kroha OS: загрузка палитры/названия и рендер шаблонов.
# Шаблон — любой файл *.tmpl. В нём @ИМЯ@ заменяется значением переменной
# из config/os-release.env или design/palette.env. Для каждого цвета
# автоматически есть @ИМЯ_RGB@ ("255, 138, 61") и @ИМЯ_HEX@ (без решётки).

KROHA_ROOT="${KROHA_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
KROHA_ENV_FILES=("$KROHA_ROOT/config/os-release.env" "$KROHA_ROOT/design/palette.env")
KROHA_SED_SCRIPT=""

kroha_load_vars() {
	local f name value r g b
	local -a names=()
	for f in "${KROHA_ENV_FILES[@]}"; do
		set -a
		# shellcheck disable=SC1090
		. "$f"
		set +a
		while IFS= read -r name; do names+=("$name"); done \
			< <(sed -n 's/^\([A-Z][A-Z0-9_]*\)=.*/\1/p' "$f")
	done
	KROHA_SED_SCRIPT="$(mktemp)"
	for name in "${names[@]}"; do
		value="${!name}"
		printf 's|@%s@|%s|g\n' "$name" "$(printf '%s' "$value" | sed 's/[|&\\]/\\&/g')" >> "$KROHA_SED_SCRIPT"
		if [[ "$value" =~ ^#([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})([0-9A-Fa-f]{2})$ ]]; then
			r=$((16#${BASH_REMATCH[1]})); g=$((16#${BASH_REMATCH[2]})); b=$((16#${BASH_REMATCH[3]}))
			printf 's|@%s_RGB@|%d, %d, %d|g\n' "$name" "$r" "$g" "$b" >> "$KROHA_SED_SCRIPT"
			printf 's|@%s_HEX@|%s|g\n' "$name" "${value#\#}" >> "$KROHA_SED_SCRIPT"
		fi
	done
	export KROHA_SED_SCRIPT
}

# kroha_render <шаблон> <результат>
kroha_render() {
	[ -n "$KROHA_SED_SCRIPT" ] || kroha_load_vars
	mkdir -p "$(dirname "$2")"
	sed -f "$KROHA_SED_SCRIPT" "$1" > "$2"
	if grep -qE '@[A-Z][A-Z0-9_]*@' "$2"; then
		echo "ОШИБКА: в $2 остались незаменённые переменные:" >&2
		grep -noE '@[A-Z][A-Z0-9_]*@' "$2" >&2
		return 1
	fi
}

# kroha_render_tree <каталог>: все *.tmpl -> файл без .tmpl (с сохранением прав)
kroha_render_tree() {
	local t out
	while IFS= read -r -d '' t; do
		out="${t%.tmpl}"
		kroha_render "$t" "$out"
		chmod --reference="$t" "$out"
		rm -f "$t"
	done < <(find "$1" -type f -name '*.tmpl' -print0)
}
