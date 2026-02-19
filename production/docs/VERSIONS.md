# Versionen (Ist-Stand der laufenden Testumgebung)

Erfasst am: 2026-02-19

## System

- Hostname: `doorbird-bridge`
- OS: Debian GNU/Linux 12 (bookworm)
- Kernel: `6.12.47+rpt-rpi-v8`
- Architektur: `aarch64`

## Asterisk

- Version: `Asterisk 18.26.4`
- Installationspfad: `/opt/asterisk18-test`
- Wichtige Module:
  - `chan_sip.so` (Running)
  - `app_confbridge.so` (Running)

## Relevante Pakete

- `ffmpeg`: `8:5.1.8-0+deb12u1+rpt1`
- `baresip-core`: `1.0.0-4+b3`
- `baresip-ffmpeg`: `1.0.0-4+b3`
- `kamailio`: `5.6.3-2`
- `rtpengine-daemon`: `10.5.3.5-1`
- `freeswitch`: `1.10.12~release~1~a88d069d6f~bookworm-1~bookworm+1`
- `tcpdump`: `4.99.3-1`
- `sngrep`: `1.6.0-1`

## SIP Endpunkte (Ist-Zustand)

- DoorBird Peer: `doorbird` -> `192.168.11.122:5060` (dynamic)
- G1 Peer A: `g1_23` -> `192.168.11.23:5060`
- G1 Peer B: `g1_53` -> `192.168.11.53:5060`
- Asterisk SIP Listen: `0.0.0.0:5090`
