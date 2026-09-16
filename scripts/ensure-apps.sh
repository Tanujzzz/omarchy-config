#!/bin/bash
# Install must-have apps if missing. Needs sudo for installs.
# Sources: repo (official incl. omarchy repo) via omarchy-pkg-add,
#          AUR via yay. See packages/keep.txt.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
run() { if [[ "$DRY_RUN" == "1" ]]; then echo "[dry-run] $*"; else eval "$*"; fi; }

REPO_PKGS=(kitty fish fastfetch nano discord spotify vlc)
AUR_PKGS=(zen-browser-bin visual-studio-code-bin)

# yay is required for AUR packages
if ! command -v yay &>/dev/null; then
  echo "==> Installing yay (needed for AUR)"
  run "omarchy-pkg-add yay"
fi

for pkg in "${REPO_PKGS[@]}"; do
  if pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg already installed, skipping"
  else
    echo "==> Installing $pkg (repo)"
    run "omarchy-pkg-add $pkg"
  fi
done

for pkg in "${AUR_PKGS[@]}"; do
  if pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg already installed, skipping"
  else
    echo "==> Installing $pkg (AUR)"
    run "omarchy-pkg-aur-add $pkg"
  fi
done

# Zen as default browser (chromium stays installed for webapp engine)
if [[ "$(xdg-settings get default-web-browser 2>/dev/null)" == "zen.desktop" ]]; then
  echo "==> Zen already default browser, skipping"
else
  echo "==> Setting Zen as default browser"
  run "xdg-settings set default-web-browser zen.desktop"
  run "omarchy launch browser --help >/dev/null && echo '(verify: omarchy launch browser opens Zen)'"
fi
