#!/usr/bin/env bash
set -euo pipefail

# Fetch the official LibreOffice macOS disk image and unpack LibreOffice.app
# into a local workspace-only directory for review.
#
# Do not ship the output in releases until the compliance checklist is complete.

LIBREOFFICE_URL="${LIBREOFFICE_URL:-https://download.documentfoundation.org/libreoffice/stable/26.2.1/mac/aarch64/LibreOffice_26.2.1_MacOS_aarch64.dmg}"
WORK_ROOT="${WORK_ROOT:-$PWD/.build/libreoffice}"
DMG_PATH="${WORK_ROOT}/LibreOffice.dmg"
MOUNT_POINT="${WORK_ROOT}/mount"
APP_PATH="${WORK_ROOT}/LibreOffice.app"

mkdir -p "${WORK_ROOT}"

echo "Downloading official LibreOffice disk image..."
curl -L "${LIBREOFFICE_URL}" -o "${DMG_PATH}"

echo "Mounting disk image..."
mkdir -p "${MOUNT_POINT}"
hdiutil attach "${DMG_PATH}" -mountpoint "${MOUNT_POINT}" -nobrowse -readonly

cleanup() {
  hdiutil detach "${MOUNT_POINT}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

SOURCE_APP="$(find "${MOUNT_POINT}" -maxdepth 2 -name 'LibreOffice.app' -print -quit)"

if [[ -z "${SOURCE_APP}" ]]; then
  echo "Could not locate LibreOffice.app inside mounted disk image." >&2
  exit 1
fi

rm -rf "${APP_PATH}"
cp -R "${SOURCE_APP}" "${APP_PATH}"

echo "Local review bundle created at: ${APP_PATH}"
echo "Next steps:"
echo "1. Run Scripts/review_libreoffice_bundle.sh against the copied app."
echo "2. Record the exact version and source URL in ConversionEngines/manifests/."
echo "3. Copy the required notices and license texts before distribution."
