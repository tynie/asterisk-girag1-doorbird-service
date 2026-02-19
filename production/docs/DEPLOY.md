# Deploy und Konfiguration

## Voraussetzungen

- SSH Zugriff auf Pi als `config`
- `sudo -n` fuer relevante Kommandos aktiv
- Asterisk18 vorhanden unter `/opt/asterisk18-test`

## A. Deploy von Windows (empfohlen)

```powershell
powershell -ExecutionPolicy Bypass -File .\deploy\push_to_pi.ps1 `
  -PiHost 192.168.11.180 `
  -PiUser config `
  -KeyPath C:\Users\admin\Documents\codex\doorbird-g1-bridge\key2
```

Das Script:

- kopiert alle relevanten Konfigs/Skripte nach `/home/config`
- installiert `doorbird-preview-live.service`
- deployed Asterisk-Dateien
- fuehrt `apply18.sh` und Reloads aus

## B. Manuelles Deploy auf Pi

```bash
sudo cp /home/config/sip_doorbird_test.conf /opt/asterisk18-test/etc/asterisk/sip_doorbird_test.conf
sudo cp /home/config/extensions_doorbird_test.conf /opt/asterisk18-test/etc/asterisk/extensions_doorbird_test.conf
sudo cp /home/config/confbridge_doorbird_test.conf /opt/asterisk18-test/etc/asterisk/confbridge_doorbird_test.conf
sudo chmod 755 /home/config/pi_baresip_preview_call.sh /home/config/pi_baresip_preview_dual_live.sh /home/config/doorbird_conf_guard.sh
sudo cp /home/config/doorbird-preview-live.service /etc/systemd/system/doorbird-preview-live.service
sudo systemctl daemon-reload
sudo bash /home/config/apply18.sh
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan reload'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'module reload app_confbridge.so'
```

## C. DoorBird/G1 Konfiguration

DoorBird SIP:

- SIP aktiviert: `On`
- SIP User: `doorbird`
- SIP Passwort: `doorbird`
- SIP Proxy/Server: `192.168.11.180:5090`
- Zielrufnummer: `7800`

Gira G1:

- SIP Teilnehmer `sip:doorbird@192.168.11.180`
- "Teilnehmer hat Kamera" aktiv

## D. Schnelle Checks

```bash
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'sip show peers'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show 7800@doorbird-in'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'dialplan show s@doorbird-cleanup'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'confbridge show profile bridge doorbird_bridge'
```
