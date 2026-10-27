#!/bin/bash
# Only the two approved plugins; floating upstream default branches, no pins.
set -euo pipefail
[[ "${1:-}" != "--dry-run" ]] || export DRY_RUN=1
DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGINS_DIR="$HOME/.config/omarchy/plugins"
BACKUPS_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/omarchy-configuration/backups/plugins"
export GIT_TERMINAL_PROMPT=0

ensure_plugin() {
  local id="$1" url="$2" target="$PLUGINS_DIR/$1" origin stage backup
  if [[ "$DRY_RUN" == 1 ]]; then
    echo "[dry-run] install/update $id from $url (latest upstream default branch; back up existing non-git copy)"
    return
  fi
  if [[ -L "$target" ]]; then echo "Refusing symlinked plugin directory: $target" >&2; return 1; fi
  if [[ -d "$target/.git" ]]; then
    origin=$(git -C "$target" remote get-url origin)
    if [[ "$origin" != "$url" && "$origin" != "git@github.com:${url#https://github.com/}" ]]; then
      echo "Unexpected origin for $id: $origin; leaving it untouched" >&2; return 1
    fi
    if [[ -n "$(git -C "$target" status --porcelain)" ]]; then
      echo "Local changes in $target; back them up or commit before updating" >&2; return 1
    fi
    omarchy plugin update "$id" --yes
  else
    # Includes migration of the previously copied Instrument Cluster install.
    stage=$(mktemp -d)
    if ! git clone -- "$url" "$stage/plugin"; then rm -rf "$stage"; return 1; fi
    if ! omarchy plugin validate "$stage/plugin" ||
       [[ "$(jq -r .id "$stage/plugin/manifest.json")" != "$id" ]]; then
      echo "Invalid plugin or unexpected ID from $url" >&2; rm -rf "$stage"; return 1
    fi
    mkdir -p "$PLUGINS_DIR"
    backup=""
    if [[ -e "$target" ]]; then
      mkdir -p "$BACKUPS_DIR"
      backup="$BACKUPS_DIR/$id.$(date +%s%N)"
      mv "$target" "$backup"
      echo "==> Previous plugin saved to $backup"
    fi
    if ! mv "$stage/plugin" "$target"; then
      if [[ -n "$backup" ]]; then mv "$backup" "$target"; fi
      rm -rf "$stage"; return 1
    fi
    rmdir "$stage"
  fi
  omarchy plugin validate "$target"
}

ensure_plugin instrument-cluster https://github.com/Tanujzzz/omarchy-instrument-cluster-plugin.git
ensure_plugin omaconnect https://github.com/jitendradara12/omaconnect.git
if [[ "$DRY_RUN" == 1 ]]; then
  echo '[dry-run] replace stock clock with Instrument Cluster; add OmaConnect if absent; preserve all other shell settings'
  echo '[dry-run] rescan Omarchy plugins'
else
  python3 "$REPO_DIR/scripts/setup-config.py" shell "$HOME/.config/omarchy/shell.json" \
    /usr/share/omarchy/config/omarchy/shell.json
  omarchy-shell shell rescanPlugins >/dev/null
fi
