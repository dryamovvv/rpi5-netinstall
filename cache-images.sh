#!/bin/bash
set -euo pipefail

# Downloads OS images locally and patches os_list.json to use local URLs.
# Usage: ./cache-images.sh <server-ip> [port]
# Example: ./cache-images.sh 192.168.1.1 80

if [ $# -lt 1 ]; then
  echo "Usage: $0 <server-ip> [port]"
  echo "Example: $0 192.168.1.1 80"
  exit 1
fi

SERVER_IP="$1"
PORT="${2:-80}"
IMAGES_DIR="/srv/netinstall/images"
OS_LIST_FILE="/srv/netinstall/www/os_list.json"

mkdir -p "${IMAGES_DIR}"

echo "==> Reading os_list.json..."
if [ ! -f "${OS_LIST_FILE}" ]; then
  echo "ERROR: ${OS_LIST_FILE} not found"
  exit 1
fi

# Count entries
ENTRY_COUNT=$(jq '.os_list | length' "${OS_LIST_FILE}")
echo "==> Found ${ENTRY_COUNT} OS entr(ies)"

for i in $(seq 0 $((ENTRY_COUNT - 1))); do
  NAME=$(jq -r ".os_list[$i].name" "${OS_LIST_FILE}")
  URL=$(jq -r ".os_list[$i].url" "${OS_LIST_FILE}")
  DOWNLOAD_SHA=$(jq -r ".os_list[$i].image_download_sha256 // empty" "${OS_LIST_FILE}")
  FILENAME=$(basename "${URL}")

  echo ""
  echo "==> [${i}/${ENTRY_COUNT}] Caching: ${NAME}"
  echo "    URL: ${URL}"
  echo "    File: ${IMAGES_DIR}/${FILENAME}"

  if [ -f "${IMAGES_DIR}/${FILENAME}" ]; then
    echo "    Already cached, skipping download"
  else
    echo "    Downloading..."
    curl -sL -o "${IMAGES_DIR}/${FILENAME}" "${URL}"

    if [ -n "${DOWNLOAD_SHA}" ]; then
      LOCAL_SHA=$(sha256sum "${IMAGES_DIR}/${FILENAME}" | awk '{print $1}')
      if [ "${LOCAL_SHA}" != "${DOWNLOAD_SHA}" ]; then
        echo "    WARNING: SHA256 mismatch! Expected ${DOWNLOAD_SHA}, got ${LOCAL_SHA}"
      else
        echo "    SHA256 verified OK"
      fi
    fi
  fi

  LOCAL_URL="http://${SERVER_IP}:${PORT}/images/${FILENAME}"
  echo "    New URL: ${LOCAL_URL}"
done

echo ""
echo "==> Patching os_list.json with local URLs..."
jq --arg ip "${SERVER_IP}" --arg port "${PORT}" \
  '.os_list[].url |= "http://\($ip):\($port)/images/" + (split("/") | last)' \
  "${OS_LIST_FILE}" > "${OS_LIST_FILE}.tmp" && mv "${OS_LIST_FILE}.tmp" "${OS_LIST_FILE}"

echo "==> Done. Images cached in ${IMAGES_DIR}"
echo "    os_list.json updated with local URLs"
cat "${OS_LIST_FILE}"
