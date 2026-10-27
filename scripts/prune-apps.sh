#!/bin/bash
# Remove unwanted apps ONLY if installed AND dependency-clean.
# Anything required by another package (e.g. mpv <- mpv-mpris) is SKIPPED + warned.
# Needs sudo for removals. See packages/remove.txt.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"

# Omarchy-critical: never remove even if leaf (safety net)
CRITICAL="hyprland quickshell uwsm xdg-terminal-exec"

while read -r pkg || [[ -n "$pkg" ]]; do
  [[ "$pkg" =~ ^#.*$ || -z "$pkg" ]] && continue
  if ! pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg not installed, skipping"
    continue
  fi
  if [[ " $CRITICAL " == *" $pkg "* ]]; then
    echo "==> $pkg is Omarchy-critical, skipping"
    continue
  fi
  qi_out=$(pacman -Qi "$pkg" 2>/dev/null) || { echo "==> $pkg query failed, SKIPPING (fail closed)"; continue; }
  required_by=$(echo "$qi_out" | awk -F': ' '/^Required By/{print $2}')
  if [[ -n "$required_by" && "$required_by" != "None" ]]; then
    echo "==> $pkg required by [$required_by], SKIPPING (dependency guard)"
    continue
  fi
  echo "==> Removing $pkg"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] omarchy-pkg-drop $pkg"
  else
    omarchy-pkg-drop "$pkg"
  fi
done <"$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/packages/remove.txt"

# Stale launchers for removed terminals (user-owned copies, safe to drop
# once the binary is gone and it isn't the active default)
for term in foot alacritty; do
  if ! command -v "$term" &>/dev/null; then
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[dry-run] remove stale launcher: $HOME/.local/share/applications/$term.desktop"
    else
      rm -f ~/.local/share/applications/"$term".desktop
    fi
  fi
done
