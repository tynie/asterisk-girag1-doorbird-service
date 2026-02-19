# Betrieb, Tests und Troubleshooting

## Service-Steuerung

Preview-Service manuell:

```bash
sudo systemctl start doorbird-preview-live.service
sudo systemctl status doorbird-preview-live.service --no-pager
```

## Wichtige Logs

- Asterisk:
  - `/home/config/asterisk18-test.log`
- Service-Journal:
  - `journalctl -fu doorbird-preview-live.service`
- ffmpeg Service-Legs:
  - `/tmp/doorbird-live-relay.log`
  - `/tmp/live-service-23.log`
  - `/tmp/live-service-53.log`
- Timeout Guard:
  - `/tmp/doorbird-conf-guard.log`

## Live-Diagnose

```bash
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'sip show peers'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'confbridge list doorbird-main'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'database show doorbird'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'core show channels concise'
```

## Standard-Testablauf

1. Klingeln an DoorBird.
2. Pruefen: beide G1 klingeln.
3. Auf einem G1 annehmen.
4. Pruefen:
   - anderer G1 beendet
   - Audio beidseitig
   - Livebild auf angenommenem G1
5. Auflegen.
6. Nach 20 Sekunden erneut klingeln.
7. Pruefen: neuer Call kommt sofort wieder an.

## Wenn zweiter Klingelversuch haengt

1. `confbridge list doorbird-main` pruefen.
2. Wenn nur DoorBird-Leg haengt:
   - Guard-Log pruefen:
     - `tail -n 50 /tmp/doorbird-conf-guard.log`
3. DBDBG Marker pruefen:
   - `grep DBDBG /home/config/asterisk18-test.log | tail -n 120`
