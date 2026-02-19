#!/usr/bin/env bash
set -euo pipefail

ASTERISK_VERSION="${ASTERISK_VERSION:-18.26.4}"
PREFIX="${PREFIX:-/opt/asterisk18-test}"
SRC_BASE="${SRC_BASE:-/usr/local/src}"

echo "[1/6] install runtime/build deps"
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl wget gnupg lsb-release \
  build-essential pkg-config git subversion \
  libxml2-dev libncurses5-dev libncursesw5-dev libnewt-dev \
  libssl-dev libsqlite3-dev libjansson-dev libedit-dev uuid-dev \
  libspeexdsp-dev libspeex-dev libopus-dev libcurl4-openssl-dev \
  ffmpeg baresip baresip-ffmpeg tcpdump sngrep

echo "[2/6] download asterisk ${ASTERISK_VERSION}"
mkdir -p "${SRC_BASE}"
cd "${SRC_BASE}"
TARBALL="asterisk-${ASTERISK_VERSION}.tar.gz"
SRC_DIR="asterisk-${ASTERISK_VERSION}"
if [[ ! -f "${TARBALL}" ]]; then
  wget "https://downloads.asterisk.org/pub/telephony/asterisk/${TARBALL}"
fi
if [[ ! -d "${SRC_DIR}" ]]; then
  tar -xzf "${TARBALL}"
fi

echo "[3/6] configure"
cd "${SRC_DIR}"
./configure \
  --prefix="${PREFIX}" \
  --sysconfdir="${PREFIX}/etc/asterisk" \
  --localstatedir="${PREFIX}/var"

echo "[4/6] enable required modules"
make menuselect.makeopts
menuselect/menuselect --enable chan_sip --enable app_confbridge menuselect.makeopts || true

echo "[5/6] build/install"
make -j"$(nproc)"
make install
make samples
ldconfig

echo "[6/6] runtime dirs/files"
mkdir -p /home/config/baresip-doorbirdtest
if [[ ! -f /home/config/silence.wav ]]; then
  ffmpeg -hide_banner -loglevel error \
    -f lavfi -i anullsrc=r=48000:cl=stereo -t 3600 \
    -c:a pcm_s16le /home/config/silence.wav
fi
chown -R config:config /home/config/baresip-doorbirdtest /home/config/silence.wav

echo "bootstrap complete"
echo "Asterisk binary: ${PREFIX}/sbin/asterisk"
