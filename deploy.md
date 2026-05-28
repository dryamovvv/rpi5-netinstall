# Deploy: RPi5 Network Install на Keenetic Hopper SE

## Характеристики Hopper SE (KN-3812)

| Параметр | Значение |
|----------|----------|
| CPU | MT7981B (Filogic 820) — 2× ARM Cortex-A53 @ 1.3 ГГц |
| RAM | 512 MB DDR4 |
| Архитектура | **aarch64** |
| USB | USB 3.0 |
| Накопитель | SSD 1 TB (через USB) |

## План развёртывания

### Шаг 1. Подготовка SSD (на ПК)

SSD нужно отформатировать в **ext4** — Entware требует Linux-файловую систему
с поддержкой chmod/chown и симлинков.

```bash
# Определить диск (например /dev/sdX)
sudo fdisk -l

# Создать один раздел ext4 на весь диск
sudo parted /dev/sdX mklabel gpt
sudo parted /dev/sdX mkpart primary ext4 0% 100%
sudo mkfs.ext4 /dev/sdX1
sudo e2label /dev/sdX1 NETINSTALL
```

Вставить SSD в USB-порт роутера.

### Шаг 2. Включить компоненты KeeneticOS (веб-интерфейс)

Зайти в веб-интерфейс роутера (`http://192.168.1.1`):

1. **Общие настройки → Обновления и компоненты → Компоненты ОС**
2. Установить:
   - **Файловая система Ext4** (`ext4`)
   - **Поддержка открытых пакетов** (`opkg`)
   - **Сервер SMB** (`samba`) — опционально, для просмотра файлов по сети

После установки компонентов SSD появится на странице **Приложения → Диски и принтеры**.

### Шаг 3. Установка Entware

Есть два варианта:

#### Вариант A — автоматическая (рекомендуется)

Зайти в CLI роутера по адресу `http://192.168.1.1/a` (встроенный терминал):

```
opkg disk storage:/ https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz
```

Дождаться в системном журнале сообщения:

> `[5/5] Установка системы пакетов "Entware" завершена!`

#### Вариант B — ручная (offline)

1. Скачать установщик: https://bin.entware.net/aarch64-k3.10/installer/aarch64-installer.tar.gz
2. В веб-интерфейсе зайти в **Приложения → Диски и принтеры**, открыть SSD
3. Создать папку `install`, положить в неё `aarch64-installer.tar.gz`
4. Перейти в **Приложения → Менеджер пакетов OPKG**
5. В поле **Накопитель** выбрать свой SSD
6. В поле **Сценарий initrc** ввести `/opt/etc/init.d/rc.unslung`
7. Нажать **Сохранить**
8. Проверить системный журнал — дождаться завершения установки

### Шаг 4. Доступ по SSH (опционально, для отладки)

После установки Entware на роутере открывается SSH на порту **222**:

```bash
ssh root@192.168.1.1 -p 222
```

Пароль по умолчанию: `keenetic`

Сменить пароль сразу:
```bash
passwd
```

### Шаг 5. Установка lighttpd

```bash
# Подключиться по SSH
ssh root@192.168.1.1 -p 222

# Обновить список пакетов
opkg update

# Установить lighttpd
opkg install lighttpd

# Проверить, что lighttpd запущен
/opt/etc/init.d/S80lighttpd check
```

### Шаг 6. Разместить файлы netinstall

SSD будет смонтирован автоматически. Путь монтирования можно узнать в веб-интерфейсе
(Приложения → Диски и принтеры → SSD) — обычно это `/media/DISK_A1` или `/media/sda1`.

```bash
# Определить точку монтирования SSD
ls /media/

# Создать структуру каталогов
mkdir -p /media/DISK_A1/netinstall/{boot,www,images}

# Скопировать boot.img + boot.sig (предварительно скачать bootstrap.sh на ПК)
# Зайти на роутер по SMB или через scp
```

**Проще всего через scp с ПК** (потребуется сначала настроить SSH на роутере):

```bash
# На ПК — скопировать файлы на роутер
scp -P 222 /home/dryamov/Repositories/netinstall/os_list.json \
  root@192.168.1.1:/media/DISK_A1/netinstall/www/

scp -P 222 /path/to/boot.img \
  root@192.168.1.1:/media/DISK_A1/netinstall/boot/

scp -P 222 /path/to/boot.sig \
  root@192.168.1.1:/media/DISK_A1/netinstall/boot/
```

### Шаг 7. Настройка lighttpd

Отредактировать `/opt/etc/lighttpd/lighttpd.conf`:

```lighttpd
server.modules = (
    "mod_access",
    "mod_alias",
    "mod_staticfile",
)

server.document-root        = "/media/DISK_A1/netinstall/www"
server.upload-dirs          = ("/tmp")
server.errorlog             = "/opt/var/log/lighttpd/error.log"
server.stat-cache-engine    = "simple"
server.max-connections      = 256

# Важно: порт 80 занят веб-интерфейсом Keenetic
# Используем порт 8080 → в EEPROM указываем HTTP_PORT=8080
server.port                 = 8080
server.bind                 = "0.0.0.0"

# boot.img и boot.sig
alias.url = (
    "/boot/" => "/media/DISK_A1/netinstall/boot/",
)

# OS images (offline-режим)
# alias.url += ( "/images/" => "/media/DISK_A1/netinstall/images/" )

mimetype.assign = (
    ".img"  => "application/octet-stream",
    ".sig"  => "application/octet-stream",
    ".xz"   => "application/x-xz",
    ".json" => "application/json",
    ""      => "application/octet-stream",
)

dir-listing.activate = "disable"
```

Перезапустить lighttpd:

```bash
/opt/etc/init.d/S80lighttpd restart
# Добавить в автозагрузку (если ещё не добавлен)
/opt/etc/init.d/S80lighttpd enable
```

Проверить:

```bash
curl http://192.168.1.1:8080/os_list.json
curl -I http://192.168.1.1:8080/boot/boot.img
```

### Шаг 8. Настройка EEPROM на RPi5

Подключить RPi5 к питанию, клавиатуре, монитору. Выполнить:

```bash
sudo rpi-eeprom-config --edit
```

Привести к виду:

```
[all]
BOOT_ORDER=0xf21
HTTP_HOST=192.168.1.1
HTTP_PORT=8080
HTTP_PATH=/boot
IMAGER_REPO_URL=http://192.168.1.1:8080/os_list.json
NET_INSTALL_AT_POWER_ON=1
```

Перезагрузить RPi5.

### Шаг 9. Первая загрузка

1. RPi5 загружается → видит DHCP → получает IP
2. Скачивает `http://192.168.1.1:8080/boot/boot.img` (и boot.sig для проверки)
3. Запускается Raspberry Pi Imager
4. Imager читает `IMAGER_REPO_URL` из EEPROM
5. Скачивает `os_list.json` → видит Arch Linux ARM
6. Space → N → выбираете Arch Linux → Flash

## Схема работы

```
RPi5                              Keenetic Hopper SE (роутер)
─────                             ──────────────────────────
                                   ┌─────────────────────┐
  DHCP ──────────→ IP (192.168.1.x)│  KeeneticOS         │
                                   │  192.168.1.1:80     │
  GET /boot/boot.img ──→ ──────→ │  ┌───────────────┐  │
  GET /boot/boot.sig  ──→       │  │ lighttpd       │  │
  GET /os_list.json   ──→       │  │ 192.168.1.1    │  │
                                   │  :8080           │  │
  (Imager показывает              │  └───────┬───────┘  │
   Arch Linux ARM)                 │          │          │
                                   │    SSD 1TB (ext4)   │
  Выбор OS → download → write     │    /media/DISK_A1/  │
                                   │    └── netinstall/   │
                                   │        ├── boot/     │
                                   │        ├── www/      │
                                   │        └── images/   │
                                   └─────────────────────┘
```

## Обновление os_list.json при новом релизе

```bash
# На ПК — скопировать свежий os_list.json на роутер
scp -P 222 /home/dryamov/Repositories/netinstall/update-os-list.sh \
  root@192.168.1.1:/media/DISK_A1/netinstall/

# На роутере — запустить
ssh root@192.168.1.1 -p 222 \
  /media/DISK_A1/netinstall/update-os-list.sh
```

## Offline-режим (опционально)

Если нужно полностью отключить доступ к WAN:

```bash
# На роутере
ssh root@192.168.1.1 -p 222
mkdir -p /media/DISK_A1/netinstall/images
cd /media/DISK_A1/netinstall/images

# Скачать образ
wget https://github.com/dryamovvv/archlinux-rpi5-aarch64/\
releases/latest/download/archlinux-rpi5-aarch64.img.xz

# Обновить os_list.json с локальным URL
# Изменить url на http://192.168.1.1:8080/images/archlinux-rpi5-aarch64.img.xz
# Раскомментировать alias.url для /images/ в lighttpd.conf
# Перезапустить lighttpd: /opt/etc/init.d/S80lighttpd restart
```

## Источники

- Keenetic Hopper SE: https://keenetic.com/en/keenetic-hopper-se
- Entware на Keenetic: https://help.keenetic.com/hc/ru/articles/360021214160
- RPi5 EEPROM config: https://www.raspberrypi.com/documentation/computers/raspberry-pi.html
