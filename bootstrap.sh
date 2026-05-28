#!/bin/bash
set -euo pipefail

NETINSTALL_DIR="/srv/netinstall"
BOOT_DIR="${NETINSTALL_DIR}/boot"

mkdir -p "${BOOT_DIR}"

echo "==> Downloading official boot.img..."
wget -O "${BOOT_DIR}/boot.img" \
  https://downloads.raspberrypi.com/rpi-imager/boot.img

echo "==> Downloading official boot.sig..."
wget -O "${BOOT_DIR}/boot.sig" \
  https://downloads.raspberrypi.com/rpi-imager/boot.sig

echo "==> Done. Files placed in ${BOOT_DIR}:"
ls -lh "${BOOT_DIR}/"
