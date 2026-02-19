#!/usr/bin/env bash
set -euo pipefail

# Watch SIP INVITEs from DoorBird to Kamailio and trigger dual preview helper.
# This keeps preview logic decoupled from the stable SIP call path.

DOORBIRD_IP="${DOORBIRD_IP:-192.168.11.122}"
SIP_PORT="${SIP_PORT:-5080}"
COOLDOWN_SEC="${COOLDOWN_SEC:-20}"
LOG_FILE="${LOG_FILE:-/var/log/doorbird-preview-watch.log}"
TRIGGER_CMD="${TRIGGER_CMD:-/usr/local/bin/doorbird_preview_dual.sh}"
LOCK_FILE="${LOCK_FILE:-/tmp/doorbird-preview-watch-trigger.lock}"

last_trigger=0

echo "$(date -Is) watcher-start doorbird=${DOORBIRD_IP} port=${SIP_PORT}" >> "${LOG_FILE}" 2>/dev/null || true

TCPDUMP_BIN="$(command -v tcpdump || true)"
if [[ -z "${TCPDUMP_BIN}" ]]; then
  echo "$(date -Is) watcher-error tcpdump-not-found" >> "${LOG_FILE}" 2>/dev/null || true
  exit 127
fi

while true; do
  while IFS= read -r line; do
    case "${line}" in
      *"INVITE sip:7000@"*|*"INVITE sip:7001@"*|*"INVITE sip:7012@"*|*"INVITE sip:7013@"*)
        now="$(date +%s)"
        if (( now - last_trigger < COOLDOWN_SEC )); then
          echo "$(date -Is) trigger-skipped cooldown_sec=${COOLDOWN_SEC}" >> "${LOG_FILE}" 2>/dev/null || true
          continue
        fi
        last_trigger="${now}"
        {
          echo "$(date -Is) trigger invite-line=${line}"
          /usr/bin/flock -n "${LOCK_FILE}" "${TRIGGER_CMD}"
          echo "$(date -Is) trigger-finished rc=$?"
        } >> "${LOG_FILE}" 2>&1 &
        ;;
    esac
  done < <("${TCPDUMP_BIN}" -l -n -A -s 0 -i any "udp and src host ${DOORBIRD_IP} and dst port ${SIP_PORT}" 2>>"${LOG_FILE}" || true)

  echo "$(date -Is) watcher-loop-restart" >> "${LOG_FILE}" 2>/dev/null || true
  sleep 1
done
