#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo "usage: $0 /path/to/ffmpeg" >&2
  exit 1
fi

FFMPEG_BIN="$1"

if [ ! -x "${FFMPEG_BIN}" ]; then
  echo "error: ${FFMPEG_BIN} is not executable" >&2
  exit 1
fi

BUILDCONF="$("${FFMPEG_BIN}" -buildconf 2>&1 || true)"

echo "Reviewing ${FFMPEG_BIN}"
echo
echo "${BUILDCONF}"
echo

if echo "${BUILDCONF}" | grep -q -- "--enable-gpl"; then
  echo "FAIL: build includes --enable-gpl" >&2
  exit 2
fi

if echo "${BUILDCONF}" | grep -q -- "--enable-nonfree"; then
  echo "FAIL: build includes --enable-nonfree" >&2
  exit 3
fi

echo "PASS: no prohibited FFmpeg configure flags detected in -buildconf output."
