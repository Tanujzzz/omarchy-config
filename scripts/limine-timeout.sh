#!/bin/bash
# Set Limine boot menu timeout to 15s. Needs sudo (writes /boot/limine.conf).
# The `timeout:` directive lives in the limine.conf header, which Omarchy's
# entry managers preserve across updates. Idempotent; restores backup on failure.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
TIMEOUT="${LIMINE_TIMEOUT:-15}"
ESP_CONF="/boot/limine.conf"

if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || (( TIMEOUT > 9999 )); then
  echo "Invalid LIMINE_TIMEOUT='$TIMEOUT' (must be 0-9999)"
  exit 1
fi

SUDO=""
[[ "$EUID" -ne 0 ]] && SUDO="sudo"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] sudo: set 'timeout: $TIMEOUT' in $ESP_CONF (with backup)"
  exit 0
fi

BAK="$ESP_CONF.bak.$(date +%s)"
$SUDO cp "$ESP_CONF" "$BAK"
echo "Backup: $BAK"
# Restore backup on any failure below
trap '$SUDO cp "$BAK" "$ESP_CONF"; echo "Restored backup after failure"' ERR

if $SUDO grep -qE "^#?timeout:" "$ESP_CONF"; then
  $SUDO sed -i -E "s/^#?timeout:.*/timeout: $TIMEOUT/" "$ESP_CONF"
else
  # Insert at top of header
  $SUDO sed -i "1i timeout: $TIMEOUT" "$ESP_CONF"
fi

if $SUDO grep -qE "^timeout: ${TIMEOUT}$" "$ESP_CONF"; then
  trap - ERR
  echo "Verified: timeout: $TIMEOUT present in $ESP_CONF"
  echo "Confirm on next reboot (menu should wait ${TIMEOUT}s)."
else
  echo "FAILED to verify timeout; restoring backup"
  $SUDO cp "$BAK" "$ESP_CONF"
  trap - ERR
  exit 1
fi
