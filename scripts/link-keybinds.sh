#!/bin/bash
# Install update-safe keybind overlay (config/hypr/bindings.lua -> live).
# No sudo needed. Validates with hyprctl reload + configerrors.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] copy config/hypr/bindings.lua -> ~/.config/hypr/bindings.lua + hyprctl reload"
  exit 0
fi

cp ~/.config/hypr/bindings.lua ~/.config/hypr/bindings.lua.bak.$(date +%s)
cp "$REPO_DIR/config/hypr/bindings.lua" ~/.config/hypr/bindings.lua
hyprctl reload
errors=$(hyprctl configerrors 2>&1 || true)
if [[ -n "$errors" ]]; then
  echo "Config errors detected:"
  echo "$errors"
  exit 1
fi
echo "Keybinds applied, no config errors."
