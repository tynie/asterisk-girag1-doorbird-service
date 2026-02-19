#!/usr/bin/env bash
set -euo pipefail

ENV_FILE="${1:-/home/config/doorbird.devices.env}"
TPL_FILE="${2:-/home/config/sip_doorbird_test.conf.tpl}"
OUT_FILE="${3:-/home/config/sip_doorbird_test.conf}"

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "devices env not found: ${ENV_FILE}" >&2
  exit 2
fi
if [[ ! -f "${TPL_FILE}" ]]; then
  echo "sip template not found: ${TPL_FILE}" >&2
  exit 2
fi

# shellcheck disable=SC1090
source "${ENV_FILE}"

PI_IP="${PI_IP:-192.168.11.180}"
DOORBIRD_IP="${DOORBIRD_IP:-192.168.11.122}"
G1_23_IP="${G1_23_IP:-192.168.11.23}"
G1_53_IP="${G1_53_IP:-192.168.11.53}"
AST_SIP_PORT="${AST_SIP_PORT:-5090}"
DOORBIRD_SIP_PORT="${DOORBIRD_SIP_PORT:-5060}"
G1_SIP_PORT="${G1_SIP_PORT:-5060}"
KPROXY_PORT="${KPROXY_PORT:-5080}"

tmp="$(mktemp)"
trap 'rm -f "${tmp}"' EXIT

sed \
  -e "s|__PI_IP__|${PI_IP}|g" \
  -e "s|__DOORBIRD_IP__|${DOORBIRD_IP}|g" \
  -e "s|__G1_23_IP__|${G1_23_IP}|g" \
  -e "s|__G1_53_IP__|${G1_53_IP}|g" \
  -e "s|__AST_SIP_PORT__|${AST_SIP_PORT}|g" \
  -e "s|__DOORBIRD_SIP_PORT__|${DOORBIRD_SIP_PORT}|g" \
  -e "s|__G1_SIP_PORT__|${G1_SIP_PORT}|g" \
  -e "s|__KPROXY_PORT__|${KPROXY_PORT}|g" \
  "${TPL_FILE}" > "${tmp}"

install -m 644 "${tmp}" "${OUT_FILE}"
echo "rendered ${OUT_FILE} from ${ENV_FILE}"
