#!/bin/bash
# Install the package manifest. :latest entries also update existing installs.
# Use a current Omarchy system/package database; never run a partial pacman -Sy.
set -euo pipefail

[[ "${1:-}" != "--dry-run" ]] || export DRY_RUN=1
DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
run() {
  if [[ "$DRY_RUN" == 1 ]]; then printf '[dry-run] '; printf '%q ' "$@"; printf '\n'; else "$@"; fi
}

REPO_PKGS=() AUR_PKGS=() LATEST_REPO_PKGS=() LATEST_AUR_PKGS=()
while IFS=: read -r source pkg policy extra || [[ -n "$source" ]]; do
  [[ -z "$source" || "$source" == \#* ]] && continue
  if [[ ! "$source" =~ ^(repo|aur)$ || ! "$pkg" =~ ^[a-zA-Z0-9][a-zA-Z0-9@._+-]*$ ||
        ! "${policy:-}" =~ ^(latest)?$ || -n "${extra:-}" ]]; then
    echo "Invalid package entry: $source:$pkg:${policy:-}" >&2; exit 1
  fi
  if [[ "$source" == repo && "${policy:-}" == latest ]]; then LATEST_REPO_PKGS+=("$pkg")
  elif [[ "$source" == aur && "${policy:-}" == latest ]]; then LATEST_AUR_PKGS+=("$pkg")
  elif [[ "$source" == repo ]]; then REPO_PKGS+=("$pkg")
  else AUR_PKGS+=("$pkg"); fi
done <"$REPO_DIR/packages/keep.txt"

if ! command -v yay &>/dev/null; then run omarchy pkg add yay; fi

for pkg in "${REPO_PKGS[@]}"; do
  if pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg already installed, skipping"
  else
    echo "==> Installing $pkg (repo)"
    run omarchy pkg add "$pkg"
  fi
done

for pkg in "${AUR_PKGS[@]}"; do
  if pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg already installed, skipping"
  else
    echo "==> Installing $pkg (AUR)"
    run omarchy pkg aur add "$pkg"
  fi
done

# The Omarchy add helpers skip installed packages. Direct package-manager calls
# resolve current candidates for the approved additions even on a rerun.
if (( ${#LATEST_REPO_PKGS[@]} )); then
  run sudo pacman -S --needed --noconfirm -- "${LATEST_REPO_PKGS[@]}"
fi
if (( ${#LATEST_AUR_PKGS[@]} )); then
  run yay -S --needed --noconfirm -- "${LATEST_AUR_PKGS[@]}"
fi

# Zen as default browser (chromium stays installed for webapp engine)
if [[ "$(xdg-settings get default-web-browser 2>/dev/null)" == "zen.desktop" ]]; then
  echo "==> Zen already default browser, skipping"
else
  echo "==> Setting Zen as default browser"
  run xdg-settings set default-web-browser zen.desktop
fi
