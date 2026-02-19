# asterisk-girag1-doorbird-service

Reproduzierbares Setup fuer DoorBird -> 2x Gira G1 ueber einen Raspberry Pi mit Asterisk 18 und Preview-Service.

Stand: 2026-02-19

## Ziel

Bei Klingeln an der DoorBird soll der Pi den Ruf steuern, beide G1 erreichen und danach den aktiven Gespraechspfad stabil halten.

## Aktueller Loesungsstand

- Eingangscall von DoorBird auf Asterisk18 (`chan_sip`, Port `5090`)
- Preview-Service wird parallel gestartet (baresip + ffmpeg)
- Winner-Logik im Dialplan (`postanswer` + `pa-common`)
- Audio/Livebild nach Annahme stabil
- Automatisches Cleanup gegen haengende Konferenzen:
  - `60s` Talk-Timeout
  - `10s` Post-Hangup-Timeout

## Architektur (kurz)

1. DoorBird ruft `7800@PI:5090`.
2. Asterisk beantwortet, setzt Session-State in AstDB, startet `doorbird-preview-live.service`.
3. Service transcodiert DoorBird-Video und baut zwei Preview-Calls auf `7901`/`7902` auf.
4. Bei Annahme wird ein Gewinner gesetzt (`doorbird/winner`), Gewinner-G1 und Service-Leg in `ConfBridge` gejoint.
5. Cleanup/Timeouts werden ueber `doorbird-cleanup` + `doorbird_conf_guard.sh` erzwungen.

Details: `docs/CALLFLOW.md`

## Repo-Struktur

- `asterisk18/`:
  - `sip_doorbird_test.conf`
  - `extensions_doorbird_test.conf`
  - `confbridge_doorbird_test.conf`
  - `apply18.sh`
- `scripts/`:
  - `pi_baresip_preview_call.sh`
  - `pi_baresip_preview_dual_live.sh`
  - `doorbird_conf_guard.sh`
  - `doorbird-preview-live.service`
- `assets/baresip-doorbirdtest/`:
  - baresip Template (`config`, `accounts`, `contacts`)
- `deploy/`:
  - `bootstrap_pi_bookworm.sh`
  - `install_solution_on_pi.sh`
  - `push_to_pi.ps1`
- `docs/`:
  - Install, Deploy, Betrieb, Callflow

## Schnellstart (bestehender Pi)

1. Lokale Datei `doorbird.local.env.example` anpassen und als `doorbird.local.env` auf den Pi legen.
2. Deploy von Windows:
   - `powershell -ExecutionPolicy Bypass -File .\deploy\push_to_pi.ps1`
3. DoorBird SIP-Ziel auf Pi/Asterisk18 setzen:
   - SIP User: `doorbird`
   - SIP Passwort: `doorbird`
   - Proxy/Server: `192.168.11.180:5090`
   - Zielrufnummer: `7800`
4. Funktionstest aus `docs/OPERATIONS.md` ausfuehren.

## Vollstaendiger Neuaufbau

Siehe:

- `docs/INSTALL_PI.md`
- `docs/DEPLOY.md`

## Betrieb und Logs

- Asterisk:
  - `/home/config/asterisk18-test.log`
- Preview-Service:
  - `journalctl -fu doorbird-preview-live.service`
- Guard:
  - `/tmp/doorbird-conf-guard.log`
- SIP Peer Status:
  - `asterisk -rx 'sip show peers'`

## Wichtige Hinweise

- Secrets nicht committen (`doorbird.local.env`, SSH keys, private URLs).
- Diese Loesung ist auf das gegebene LAN-Setup optimiert:
  - Pi: `192.168.11.180`
  - DoorBird: `192.168.11.122`
  - G1: `192.168.11.23` und `192.168.11.53`
- Live-Stand wurde zusaetzlich in `WORKLOG.md` dokumentiert.
