#!/usr/bin/env bash
set -euo pipefail

# Probe DoorBird RTSP stream without printing the full URL (may include secrets).
# Expects an env file with DOORBIRD_RTSP_URL.

ENV_FILE="${1:-}"
if [[ -z "${ENV_FILE}" || ! -f "${ENV_FILE}" ]]; then
  echo "usage: $0 /path/to/local.env" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

if [[ -z "${DOORBIRD_RTSP_URL:-}" ]]; then
  echo "DOORBIRD_RTSP_URL is not set in ${ENV_FILE}" >&2
  exit 2
fi

echo "Probing DoorBird RTSP (URL hidden)..."

# Keep it short; DoorBird can be slow to respond when idle.
timeout 15 ffprobe \
  -hide_banner \
  -loglevel error \
  -rtsp_transport tcp \
  -select_streams v:0 \
  -show_entries stream=codec_name,profile,codec_tag_string,width,height,r_frame_rate \
  -of default=noprint_wrappers=1:nokey=0 \
  "${DOORBIRD_RTSP_URL}"

