#!/usr/bin/env bash
set -euo pipefail

# Start two parallel preview calls (Pi -> both G1 panels) using DoorBird RTSP as video source.
#
# Usage:
#   pi_baresip_preview_dual.sh /path/to/doorbird.local.env [duration_seconds]
#
# Output:
# - Writes logs to /tmp/baresip-preview-23.log and /tmp/baresip-preview-53.log
#
# This is a helper for integrating preview into the doorbell flow.

ENV_FILE="${1:-}"
DUR="${2:-12}"

if [[ -z "${ENV_FILE}" ]]; then
  echo "usage: $0 /path/to/doorbird.local.env [duration_seconds]" >&2
  exit 2
fi

CALLER="/home/config/pi_baresip_preview_call.sh"
if [[ ! -x "${CALLER}" ]]; then
  echo "missing caller script: ${CALLER}" >&2
  exit 2
fi

echo "Starting dual preview calls for ~${DUR}s..."

rm -f /tmp/baresip-preview-23.log /tmp/baresip-preview-53.log || true

SOURCE_URL=""
if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}" || true
  SOURCE_URL="${DOORBIRD_VIDEO_URL:-${DOORBIRD_RTSP_URL:-}}"
fi

URL_23="${SOURCE_URL}"
URL_53="${SOURCE_URL}"
RELAY_PID=""

# DoorBird HTTP video endpoint can behave like single-session; force distinct query keys per leg.
if [[ "${SOURCE_URL}" == *"video.cgi"* ]]; then
  # Build one local relay from DoorBird HTTP stream and fan out to two local UDP feeds.
  # This avoids single-session behavior where only one preview leg gets video.
  if command -v ffmpeg >/dev/null 2>&1; then
    RELAY_A_PORT=23023
    RELAY_B_PORT=23053
    ffmpeg -hide_banner -loglevel error \
      -fflags nobuffer -i "${SOURCE_URL}" \
      -an -vf "fps=10,scale=320:180" \
      -c:v libx264 -preset ultrafast -tune zerolatency -pix_fmt yuv420p -g 20 \
      -f tee "[f=mpegts]udp://127.0.0.1:${RELAY_A_PORT}|[f=mpegts]udp://127.0.0.1:${RELAY_B_PORT}" \
      >/tmp/doorbird-ffmpeg-relay.log 2>&1 &
    RELAY_PID=$!
    URL_23="udp://127.0.0.1:${RELAY_A_PORT}?fifo_size=1000000&overrun_nonfatal=1"
    URL_53="udp://127.0.0.1:${RELAY_B_PORT}?fifo_size=1000000&overrun_nonfatal=1"
    sleep 1
  else
    SEP="?"
    [[ "${SOURCE_URL}" == *"?"* ]] && SEP="&"
    TS="$(date +%s)"
    URL_23="${SOURCE_URL}${SEP}client=g1-23&ts=${TS}"
    URL_53="${SOURCE_URL}${SEP}client=g1-53&ts=${TS}"
  fi
fi

timeout $((DUR+10)) "${CALLER}" "${ENV_FILE}" 192.168.11.23 "${DUR}" "${URL_23}" >/tmp/baresip-preview-23.log 2>&1 &
p1=$!
timeout $((DUR+10)) "${CALLER}" "${ENV_FILE}" 192.168.11.53 "${DUR}" "${URL_53}" >/tmp/baresip-preview-53.log 2>&1 &
p2=$!

echo "PIDs: ${p1} ${p2}"

# As soon as one G1 answers the preview call, stop BOTH preview legs.
# The real conversation should continue on the main call path only.
winner=""
deadline=$((SECONDS + DUR + 12))
while true; do
  alive1=0
  alive2=0
  kill -0 "${p1}" 2>/dev/null && alive1=1
  kill -0 "${p2}" 2>/dev/null && alive2=1
  [[ "${alive1}" -eq 0 && "${alive2}" -eq 0 ]] && break

  if [[ -z "${winner}" ]]; then
    if grep -q "Call established" /tmp/baresip-preview-23.log 2>/dev/null; then
      winner="23"
      kill -TERM "${p1}" 2>/dev/null || true
      pkill -TERM -P "${p1}" 2>/dev/null || true
      kill -TERM "${p2}" 2>/dev/null || true
      pkill -TERM -P "${p2}" 2>/dev/null || true
      echo "Preview answered on 23 (stopped both preview legs)"
    elif grep -q "Call established" /tmp/baresip-preview-53.log 2>/dev/null; then
      winner="53"
      kill -TERM "${p1}" 2>/dev/null || true
      pkill -TERM -P "${p1}" 2>/dev/null || true
      kill -TERM "${p2}" 2>/dev/null || true
      pkill -TERM -P "${p2}" 2>/dev/null || true
      echo "Preview answered on 53 (stopped both preview legs)"
    fi
  fi

  [[ "${SECONDS}" -ge "${deadline}" ]] && break
  sleep 0.2
done

wait "${p1}" || true
wait "${p2}" || true

if [[ -n "${RELAY_PID}" ]]; then
  kill -TERM "${RELAY_PID}" 2>/dev/null || true
  wait "${RELAY_PID}" 2>/dev/null || true
fi

echo "Done."
