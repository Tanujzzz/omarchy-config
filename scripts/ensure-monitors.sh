#!/bin/bash
# Set each monitor to its highest refresh rate at native (max) resolution.
# Explicit modes (e.g. 1920x1080@180), per monitor independently, position auto.
# Writes only the managed block in ~/.config/hypr/monitors.lua (markers);
# hand-written lines outside the block are preserved. Idempotent.
# No sudo needed. Validates with hyprctl reload + configerrors, rolls back on failure.
set -euo pipefail

DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIVE=~/.config/hypr/monitors.lua
START="-- omarchy-configuration:monitors:start"
END="-- omarchy-configuration:monitors:end"

# Detect: output|WxH@Hz (max resolution, then max refresh). Fails loudly.
HYPRCTL_OUT="$(hyprctl monitors all 2>&1)" || { echo "hyprctl failed: $HYPRCTL_OUT"; exit 1; }
TMP_PLAN="$(mktemp)"
printf '%s\n' "$HYPRCTL_OUT" | python3 -c "
import sys, re
modes, cur_out = {}, None
for line in sys.stdin:
    m = re.match(r'Monitor (\S+)', line)
    if m:
        cur_out = m.group(1); modes[cur_out] = []
        continue
    if 'availableModes:' in line and cur_out:
        for res, hz in re.findall(r'(\d+x\d+)@([\d.]+)Hz', line):
            modes[cur_out].append((res, float(hz)))
if not any(modes.values()):
    sys.exit('no modes parsed')
for out, ms in modes.items():
    if not ms:
        continue
    maxpx = max(int(r.split('x')[0]) * int(r.split('x')[1]) for r, _ in ms)
    cand = [(r, h) for r, h in ms if int(r.split('x')[0]) * int(r.split('x')[1]) == maxpx]
    res, hz = max(cand, key=lambda x: x[1])
    print(f'{out}|{res}@{hz:g}')
" >"$TMP_PLAN" || { echo "Monitor detection failed, aborting (nothing changed)"; rm -f "$TMP_PLAN"; exit 1; }
mapfile -t PLAN <"$TMP_PLAN"
rm -f "$TMP_PLAN"

if [[ ${#PLAN[@]} -eq 0 ]]; then
  echo "No monitors detected, aborting (nothing changed)"
  exit 1
fi

echo "Detected max-refresh modes:"
printf '  %s\n' "${PLAN[@]}"

# Preserve live scale choices (default 1)
GDK_SCALE="$(grep -oP 'omarchy_gdk_scale = \K[0-9.]+' "$LIVE" 2>/dev/null || echo 1)"
MON_SCALE="$(grep -oP 'omarchy_monitor_scale = \K[0-9.]+' "$LIVE" 2>/dev/null || echo 1)"

BLOCK="$START
"
while IFS='|' read -r out mode; do
  BLOCK+="hl.monitor({ output = \"$out\", mode = \"$mode\", position = \"auto\", scale = omarchy_monitor_scale })
"
done < <(printf '%s\n' "${PLAN[@]}")
BLOCK+="$END"

if [[ "$DRY_RUN" == "1" ]]; then
  echo "[dry-run] upsert managed block in $LIVE:"
  printf '%s\n' "$BLOCK"
  exit 0
fi

cp "$LIVE" "$LIVE.bak.$(date +%s)"
if grep -qF -- "$START" "$LIVE"; then
  TMP_BLOCK="$(mktemp)"
  printf '%s\n' "$BLOCK" >"$TMP_BLOCK"
  python3 - "$LIVE" "$START" "$END" "$TMP_BLOCK" <<'EOF'
import sys
path, start, end, bpath = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(bpath) as f:
    block = f.read()
with open(path) as f:
    text = f.read()
pre, _, rest = text.partition(start)
_, _, post = rest.partition(end)
with open(path, 'w') as f:
    f.write(pre + block + post)
EOF
  rm -f "$TMP_BLOCK"
else
  # Ensure scale vars exist, then append managed block (later rules win)
  grep -q "omarchy_gdk_scale" "$LIVE" || printf '\nlocal omarchy_gdk_scale = %s\nlocal omarchy_monitor_scale = %s\n\nhl.env("GDK_SCALE", tostring(omarchy_gdk_scale))\n' "$GDK_SCALE" "$MON_SCALE" >>"$LIVE"
  printf '\n%s\n' "$BLOCK" >>"$LIVE"
fi
cp "$LIVE" "$REPO_DIR/config/hypr/monitors.lua"

hyprctl reload
errors=$(hyprctl configerrors 2>&1 || true)
if [[ -n "$errors" ]]; then
  echo "Config errors, restoring backup:"
  echo "$errors"
  latest="$(ls -t ~/.config/hypr/monitors.lua.bak.* | head -n 1)"
  cp "$latest" "$LIVE"
  cp "$LIVE" "$REPO_DIR/config/hypr/monitors.lua"
  hyprctl reload
  exit 1
fi
echo "==> monitors applied:"
hyprctl monitors 2>/dev/null | grep -E "^Monitor|@" | head -n 10
