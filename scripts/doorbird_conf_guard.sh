#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
TOKEN="${2:-}"
SECS="${3:-}"

AST_BIN="/opt/asterisk18-test/sbin/asterisk"
AST_CFG="/opt/asterisk18-test/etc/asterisk/asterisk.conf"
ROOM="doorbird-main"
LOG="/tmp/doorbird-conf-guard.log"

log() {
  printf '%s mode=%s token=%s %s\n' "$(date '+%F %T')" "${MODE}" "${TOKEN}" "$*" >>"${LOG}"
}

if [[ -z "${MODE}" || -z "${TOKEN}" || -z "${SECS}" ]]; then
  echo "usage: $0 <ring|talk|post> <token> <seconds>" >&2
  exit 2
fi

if [[ ! "${SECS}" =~ ^[0-9]+$ ]]; then
  echo "seconds must be numeric: ${SECS}" >&2
  exit 2
fi

ast_raw() {
  "${AST_BIN}" -C "${AST_CFG}" -rx "$1" 2>/dev/null || true
}

db_get() {
  local key="$1"
  local out
  out="$(ast_raw "database get doorbird ${key}")"
  awk -F': ' '/Value: /{print $2; exit}' <<<"${out}"
}

token_matches() {
  local current
  current="$(db_get token)"
  [[ -n "${current}" && "${current}" == "${TOKEN}" ]]
}

hangup_main_leg() {
  local main_chan
  main_chan="$(db_get main_chan)"
  if [[ -z "${main_chan}" || "${main_chan}" == "none" ]]; then
    return 0
  fi
  ast_raw "channel request hangup ${main_chan}" >/dev/null
}

kick_conference() {
  ast_raw "confbridge kick ${ROOM} all" >/dev/null
}

sleep "${SECS}"

if ! token_matches; then
  log "skip: token changed"
  exit 0
fi

accepted="$(db_get accepted)"
case "${MODE}" in
  ring)
    if [[ "${accepted}" != "1" ]]; then
      hangup_main_leg
      kick_conference
      log "ring-timeout cleanup executed"
    else
      log "ring-timeout ignored (already accepted)"
    fi
    ;;
  talk)
    if [[ "${accepted}" == "1" ]]; then
      hangup_main_leg
      kick_conference
      log "talk-timeout cleanup executed"
    else
      log "talk-timeout ignored (not active)"
    fi
    ;;
  post)
    if [[ "${accepted}" != "1" ]]; then
      hangup_main_leg
      kick_conference
      log "post-timeout cleanup executed"
    else
      log "post-timeout ignored (still active)"
    fi
    ;;
  *)
    echo "unknown mode: ${MODE}" >&2
    exit 2
    ;;
esac
