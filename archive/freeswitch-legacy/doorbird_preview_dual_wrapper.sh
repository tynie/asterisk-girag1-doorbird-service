#!/bin/sh
set -eu

LOCK=/tmp/doorbird_preview.lock
LOG=/tmp/doorbird_preview_wrapper.log
ENV_FILE=/home/config/doorbird.local.env
DUR=35

# Drop privileges: secrets + baresip config live under /home/config.
{
  printf '%s uid=%s user=%s wrapper=%s\n' "$(date -Is)" "$(id -u)" "$(id -un)" "$0"
} >> "$LOG" 2>/dev/null || true

# The lock file might have been created earlier by FreeSWITCH (owner/mode unfriendly to user config).
# Ensure it's accessible before dropping privileges.
touch "$LOCK" 2>/dev/null || true
chmod 666 "$LOCK" 2>/dev/null || true

/usr/sbin/runuser -u config -- \
  /usr/bin/flock -n "$LOCK" /usr/bin/timeout 65 /home/config/pi_baresip_preview_dual.sh "$ENV_FILE" "$DUR"
rc=$?
{
  printf '%s rc=%s\n' "$(date -Is)" "$rc"
} >> "$LOG" 2>/dev/null || true
exit "$rc"
