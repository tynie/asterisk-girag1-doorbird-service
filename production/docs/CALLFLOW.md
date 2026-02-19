# Callflow und Medienfluss

## Kernkomponenten

- DoorBird SIP Endpoint (`doorbird`)
- Asterisk18 (`chan_sip`, `app_confbridge`)
- Preview-Service (`doorbird-preview-live.service`)
- ffmpeg (Transcode + Dual UDP Ausgabe)
- baresip (2 parallele Service-Legs)
- Gira G1 Endpunkte (`g1_23`, `g1_53`)

## Ablauf

1. DoorBird -> Asterisk `7800`.
2. `7800`:
   - `Answer()`
   - AstDB State setzen (`doorbird/token`, `doorbird/main_chan`, `doorbird/accepted`)
   - Preview-Service starten
   - `ConfBridge(doorbird-main,doorbird_bridge,doorbird_user)`
3. Preview-Service:
   - liest DoorBird RTSP/HTTP Stream
   - transcodiert mit ffmpeg auf H264 Baseline (`352x288`, `fps=10`)
   - sendet nach `udp://127.0.0.1:23023` und `udp://127.0.0.1:23053`
   - ruft Asterisk `7901` und `7902` via baresip
4. `7901`/`7902` waehlen G1 und springen mit `G(postanswer...)` in `pa-common`.
5. `pa-common`:
   - Winner bestimmen (`doorbird/winner`)
   - Service-Leg join als `doorbird_preview_user` (marked)
   - Winner-G1 join als `doorbird_user`
6. Hangup/Cleanup:
   - `doorbird-cleanup` bei Main-/G1-Hangup
   - Guard-Script fuer harte Timeouts

## Timeouts

- Talk-Timeout:
  - Trigger beim Winner-G1 Join
  - `doorbird_conf_guard.sh talk <token> 60`
  - beendet stale Session nach 60s aktivem Call

- Post-Hangup-Timeout:
  - Trigger beim Winner-G1 Hangup
  - `doorbird_conf_guard.sh post <token> 10`
  - beendet Restzustand falls Main-Call/Konferenz offen bleibt

## Relevante Dateien

- Dialplan:
  - `asterisk18/extensions_doorbird_test.conf`
- SIP:
  - `asterisk18/sip_doorbird_test.conf`
- ConfBridge:
  - `asterisk18/confbridge_doorbird_test.conf`
- Preview:
  - `scripts/pi_baresip_preview_dual_live.sh`
  - `scripts/pi_baresip_preview_call.sh`
  - `scripts/doorbird-preview-live.service`
- Timeout Guard:
  - `scripts/doorbird_conf_guard.sh`
