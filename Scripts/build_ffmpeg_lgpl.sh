#!/bin/sh
set -eu

# This script is intentionally conservative.
# It is a template for producing a reviewable LGPL-oriented FFmpeg build for Dragon.
# Do not use the output in releases until the compliance checklist is completed.

FFMPEG_VERSION="${FFMPEG_VERSION:-8.0.1}"
WORK_ROOT="${WORK_ROOT:-$PWD/.build/ffmpeg}"
SOURCE_ARCHIVE="${WORK_ROOT}/ffmpeg-${FFMPEG_VERSION}.tar.xz"
SOURCE_DIR="${WORK_ROOT}/ffmpeg-${FFMPEG_VERSION}"
INSTALL_DIR="${WORK_ROOT}/install"

mkdir -p "${WORK_ROOT}"

echo "Downloading FFmpeg ${FFMPEG_VERSION} from the official FFmpeg release site..."
curl -L "https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.xz" -o "${SOURCE_ARCHIVE}"

echo "Extracting source..."
rm -rf "${SOURCE_DIR}"
tar -xf "${SOURCE_ARCHIVE}" -C "${WORK_ROOT}"

cd "${SOURCE_DIR}"

echo "Configuring FFmpeg for a cautious LGPL-oriented Dragon build..."
./configure \
  --prefix="${INSTALL_DIR}" \
  --disable-debug \
  --disable-doc \
  --enable-static \
  --disable-shared \
  --disable-autodetect \
  --disable-gpl \
  --disable-nonfree \
  --disable-ffplay \
  --disable-ffprobe \
  --enable-network \
  --enable-videotoolbox \
  --enable-audiotoolbox \
  --enable-appkit \
  --enable-avfoundation \
  --enable-securetransport \
  --enable-ffmpeg

echo "Building..."
make -j"$(sysctl -n hw.ncpu)"
make install

echo
echo "FFmpeg build complete."
echo "Binary: ${INSTALL_DIR}/bin/ffmpeg"
echo
echo "Next required steps:"
echo "1. Run Scripts/review_ffmpeg_binary.sh against the produced binary."
echo "2. Record the exact build configuration in ConversionEngines/manifests/."
echo "3. Add license texts and attribution before any distribution."
