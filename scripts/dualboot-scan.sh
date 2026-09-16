#!/bin/bash
# Dual-boot OS detection (opt-in, fresh installs only).
# Prompts [y/N, default No]: run `limine-scan` (finds Windows/Ubuntu/anything on
# any disk via FIND_BOOTLOADERS) and let the user answer its own
# selections/confirmations. Runs BEFORE limine-timeout.sh so the scan can't
# clobber `timeout: 15`. Default boot entry is left untouched.
# Needs sudo + interactive TTY when the scan actually runs.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
ESP_CONF="/boot/limine.conf"

has_tty() { (true </dev/tty >/dev/tty) 2>/dev/null; }

# Never-failing prompt: any TTY/read failure means No (safe for reruns/pipes).
ask() {
  local ans=""
  IFS= read -rp "$1 [y/N] " ans </dev/tty >/dev/tty 2>/dev/null || ans=""
  [[ "$ans" =~ ^[Yy]$ ]]
}

# Limine entries start at column 0 with ':'. Foreign = not Omarchy/snapshot.
list_entries() {
  sudo grep -E "^:" "$ESP_CONF" 2>/dev/null | sed 's/^: *//' || true
}
list_foreign() {
  list_entries | grep -viE "omarchy|snapshot" || true
}

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] prompt: fresh dual-boot install? run limine-scan? [y/N] -> sudo limine-scan + entry diff"
  exit 0
fi

if ! has_tty; then
  echo "==> No interactive terminal, skipping dual-boot scan"
  exit 0
fi

before_foreign=$(list_foreign || true)
if [[ -n "$before_foreign" ]]; then
  echo "==> Existing non-Omarchy boot entries detected:"
  echo "$before_foreign" | sed 's/^/    /'
  if ! ask "Run limine-scan again anyway?"; then echo "Skipped."; exit 0; fi
else
  if ! ask "Fresh dual-boot install? Run limine-scan to detect other OSes (Windows/Ubuntu/anything)?"; then echo "Skipped."; exit 0; fi
fi

echo "==> Backing up $ESP_CONF"
if ! sudo cp "$ESP_CONF" "$ESP_CONF.bak.$(date +%s)"; then
  echo "WARNING: backup failed (no sudo?) — skipping scan, continuing install."
  exit 0
fi

echo "==> Running limine-scan (answer its prompts yourself)"
if sudo limine-scan </dev/tty; then
  echo "==> Scan done. Current boot entries (order as shown at boot):"
  list_entries | sed 's/^/    /'
  after_foreign=$(list_foreign || true)
  if [[ -z "$after_foreign" ]]; then
    echo "WARNING: scan ran but no non-Omarchy entry found — check the output above."
  fi
  echo "Note: default boot entry left as-is; reorder manually later if wanted."
else
  echo "WARNING: limine-scan reported failure — continuing (timeout step still applies)."
fi
