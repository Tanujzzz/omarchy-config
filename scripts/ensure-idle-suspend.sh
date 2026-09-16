#!/bin/bash
# Idle auto-suspend via hypridle.
# Root cause it fixes: Omarchy's shell idle service only does screensaver
# (150s) + lock (300s) — nothing ever suspends, so idle machines blank the
# screen but keep the CPU running. Manual menu suspend (systemctl suspend)
# always worked; only the automatic step was missing.
# Installs hypridle if missing (needs sudo), renders
# config/hypr/hypridle.conf -> ~/.config/hypr/hypridle.conf, enables the
# hypridle user service. Idempotent.
# Override: IDLE_SUSPEND_SEC=1800 bash scripts/ensure-idle-suspend.sh
set -euo pipefail

if [[ "${1:-}" == "--dry-run" ]]; then export DRY_RUN=1; fi
DRY_RUN="${DRY_RUN:-0}"
IDLE_SUSPEND_SEC="${IDLE_SUSPEND_SEC:-1800}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE=~/.config/hypr/hypridle.conf
TEMPLATE="$REPO_DIR/config/hypr/hypridle.conf"

run() { if [[ "$DRY_RUN" == "1" ]]; then echo "[dry-run] $*"; else eval "$*"; fi; }

if ! [[ "$IDLE_SUSPEND_SEC" =~ ^[0-9]+$ ]] || (( IDLE_SUSPEND_SEC < 60 )); then
  echo "IDLE_SUSPEND_SEC must be a number >= 60 (got: $IDLE_SUSPEND_SEC)"
  exit 1
fi

if (( IDLE_SUSPEND_SEC < 300 )); then
  echo "WARNING: IDLE_SUSPEND_SEC=$IDLE_SUSPEND_SEC is shorter than the shell lock (300s); suspend will precede lock."
fi

if pacman -Q hypridle &>/dev/null; then
  echo "==> hypridle already installed, skipping"
else
  echo "==> Installing hypridle (repo, needs sudo)"
  run "omarchy-pkg-add hypridle"
fi

TMP="$(mktemp)"
sed "s/__IDLE_SUSPEND_SEC__/$IDLE_SUSPEND_SEC/g" "$TEMPLATE" >"$TMP"
if [[ -f "$LIVE" ]] && cmp -s "$TMP" "$LIVE"; then
  echo "==> hypridle.conf already current (suspend after ${IDLE_SUSPEND_SEC}s idle), skipping write"
  rm -f "$TMP"
elif [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] write $LIVE (suspend after ${IDLE_SUSPEND_SEC}s idle):"
  cat "$TMP"
  rm -f "$TMP"
else
  [[ -f "$LIVE" ]] && cp "$LIVE" "$LIVE.bak.$(date +%s)"
  cp "$TMP" "$LIVE"
  rm -f "$TMP"
  echo "==> hypridle.conf written (suspend after ${IDLE_SUSPEND_SEC}s idle)"
fi

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] systemctl --user enable --now hypridle.service"
  exit 0
fi

systemctl --user enable --now hypridle.service
sleep 1
if [[ "$(systemctl --user is-active hypridle.service)" != "active" ]]; then
  echo "hypridle.service failed to start:"
  systemctl --user status hypridle.service --no-pager | head -n 15
  exit 1
fi
echo "==> hypridle.service active (verify: journalctl --user -u hypridle.service | grep 'found .* rules')"
