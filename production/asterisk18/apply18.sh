#!/usr/bin/env bash
set -euo pipefail
ASTCFG=/opt/asterisk18-test/etc/asterisk
ASTBIN=/opt/asterisk18-test/sbin/asterisk
ASTCON=/opt/asterisk18-test/etc/asterisk/asterisk.conf

sudo -n cp /home/config/sip_doorbird_test.conf "$ASTCFG/sip_doorbird_test.conf"
sudo -n cp /home/config/extensions_doorbird_test.conf "$ASTCFG/extensions_doorbird_test.conf"
sudo -n cp /home/config/confbridge_doorbird_test.conf "$ASTCFG/confbridge_doorbird_test.conf"

sudo -n cp "$ASTCFG/modules.conf" "$ASTCFG/modules.conf.bak18"
sudo -n perl -i -pe 's/^noload = chan_sip\.so$/;noload = chan_sip.so/m' "$ASTCFG/modules.conf"
if ! sudo -n grep -Fxq 'noload = chan_pjsip.so' "$ASTCFG/modules.conf"; then
  echo 'noload = chan_pjsip.so' | sudo -n tee -a "$ASTCFG/modules.conf" >/dev/null
fi

sudo -n cp "$ASTCFG/sip.conf" "$ASTCFG/sip.conf.bak18"
if ! sudo -n grep -Fq 'sip_doorbird_test.conf' "$ASTCFG/sip.conf"; then
  echo '#include sip_doorbird_test.conf' | sudo -n tee -a "$ASTCFG/sip.conf" >/dev/null
fi

sudo -n cp "$ASTCFG/extensions.conf" "$ASTCFG/extensions.conf.bak18"
if ! sudo -n grep -Fq 'extensions_doorbird_test.conf' "$ASTCFG/extensions.conf"; then
  echo '#include extensions_doorbird_test.conf' | sudo -n tee -a "$ASTCFG/extensions.conf" >/dev/null
fi

sudo -n cp "$ASTCFG/confbridge.conf" "$ASTCFG/confbridge.conf.bak18"
if ! sudo -n grep -Fq 'confbridge_doorbird_test.conf' "$ASTCFG/confbridge.conf"; then
  echo '#include confbridge_doorbird_test.conf' | sudo -n tee -a "$ASTCFG/confbridge.conf" >/dev/null
fi

if sudo -n grep -q '^rtpstart=' "$ASTCFG/rtp.conf"; then
  sudo -n sed -i 's/^rtpstart=.*/rtpstart=30000/' "$ASTCFG/rtp.conf"
else
  echo 'rtpstart=30000' | sudo -n tee -a "$ASTCFG/rtp.conf" >/dev/null
fi
if sudo -n grep -q '^rtpend=' "$ASTCFG/rtp.conf"; then
  sudo -n sed -i 's/^rtpend=.*/rtpend=30100/' "$ASTCFG/rtp.conf"
else
  echo 'rtpend=30100' | sudo -n tee -a "$ASTCFG/rtp.conf" >/dev/null
fi

sudo -n pkill -f '/opt/asterisk18-test/sbin/asterisk' || true
sleep 1
sudo -n "$ASTBIN" -C "$ASTCON" -f -g -U root -G root >/home/config/asterisk18-test.log 2>&1 &
sleep 2

sudo -n "$ASTBIN" -C "$ASTCON" -rx 'core show version'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'module show like chan_sip'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'module show like app_confbridge'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'sip show settings' | sed -n '1,80p'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'sip show peers'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'dialplan show 7800@doorbird-in'
sudo -n "$ASTBIN" -C "$ASTCON" -rx 'dialplan show s@joinconf'
ss -lntup | grep 5090 || true
