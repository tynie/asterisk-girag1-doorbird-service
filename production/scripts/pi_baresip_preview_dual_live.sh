#!/usr/bin/env bash
set -euo pipefail

# Start two parallel preview calls (Pi -> both G1) with transcoded DoorBird live stream.
#
# Usage:
#   pi_baresip_preview_dual_live.sh [duration_seconds]
#
# Requires:
#   /home/config/doorbird.local.env
#   /home/config/pi_baresip_preview_call.sh
#   ffmpeg

DUR="${1:-30}"
ENV_FILE="/home/config/doorbird.local.env"
DEVICES_ENV="/home/config/doorbird.devices.env"
CALLER="/home/config/pi_baresip_preview_call.sh"
OUT_23_PORT=23023
OUT_53_PORT=23053
AST_IP=192.168.11.180
AST_PORT=5090
CALL_EXTRA=8
RELAY_EXTRA=12
RELAY_PID=""
P1=""
P2=""
WINNER_FILE="/tmp/doorbird_preview_winner"

if [[ ! -x "${CALLER}" ]]; then
  echo "missing caller script: ${CALLER}" >&2
  exit 2
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "env file not found: ${ENV_FILE}" >&2
  exit 2
fi

if ! command -v ffmpeg >/dev/null 2>&1; then
  echo "ffmpeg not installed" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"
SOURCE_URL="${DOORBIRD_RTSP_URL:-${DOORBIRD_VIDEO_URL:-}}"
if [[ -z "${SOURCE_URL}" ]]; then
  echo "Neither DOORBIRD_RTSP_URL nor DOORBIRD_VIDEO_URL set in ${ENV_FILE}" >&2
  exit 2
fi

# Optional central network/device config.
if [[ -f "${DEVICES_ENV}" ]]; then
  # shellcheck disable=SC1090
  source "${DEVICES_ENV}"
  AST_IP="${PI_IP:-${AST_IP}}"
  AST_PORT="${AST_SIP_PORT:-${AST_PORT}}"
fi

cleanup() {
  [[ -n "${P1}" ]] && kill -TERM "${P1}" 2>/dev/null || true
  [[ -n "${P2}" ]] && kill -TERM "${P2}" 2>/dev/null || true
  [[ -n "${RELAY_PID}" ]] && kill -TERM "${RELAY_PID}" 2>/dev/null || true
  sleep 1
  [[ -n "${P1}" ]] && kill -9 "${P1}" 2>/dev/null || true
  [[ -n "${P2}" ]] && kill -9 "${P2}" 2>/dev/null || true
  [[ -n "${RELAY_PID}" ]] && kill -9 "${RELAY_PID}" 2>/dev/null || true
  # Defensive cleanup for straggler baresip workers.
  pkill -f "/tmp/baresip-preview\\." 2>/dev/null || true
  sleep 1
  pkill -9 -f "/tmp/baresip-preview\\." 2>/dev/null || true
}
trap cleanup EXIT

URL_23="udp://127.0.0.1:${OUT_23_PORT}?fifo_size=120000&overrun_nonfatal=1"
URL_53="udp://127.0.0.1:${OUT_53_PORT}?fifo_size=120000&overrun_nonfatal=1"

echo "Starting dual live preview (${DUR}s) with transcoded stream"
echo "Source hidden; outputs -> ${URL_23} and ${URL_53}"
rm -f "${WINNER_FILE}" || true

IN_ARGS=()
if [[ "${SOURCE_URL}" == rtsp://* ]]; then
  IN_ARGS=(-rtsp_transport tcp -fflags +nobuffer+discardcorrupt -flags low_delay -analyzeduration 0 -probesize 32768)
fi

timeout $((DUR + RELAY_EXTRA)) ffmpeg -hide_banner -loglevel warning \
  "${IN_ARGS[@]}" \
  -i "${SOURCE_URL}" \
  -map 0:v:0 \
  -an \
  -vf "fps=10,scale=352:288,setsar=1" \
  -c:v libx264 -preset ultrafast -tune zerolatency \
  -pix_fmt yuv420p -profile:v baseline -level 3.0 \
  -x264-params "keyint=5:min-keyint=5:scenecut=0:repeat-headers=1:bframes=0:ref=1:cabac=0:aud=1" \
  -g 5 -keyint_min 5 -sc_threshold 0 \
  -b:v 450k -maxrate 450k -bufsize 900k \
  -muxdelay 0 -muxpreload 0 \
  -f tee "[f=mpegts:mpegts_flags=resend_headers:flush_packets=1]udp://127.0.0.1:${OUT_23_PORT}|[f=mpegts:mpegts_flags=resend_headers:flush_packets=1]udp://127.0.0.1:${OUT_53_PORT}" \
  >/tmp/doorbird-live-relay.log 2>&1 &
RELAY_PID=$!

sleep 1

timeout $((DUR + CALL_EXTRA)) "${CALLER}" "${ENV_FILE}" "${AST_IP}" "${DUR}" "${URL_23}" 7901 "${AST_PORT}" >/tmp/live-service-23.log 2>&1 &
P1=$!
timeout $((DUR + CALL_EXTRA)) "${CALLER}" "${ENV_FILE}" "${AST_IP}" "${DUR}" "${URL_53}" 7902 "${AST_PORT}" >/tmp/live-service-53.log 2>&1 &
P2=$!

winner=""
deadline=$((SECONDS + DUR + CALL_EXTRA + 4))
while true; do
  alive1=0
  alive2=0
  kill -0 "${P1}" 2>/dev/null && alive1=1
  kill -0 "${P2}" 2>/dev/null && alive2=1
  [[ "${alive1}" -eq 0 && "${alive2}" -eq 0 ]] && break

  if [[ -z "${winner}" && -s "${WINNER_FILE}" ]]; then
    winner="$(tr -d '\r\n[:space:]' < "${WINNER_FILE}" || true)"
    if [[ "${winner}" == "23" ]]; then
      echo "Winner file=23 -> keep both legs running (debug, no loser kill)"
    elif [[ "${winner}" == "53" ]]; then
      echo "Winner file=53 -> keep both legs running (debug, no loser kill)"
    else
      winner=""
    fi
  fi

  [[ "${SECONDS}" -ge "${deadline}" ]] && break
  sleep 0.2
done

wait "${P1}" || true
wait "${P2}" || true
wait "${RELAY_PID}" || true

echo "Dual live preview done"
