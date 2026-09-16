#!/bin/bash
# Aesthetics: 12px rounding + opaque windows, duck fastfetch, 1.25x bar.
# No sudo needed. Hyprland validated via hyprctl; shell.toml hot-reloads.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# 1. looknfeel overlay (rounding + opacity)
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] copy config/hypr/looknfeel.lua -> ~/.config/hypr/looknfeel.lua + hyprctl reload"
else
  cp ~/.config/hypr/looknfeel.lua ~/.config/hypr/looknfeel.lua.bak.$(date +%s)
  cp "$REPO_DIR/config/hypr/looknfeel.lua" ~/.config/hypr/looknfeel.lua
  hyprctl reload
  errors=$(hyprctl configerrors 2>&1 || true)
  if [[ -n "$errors" ]]; then echo "Config errors:"; echo "$errors"; exit 1; fi
  echo "==> looknfeel applied, no config errors"
fi

# 2. fastfetch config + duck logo
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] copy config/fastfetch/{config.jsonc,duck.png} -> ~/.config/fastfetch/"
else
  mkdir -p ~/.config/fastfetch
  [[ -f ~/.config/fastfetch/config.jsonc ]] && cp ~/.config/fastfetch/config.jsonc ~/.config/fastfetch/config.jsonc.bak.$(date +%s)
  [[ -f ~/.config/fastfetch/duck.png ]] && cp ~/.config/fastfetch/duck.png ~/.config/fastfetch/duck.png.bak.$(date +%s)
  cp "$REPO_DIR/config/fastfetch/config.jsonc" ~/.config/fastfetch/config.jsonc
  cp "$REPO_DIR/config/fastfetch/duck.png" ~/.config/fastfetch/duck.png
  fastfetch -c ~/.config/fastfetch/config.jsonc >/dev/null && echo "==> fastfetch config valid"
fi

# 4. imv: disable Tensaku action when tensaku is pruned (else dead Ctrl+E)
if ! command -v tensaku-edit &>/dev/null && grep -q "^<Ctrl+e>.*tensaku" ~/.config/imv/config 2>/dev/null; then
  echo "==> Disabling dead imv Tensaku action"
  if [[ "$DRY_RUN" == "1" ]]; then
    echo "[dry-run] comment out tensaku line in ~/.config/imv/config"
  else
    cp ~/.config/imv/config ~/.config/imv/config.bak.$(date +%s)
    sed -i 's|^<Ctrl+e>.*tensaku|# Tensaku removed (omarchy-configuration prune) — Ctrl+E disabled.\n# &|' ~/.config/imv/config
  fi
else
  echo "==> imv Tensaku action already handled, skipping"
fi

# 5. bar 1.25x via shell.toml tokens (both orientations; font-scale multiplies)
if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] set [bar] size-horizontal=33 size-vertical=35 in ~/.config/omarchy/shell.toml"
else
  cp ~/.config/omarchy/shell.toml ~/.config/omarchy/shell.toml.bak.$(date +%s)
  python3 - "$HOME/.config/omarchy/shell.toml" <<'EOF'
import sys
path = sys.argv[1]
with open(path) as f:
    lines = f.read().splitlines()
out, in_bar, seen, bar_idx = [], False, set(), None
for i, line in enumerate(lines):
    s = line.strip()
    if s.startswith('['):
        in_bar = (s == '[bar]')
        if in_bar and bar_idx is None:
            bar_idx = len(out)
        out.append(line)
        continue
    if in_bar and s.startswith('size-horizontal'):
        out.append('size-horizontal = 33'); seen.add('h'); continue
    if in_bar and s.startswith('size-vertical'):
        out.append('size-vertical = 35'); seen.add('v'); continue
    out.append(line)
missing = []
if 'h' not in seen:
    missing.append('size-horizontal = 33')
if 'v' not in seen:
    missing.append('size-vertical = 35')
if missing:
    if bar_idx is None:
        out.append('[bar]')
        out.extend(missing)
    else:
        out[bar_idx + 1:bar_idx + 1] = missing
with open(path, 'w') as f:
    f.write('\n'.join(out) + '\n')
EOF
  echo "==> bar tokens set (shell hot-reloads; omarchy restart shell if needed)"
fi
