# DoorBird -> 2x G1 with persistent video after answer

## Status

This variant is currently confirmed working by test:

- both G1 receive call/preview
- after accepting on one G1, video keeps running (no freeze)
- audio works

## Active call flow

1. DoorBird calls `7800@192.168.11.180:5090`.
2. Asterisk (`7800`) answers, starts `doorbird-preview-live.service`, joins `ConfBridge(doorbird-main,...)`.
3. Service script transcodes DoorBird stream and starts 2 SIP legs to Asterisk:
   - `7901` (G1_23 path)
   - `7902` (G1_53 path)
4. `7901/7902` dial G1 with `G(postanswer^23svc^1)` / `G(postanswer^53svc^1)`.
5. On answer, Asterisk transfers both dial legs via `postanswer` into `pa-common`:
   - service leg joins as `doorbird_preview_user` (marked video source)
   - G1 leg joins as `doorbird_user`
6. Winner is written to:
   - AstDB `doorbird/winner`
   - `/tmp/doorbird_preview_winner`

Key point: using `Dial(...,G(...))` avoids delayed `ChannelRedirect` timing issues that caused freeze.

## Critical config

### `asterisk18/confbridge_doorbird_test.conf`

- bridge profile:
  - `video_mode=last_marked`
- preview user profile:
  - `marked=yes`
  - `startmuted=yes`
  - `jitterbuffer=no`

### `asterisk18/extensions_doorbird_test.conf`

- `7800` triggers preview service and enters conference.
- `7901/7902` use `Dial(...,G(postanswer...))`.
- `postanswer` + `pa-common` perform deterministic join logic.
- timeout guard state is tracked in AstDB:
  - `doorbird/token`
  - `doorbird/main_chan`
  - `doorbird/accepted`
- `[doorbird-cleanup]` handles:
  - main-leg cleanup (reset DB state + stop preview service)
  - post-hangup timeout trigger for stale ringing state
- `dbg-hangup` and `DBDBG` logs are enabled for traceability.

### `scripts/doorbird_conf_guard.sh`

- timer helper for conference cleanup:
  - `talk <token> 60`:
    - if call is still active after answer, hang up stale main leg + kick conference.
  - `post <token> 10`:
    - after winner hangup, if session is still open, force cleanup so next ring works immediately.

### `scripts/pi_baresip_preview_dual_live.sh`

- ffmpeg relay to local UDP `23023/23053`
- service calls to `7901/7902`
- winner file is read, but loser-kill is currently disabled (debug mode).

## Deploy / reload

Use this sequence on the Pi:

```bash
sudo cp /home/config/extensions_doorbird_test.conf /opt/asterisk18-test/etc/asterisk/extensions_doorbird_test.conf
sudo cp /home/config/confbridge_doorbird_test.conf /opt/asterisk18-test/etc/asterisk/confbridge_doorbird_test.conf
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan reload'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'module reload app_confbridge.so'
```

## Fast verification

```bash
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show 7901@doorbird-in'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show 23svc@postanswer'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show s@pa-common'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'confbridge show profile bridge doorbird_bridge'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'confbridge show profile user doorbird_preview_user'
```

## Runtime logs

- Asterisk core log:
  - `/home/config/asterisk18-test.log`
- Preview service journal:
  - `journalctl -fu doorbird-preview-live.service`
- Per-leg service logs:
  - `/tmp/live-service-23.log`
  - `/tmp/live-service-53.log`
- Filtered dialplan trace marker:
  - `DBDBG`

## Notes

- `joinconf` / `joinsvc` blocks are still present for debug/back-compat tracing, but active path is now `postanswer` + `pa-common`.
- Current service script is in debug mode for winner handling (no loser kill). If required later, loser-kill can be re-enabled safely after this baseline.
