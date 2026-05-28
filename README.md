# RPi5 Network Install — локальный сервер

Сервер для Network Install Raspberry Pi 5 через EEPROM.
Раздаёт официальный `boot.img` + `boot.sig` и кастомный `os_list.json`.

## Быстрый старт на роутере

```bash
# 1. Установить lighttpd
sudo pacman -S lighttpd          # Arch
# или
sudo apt install lighttpd        # Debian/Ubuntu
# или
sudo apk add lighttpd            # Alpine

# 2. Запустить инициализацию
sudo ./scripts/netinstall-init.sh

# 3. Всё. lighttpd запущен на порту 80.
```

## Настройка EEPROM на RPi5

Подключите RPi5 к монитору и клавиатуре, выполните:

```bash
sudo rpi-eeprom-config --edit
```

Приведите конфиг к виду:

```
[all]
BOOT_ORDER=0xf21
HTTP_HOST=192.168.1.1          # IP роутера с lighttpd
HTTP_PATH=/boot
IMAGER_REPO_URL=http://192.168.1.1/os_list.json
NET_INSTALL_AT_POWER_ON=1
```

Перезагрузите RPi5. На экране появится Network Install → Space → N → выберите Arch Linux ARM.

## Структура файлов

```
/srv/netinstall/
├── boot/
│   ├── boot.img       # официальный образ rpi-imager
│   └── boot.sig       # RSA-подпись
├── www/
│   └── os_list.json   # список ОС для Imager
├── images/            # кеш образов (offline-режим)
└── scripts/
    ├── update-os-list.sh   # синк os_list.json из GitHub
    └── cache-images.sh     # загрузка образов локально
```

## Обновление os_list.json

При выходе нового релиза Arch Linux ARM:

```bash
sudo ./scripts/update-os-list.sh
```

Это скачает свежий `os_list.json` из GitHub Releases
и обновит `/srv/netinstall/www/os_list.json`.

## Полный offline (опционально)

```bash
sudo ./scripts/cache-images.sh 192.168.1.1 80
```

Скрипт скачает все образы из `os_list.json` локально,
пропишет в `os_list.json` локальные URL вместо GitHub.

## Параметры EEPROM

Основано на [официальной документации](https://www.raspberrypi.com/documentation/computers/raspberry-pi.html#raspberry-pi-bootloader-configuration).

| Параметр | Значение | Описание |
|----------|----------|----------|
| `BOOT_ORDER` | `0xf21` | Network → USB → SD → restart |
| `HTTP_HOST` | IP роутера | Хост для boot.img |
| `HTTP_PATH` | `/boot` | Путь до boot.img на сервере |
| `IMAGER_REPO_URL` | URL os_list.json | Откуда Imager берёт список ОС |
| `NET_INSTALL_AT_POWER_ON` | `1` | Показывать меню при загрузке |
