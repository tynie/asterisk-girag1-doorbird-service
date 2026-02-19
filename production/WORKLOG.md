# DoorBird-G1 Bridge Worklog

## 2026-02-17

### 14:25 - Passthrough-Umstellung vorbereitet und ausgerollt
- `integrationvorschlag.txt` erneut gelesen und Kernidee bestätigt: `bypass_media=true` + `bridge_early_media=true`, keine lokale Preview-Injektion im Medienpfad.
- Lokale Testdatei geprüft: `freeswitch/07_doorbird_v2_7100.xml` ist passthrough-only (keine `execute_on_pre_answer`-Hooks).
- Deployment auf Pi: `/etc/freeswitch/dialplan/public/07_doorbird_v2_7100.xml` aktualisiert und `fs_cli -x reloadxml` erfolgreich.
- Verifikation auf Pi: `bypass_media=true` und `bridge_early_media=true` in der aktiven XML vorhanden, keine `execute_on_pre_answer`-Zeilen mehr.
- Cleanup: `/home/config/doorbird.local.env` auf `PREVIEW_TESTSRC=0` gesetzt.
- Nächster Schritt: Klingel-Test mit DoorBird-Ziel `7100@192.168.11.180:5081` und Ergebnisvergleich Preview/Livebild/Audio/Cancel-Verhalten.

### 14:31 - SIP/SDP-Diagnose fuer 7100 Passthrough gestartet
- Hintergrundcapture auf Pi gestartet: `/tmp/sip7100_passthrough.pcap` (nur SIP-Ports 5060/5081, Hosts DoorBird/G1/Pi).
- Ziel: pruefen, ob DoorBird in INVITE `m=video` anbietet und ob FreeSWITCH das unveraendert zu beiden G1 weitergibt.

### 14:33 - Capture-Start korrigiert
- Hintergrundstart via komplexem Quoting verworfen (fehleranfaellig).
- Wechsel auf direkten `sudo timeout`-Capture fuer ein kurzes, reproduzierbares Messfenster.

### 14:36 - Wechsel von bypass_media auf proxy_media (7100)
- Ursache nach SIP/SDP-Pruefung: Video wird korrekt signalisiert (`m=video`, `H264`, `fmtp`), aber bei reinem bypass-Pfad kein Bild auf G1.
- Dialplan `freeswitch/07_doorbird_v2_7100.xml` angepasst auf `bypass_media=false` und `proxy_media=true` (global + in bridge-Originate-String).
- Ziel: RTP ueber Pi terminieren, um Bildpfad fuer Preview/Livebild stabiler zu machen.

### 14:40 - Erstes Audio-Richtungscapture ohne Call
- Capture enthielt nur Keepalive/REGISTER, keinen Klingel-Call; daher keine Auswertung moeglich.
- Zweites 90s-Capture wird direkt erneut gestartet mit explizitem Testfenster (Klingeln + Annahme + Sprechen).

### 14:45 - Fix fuer einseitiges Audio (G1 -> DoorBird)
- RTP-Analyse (`rtp_oneway_audio2.pcap`): DoorBird sendet Audio an Pi, aber Pi sendet keinen RTP-Audio-Stream zur DoorBird zurueck.
- Dialplan-Anpassung in `freeswitch/07_doorbird_v2_7100.xml`: `bypass_after_bridge=true` und `bypass_media_after_bridge=true`.
- Ziel: Nach Annahme Medienpfad direkt DoorBird<->angenommener G1, dadurch stabile bidirektionale Audio/Video-Session.

### 14:50 - Rollback nach Audio-Regression
- Letzte Aenderung (`bypass_after_bridge=true`, `bypass_media_after_bridge=true`) fuehrte zu kompletter Audio-Regression.
- Sofortiger Rollback auf vorherigen Stand: beide Parameter wieder `false` in `freeswitch/07_doorbird_v2_7100.xml`.
- Ziel: Rueckkehr auf den zuvor stabileren Zustand (beide klingeln, Livebild nach Annahme, zumindest einseitiges Audio).

### 14:58 - Early-Media fuer Audio-Stabilitaet deaktiviert
- Beobachtung: In proxy_media+Fork mit 183/early-media blieb Rueckkanal-Audio (G1->DoorBird) aus.
- Dialplan in `freeswitch/07_doorbird_v2_7100.xml` geaendert auf `ignore_early_media=true` und `bridge_early_media=false` (global + bridge-String).
- Erwartung: stabiler 2-Wege-Audio-Pfad nach 200 OK; Preview wird dabei bewusst geopfert.

### 15:05 - Testmodus ohne proxy_media/bypass_media
- Aenderung in `freeswitch/07_doorbird_v2_7100.xml`: `proxy_media=false`, `bypass_media=false` (global + bridge-String).
- Ziel: Rueckkanal-Audio pruefen im vollstaendigen FS-Bridge-Pfad, nachdem proxy_media one-way Audio erzeugt hat.
- Early-Media bleibt deaktiviert (`ignore_early_media=true`, `bridge_early_media=false`) fuer stabilen Answer-Pfad.

### 15:12 - Proxy-Media + Audio auf PCMU festgesetzt
- Ausgangslage: FS-Mediabridge gab bidirektionales Audio, aber Video blieb schwarz.
- Neue Testkonfiguration in `freeswitch/07_doorbird_v2_7100.xml`: `proxy_media=true`, `bypass_media=false`, `ignore_early_media=true`, `bridge_early_media=false`.
- Audio-Codecs strikt auf `PCMU` begrenzt (`codec_string` und `absolute_codec_string` auf `PCMU,H264`) um Transcoding-/Aushandlungsprobleme beim Rueckkanal zu reduzieren.

### 15:18 - Test: nur bypass_media_after_bridge aktiv
- Ausgangslage: proxy_media liefert Livebild, aber Audio nur DoorBird -> G1.
- Geaendert in `freeswitch/07_doorbird_v2_7100.xml`: `bypass_media_after_bridge=true`, `bypass_after_bridge=false`.
- Ziel: nach Annahme direkter Medienpfad zur Verbesserung des Rueckkanals ohne den SIP-Bridge-Aufbau zu destabilisieren.

### 15:22 - Rollback nach Totalausfall Audio
- Letzter Test mit `bypass_media_after_bridge=true` fuehrte zu komplettem Audioausfall.
- Ruecknahme in `freeswitch/07_doorbird_v2_7100.xml`: `bypass_media_after_bridge=false` (wieder vorheriger Stand).
- Ziel: Rueckkehr zu Livebild + Klingeln auf beiden + zumindest einseitigem Audio als stabile Basis.

### 15:26 - SIP-Profil-Fix fuer RTP-Rueckkanal vorbereitet
- RTP-Analyse zeigt: G1 -> FreeSWITCH Audio (PT=0) vorhanden, aber FreeSWITCH -> DoorBird Audioport keine RTP-Pakete.
- Profilpatches erstellt: `freeswitch/external.xml` und `freeswitch/internal.xml` mit `inbound-late-negotiation=false`, `NDLB-force-rport=true`, `disable-rtp-auto-adjust=false`.
- Ziel: sauberere RTP-Quell-/Zielbindung und stabile Rueckrichtung zum DoorBird-Endpunkt.

### 15:29 - SIP-Profile deployed und neu gestartet
- `external.xml` und `internal.xml` auf Pi ausgerollt (`/etc/freeswitch/sip_profiles/`).
- `reloadxml` ausgefuehrt sowie `sofia profile external/internal restart reloadxml`.
- Aktive Verifikation: beide Profile haben jetzt `inbound-late-negotiation=false`, `NDLB-force-rport=true`, `disable-rtp-auto-adjust=false`.

### 15:35 - Stabiler Basisstand erreicht
- Nutzer-Test bestaetigt: Audio jetzt beidseitig funktionsfaehig (DoorBird <-> G1).
- Nutzer-Test bestaetigt: Livebild nach Annahme funktioniert.
- Beide G1 klingeln weiterhin.
- Offener Punkt: kein Preview-Bild vor Annahme.
- Aktive SIP-Profil-Aenderungen (`external.xml` + `internal.xml`) bleiben gesetzt, da sie den Rueckkanal-Audiofehler behoben haben.

### 15:42 - Isolierte Preview-Testroute angelegt (7200)
- Neue Datei erstellt: `freeswitch/08_doorbird_v2_7200_preview.xml`.
- Zweck: Preview/early-media testen, ohne die stabile Route `7100` zu veraendern.
- Konfiguration in 7200: `proxy_media=true`, `ignore_early_media=false`, `bridge_early_media=true`, Audio/Video-Codecs `PCMU,H264`.

### 15:47 - Ergebnis isolierte Preview-Route 7200
- Nutzer-Test mit DoorBird-Ziel `7200@192.168.11.180:5081`: kein Preview auf beiden G1.
- Nach Annahme: Livebild vorhanden, Audio beidseitig funktionsfaehig, anderer G1 beendet sauber.
- Schluss: stabile Ein-Call-Session erreicht, Preview vor Annahme weiterhin nicht reproduzierbar.

### 15:52 - 7200 Early-Media-Trace ausgewertet
- Capture: `/tmp/preview_7200_trace.pcap` (60s, SIP+RTP) mit DoorBird-Ziel `7200@192.168.11.180:5081`.
- SIP zeigt korrekt 183 von beiden G1 und 200 OK nach Annahme.
- RTP-Analyse: vor `200 OK` keine relevanten Video- oder Audio-Streams aus dem DoorBird-Callpfad; Medienfluss startet erst nach Annahme (~13.56s).
- Schluss: In diesem 1-Call-Bridging liefert DoorBird faktisch kein verwertbares Early-Media fuer Preview; daher bleibt Preview auf beiden G1 aus, obwohl 183 signalisiert wird.

### 16:00 - Hybrid-Route 7300 fuer getrennte Preview + stabilen Hauptcall
- Neue Dialplan-Datei: `freeswitch/09_doorbird_v2_7300_hybrid_preview.xml` erstellt.
- Ablauf in 7300: `lua doorbird_trigger_preview.lua` (separate dual preview calls) -> kurzer Sleep 700ms -> stabiler Haupt-Bridge-Call (wie 7100).
- Ziel: Preview ueber separaten Mechanismus testen, ohne den funktionierenden Audio/Livebild-Pfad zu verlieren.

### 16:07 - Wechsel auf Single-Call-Preview-Injection (7400)
- Dual-Call-Hybrid (7300) verworfen wegen unerwuenschter zweiter eingehender Calls.
- Neue Route erstellt: `freeswitch/10_doorbird_v2_7400_singlecall_inject_preview.xml`.
- Ansatz: nur ein Hauptcall, Preview-Injektion pro B-Leg via `execute_on_pre_answer` (`doorbird_preview_multicast.lua 23/53`), Stop bei Annahme via `doorbird_stop_preview.lua`.
- Nebenbefund: `/etc/freeswitch/doorbird_preview_url*.txt` waren nicht vorhanden; werden beim Deploy neu gesetzt.

### 16:10 - 7400 deployed + Preview-URLs wiederhergestellt
- `10_doorbird_v2_7400_singlecall_inject_preview.xml` auf Pi deployed (`/etc/freeswitch/dialplan/public/`) und `reloadxml` ausgefuehrt.
- Verify: Route `7400` aktiv mit `execute_on_pre_answer`/`execute_on_answer` pro G1-Leg.
- Fehlende Dateien neu angelegt: `/etc/freeswitch/doorbird_preview_url.txt`, `/etc/freeswitch/doorbird_preview_url_23.txt`, `/etc/freeswitch/doorbird_preview_url_53.txt`.
- URLs gesetzt auf lokalen Relay-Feed (`udp://127.0.0.1:5004` fuer 23/default, `udp://127.0.0.1:5006` fuer 53).

### 16:14 - Fix 7400 Bridge-Syntax (nur ein G1 klingelte)
- Ursachevermutung: fragile per-leg Var-Syntax in der langen `bridge`-Data-Zeile.
- Umgestellt auf robuste Leg-Optionen: `[execute_on_pre_answer=...,execute_on_answer=...]` je Ziel.
- Konfliktanfaellige per-leg Codec-Parameter aus den Endpunktbloecken entfernt; globale Codec-Settings bleiben aktiv.

### 16:20 - Rollback von Preview-Testpfaden 7300/7400
- Ergebnis 7400: keine Preview, kein Livebild, Rueckkanal-Audio erneut defekt (Regression).
- Testpfade deaktiviert auf Pi: `09_doorbird_v2_7300_hybrid_preview.xml` und `10_doorbird_v2_7400_singlecall_inject_preview.xml` umbenannt auf `.disabled.*`.
- `reloadxml` ausgefuehrt; aktiver stabiler Pfad bleibt `07_doorbird_v2_7100.xml` (ein Call, beide klingeln, Livebild nach Annahme, beidseitiges Audio).

### 16:28 - Vorbereitung V3-Orchestrator
- Zielbild bestaetigt: ein DoorBird-Hauptcall, Audio stabil durchreichen, Video/Preview separat steuern.
- Preview-Relay-Service wird vor V3-Test explizit neu gestartet, damit aktuelle `doorbird.local.env`-Werte aktiv sind (kein veralteter Testbild-Prozess).

### 16:31 - Preview-Relay auf echten DoorBird-Stream neu gestartet
- `doorbird-preview-relay.service` neu gestartet.
- Verifikation: ffmpeg liest jetzt aktiv `rtsp://...@192.168.11.139:554/mpeg/media.amp` (kein `testsrc` mehr).
- Ausgaben laufen auf `udp://127.0.0.1:5004` und `udp://127.0.0.1:5006` fuer beide G1-Legs.

### 16:34 - V3 Orchestrator-Route 7500 vorbereitet
- Neue Dialplan-Datei erstellt: `freeswitch/11_doorbird_v3_7500_orchestrator.xml`.
- Route `7500` ruft direkt `doorbird_dual_call_orchestrator.lua` auf (Pi steuert beide G1-Legs, Winner-Bridge).
- `doorbird_dual_call_orchestrator.lua` wird ebenfalls zur sicheren Synchronisierung auf den Pi deployed.

### 16:40 - Fix fuer 7500 Sofortabbruch nach Annahme
- Analyse aus `freeswitch.log`: `uuid_bridge` war zwar `+OK`, danach A-Leg-Hangup mit `DESTINATION_OUT_OF_ORDER` / SIP 502.
- Ursache: DoorBird-A-Leg beim Bridge-Zeitpunkt noch nicht beantwortet.
- Orchestrator gepatcht (`freeswitch/doorbird_dual_call_orchestrator.lua`): vor `uuid_bridge` explizit `session:answer()` + kurzer Delay.
- Zusaetzlich Outbound-Leg-Optionen verschaerft: `codec_string=PCMU,H264`, `absolute_codec_string=PCMU,H264`, `proxy_media=true`, `rtp_disable_video=false`.

### 16:48 - V3 Orchestrator-Bridge auf Session-Bridge umgestellt
- Hypothese: manuelles `session:answer()` + `uuid_bridge` stabilisiert zwar Audio, blockiert aber saubere Video-SDP-Uebernahme.
- Aenderung in `freeswitch/doorbird_dual_call_orchestrator.lua`: finale Kopplung jetzt per `session:execute("bridge", "uuid:<winner>")` statt API-`uuid_bridge`.
- `session:answer()` vor Bridge entfernt.
- Ziel: DoorBird-Antwort/SDP aus Gewinner-Leg korrekt aufbauen (Audio+Video), ohne 502-Rueckfall.

### 16:55 - Rollback nach V3/7500 Totalausfall
- Nutzerergebnis fuer 7500: keine Preview, kein Livebild, kein Audio.
- V3-Dialplan deaktiviert: `/etc/freeswitch/dialplan/public/11_doorbird_v3_7500_orchestrator.xml` -> `.disabled`.
- `reloadxml` ausgefuehrt; stabiler Produktivpfad bleibt `07_doorbird_v2_7100.xml`.
- Empfehlung fuer Betrieb: DoorBird-Ziel auf `7100@192.168.11.180:5081` setzen.

### 17:03 - Start Asterisk-Gegenprobe
- Ziel: isolierter Asterisk-Test ohne Aenderung am stabilen FreeSWITCH-Produktivpfad.
- Initiale Bestandsaufnahme gestartet: Installation/Status von Asterisk und relevante freie SIP/RTP-Ports auf dem Pi.

### 17:06 - Paketlage Asterisk geprueft
- `apt-get install asterisk` fehlgeschlagen: kein Installation Candidate im aktiven Debian/RPi-Repo.
- Naechster Schritt: verfuegbare Asterisk-bezogene Pakete und alternative Laufzeitoption (Container) pruefen.

### 17:12 - Zusatzdokumente ausgewertet
- `SIP Settings Doorbird.txt` gelesen; Basiswerte sind konsistent (SIP an, Proxy auf Pi, Fehlercode 200).
- Fuer `cnt_asterisk_en.pdf` wurde Text-Extraktion ueber Pi vorbereitet (`poppler-utils`/`pdftotext`), da lokal kein PDF-Extractor verfuegbar ist.

### 17:15 - Dokument-Auswertung und Implikation
- `cnt_asterisk_en.pdf` ausgelesen: fuer Video in Asterisk soll `chan_sip` genutzt werden; `pjsip` wird laut DoorBird-Doku fuer Video nicht empfohlen.
- `SIP Settings Doorbird.txt` bestaetigt plausible Basiswerte (SIP aktiv, Proxy auf Pi, Fehlercode 200).
- Naechster Schritt: Status der abgebrochenen Asterisk-Kompilierung pruefen und falls moeglich direkt mit `chan_sip`-Testinstanz fortfahren.

### 17:31 - Statuscheck nach Build-Unterbrechung
- Nutzerabbruch waehrend Build-Wartekommando; aktueller Status auf Pi wird neu verifiziert (Prozesse, Installationsartefakte, Binary, Ports).

### 17:36 - Asterisk-Statuscheck
- Asterisk Build/Install ist erfolgreich: `/opt/asterisk-test/sbin/asterisk` vorhanden, Version `20.18.2`.
- Kein laufender Asterisk-Dienst, FreeSWITCH laeuft unveraendert weiter.
- Modulpruefung: nur `chan_pjsip`/`res_pjsip*` vorhanden; `chan_sip.so` fehlt trotz vorhandenem `chan_sip.c` im Source-Tree.
- Implikation: DoorBird-PDF (Video nur mit `chan_sip`) passt nicht direkt zu diesem Asterisk-20-Build.

### 17:40 - Entscheidung: Asterisk 18 Testinstanz
- Aufgrund fehlendem `chan_sip.so` in Asterisk 20 wird eine separate Asterisk-18-Instanz aufgebaut.
- Zielpfad: `/opt/asterisk18-test` (voll isoliert vom bestehenden FreeSWITCH-Setup).

### 18:18 - Asterisk18 Testkonfiguration (chan_sip) erstellt
- Neue Dateien lokal: `asterisk18/sip_doorbird_test.conf` und `asterisk18/extensions_doorbird_test.conf`.
- Inhalt: isolierter SIP-Port `5090`, DoorBird-Peer (IP-basiert), zwei G1-Peers (`23`,`53`), Dialplan-Extension `7600` mit parallelem Dial auf beide G1.

### 08:36 - Asterisk18 Deployment stabilisiert
- Ursache fuer vorigen Abbruch identifiziert: PowerShell-Quoting + CRLF in Remote-Skripten.
- Zugriff auf Pi ueber absolute Binarys umgestellt (`C:\Windows\System32\OpenSSH\ssh.exe`/`scp.exe`), da `ssh.bat` im Sandbox-Pfad lag.
- Testdateien erfolgreich auf Pi kopiert: `/home/config/sip_doorbird_test.conf`, `/home/config/extensions_doorbird_test.conf`.

### 08:44 - Asterisk18 Runtime auf chan_sip validiert
- Modulcheck: `chan_sip.so` laeuft in Asterisk18.
- `sip show settings` zeigt jetzt korrekt:
  - `UDP Bindaddress: 0.0.0.0:5090`
  - `Videosupport: Yes`
  - `Allow unknown access: No`
- Peer-Status: `g1_23` und `g1_53` beide `OK`.

### 08:49 - Dialplan-Testziel 7600 bestaetigt
- Kontext `doorbird-in` aktiv.
- Extension `7600` vorhanden mit parallelem Dial:
  - `Dial(SIP/g1_23&SIP/g1_53,45)`
- Port-Check: Asterisk18 lauscht auf UDP `5090`.
### 09:05 - Warum bei Asterisk nichts klingelte
- Live-Capture zeigte: DoorBird sendet weiterhin SIP nach `192.168.11.180:5080` (REGISTER sichtbar), nicht nach `5090`.
- Dadurch landet der Ruf weiterhin auf dem bestehenden Kamailio/FreeSWITCH-Pfad statt in Asterisk18.
- Parallel bestaetigt: Asterisk18 auf `5090` ist erreichbar und pollt beide G1 erfolgreich per OPTIONS (`200 OK`).
- Schlussfolgerung: In DoorBird muss der SIP-Proxy/Server-Port explizit auf `5090` umgestellt werden; nur die Zieladresse `7600@...:5090` reicht offenbar nicht.
### 09:12 - 403 auf Asterisk18 behoben (Auth/Registration)
- Asterisk-Logauswertung:
  - `Peer 'doorbird' is trying to register, but not configured as host=dynamic`
  - `Failed to authenticate device ... for INVITE`
- Anpassung in `asterisk18/sip_doorbird_test.conf` fuer `[doorbird]`:
  - `type=friend`
  - `host=dynamic`
  - `defaultuser=doorbird`
  - `secret=doorbird`
  - `nat=force_rport,comedia`
  - `insecure=port`
- Datei auf Pi deployed nach `/opt/asterisk18-test/etc/asterisk/sip_doorbird_test.conf`.
- `sip reload` ausgefuehrt; Verifikation zeigt jetzt fuer Peer `doorbird`:
  - `Dynamic: Yes`
  - `Secret: <Set>`
  - `Def. Username: doorbird`
### 09:20 - 403/INVITE-Auth Pfad gehärtet
- Analyse: DoorBird registriert inzwischen korrekt an Asterisk18 (`401` -> `200 OK`) auf `5090`.
- Anpassung fuer DoorBird-Peer: `insecure=port,invite` (vorher nur `port`).
- Ziel: INVITE ohne zusaetzliche Digest-Auth akzeptieren, wenn Peer/Port passt.
- Deploy + `sip reload` ausgefuehrt.
- Verifikation:
  - `Reg. Contact: sip:doorbird@192.168.11.122:5060;ob`
  - `Insecure: port,invite`
  - `Dynamic: Yes`
### 09:25 - Preview-Tuning in Asterisk18 (Early-Media)
- Analyse: SIP-Flow zeigt bereits `183 Session Progress` mit `m=video` an beide G1-Legs, dennoch kein stabiles Preview.
- Zusatztuning gesetzt in `asterisk18/sip_doorbird_test.conf` `[general]`:
  - `progressinband=yes`
  - `prematuremedia=yes`
- DoorBird-Peer unveraendert auf:
  - `host=dynamic`, `defaultuser=doorbird`, `secret=doorbird`, `insecure=port,invite`
- Asterisk18 sauber neu gestartet und verifiziert:
  - lauscht auf `5090`
  - DoorBird weiter registriert (`Reg. Contact` vorhanden)
### 09:30 - Ergebnis Asterisk18 Early-Media-Test
- Trotz `progressinband=yes` und `prematuremedia=yes` bleibt das Verhalten unveraendert:
  - beide G1 klingeln,
  - Preview nicht stabil auf beiden gleichzeitig,
  - Livebild/Audio nach Annahme funktionieren.
- Bewertung: Standard-SIP-Forking mit Early-Media liefert hier keinen reproduzierbaren Dual-Preview-Effekt auf beiden G1.
### 09:36 - Asterisk Forking-Isolation Test vorbereitet
- Dialplan erweitert fuer sauberen Capability-Vergleich:
  - `7600`: Parallel-Fork (G1_23 + G1_53) mit explizitem `Progress()`.
  - `7601`: Single-Leg nur `G1_23` mit `Progress()`.
  - `7602`: Single-Leg nur `G1_53` mit `Progress()`.
- Ziel: feststellen, ob Preview bereits bei Single-Leg geht (dann Forking/Fanout-Limit), oder generell nicht geht (Endpoint/Interworking-Limit).
- Dialplan auf Pi deployed und per `dialplan reload` aktiv verifiziert.
### 09:42 - Ergebnis Forking-Isolation (entscheidend)
- Nutzer-Test:
  - `7601` (Single-Leg G1_23): Preview = JA
  - `7602` (Single-Leg G1_53): Preview = JA
  - `7600` (Parallel-Fork): Preview = NEIN
- Schlussfolgerung:
  - Endgeraete koennen Early-Video (Single-Leg bestaetigt).
  - Problem entsteht beim 1->N Early-Media-Forking/Fanout.
  - Asterisk-Standardforking liefert kein reproduzierbares Dual-Preview aus einem eingehenden DoorBird-Stream.
### 09:49 - Integrations-POC: Asterisk Call-Controller + Kamailio/RTPengine Fanout
- Neuer Ansatz umgesetzt:
  - Asterisk bleibt Entry/B2BUA fuer DoorBird auf `5090`.
  - Asterisk waehlt fuer Forking nicht mehr direkt beide G1, sondern `SIP/7000@kproxy`.
  - `kproxy` zeigt auf lokalen Kamailio-Port `5080`, der per RTPengine auf beide G1 forkt.
- Asterisk-Konfig erweitert:
  - `sip_doorbird_test.conf`: neuer Peer `[kproxy]` (`192.168.11.180:5080`, `ulaw+h264`, `insecure=port,invite`).
  - `extensions_doorbird_test.conf`: neue Test-Extension `7610`:
    - `Progress()`
    - `Dial(SIP/7000@kproxy,45)`
- Deploy/Reload erfolgreich; `dialplan show 7610@doorbird-in` und `sip show peer kproxy` validiert.
### 10:01 - Kamailio/RTPengine Branch-Fanout Tuning (Asterisk->7610 Pfad)
- Hypothese: ein initiales globales `rtpengine_offer` vor dem Fork erzeugt einen zusaetzlichen nicht-branchgebundenen Medienzustand und behindert sauberes 1->N-Early-Media.
- Aenderung in `kamailio-doorbird-g1.cfg`:
  - globalen `rtpengine_offer(...)` im INVITE-Block entfernt.
  - Media-Anker erfolgt jetzt nur noch pro Branch in `branch_route[DB_BRANCH]`.
- Deploy nach `/etc/kamailio/doorbird-g1.cfg`, Syntaxcheck (`kamailio -c`) und Service-Restart erfolgreich.
- Verifikation:
  - Kamailio aktiv auf `udp:192.168.11.180:5080`.
  - RTPengine-Socket `udp:127.0.0.1:2223` erreichbar laut Startup-Log.
### 10:10 - Neuer Testpfad: explizite Dual-Legs statt downstream Forking
- Umsetzung gemaess naechstem Testansatz:
  - Asterisk erzeugt zwei explizite parallele Legs (`Dial(SIP/7000@kproxy&SIP/7002@kproxy,45)`) in neuer Extension `7620`.
  - Kamailio forked dafuer nicht mehr downstream, sondern routet:
    - `7000` strikt auf G1_23 (single-leg)
    - `7002` strikt auf G1_53 (single-leg)
  - Legacy-Forkroute fuer Vergleich bleibt auf `7001` erhalten.
- Ziel: getrennte Media-Sessions pro G1-Leg erzwingen und testen, ob Dual-Preview dadurch stabil auf beiden erscheint.
- Deploy/Reload erfolgreich:
  - `dialplan show 7620@doorbird-in` ok
  - `kamailio -c` ok, Service `active`
### 10:18 - Folgeanalyse nach 7620 (keine Preview, Livebild spaet)
- Nutzerergebnis fuer `7620`: beide klingeln, keine Preview, Livebild erst nach ~10s.
- Sofortiger Isolationsschritt vorbereitet:
  - Neue Testextensions `7621` und `7622` (jeweils Single-Leg ueber kproxy `7000` bzw. `7002`).
- Ziel: klären, ob die neue Kamailio-Single-Route selbst Early-Preview liefert.
- Deploy/Reload erfolgreich und Dialplan verifiziert.
### 10:23 - Isolationsresultat 7621/7622 (entscheidend)
- Nutzer-Test:
  - `7621` (Asterisk -> kproxy 7000 -> G1_23): Preview + Livebild + Audio = JA
  - `7622` (Asterisk -> kproxy 7002 -> G1_53): Preview + Livebild + Audio = JA
- Zusammen mit `7620` (parallel 7000 & 7002): keine Preview, Livebild erst nach Annahme/Verzoegerung.
- Harte Ableitung:
  - Jede einzelne Kette kann Early-Media-Video sauber.
  - Der Ausfall entsteht exakt beim parallelen Dial/Forking in Asterisk (ein Inbound-Leg auf zwei gleichzeitige Early-Media-Outbound-Legs).
  - Damit ist das kein reines Kamailio- oder einzelnes G1-Problem, sondern ein Parallel-Early-Media-Limit in diesem B2BUA-Setup.
### 10:34 - Variant-2 POC aufgebaut (isolierter Port 5095)
- Zielarchitektur umgesetzt:
  - DoorBird -> Kamailio `5095` (Ingress)
  - Kamailio forkt `7700` auf zwei getrennte Asterisk-Einzelziele (`7701`,`7702`) an `5090`
  - Asterisk `7701` ruft nur G1_23, `7702` ruft nur G1_53
- Dadurch wird Asterisk-Parallelforking umgangen; stattdessen zwei getrennte Single-Leg-B2BUA-Pfade.
- Aenderungen:
  - `asterisk18/extensions_doorbird_test.conf`: neue Extensions `7701`, `7702`
  - `kamailio-doorbird-g1.cfg`: neuer Listen-Port `5095`, neue Route fuer `rU==7700`
- Deploy/Reload erfolgreich verifiziert:
  - Kamailio lauscht auf `5080` und `5095`
  - Asterisk-Dialplan `7701`/`7702` aktiv
### 10:29 - Fix fuer DoorBird 404 auf Variant-2 (5095)
- Symptom: DoorBird SIP-Settings meldeten 404 bei `5095`.
- Beobachtung: SIP-Traffic auf `5095` kommt an; wahrscheinlich URI-Mismatch (DoorBird nutzt teils `doorbird@...` statt `7700@...`).
- Kamailio-Fix:
  - Variant-2-Route akzeptiert jetzt `INVITE` fuer `$rU == "7700"` **oder** `$rU == "doorbird"`.
  - Beide Faelle werden auf die zwei Asterisk-Legs `7701`/`7702` geforkt.
- Deploy + Syntaxcheck + Restart erfolgreich, Kamailio `active`.
### 10:35 - Variant-2 Ergebnis nach korrigiertem Zielstring
- Nutzerergebnis (DoorBird -> 5095 -> Variant-2):
  - beide G1 klingeln,
  - Preview nur auf einem,
  - nach Annahme Livebild vorhanden,
  - Audio stabil.
- Interpretation:
  - auch mit getrennten Single-Leg-Routen (7701/7702) und ohne Asterisk-Dial(A&B) kein stabiles Dual-Preview.
  - damit bleibt das Verhalten konsistent mit frueheren Tests: Dual-Preview scheitert auf End-to-End-Ebene trotz stabiler Signalisierung und Medien nach Annahme.
### 10:45 - Durchbruch: Dual-Demo-Preview vom Pi erfolgreich
- Testziel: Pi startet zwei parallele SIP-Calls direkt zu beiden G1 und sendet lokales Demo-Video (`preview_testsrc.mp4`) als Early-Media.
- Fix vorher: `scripts/pi_baresip_preview_call.sh` robust gemacht, damit Source-Override immer greift (nicht nur bei `INPUT_URL`-Placeholder).
- Nutzerbeobachtung:
  - Demo-Video erscheint auf beiden G1 nach ~1-2 Sekunden als Preview.
- Bedeutung:
  - G1 kann gleichzeitige Dual-Preview technisch darstellen.
  - Das Kernproblem liegt nicht an G1-Faehigkeit, sondern an bisherigem DoorBird->Bridge Early-Media-Flow.
### 10:52 - Korrektur zum Dual-Demo-Test
- Nutzerkorrektur: nur ein G1 hat geklingelt.
- Protokollsicht (`/tmp/demo-23.log`, `/tmp/demo-53.log`): beide Legs haben `100 Trying`, `180 Ringing` und `183 Session Progress` erhalten.
- Das bedeutet: SIP-seitig wurden beide G1 gleichzeitig angerufen und in Early-Media gesetzt.
- Wahrnehmungsdifferenz (nur ein G1 klingelt) muss daher auf Endgeraet/UI-Verhalten liegen, nicht auf fehlendem zweiten INVITE.
### 10:58 - Forensik Dual-Demo (SIP+RTP pro G1 verifiziert)
- Kontrolllauf mit parallelen Pi->G1-Demo-Calls (`preview_testsrc.mp4`) inkl. gleichzeitiger `tcpdump`-Aufzeichnung.
- SIP in pcap belegt fuer beide Legs:
  - INVITE an 23 und 53,
  - jeweils `180 Ringing` und `183 Session Progress`.
- RTP in pcap belegt fuer beide Legs:
  - Audio-RTP zu beiden G1,
  - H.264-Pakete zu beiden G1 (u.a. zu Port 11500 je Ziel).
- Fazit: technische Zustellung von Early-Media-Video an beide G1 ist gleichzeitig vorhanden; verbleibende Inkonsistenz ist G1-Client-/UI-seitige Darstellung/Klingelwahrnehmung.
### 10:48 - Einfacher startbarer Demo-Preview-Service gebaut
- Ziel: manueller Start eines Dienstes, der sofort beide G1 mit Demo-Video als Preview anruft.
- Neue Dateien lokal:
  - `scripts/pi_baresip_preview_dual_demo.sh`
  - `scripts/doorbird-preview-demo.service`
- Verhalten:
  - Service ist `oneshot` und ruft fuer 30s beide G1 parallel an.
  - Videoquelle: `/home/config/preview_testsrc.mp4`.
  - Logs pro Leg: `/tmp/demo-service-23.log`, `/tmp/demo-service-53.log`.
- Deploy auf Pi:
  - Script nach `/home/config/pi_baresip_preview_dual_demo.sh`
  - Unit nach `/etc/systemd/system/doorbird-preview-demo.service`
  - `daemon-reload`, `enable`, Test-`start` erfolgreich (exit 0).
### 11:07 - Live-Preview-Service finalisiert
- Neuer Service fuer Kamera-Livestream (statt Demo): `doorbird-preview-live.service`.
- Neue Wrapper-Logik: `scripts/pi_baresip_preview_dual_live.sh` startet den bestehenden Dual-Caller mit `doorbird.local.env`.
- Stabilitaetsfix:
  - Wrapper raeumt haengende `baresip`-Prozesse auf (`pkill` Cleanup).
  - Service-Tuning: `TimeoutStopSec=10`, `KillMode=mixed`.
- Erreichbarkeitsfix fuer Kameraquelle:
  - `doorbird.local.env` von `192.168.11.139` auf `192.168.11.122` aktualisiert (RTSP + HTTP URL).
- Verifikation:
  - `systemctl restart doorbird-preview-live` laeuft durch.
  - Service endet mit `status=0/SUCCESS`.
### 11:13 - Live-Preview jetzt mit erzwungener Transkodierung
- Ursache adressiert: DoorBird-Livestream war formatseitig nicht robust genug fuer G1-Preview.
- `pi_baresip_preview_dual_live.sh` komplett auf Transcode-Pipeline umgebaut:
  - Quelle aus `doorbird.local.env`
  - FFmpeg-Transcode nach H264 Baseline (352x288, 10fps, keyint=5, zerolatency)
  - Ausgabe auf zwei getrennte lokale UDP-Streams (`23023`, `23053`)
  - Zwei parallele baresip-Calls nutzen je eigenen UDP-Feed.
- Sauberes Ende verbessert:
  - PID-getracktes Cleanup fuer Relay + Calls
  - zusaetzliches `pkill` fuer verbleibende `/tmp/baresip-preview.*` Prozesse
- Service-Tuning:
  - `doorbird-preview-live.service` auf `TimeoutStartSec=120`.
- Verifikation:
  - `systemctl restart doorbird-preview-live` endet jetzt konsistent mit `status=0/SUCCESS`.
### 11:19 - Latenz-Tuning fuer Live-Preview
- Ziel: geringere Preview-Latenz bei weiterhin stabilem Dual-Call.
- Anpassungen umgesetzt:
  - `pi_baresip_preview_dual_live.sh`:
    - kleinere UDP-FIFOs (`120000` statt `1000000`),
    - RTSP low-latency Input (`-fflags nobuffer`, `-flags low_delay`, `-analyzeduration 0`, `-probesize 32768`),
    - Muxing low-latency (`-muxdelay 0`, `-muxpreload 0`, `flush_packets=1`).
  - `pi_baresip_preview_call.sh` (temp config overrides):
    - `jitter_buffer_delay 1-1`,
    - `video_fps 10.00`,
    - `video_size 352x288`,
    - `video_bitrate 180000`.
- Deploy auf Pi und Testlauf:
  - `doorbird-preview-live.service` beendet sich sauber mit `status=0/SUCCESS`.
### 11:25 - Warm Relay (Option 1) umgesetzt
- Neuer Dauer-Relay-Service aufgebaut:
  - `doorbird-preview-warm-relay.service` (always-on)
  - transkodiert DoorBird fortlaufend auf lokale UDP-Feeds `23023` und `23053`.
- `doorbird-preview-live` umgestellt:
  - kein FFmpeg-Kaltstart mehr pro Call,
  - nutzt nur noch die warmen Relay-Feeds fuer beide SIP-Preview-Calls.
- Deploy/Verifikation:
  - Warm-Relay ist `active (running)` mit ffmpeg-Prozess.
  - `doorbird-preview-live` laeuft und endet sauber mit `status=0/SUCCESS`.
- Erwarteter Effekt: geringere Startlatenz, da nur SIP-Call-Setup verbleibt.
### 11:30 - Warm-Relay komplett zurueckgerollt (auf Wunsch)
- Warm-Relay-Ansatz deaktiviert und entfernt:
  - `doorbird-preview-warm-relay.service` auf Pi `disable --now`
  - Unit-Datei auf Pi entfernt
  - lokale Unit-Datei geloescht
- `doorbird-preview-live` wieder auf Kaltstart-Transcode zurueckgestellt:
  - startet FFmpeg nur waehrend des Service-Laufs,
  - danach sauberer Stop/Cleanup.
- Verifikation:
  - Warm-Relay ist `inactive`
  - `doorbird-preview-live` laeuft und endet mit `status=0/SUCCESS`.
### 11:36 - Instrumentierter Latenz-Messlauf (SIP vs erstes H264)
- Messaufbau:
  - `doorbird-preview-live` gestartet,
  - parallel pcap auf Pi (`/tmp/live-latency.pcap`) mit SIP+RTP fuer beide G1.
- Beobachtete Zeiten (Epoch aus pcap):
  - erste `183`:
    - G1_23: `1771425366.072`
    - G1_53: `1771425366.171`
  - erstes H264-Paket vom Pi an G1:
    - G1_53: `1771425366.855` (ca. +0.68s nach 183)
    - G1_23: `1771425368.356` (ca. +2.28s nach 183)
- Interpretation:
  - Signalisierung ist schnell (`183` frueh),
  - Video-Pakete starten ebenfalls deutlich vor den subjektiven ~5s,
  - Restlatenz liegt damit sehr wahrscheinlich im Endgeraet (Preview-Renderer/Prebuffer), nicht primär im SIP/Relay-Transport.
### 11:40 - DoorBird-Call triggert jetzt Preview-Script
- Neue Asterisk-Extension hinzugefuegt: `7800@doorbird-in`.
- Verhalten:
  - bei eingehendem Ruf auf `7800` fuehrt Asterisk aus:
    - `TrySystem(sudo -n systemctl start doorbird-preview-live.service)`
  - danach `Hangup()`.
- Deploy auf Pi:
  - `extensions_doorbird_test.conf` aktualisiert,
  - `dialplan reload` ausgefuehrt,
  - `dialplan show 7800@doorbird-in` verifiziert.
- Hinweis:
  - Das ist bewusst ein Trigger-Only-Schritt fuer den naechsten Integrationsschritt.
### 11:44 - Winner/Loser-Logik fuer Preview-Calls umgesetzt
- Anforderung: wenn ein G1 annimmt, soll der andere klingelnde G1-Call beendet werden.
- Umsetzung in `pi_baresip_preview_dual_live.sh`:
  - Monitoring der beiden Leg-Logs auf `Call established`.
  - Bei erstem Gewinner:
    - loser Prozess wird per `TERM` beendet,
    - Gewinner laeuft weiter.
- Verifikation im Service-Run:
  - Journal: `Preview answered on 23 -> stopped ringing call on 53`.
  - Service endet weiterhin sauber mit `status=0/SUCCESS`.
### 11:47 - Handoff-Prototyp fuer DoorBird-Audio integriert
- Ziel: nach Annahme eines Preview-Calls den anderen beenden und DoorBird-Ruf auf den Gewinner-G1 umlegen.
- `pi_baresip_preview_dual_live.sh` erweitert:
  - schreibt Gewinner in `/tmp/doorbird_preview_winner` (`23` oder `53`),
  - beendet nach Gewinner-Erkennung beide Preview-Legs (kurzer Handoff).
- Asterisk-Extension `7800` erweitert:
  - startet Preview-Service non-blocking,
  - wartet bis zu 35s auf Winner-Datei,
  - waehlt anschliessend nur den Gewinner-G1 fuer den DoorBird-Hauptruf (`Dial(SIP/g1_23)` oder `Dial(SIP/g1_53)`).
- Deploy/Reload verifiziert, `dialplan show 7800@doorbird-in` zeigt aktive Wait+Handoff-Logik.
### 12:10 - Conference-Flow korrigiert (DoorBird + Gewinner in einem Raum)
- Problembeobachtung vom Test:
  - DoorBird und G1 hoeren jeweils "only person in this conference".
  - Zweiter G1-Call wurde nicht sauber beendet.
- Dialplan-Anpassungen in `asterisk18/extensions_doorbird_test.conf`:
  - `7800` setzt nun vor Start `DB(doorbird/winner)=none`.
  - Konferenz ist fest auf `doorbird-main` (kein Dateilookup mehr).
  - `ConfBridge` nutzt jetzt explizite Profile: `ConfBridge(doorbird-main,doorbird_bridge,doorbird_user)`.
  - `7901`/`7902` uebergeben Kandidaten-ID (`23`/`53`) an `joinconf`.
  - `joinconf` hat Winner-Lock via AstDB:
    - erster Answer claimt Winner,
    - zweiter Answer wird mit `486` abgewiesen.
  - Beim Claim wird Winner zusaetzlich nach `/tmp/doorbird_preview_winner` geschrieben.
- Erwarteter Effekt:
  - DoorBird und genau ein G1 sind im gleichen Raum,
  - der zweite G1 kann nicht parallel aktiv bleiben.

### 12:13 - ConfBridge-Profil ohne Ansagen hinzugefuegt
- Neue Datei `asterisk18/confbridge_doorbird_test.conf`:
  - `[doorbird_bridge]` und `[doorbird_user]`.
  - `doorbird_user` mit `quiet=yes`, `announce_join_leave=no`, `announce_user_count=no`.
- Ziel:
  - keine Ansage "only person in this conference" mehr,
  - ruhiger Call-Aufbau.

### 12:15 - Deployment-Skript erweitert
- `asterisk18/apply18.sh` aktualisiert:
  - kopiert jetzt auch `confbridge_doorbird_test.conf` nach Asterisk-Config,
  - haengt `#include confbridge_doorbird_test.conf` in `confbridge.conf` an (falls fehlend),
  - erweitert Verifikation um `app_confbridge` und relevante Dialplan-Checks.

### 12:17 - Preview-Service Winner-Abbruch robust gemacht
- `scripts/pi_baresip_preview_dual_live.sh` erweitert:
  - liest aktiv `/tmp/doorbird_preview_winner`.
  - sobald Winner-Datei gesetzt ist, wird loser Leg sofort terminiert (nicht nur ueber Log-Muster `Call established`).
- Ziel:
  - schnelleres und deterministisches Beenden des zweiten G1-Calls.
### 12:22 - Deploy auf Pi + Verifikation
- Geaenderte Dateien auf Pi kopiert:
  - `/home/config/extensions_doorbird_test.conf`
  - `/home/config/confbridge_doorbird_test.conf`
  - `/home/config/pi_baresip_preview_dual_live.sh`
  - `/home/config/apply18.sh`
- Asterisk18 neu gestartet und live verifiziert:
  - `dialplan show 7800@doorbird-in` -> neue ConfBridge-Route aktiv
  - `dialplan show s@joinconf` -> Winner-Lock aktiv
  - `confbridge show profile user doorbird_user` -> `quiet`/no-announcements aktiv
- Zusatzfix im Deploy-Skript:
  - Asterisk-Log in `apply18.sh` von `/tmp/asterisk18-test.log` auf `/home/config/asterisk18-test.log` umgestellt.
### 12:28 - Standbild nach Annahme behoben (ConfBridge Video aktiviert)
- Problem: Nach Annahme blieb nur Standbild (letztes Preview-Frame), obwohl Preview waehrend Klingeln lief.
- Ursache: `ConfBridge`-Bridgeprofil lief effektiv ohne Video (`Video Mode: no video`).
- Fix:
  - `asterisk18/confbridge_doorbird_test.conf` angepasst:
    - `[doorbird_bridge]` -> `video_mode=follow_talker`
- Deploy/Reload auf Pi:
  - Datei nach `/home/config` und `/opt/asterisk18-test/etc/asterisk/` kopiert.
  - `module reload app_confbridge.so` ausgefuehrt.
  - Verifikation: `confbridge show profile bridge doorbird_bridge` zeigt nun `Video Mode: follow_talker`.
- Erwarteter Effekt:
  - Nach Annahme wird laufendes Livevideo aus der Konferenz weitergegeben statt Freeze auf letztem Preview-Frame.
### 12:36 - Architektur auf persistenten Preview-Stream nach Annahme umgestellt
- Hinweis aus Test: Standbild nach Annahme blieb unveraendert.
- Analyse:
  - mit `U(joinconf...)` wurde nur der G1-Channel in die Konferenz verschoben,
  - der Preview-Service-Channel war danach nicht mehr im aktiven Medienpfad.
- Dialplan-Fix (`asterisk18/extensions_doorbird_test.conf`):
  - `7901/7902`: `Dial(...,U(joinconf^23|53))` (nur Kandidat uebergeben).
  - `joinconf`:
    - Winner-Lock bleibt aktiv,
    - ermittelt `BRIDGEPEER` (Service-Channel),
    - redirectet Service-Channel nach `[joinsvc]`,
    - legt G1 in `ConfBridge(doorbird-main,doorbird_bridge,doorbird_user)`.
  - Neuer Kontext `[joinsvc]`:
    - Service-Channel joint ebenfalls `doorbird-main`.
- ConfBridge-Profil-Fix (`asterisk18/confbridge_doorbird_test.conf`):
  - `video_mode` auf `last_marked` gestellt.
  - neues User-Profil `doorbird_preview_user` mit `marked=yes`, `startmuted=yes`.
  - Ziel: Preview-Service bleibt markierte Videoquelle, Audio kommt DoorBird<->G1.
- Preview-Service-Fix (`scripts/pi_baresip_preview_dual_live.sh`):
  - bei Winner wird nur der Verlierer-Leg beendet,
  - Gewinner-Leg bleibt aktiv als Videoquelle (nicht mehr sofort beendet).
### 12:48 - Service-Channel-Zuordnung fuer Video-Pinning stabilisiert
- Vermutete Hauptursache fuer Freeze nach Annahme:
  - `BRIDGEPEER` im `U(joinconf...)` ist nicht stabil/oft leer in dieser Phase.
  - Dann wird der Preview-Service-Channel nicht in `joinsvc` gezogen.
  - Ergebnis: G1 ist in Konferenz ohne aktive Videoquelle -> letztes Frame bleibt stehen.
- Fix in `asterisk18/extensions_doorbird_test.conf`:
  - `7901/7902`: setzen `__SVC_CHAN=${CHANNEL(name)}` auf dem eingehenden Service-Kanal vor `Dial(...)`.
  - `joinconf`: nutzt jetzt dieses geerbte `SVC_CHAN` fuer `ChannelRedirect(...,joinsvc,s,1)`.
  - zusaetzliches `NoOp`-Tracing mit `svc_chan` zur Live-Pruefung.
### 16:07 - Root Cause aus pcap + Fix fuer Freeze nach Annahme
- Analyse aus `/tmp/freeze-debug.pcap`:
  - G1_23 sendet `200 OK` um `15:59:43.251`.
  - Video zu G1_23 (Asterisk `30068 -> 11500`) endet praktisch genau zu diesem Zeitpunkt (`last=1771430383.241`).
  - Service-Call-ID `9c47ef6e0c54686e` bleibt bis fast zum Ende im Early-Media-Dialog (`183`), `200 OK` kommt erst bei `15:59:52.517`.
- Schlussfolgerung:
  - Video hing am Early-Media-Pfad des Service-Legs; beim Winner-Answer brach dieser Pfad weg.
- Fix in `asterisk18/extensions_doorbird_test.conf`:
  - `7901/7902` beantworten den Service-Leg jetzt sofort mit `Answer()` vor `Dial(...)`.
  - Damit wird der Service-Leg von Anfang an als etablierter Dialog gefahren, nicht nur 183-only.
### 16:17 - Winner-Erkennung nur noch via Asterisk (kein Log-Polling)
- `pi_baresip_preview_dual_live.sh`: Entfernt die Log-basierte Winner-Erkennung ("Call established").
- Winner wird jetzt ausschliesslich ueber `/tmp/doorbird_preview_winner` aus dem Dialplan gesetzt.
- Ziel: beide G1 klingeln, bis Asterisk den tatsaechlichen Gewinner setzt; kein vorzeitiges Stoppen durch fruehe `200 OK` vom Asterisk-Antwortschritt.
### 16:36 - Debug-Instrumentierung fuer Freeze-Analyse eingebaut
- `extensions_doorbird_test.conf` erweitert um `Log(NOTICE,DBDBG ...)` an allen kritischen Stellen:
  - `7800` Start,
  - `7901`/`7902` Service-Leg Erzeugung,
  - `joinconf` claim/reject inkl. `SVC_CHAN`,
  - `joinsvc` Eintritt.
- Hangup-Handler hinzugefuegt:
  - neuer Kontext `[dbg-hangup]`,
  - auf Service-/Join-Channels via `CHANNEL(hangup_handler_push)` gesetzt.
- Ziel:
  - exakt sichtbar, welcher Channel wann in ConfBridge landet,
  - und welcher Leg den Video-Pfad beendet.
- Deploy:
  - Datei auf Pi kopiert,
  - nach `/opt/asterisk18-test/etc/asterisk/` synchronisiert,
  - `dialplan reload` ausgefuehrt,
  - `dbg-hangup` Kontext verifiziert.
### 17:22 - Root Cause aus DBDBG bestätigt + G()-Transfer-Refactor
- Befund aus `DBDBG`-Logs:
  - `joinconf claim` kam frueh,
  - `joinsvc enter` fuer Service-Leg kam erst deutlich spaeter,
  - damit erfolgte `ChannelRedirect` nicht rechtzeitig fuer den Answer-Uebergang.
- Schlussfolgerung:
  - Freeze entsteht durch spaetes Umschalten des Service-Legs in die Konferenz.
- Umbau umgesetzt:
  - `7901/7902` jetzt `Dial(...,G(postanswer^23svc^1|53svc^1))` statt `U(joinconf...)`.
  - Neuer direkter Postanswer-Flow:
    - `[postanswer]` mit klaren Entry-Prioritaeten (1=Service, 2=G1),
    - `[pa-role]` setzt Kandidat/Rolle,
    - `[pa-common]` setzt/liest Winner, schreibt Winner-File, joined je Rolle in ConfBridge.
- Wichtiger Korrekturpunkt:
  - Erstversion hatte Priority-Kollisionen in `postanswer`.
  - Finalversion nutzt jetzt saubere `23svc/53svc` + `pa-role`, ohne kollidierende Prioritaeten.
- Deploy:
  - Dialplan auf Pi kopiert, nach `/opt/asterisk18-test/etc/asterisk/` synchronisiert, `dialplan reload`.
  - Verifiziert: `dialplan show 23svc@postanswer` zeigt exakt Prioritaet 1+2.
### 17:28 - Postanswer-Fix fuer Sofort-Abbruch
- Fehlerursache identifiziert:
  - Asterisk meldete `No such label '1(23' in context 'pa-role'`.
  - Grund: `Goto(...,1(23,svc))` ist fuer Argumente syntaktisch falsch.
- Dialplan korrigiert:
  - `postanswer` nutzt jetzt args-freie Goto-Ziele:
    - `23svc,1 -> pa-common,23svc,1`
    - `23svc,2 -> pa-common,23g1,1`
    - `53svc,1 -> pa-common,53svc,1`
    - `53svc,2 -> pa-common,53g1,1`
  - `pa-common` setzt Rolle/Kandidat je Ziel-Exten und fuehrt dann den gemeinsamen Winner/ConfBridge-Flow aus.
- Stabilitaetsfix:
  - `Return()` nach `ConfBridge` durch `Hangup()` ersetzt (wir kommen per `Goto`, nicht `Gosub`).
- Deploy/Verify:
  - Datei auf Pi kopiert,
  - in `/opt/asterisk18-test/etc/asterisk/` synchronisiert,
  - `dialplan reload` ausgefuehrt,
  - `dialplan show s@pa-common` verifiziert.
### 17:40 - Persistente Loesungsdokumentation erstellt
- Neue Datei: `SOLUTION_DOORBIRD_G1_STREAM_AFTER_ANSWER.md`
- Inhalt:
  - final funktionierender Callflow,
  - aktive Dialplan/ConfBridge-Parameter,
  - Deploy- und Verify-Kommandos,
  - relevante Laufzeit-Logs,
  - Hinweise zum aktuellen Debug-Status.
- Zweck:
  - reproduzierbare Referenz fuer diesen stabilen Stand,
  - schnell abrufbar fuer spaetere Weiterentwicklung/Recovery.
### 18:05 - Timeout-Guard gegen haengende DoorBird-Conference eingebaut
- Anlass:
  - Log `log-call-nach-erstem-call.txt` zeigte stale Conference mit nur `SIP/doorbird-*` in `doorbird-main`.
  - Folge: erneutes Klingeln war blockiert, bis Conference von selbst verschwand.
- Dialplan-Aenderungen in `asterisk18/extensions_doorbird_test.conf`:
  - `7800`: speichert jetzt `token`, `main_chan`, `accepted` in AstDB.
  - `7800`: `hangup_handler_push` auf neuem Kontext `[doorbird-cleanup]`.
  - `pa-common` (Winner G1): setzt `DB(doorbird/accepted)=1`, startet `60s` Talk-Timeout-Guard.
  - `pa-common` (Winner G1): setzt eigenen Hangup-Handler (`doorbird-cleanup`) fuer Post-Call-Cleanup.
  - Neuer Kontext `[doorbird-cleanup]`:
    - bei `main`-Hangup DB reset + Preview-Service Stop.
    - bei G1-Hangup `accepted=0` und `10s` Post-Timeout-Guard.
- Neue Datei: `scripts/doorbird_conf_guard.sh`
  - Modi:
    - `talk <token> 60`: beendet stale Session nach 60s aktivem angenommenen Gespraech.
    - `post <token> 10`: beendet Restzustand 10s nach Winner-Hangup, falls Session noch offen.
  - Guard arbeitet token-basiert (nur aktiver Call wird angefasst), haengt Main-Channel ab und kickt Conference.
### 18:25 - Repo fuer Rebuild/Weitergabe vollstaendig dokumentiert
- Ziel: Das Setup soll direkt aus dem Repo reproduzierbar nachbaubar sein.
- Neu angelegt:
  - `README.md` (Architektur, Quickstart, Betriebsuebersicht)
  - `docs/INSTALL_PI.md` (OS + Installpfad)
  - `docs/DEPLOY.md` (DoorBird/G1 Settings + Deploy)
  - `docs/CALLFLOW.md` (Ablauf inkl. Timeout-Logik)
  - `docs/OPERATIONS.md` (Tests, Logs, Troubleshooting)
  - `docs/VERSIONS.md` (ausgelesene Ist-Versionen vom Pi)
  - `deploy/bootstrap_pi_bookworm.sh` (Asterisk18 Build/Bootstrap)
  - `deploy/install_solution_on_pi.sh` (Pi-seitige Installation aus `/home/config`)
  - `deploy/push_to_pi.ps1` (Windows-Deploy inkl. Verify)
  - `assets/baresip-doorbirdtest/{config,accounts,contacts}` (relevante Baresip-Template-Dateien)
- Repo-Hygiene:
  - `.gitignore` erweitert um Secrets/Keys und Runtime-Artefakte.
### 18:52 - Git-Setup + Push-Versuch auf GitHub-Repo
- Git auf Pi installiert:
  - `sudo apt-get install -y git`
  - Version: `2.39.5`
- Ziel-Repo auf Pi geklont:
  - `https://github.com/tynie/asterisk-girag1-doorbird-service.git`
  - Hinweis: leeres Repo (frischer `main` Root-Commit).
- Relevante Projektstruktur in den Clone kopiert:
  - `README.md`, `WORKLOG.md`, `SOLUTION_*.md`, `.gitignore`
  - `docs/`, `deploy/`, `asterisk18/`, `scripts/`, `assets/baresip-doorbirdtest/`, `freeswitch/`
  - Env-Templates (`doorbird.local.env.example`, `local.env.example`)
- Commit erfolgreich erstellt:
  - Commit-ID: `5fdf84f`
  - Message: `Add reproducible DoorBird-G1 Asterisk service setup and docs`
- Push-Blocker:
  - `git push origin HEAD:main` fehlgeschlagen mit
    - `fatal: could not read Username for 'https://github.com': No such device or address`
  - Ursache: fehlende GitHub-Authentifizierung (PAT/SSH-Key) auf dem Pi.
### 19:06 - Push-Versuch direkt vom Windows-PC
- Git auf PC wurde erkannt unter:
  - `C:\Program Files\Git\cmd\git.exe` (nicht im PATH des Sandbox-Terminals)
- Lokales Repo in `doorbird-g1-bridge` initialisiert:
  - Branch `main`
  - Remote `origin` -> `https://github.com/tynie/asterisk-girag1-doorbird-service.git`
- Commit erfolgreich erstellt:
  - Commit-ID: `4b5c312`
  - Message: `Add reproducible DoorBird-G1 bridge setup, docs, and deploy scripts`
- Push-Blocker 1:
  - Umgebung hatte Proxy-Variablen auf `127.0.0.1:9` (`HTTP_PROXY`, `HTTPS_PROXY`, `ALL_PROXY`, `GIT_HTTP_PROXY`, `GIT_HTTPS_PROXY`).
  - Nach Proxy-Bypass war `ls-remote` erreichbar.
- Push-Blocker 2 (entscheidend):
  - Nicht-interaktive Umgebung kann keine GitHub-Credentials anfordern/speichern (`fatal: could not read Username`).
  - Device-Login via `git credential-manager github login --device --no-ui` schlug mit TLS/SChannel-Fehler fehl.
### 19:20 - Repo in `production/` und `archive/` getrennt
- Strukturierung umgesetzt:
  - `production/`: alle aktiven Asterisk/Preview/Deploy/Doku-Dateien.
  - `archive/`: historische FreeSWITCH-Varianten, Legacy-Konfigurationen, Referenzdokumente.
- Konkrete Verschiebungen:
  - `asterisk18/`, `scripts/`, `deploy/`, `docs/`, `assets/`, Env-Beispiele, `SOLUTION_*`, `WORKLOG.md` -> `production/`.
  - `freeswitch/` -> `archive/freeswitch-legacy/`.
  - fruehere XML/Kamailio-Konfigs -> `archive/legacy-configs/`.
  - Notizen/Referenzdateien -> `archive/references/`.
- Lokale Artefakte getrennt und ausgeschlossen:
  - `archive/artifacts/` (pcap/log/G1-Logdumps),
  - `archive/local-secrets/` (SSH-Key/URLs etc.).
- Repo-Hygiene:
  - `.gitignore` erweitert um `archive/artifacts/`, `archive/local-secrets/` und production-env-Dateien.
  - neuer Root-`README.md` als Einstieg + `archive/README.md` fuer den Legacy-Bereich.
