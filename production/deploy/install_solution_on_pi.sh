#!/usr/bin/env bash
set -euo pipefail

CONF_HOME="${CONF_HOME:-/home/config}"
AST_CFG="${AST_CFG:-/opt/asterisk18-test/etc/asterisk}"
AST_BIN="${AST_BIN:-/opt/asterisk18-test/sbin/asterisk}"
AST_CON="${AST_CON:-/opt/asterisk18-test/etc/asterisk/asterisk.conf}"

echo "[1/5] install scripts and templates"
install -d -m 755 "${CONF_HOME}/baresip-doorbirdtest"
for f in \
  "${CONF_HOME}/pi_baresip_preview_call.sh" \
  "${CONF_HOME}/pi_baresip_preview_dual_live.sh" \
  "${CONF_HOME}/doorbird_conf_guard.sh" \
  "${CONF_HOME}/apply_devices_env.sh"; do
  [[ -f "${f}" ]] && chmod 755 "${f}"
done
install -m 644 "${CONF_HOME}/baresip-doorbirdtest.config" "${CONF_HOME}/baresip-doorbirdtest/config"
install -m 644 "${CONF_HOME}/baresip-doorbirdtest.accounts" "${CONF_HOME}/baresip-doorbirdtest/accounts"
install -m 644 "${CONF_HOME}/baresip-doorbirdtest.contacts" "${CONF_HOME}/baresip-doorbirdtest/contacts"

if [[ ! -f "${CONF_HOME}/silence.wav" ]]; then
  ffmpeg -hide_banner -loglevel error \
    -f lavfi -i anullsrc=r=48000:cl=stereo -t 3600 \
    -c:a pcm_s16le "${CONF_HOME}/silence.wav"
fi

echo "[2/5] install systemd service"
install -m 644 "${CONF_HOME}/doorbird-preview-live.service" /etc/systemd/system/doorbird-preview-live.service
systemctl daemon-reload

echo "[3/5] install asterisk configs"
if [[ -f "${CONF_HOME}/doorbird.devices.env" && -f "${CONF_HOME}/sip_doorbird_test.conf.tpl" ]]; then
  echo "render sip config from doorbird.devices.env"
  bash "${CONF_HOME}/apply_devices_env.sh" \
    "${CONF_HOME}/doorbird.devices.env" \
    "${CONF_HOME}/sip_doorbird_test.conf.tpl" \
    "${CONF_HOME}/sip_doorbird_test.conf"
fi
install -m 644 "${CONF_HOME}/sip_doorbird_test.conf" "${AST_CFG}/sip_doorbird_test.conf"
install -m 644 "${CONF_HOME}/extensions_doorbird_test.conf" "${AST_CFG}/extensions_doorbird_test.conf"
install -m 644 "${CONF_HOME}/confbridge_doorbird_test.conf" "${AST_CFG}/confbridge_doorbird_test.conf"

echo "[4/5] run apply18"
bash "${CONF_HOME}/apply18.sh"

echo "[5/5] explicit reloads"
"${AST_BIN}" -C "${AST_CON}" -rx "dialplan reload"
"${AST_BIN}" -C "${AST_CON}" -rx "sip reload"
"${AST_BIN}" -C "${AST_CON}" -rx "module reload app_confbridge.so"

echo "install complete"
