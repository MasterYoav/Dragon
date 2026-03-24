#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 /path/to/LibreOffice.app" >&2
  exit 1
fi

APP_PATH="$1"
SOFFICE_PATH="${APP_PATH}/Contents/MacOS/soffice"
INFO_PLIST="${APP_PATH}/Contents/Info.plist"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "LibreOffice review failed: app bundle not found at ${APP_PATH}" >&2
  exit 1
fi

if [[ ! -x "${SOFFICE_PATH}" ]]; then
  echo "LibreOffice review failed: executable not found at ${SOFFICE_PATH}" >&2
  exit 1
fi

if [[ ! -f "${INFO_PLIST}" ]]; then
  echo "LibreOffice review failed: Info.plist missing at ${INFO_PLIST}" >&2
  exit 1
fi

echo "Bundle identifier:"
/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "${INFO_PLIST}" || true

echo "Bundle version:"
/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}" || true

echo "Executable check:"
"${SOFFICE_PATH}" --version || true

echo "PASS: LibreOffice bundle contains a runnable soffice executable and bundle metadata."
echo "Next steps:"
echo "1. Record the version and source URL in a manifest."
echo "2. Copy required license texts and notices into ConversionEngines/licenses/."
echo "3. Complete the release compliance checklist before shipping."
