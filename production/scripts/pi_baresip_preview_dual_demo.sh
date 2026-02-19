#!/usr/bin/env bash
set -euo pipefail

# Start two parallel preview calls (Pi -> both G1) with a local demo video.
#
# Usage:
#   pi_baresip_preview_dual_demo.sh [duration_seconds] [video_file]
#
# Defaults:
#   duration: 30
#   video_file: /home/config/preview_testsrc.mp4

DUR="${1:-30}"
VIDEO_FILE="${2:-/home/config/preview_testsrc.mp4}"
CALLER="/home/config/pi_baresip_preview_call.sh"
ENV_FILE="/home/config/doorbird.local.env"

if [[ ! -x "${CALLER}" ]]; then
  echo "missing caller script: ${CALLER}" >&2
  exit 2
fi

if [[ ! -f "${VIDEO_FILE}" ]]; then
  echo "video file not found: ${VIDEO_FILE}" >&2
  exit 2
fi

URL="file:${VIDEO_FILE}"

echo "Starting dual demo preview for ${DUR}s using ${VIDEO_FILE}"
rm -f /tmp/demo-service-23.log /tmp/demo-service-53.log || true

timeout $((DUR+8)) "${CALLER}" "${ENV_FILE}" 192.168.11.23 "${DUR}" "${URL}" >/tmp/demo-service-23.log 2>&1 &
p1=$!
timeout $((DUR+8)) "${CALLER}" "${ENV_FILE}" 192.168.11.53 "${DUR}" "${URL}" >/tmp/demo-service-53.log 2>&1 &
p2=$!

wait "${p1}" || true
wait "${p2}" || true

echo "Dual demo preview done"
