#!/bin/bash
# Ensure Kitty is the default terminal, fish is installed and wired up.
# Idempotent: every step checks first. Needs sudo for package installs.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
run() { if [[ "$DRY_RUN" == "1" ]]; then echo "[dry-run] $*"; else eval "$*"; fi; }

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. Kitty default (always enforce so it stays Super+Return)
if ! head -n 20 ~/.config/xdg-terminals.list 2>/dev/null | grep -q "^kitty.desktop"; then
  echo "==> Setting Kitty as default terminal"
  run "omarchy install terminal kitty"
else
  echo "==> Kitty already default, skipping"
fi

# 2. Packages (repo): fish, fastfetch
for pkg in fish fastfetch; do
  if pacman -Q "$pkg" &>/dev/null; then
    echo "==> $pkg already installed, skipping"
  else
    echo "==> Installing $pkg"
    run "omarchy-pkg-add $pkg"
  fi
done

# 3. Kitty uses fish (only meaningful once fish exists)
if command -v fish &>/dev/null; then
  if grep -q "^shell /usr/bin/fish" ~/.config/kitty/kitty.conf 2>/dev/null; then
    echo "==> Kitty already uses fish, skipping"
  else
    echo "==> Wiring Kitty to fish"
    if [[ "$DRY_RUN" == "1" ]]; then
      echo "[dry-run] copy config/kitty/kitty.conf -> ~/.config/kitty/kitty.conf"
    else
      cp ~/.config/kitty/kitty.conf ~/.config/kitty/kitty.conf.bak.$(date +%s)
      cp "$REPO_DIR/config/kitty/kitty.conf" ~/.config/kitty/kitty.conf
      omarchy restart terminal || true
    fi
  fi
else
  echo "==> fish not present yet, deferring Kitty shell wiring"
fi

# 4. Fish config (starship + fastfetch, fisher core)
echo "==> Installing fish config"
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] copy config/fish/config.fish -> ~/.config/fish/config.fish"
else
  mkdir -p ~/.config/fish
  [[ -f ~/.config/fish/config.fish ]] && cp ~/.config/fish/config.fish ~/.config/fish/config.fish.bak.$(date +%s)
  cp "$REPO_DIR/config/fish/config.fish" ~/.config/fish/config.fish
fi
if command -v fish &>/dev/null && ! fish -c "fisher --version" &>/dev/null; then
  echo "==> Installing fisher (core only)"
  run "fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher'"
else
  echo "==> fisher already present or fish missing, skipping"
fi

# 5. fastfetch in bash (interactive shells only)
if grep -q "omarchy-configuration: system info" ~/.bashrc 2>/dev/null; then
  echo "==> bash fastfetch guard already present, skipping"
else
  echo "==> Adding fastfetch guard to ~/.bashrc"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] append fastfetch guard to ~/.bashrc"
  else
    cat >>~/.bashrc <<'EOF'

# omarchy-configuration: system info on every interactive terminal
if command -v fastfetch >/dev/null 2>&1; then
  fastfetch
fi
EOF
  fi
fi

# 6. Login shell -> fish (interactive prompt, never forced)
if [[ "${SHELL:-}" == *fish ]]; then
  echo "==> Login shell already fish, skipping"
elif [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] chsh -s /usr/bin/fish (interactive)"
else
  read -rp "Set fish as your login shell now? (needs password) [y/N] " ans </dev/tty
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    chsh -s /usr/bin/fish
  else
    echo "Skipped. Run manually: chsh -s /usr/bin/fish"
  fi
fi
