#!/bin/bash
set -euo pipefail

OWNER="dryamovvv"
REPO="archlinux-rpi5-aarch64"
GITHUB_API="https://api.github.com/repos/${OWNER}/${REPO}/releases/latest"
OUTPUT_FILE="/srv/netinstall/www/os_list.json"

echo "==> Fetching latest release info from GitHub API..."
RELEASE_DATA=$(curl -sL "${GITHUB_API}")

RELEASE_TAG=$(echo "${RELEASE_DATA}" | jq -r '.tag_name')
echo "==> Latest release: ${RELEASE_TAG}"

# Find the os_list.json asset
ASSET_URL=$(echo "${RELEASE_DATA}" | jq -r '.assets[] | select(.name == "os_list.json") | .browser_download_url')

if [ -z "${ASSET_URL}" ] || [ "${ASSET_URL}" = "null" ]; then
  echo "ERROR: os_list.json not found in latest release assets"
  exit 1
fi

echo "==> Downloading os_list.json from ${ASSET_URL}..."
curl -sL -o "${OUTPUT_FILE}" "${ASSET_URL}"

echo "==> os_list.json updated at ${OUTPUT_FILE}"
echo "==> Contents:"
cat "${OUTPUT_FILE}"
