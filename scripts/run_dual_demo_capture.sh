#!/usr/bin/env bash
set -euo pipefail
sudo -n rm -f /tmp/demo-23.log /tmp/demo-53.log /tmp/dual-demo2.pcap /tmp/dual-demo2-tcpdump.log
sudo -n timeout 35 tcpdump -ni any -s 0 -w /tmp/dual-demo2.pcap '(host 192.168.11.23 or host 192.168.11.53) and udp' >/tmp/dual-demo2-tcpdump.log 2>&1 &
CAP=$!
sleep 1
timeout 32 /home/config/pi_baresip_preview_call.sh /home/config/doorbird.local.env 192.168.11.23 25 file:/home/config/preview_testsrc.mp4 >/tmp/demo-23.log 2>&1 &
P1=$!
timeout 32 /home/config/pi_baresip_preview_call.sh /home/config/doorbird.local.env 192.168.11.53 25 file:/home/config/preview_testsrc.mp4 >/tmp/demo-53.log 2>&1 &
P2=$!
wait $P1 || true
wait $P2 || true
wait $CAP || true
echo DONE
ls -lh /tmp/dual-demo2.pcap /tmp/demo-23.log /tmp/demo-53.log
