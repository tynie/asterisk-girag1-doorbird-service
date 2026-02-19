#!/usr/bin/env bash
set -euo pipefail

# Place a SIP video call to a Gira G1 using baresip, streaming DoorBird video URL as source.
# This is a TEST helper for the "Fallback 2" approach.
#
# It does not modify kamailio/freeswitch; you can stop using it at any time.
# It avoids printing the source URL (may contain credentials).
#
# Usage:
#   pi_baresip_preview_call.sh /path/to/doorbird.local.env 192.168.11.23 [duration_seconds] [source_url_override] [dest_user] [dest_port]
#
# Notes:
# - Expects baresip + avformat module installed on the Pi.
# - Expects DOORBIRD_VIDEO_URL or DOORBIRD_RTSP_URL set in env file.
# - Uses a temporary baresip config dir under /tmp.

ENV_FILE="${1:-}"
G1_IP="${2:-}"
DUR="${3:-25}"
SOURCE_URL_OVERRIDE="${4:-}"
DEST_USER="${5:-7000}"
DEST_PORT="${6:-5060}"

if [[ -z "${ENV_FILE}" || -z "${G1_IP}" ]]; then
  echo "usage: $0 /path/to/doorbird.local.env <g1_ip> [duration_seconds]" >&2
  exit 2
fi
if [[ ! -f "${ENV_FILE}" ]]; then
  echo "env file not found: ${ENV_FILE}" >&2
  exit 2
fi

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

SOURCE_URL="${SOURCE_URL_OVERRIDE:-${DOORBIRD_VIDEO_URL:-${DOORBIRD_RTSP_URL:-}}}"
if [[ -z "${SOURCE_URL}" ]]; then
  echo "Neither DOORBIRD_VIDEO_URL nor DOORBIRD_RTSP_URL is set in ${ENV_FILE}" >&2
  exit 2
fi

if ! command -v baresip >/dev/null 2>&1; then
  echo "baresip not installed" >&2
  exit 2
fi

TEMPLATE_DIR="/home/config/baresip-doorbirdtest"
if [[ ! -f "${TEMPLATE_DIR}/config" || ! -f "${TEMPLATE_DIR}/accounts" || ! -f "${TEMPLATE_DIR}/contacts" ]]; then
  echo "template dir missing; expected ${TEMPLATE_DIR}/{config,accounts,contacts}" >&2
  exit 2
fi

WORKDIR="$(mktemp -d /tmp/baresip-preview.XXXXXX)"
cleanup() {
  rm -rf "${WORKDIR}" || true
}
trap cleanup EXIT

cp -a "${TEMPLATE_DIR}/config" "${WORKDIR}/config"
cp -a "${TEMPLATE_DIR}/accounts" "${WORKDIR}/accounts"
cp -a "${TEMPLATE_DIR}/contacts" "${WORKDIR}/contacts"
chmod 600 "${WORKDIR}/config" "${WORKDIR}/accounts" "${WORKDIR}/contacts"

# Insert source URL into config.
# Some template variants contain INPUT_URL placeholder, others have a fixed
# `video_source avformat,<url>` line. Handle both robustly.
if grep -q "INPUT_URL" "${WORKDIR}/config"; then
  sed -i -e "s|INPUT_URL|${SOURCE_URL}|g" "${WORKDIR}/config"
else
  sed -i -E "s|^([[:space:]]*video_source[[:space:]]+avformat,).*$|\\1${SOURCE_URL}|g" "${WORKDIR}/config"
fi

# Force low-latency preview profile in the temporary baresip config.
sed -i -E "s|^[[:space:]]*jitter_buffer_delay[[:space:]].*$|jitter_buffer_delay\t\t1-1|g" "${WORKDIR}/config"
sed -i -E "s|^[[:space:]]*video_fps[[:space:]].*$|video_fps\t\t10.00|g" "${WORKDIR}/config"
sed -i -E "s|^[[:space:]]*video_size[[:space:]].*$|video_size\t\t352x288|g" "${WORKDIR}/config"
sed -i -E "s|^[[:space:]]*video_bitrate[[:space:]].*$|video_bitrate\t\t180000|g" "${WORKDIR}/config"

# Minimal local identity. No registration.
# Keep From user as "doorbird" so the G1 "participant has camera" mapping matches.
cat >"${WORKDIR}/accounts" <<EOF
<sip:doorbird@192.168.11.180>;regint=0
EOF

DEST="sip:${DEST_USER}@${G1_IP}:${DEST_PORT}"

echo "Starting baresip preview call to ${DEST} for ~${DUR}s (source URL hidden)."
echo "If the G1 shows video while ringing, early RTP from caller works for preview."

# Run non-interactive and keep a local silent audio source.
# Video source comes from config (video_source avformat,INPUT_URL).
# Avoid -v to reduce logs; some module logs may print source details.
baresip -f "${WORKDIR}" \
  -e "/auplay null" \
  -e "/ausrc aufile,/home/config/silence.wav" \
  -e "/dial ${DEST}" \
  -t "${DUR}"
