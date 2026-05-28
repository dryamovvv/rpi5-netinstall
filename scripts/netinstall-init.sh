#!/bin/bash
set -euo pipefail

# One-shot setup script for RPi5 Network Install server on lighttpd.
#
# Usage:
#   sudo ./netinstall-init.sh [--offline]
#
# Options:
#   --offline  Also download OS images for fully offline operation

NETINSTALL_DIR="/srv/netinstall"
BOOT_DIR="${NETINSTALL_DIR}/boot"
WWW_DIR="${NETINSTALL_DIR}/www"
IMAGES_DIR="${NETINSTALL_DIR}/images"
SCRIPTS_DIR="${NETINSTALL_DIR}/scripts"

echo "=================================================="
echo "RPi5 Network Install - server initialisation"
echo "=================================================="
echo ""

# --- Step 1: Create directories ---
echo "[1/5] Creating directory structure..."
mkdir -p "${BOOT_DIR}" "${WWW_DIR}" "${IMAGES_DIR}" "${SCRIPTS_DIR}"

# --- Step 2: Download boot artifacts ---
echo "[2/5] Downloading official boot.img + boot.sig..."
wget -q -O "${BOOT_DIR}/boot.img" \
  https://downloads.raspberrypi.com/rpi-imager/boot.img
wget -q -O "${BOOT_DIR}/boot.sig" \
  https://downloads.raspberrypi.com/rpi-imager/boot.sig
echo "  boot.img: $(ls -lh "${BOOT_DIR}/boot.img" | awk '{print $5}')"
echo "  boot.sig: $(ls -lh "${BOOT_DIR}/boot.sig" | awk '{print $5}')"

# --- Step 3: Install lighttpd ---
echo "[3/5] Installing lighttpd..."
if command -v pacman &>/dev/null; then
  sudo pacman -S --noconfirm lighttpd
elif command -v apt-get &>/dev/null; then
  sudo apt-get update && sudo apt-get install -y lighttpd
elif command -v apk &>/dev/null; then
  sudo apk add lighttpd
else
  echo "  WARNING: Unknown package manager. Install lighttpd manually."
fi

# --- Step 4: Deploy config and os_list.json ---
echo "[4/5] Deploying config files..."
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# lighttpd.conf
install -m 644 "${SCRIPT_DIR}/lighttpd.conf" /etc/lighttpd/lighttpd.conf

# os_list.json template → www
cp "${SCRIPT_DIR}/os_list.json" "${WWW_DIR}/os_list.json"

# Scripts
cp "${SCRIPT_DIR}/update-os-list.sh" "${SCRIPTS_DIR}/"
cp "${SCRIPT_DIR}/cache-images.sh" "${SCRIPTS_DIR}/"
chmod +x "${SCRIPTS_DIR}"/*.sh

# --- Step 5: Start lighttpd ---
echo "[5/5] Starting lighttpd..."
sudo systemctl enable lighttpd
sudo systemctl restart lighttpd

echo ""
echo "=================================================="
echo "Server ready!"
echo "=================================================="
echo ""
echo "  IP:       $(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -1)"
echo "  Port:     80"
echo ""
echo "  boot.img:  http://<ip>/boot/boot.img"
echo "  boot.sig:  http://<ip>/boot/boot.sig"
echo "  os_list:   http://<ip>/os_list.json"
echo ""
echo "To configure EEPROM on RPi5:"
echo "  sudo rpi-eeprom-config --edit"
echo ""
echo "Set:"
echo "  BOOT_ORDER=0xf21"
echo "  HTTP_HOST=<ip>"
echo "  HTTP_PATH=/boot"
echo "  IMAGER_REPO_URL=http://<ip>/os_list.json"
echo "  NET_INSTALL_AT_POWER_ON=1"
echo ""

# Optional: offline mode
if [ "${1:-}" = "--offline" ]; then
  echo "==> Offline mode: caching OS images..."
  "${SCRIPTS_DIR}/cache-images.sh" "$(hostname -I | awk '{print $1}')" 80
fi
