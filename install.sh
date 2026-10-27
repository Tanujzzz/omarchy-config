#!/bin/bash
# omarchy-configuration installer (Omarchy-only).
# Fresh machine: curl -fsSL <raw-url>/install.sh | bash
# Options: DRY_RUN=1 bash install.sh / LIMINE_TIMEOUT=15 bash install.sh
set -euo pipefail

if [[ "${1:-}" == "--dry-run" ]]; then export DRY_RUN=1; fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# curl|bash bootstrap: fetch the repo if sibling scripts are absent
if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
  DEST="${OMARCHY_CONF_DIR:-$HOME/.local/share/omarchy-configuration}"
  if [[ ! -d "$DEST/scripts" ]]; then
    echo "Cloning omarchy-configuration to $DEST"
    git clone "${OMARCHY_CONF_REPO:-https://github.com/<you>/omarchy-configuration.git}" "$DEST"
  fi
  SCRIPT_DIR="$DEST"
fi

echo "=== omarchy-configuration setup (Omarchy-only) ==="
bash "$SCRIPT_DIR/scripts/ensure-shell-terminal.sh"
bash "$SCRIPT_DIR/scripts/ensure-apps.sh"
bash "$SCRIPT_DIR/scripts/ensure-development.sh"
bash "$SCRIPT_DIR/scripts/ensure-connectivity.sh"
bash "$SCRIPT_DIR/scripts/ensure-plugins.sh"
bash "$SCRIPT_DIR/scripts/prune-apps.sh"
bash "$SCRIPT_DIR/scripts/link-keybinds.sh"
bash "$SCRIPT_DIR/scripts/ensure-monitors.sh"
bash "$SCRIPT_DIR/scripts/ensure-aesthetics.sh"
bash "$SCRIPT_DIR/scripts/ensure-idle-suspend.sh"
bash "$SCRIPT_DIR/scripts/dualboot-scan.sh"
bash "$SCRIPT_DIR/scripts/limine-timeout.sh"
echo "=== Done. Reboot to confirm Limine timeout; new terminals use new keybinds. ==="
