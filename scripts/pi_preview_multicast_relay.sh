#!/usr/bin/env bash
set -euo pipefail

# Relay DoorBird camera stream to local multicast so multiple FS legs can consume
# the same preview stream concurrently.
#
# Usage:
#   pi_preview_multicast_relay.sh /home/config/doorbird.local.env

ENV_FILE="${1:-/home/config/doorbird.local.env}"
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "env file not found: ${ENV_FILE}" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

SOURCE_URL="${DOORBIRD_RTSP_URL:-${DOORBIRD_VIDEO_URL:-}}"
if [[ -z "${SOURCE_URL}" ]]; then
  echo "Neither DOORBIRD_VIDEO_URL nor DOORBIRD_RTSP_URL set in ${ENV_FILE}" >&2
  exit 1
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not installed" >&2
  exit 1
fi

# Two local outputs for both G1 legs.
OUT_URL_23="${PREVIEW_OUT_URL_23:-udp://127.0.0.1:5004?pkt_size=1316}"
OUT_URL_53="${PREVIEW_OUT_URL_53:-udp://127.0.0.1:5006?pkt_size=1316}"
TESTSRC="${PREVIEW_TESTSRC:-0}"

echo "Starting preview relay (source hidden) -> ${OUT_URL_23} and ${OUT_URL_53}"

run_dual_output() {
  local src="$1"
  shift
  local in_args=("$@")
  local tee_out="[f=mpegts:mpegts_flags=resend_headers]${OUT_URL_23}|[f=mpegts:mpegts_flags=resend_headers]${OUT_URL_53}"

  if [[ "${TESTSRC}" == "1" ]]; then
    ffmpeg -hide_banner -loglevel warning \
      -f lavfi -i "testsrc=size=352x288:rate=10" \
      -map 0:v:0 \
      -an \
      -c:v libx264 -preset ultrafast -tune zerolatency \
      -pix_fmt yuv420p -profile:v baseline -level 3.0 \
      -x264-params "keyint=5:min-keyint=5:scenecut=0:repeat-headers=1:bframes=0:ref=1:cabac=0:aud=1" \
      -g 5 -keyint_min 5 -sc_threshold 0 \
      -b:v 450k -maxrate 450k -bufsize 900k \
      -f tee "${tee_out}"
    return
  fi

  ffmpeg -hide_banner -loglevel warning \
    -fflags +nobuffer+discardcorrupt -flags low_delay \
    "${in_args[@]}" \
    -i "${src}" \
    -map 0:v:0 \
    -an \
    -vf "fps=10,scale=352:288,setsar=1" \
    -c:v libx264 -preset ultrafast -tune zerolatency \
    -pix_fmt yuv420p -profile:v baseline -level 3.0 \
    -x264-params "keyint=5:min-keyint=5:scenecut=0:repeat-headers=1:bframes=0:ref=1:cabac=0:aud=1" \
    -g 5 -keyint_min 5 -sc_threshold 0 \
    -b:v 450k -maxrate 450k -bufsize 900k \
    -muxdelay 0 -muxpreload 0 \
    -f tee "${tee_out}"
}

# Keep relay alive even if DoorBird stream temporarily drops.
while true; do
  IN_ARGS=()
  if [[ "${SOURCE_URL}" == rtsp://* ]]; then
    IN_ARGS=(-rtsp_transport tcp -analyzeduration 0 -probesize 32768)
  fi

  run_dual_output "${SOURCE_URL}" "${IN_ARGS[@]}" || true
  sleep 1
done
