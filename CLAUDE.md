# Kroha OS — свой лёгкий Linux-дистрибутив под конкретный ноутбук

> Этот файл — задание и правила для Claude Code (облачная сессия).
> Прочитай его целиком перед началом работы. Название «Kroha OS» — рабочее,
> оно задаётся в ОДНОМ месте (`config/os-release.env`), чтобы его легко было сменить.

## 0. Кто пользователь и как с ним общаться

- Пользователь говорит по-русски и не программист. Отвечай **по-русски**, просто,
  без лишнего жаргона. Каждую инструкцию для него давай по шагам ("нажми X, потом Y").
- Это **единственный компьютер пользователя**, на нём сейчас Linux mint и его файлы.
  Никогда не предлагай действия, которые молча сотрут диск. Установщик обязан
  явно предлагать «Установить рядом с Windows» и предупреждать о бэкапе.
- Пользователь не будет ничего собирать сам. Всё собирается в **GitHub Actions**,
  а пользователь только скачивает готовый `.iso` со страницы Releases.

## 1. Цель (что значит «готово»)

Готовый загрузочный **ISO-образ** с:
1. **Live-режимом** (можно загрузиться с флешки и попробовать без установки).
2. **Графическим установщиком** (Calamares) с ярлыком «Установить Kroha OS» на рабочем столе.
3. После установки — полноценная ОС: интернет (Wi-Fi + кабель), звук, браузер,
   файлы, видео, PDF, флешки, яркость/громкость с клавиш, сон при закрытии крышки,
   русский язык и раскладка (переключение Alt+Shift).
4. **Свой дизайн** везде: GRUB → загрузочная заставка → экран входа → рабочий стол →
   установщик. Единая палитра, свои обои, своё имя.
5. **Сильная оптимизация**: после входа в систему простой — **≤ 350 МБ ОЗУ**,
   загрузка до экрана входа на этом SSD — **≤ 20 с**.

## 2. Целевое железо (снято с реального ноутбука)

| Компонент | Что стоит | Что это значит для Linux |
|---|---|---|
| Модель | HP Laptop 15-bw0xx, BIOS Insyde F.30 (2018) | Меню загрузки — **F9**, BIOS — **F10**, меню старта — **Esc** |
| Прошивка | **UEFI** (64-бит) | Нужен UEFI-загрузчик (grub-efi + shim для Secure Boot). Legacy BIOS тоже оставить |
| CPU | AMD A10-9620P, 4 ядра, 2.5 ГГц (Bristol Ridge) | `amd64-microcode`, драйвер частоты `amd-pstate` не поддерживается → `acpi-cpufreq`, это нормально |
| ОЗУ | ~8 ГБ (7.47 доступно) | Хватает с запасом; добавить **zram** (lz4/zstd, 50% ОЗУ), swap-файл не нужен |
| Встроенная GPU | AMD Radeon R5 (Bristol Ridge, GCN 3) | Драйвер `amdgpu` (ядро, по умолчанию), `firmware-amd-graphics`, Mesa. VA-API для видео: `mesa-va-drivers` |
| Дискретная GPU | AMD Radeon R7 M340 (Oland, GCN 1) | Драйвер `radeon`, работает через PRIME. Должна **сама засыпать** (runtime PM). Никаких проприетарных драйверов |
| Диск | SSD Kingston A400 240 ГБ, SATA | ext4 с `noatime`, включить `fstrim.timer` |
| Wi-Fi | **Realtek RTL8723DE** (PCI 10ec:d723) | Драйвер `rtw88_8723de` (в ядре), прошивка из `firmware-realtek`. Известны обрывы → см. раздел 5 |
| Ethernet | Realtek RTL8168 | `r8169` + `firmware-realtek` |
| Bluetooth | Realtek (в составе 8723DE) | `firmware-realtek`, `bluez`; сервис включается по требованию |
| Звук | Realtek HDA + AMD HDMI HDA | PipeWire + WirePlumber, `pavucontrol` |
| Экран | **1366×768** | ВСЕ окна (особенно установщик!) должны помещаться в 768 px по высоте |

Пользователь называет ноутбук «очень слабым» — на Windows 10 он действительно тормозит,
но для лёгкого Linux этого железа хватает с запасом. Главное — не тащить тяжёлое
(GNOME, KDE, Snap, Flatpak, Electron-приложения по умолчанию).

## 3. Принятые архитектурные решения (не пересматривай без причины)

- **База: Debian 13 "trixie" (stable), amd64.** Стабильно, есть всё железо, долгие обновления.
- **Сборщик: `live-build`** (официальный инструмент Debian для live-ISO).
- **Компоненты репозитория:** `main contrib non-free-firmware` (без прошивок Wi-Fi не будет).
- **Графика: X11** (Wayland-композиторы тяжелее на GCN 1/3 и хуже с лёгкими DE).
- **Рабочее окружение — собственное, на лёгких кирпичиках:**
  - оконный менеджер **Openbox** (своя тема),
  - панель **tint2** (свой конфиг), меню **jgmenu**, лаунчер **rofi**,
  - уведомления **dunst**, рабочий стол/иконки **pcmanfm --desktop**,
  - **композитор picom включён** (решение пользователя, см. раздел 6a): размытие дока/панели/меню,
    скругления окон. Автоматически выключается без 3D-ускорения (nomodeset, виртуалка) и
    переключается пунктом «Эффекты вкл/выкл»,
  - экран входа **LightDM + lightdm-gtk-greeter** (своя тема и фон).
- **Тема GTK:** на основе `materia-gtk-theme` (или `arc-theme`), перекрашенная под нашу палитру
  через собственную тему `Kroha` (свой `gtk.css` для GTK3 + `gtkrc` для GTK2). GTK4/libadwaita-приложения не ставить.
- **Иконки:** `papirus-icon-theme`, папки перекрашены в наш акцентный цвет.
- **Установщик: Calamares** (`calamares`, `calamares-settings-debian` как основа) со своим branding.
- **Загрузка:** свой GRUB-тема + своя тема **Plymouth** (простая, script/two-step, без тяжёлой анимации).
- **Сборка ISO — только в GitHub Actions**, результат — GitHub Release.

## 4. Набор программ (минимальный, но «полноценный»)

Ставить только это (плюс зависимости, `--no-install-recommends` где возможно):

- Система: `linux-image-amd64`, `amd64-microcode`, `firmware-amd-graphics`, `firmware-realtek`,
  `firmware-misc-nonfree`, `network-manager`, `network-manager-gnome` (nm-applet),
  `pipewire-audio`, `wireplumber`, `pavucontrol`, `bluez`, `blueman`,
  `xfce4-power-manager` (крышка, яркость, батарея), `tlp`, `zram-tools`,
  `udisks2`, `gvfs`, `policykit-1-gnome` или `lxpolkit`, `xdg-user-dirs`, `xss-lock` + `light-locker`
- Интерфейс: `openbox`, `tint2`, `jgmenu`, `rofi`, `dunst`, `pcmanfm`, `lxappearance`, `arandr`,
  `lightdm`, `lightdm-gtk-greeter`, `plymouth`, `fonts-noto-core`, `fonts-noto-color-emoji`,
  `fonts-inter` (основной шрифт интерфейса), `fonts-jetbrains-mono` (терминал)
- Программы: `firefox-esr` (+ `firefox-esr-l10n-ru`), `lxterminal` или `xfce4-terminal`, `mousepad`,
  `mpv`, `viewnior`, `qpdfview` или `zathura-pdf-poppler`, `xarchiver` + `7zip` + `unzip`,
  `xfce4-screenshooter`, `galculator`, `synaptic` (для установки программ мышкой)
- Локаль: `locales` (ru_RU.UTF-8 по умолчанию), `console-setup`, `keyboard-configuration`
  (раскладки `us,ru`, переключение `grp:alt_shift_toggle`), часовой пояс по умолчанию `Europe/Moscow`
  (в установщике пользователь выберет свой).

**Не ставить:** cups, avahi, ModemManager, snapd, flatpak, libreoffice (тяжёлый — можно
оставить пункт «Установить офис» в приветственном окне), GNOME/KDE-пакеты, pulseaudio.

## 5. Оптимизация и фиксы под это железо

- `zram-tools`: `ALGO=zstd`, `PERCENT=50`.
- `/etc/sysctl.d/90-kroha.conf`: `vm.swappiness=100` (это правильно для zram), `vm.vfs_cache_pressure=50`.
- fstab в установщике: ext4 `noatime`; `systemctl enable fstrim.timer`.
- Отключить/не ставить лишние сервисы; проверь `systemd-analyze blame` в QEMU и убери всё, что > 1 с и не нужно.
- `GRUB_TIMEOUT=2`, `quiet splash loglevel=3`.
- Wi-Fi RTL8723DE — `/etc/modprobe.d/rtw88.conf`:
  ```
  options rtw88_pci disable_aspm=y
  options rtw88_core disable_lps_deep=y
  ```
  (известная проблема с обрывами связи на этом чипе).
- Дискретная R7 M340: убедиться, что `radeon` runtime PM работает (`/sys/kernel/debug/vgaswitcheroo/switch`
  показывает `DynOff`). Добавить пункт в документацию: запуск игры на дискретке — `DRI_PRIME=1 игра`.
- Firefox: в `/usr/lib/firefox-esr/distribution/policies.json` — русский язык, отключить телеметрию,
  предустановить uBlock Origin; включить аппаратное ускорение видео (VA-API).
- `journald`: `SystemMaxUse=50M`.
- Автовход в live-сессии (пользователь `kroha`, без пароля), в установленной системе — обычный вход.

## 6. Дизайн (стиль «Kroha»)

Идея: **тёплый тёмный** интерфейс, спокойный, крупный, читаемый на 1366×768.

- Палитра (держать в одном файле `design/palette.env`, всё генерировать из неё):
  - фон тёмный `#1E1F26`, панель `#272833`, поверхность `#2F3140`
  - текст `#E8E6E3`, второстепенный текст `#9A9BA8`
  - **акцент `#FF8A3D`** (тёплый оранжевый), второй акцент `#4FC1B0`
  - ошибка `#E5534B`, успех `#57AB5A`
- Шрифт интерфейса: Inter 10 pt, терминал: JetBrains Mono 10 pt.
- Скругления 8 px (окна 12 px, док 18 px — через picom).
- **Обои:** нарисовать свои (SVG в репозитории → PNG 1366×768 и 1920×1080 при сборке, `rsvg-convert`).
  Абстрактная мягкая форма/волна в цветах палитры + маленький логотип. Никаких чужих картинок.
- **Логотип:** простой SVG (например, стилизованная буква «К» или капля/лист) в акцентном цвете.
- Везде одна стилистика: тема GRUB, Plymouth, LightDM, Openbox (заголовки окон), tint2,
  rofi, dunst, jgmenu, Calamares branding, `/etc/os-release` (`NAME="Kroha OS"`), `neofetch`/`fastfetch` логотип.
- **Две панели tint2** (см. 6a): верхняя строка 30 px (логотип-кнопка слева, часы по центру,
  трей справа: раскладка, сеть, звук, батарея, кнопка питания) и **парящий док снизу по центру**
  (закреплённые программы + открытые окна, только иконки, подчёркивание у запущенных).
- Горячие клавиши (Openbox `rc.xml`): Win — меню, Win+E — файлы, Win+T — терминал, Win+L — блокировка,
  Print — скриншот, медиа-клавиши громкости/яркости, Alt+Tab, Win+стрелки — привязка окон к краям.
- **Calamares:** окно максимум **1000×640**, `windowExpanding: noexpand`, слайдшоу из 3–4 своих слайдов
  на русском, свои цвета боковой панели.

## 6a. Решение пользователя: «максимально не похоже на Mint и Debian»

Пользователь попросил, чтобы дизайн резко отличался от Linux Mint (одна панель снизу) и Debian
(GNOME), и чтобы был **док с сильным размытием**. Поэтому:
- верхняя тонкая строка + нижний парящий док (две копии tint2, полупрозрачные);
- **picom** (backend glx, blur `dual_kawase`) размывает док, верхнюю строку, rofi, dunst, меню;
- лаунчер — полноэкранная сетка rofi с поиском и вкладками «Программы / Открытые окна / Выполнить»;
- яркие обои с цветными пятнами (чтобы размытие было заметно);
- эталон внешнего вида — макет `design/mockup/desktop.html.tmpl`
  (рендер: `scripts/render-mockup.sh` → `out/mockup/desktop.png`, `launcher.png`).
Цена: +20–40 МБ ОЗУ и немного GPU. Если нет аппаратного ускорения — picom не запускается.

## 7. Структура репозитория (создай её)

```
.
├── CLAUDE.md
├── README.md                     # инструкция для пользователя НА РУССКОМ (см. раздел 10)
├── config/os-release.env         # название, версия, кодовое имя — единственный источник
├── design/                       # palette.env, logo.svg, wallpaper.svg, скрипты генерации
├── build/
│   ├── auto/config               # вызов lb config со всеми параметрами
│   ├── config/package-lists/*.list.chroot
│   ├── config/includes.chroot/   # /etc, /usr/share/themes/Kroha, /etc/skel/.config/... и т.д.
│   ├── config/hooks/normal/*.hook.chroot   # настройки внутри chroot (сервисы, локаль, перекраска иконок)
│   └── config/bootloaders/       # свои grub/isolinux темы
├── scripts/
│   ├── build-iso.sh              # полная сборка (запускается в CI внутри debian:trixie)
│   └── test-qemu.sh              # смоук-тест образа в QEMU
└── .github/workflows/build-iso.yml
```

## 8. CI: сборка ISO в GitHub Actions

Ориентир для `.github/workflows/build-iso.yml` (доработай, но сохрани суть):

```yaml
name: build-iso
on:
  push:
    branches: ["**"]
    tags: ["v*"]
  pull_request:
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-24.04
    timeout-minutes: 120
    container:
      image: debian:trixie
      options: --privileged          # live-build нужны mount/chroot
    steps:
      - uses: actions/checkout@v4
      - run: apt-get update && apt-get install -y live-build librsvg2-bin xorriso squashfs-tools ca-certificates
      - run: bash scripts/build-iso.sh
      - run: cd out && sha256sum *.iso > SHA256SUMS
      - uses: actions/upload-artifact@v4
        with: { name: kroha-iso, path: out/*, retention-days: 14 }
      - if: startsWith(github.ref, 'refs/tags/v') || github.ref == 'refs/heads/main'
        uses: softprops/action-gh-release@v2
        with:
          tag_name: ${{ startsWith(github.ref, 'refs/tags/') && github.ref_name || 'latest' }}
          prerelease: ${{ github.ref == 'refs/heads/main' }}
          files: out/*
```

- У раннера ~14 ГБ свободного места — этого хватает; если упрёшься, добавь шаг очистки.
- Лимит файла в Release — 2 ГБ. Цель — **ISO ≤ 1.5 ГБ**.
- Второй job (после сборки): `test-qemu.sh` — загрузить ISO в QEMU (OVMF для UEFI и без него для BIOS),
  `-nographic`/serial-лог, убедиться, что система дошла до LightDM/графической цели
  (например, по `systemctl is-active graphical.target` через автозапускаемый в live скрипт, пишущий в serial).
  Без KVM будет медленно — дай таймаут 15 мин.

## 9. Как работать в облачной сессии

1. **Не пытайся** собрать полный ISO внутри своей песочницы, если там нет root/loop/привилегий —
   собирай через CI. Локально проверяй: `shellcheck`, `bash -n`, валидность YAML/XML/JSON,
   генерацию обоев из SVG.
2. Работай итерациями, каждая заканчивается **зелёной сборкой в CI**:
   1. Скелет репо + CI собирает «голый» live-ISO Debian с Openbox → проверь, что ISO появляется.
   2. Пакеты из раздела 4 + оптимизации и фиксы из раздела 5.
   3. Дизайн из раздела 6 (палитра → темы → обои → GRUB/Plymouth/LightDM).
   4. Calamares + branding + ярлык установки + режим «рядом с Windows».
   5. QEMU-смоук-тест в CI, замер ОЗУ (`free -m` после входа → в serial-лог).
   6. README для пользователя.
3. После каждой итерации кратко по-русски пиши пользователю: что сделано, где скачать ISO, что дальше.
4. Если сборка упала — читай лог CI сам и чини, не перекладывай это на пользователя.
5. Не выдумывай результаты: если не проверил на реальном железе, так и пиши «проверено только в QEMU».

## 10. README.md для пользователя (обязательно, по-русски, по шагам)

Должен объяснять:
1. Где скачать ISO (ссылка на Releases) и как проверить SHA256 (по желанию).
2. **Сделать бэкап** важных файлов из Windows.
3. Записать ISO на флешку (≥ 4 ГБ) через **Rufus** (режим «DD-образ», схема GPT, UEFI) или Ventoy.
4. Вставить флешку, включить ноутбук, жать **F9** → выбрать флешку.
   Если не грузится — зайти в BIOS (**F10**) и выключить **Secure Boot** (или, если у нас shim, — оставить).
5. В live-системе нажать на рабочем столе «Установить Kroha OS», выбрать
   «Установить рядом с Windows» (или «Стереть диск», если Windows больше не нужна — с предупреждением).
6. Что делать, если нет Wi-Fi / нет звука / чёрный экран (параметр `nomodeset` в GRUB как аварийный).

## 11. Чего НЕ делать

- Не писать ядро/ОС с нуля, не брать Arch/Gentoo/LFS — нужен надёжный результат для обычного человека.
- Не копировать чужие темы/логотипы/обои «как есть» и не выдавать чужой бренд за свой;
  использовать только свободные пакеты как основу и своё оформление поверх.
- Не включать тяжёлые анимации и сервисы «для красоты» (исключение — picom с размытием, см. 6a).
- Не ломать установку рядом с Windows (не трогать EFI-раздел Windows, кроме добавления своей записи).
