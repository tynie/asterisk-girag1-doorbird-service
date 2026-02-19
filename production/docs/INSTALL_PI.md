# Pi Installation (Debian Bookworm + Asterisk18 Testinstanz)

## Getestete Basis

- Hostname: `doorbird-bridge`
- OS: Debian GNU/Linux 12 (bookworm)
- Kernel: `6.12.47+rpt-rpi-v8`
- CPU Arch: `aarch64`

## 1. Basispakete installieren

Auf dem Pi:

```bash
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  ca-certificates curl wget gnupg lsb-release \
  build-essential pkg-config git subversion \
  libxml2-dev libncurses5-dev libncursesw5-dev libnewt-dev \
  libssl-dev libsqlite3-dev libjansson-dev libedit-dev uuid-dev \
  libspeexdsp-dev libspeex-dev libopus-dev libcurl4-openssl-dev \
  ffmpeg baresip baresip-ffmpeg tcpdump sngrep
```

## 2. Asterisk 18 bauen (isoliert unter /opt/asterisk18-test)

Variante mit Script:

```bash
sudo bash /home/config/bootstrap_pi_bookworm.sh
```

Oder direkt aus diesem Repo:

```bash
sudo bash ./deploy/bootstrap_pi_bookworm.sh
```

Das Script:

- baut Asterisk `18.26.4`
- installiert nach `/opt/asterisk18-test`
- aktiviert `chan_sip` und `app_confbridge`

## 3. Runtime-Dateien vorbereiten

```bash
sudo mkdir -p /home/config/baresip-doorbirdtest
```

Dateien:

- `assets/baresip-doorbirdtest/config` -> `/home/config/baresip-doorbirdtest/config`
- `assets/baresip-doorbirdtest/accounts` -> `/home/config/baresip-doorbirdtest/accounts`
- `assets/baresip-doorbirdtest/contacts` -> `/home/config/baresip-doorbirdtest/contacts`

Optional (wenn nicht vorhanden):

```bash
ffmpeg -hide_banner -loglevel error \
  -f lavfi -i anullsrc=r=48000:cl=stereo -t 3600 \
  -c:a pcm_s16le /home/config/silence.wav
sudo chown config:config /home/config/silence.wav
```

## 4. DoorBird und G1 Basiswerte

Siehe `docs/DEPLOY.md`:

- `doorbird.devices.env` (zentrale IP-Werte)
- DoorBird/G1 SIP Konfiguration

## 5. Verifikation

```bash
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'core show version'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'module show like chan_sip'
sudo /opt/asterisk18-test/sbin/asterisk -C /opt/asterisk18-test/etc/asterisk/asterisk.conf -rx 'module show like app_confbridge'
```
