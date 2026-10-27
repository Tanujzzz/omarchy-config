#!/bin/bash
# KDE Connect's range is applied to IPv4/IPv6 when UFW IPv6 is enabled.
set -euo pipefail
[[ "${1:-}" != "--dry-run" ]] || export DRY_RUN=1
if [[ "${DRY_RUN:-0}" == 1 ]]; then
  echo "[dry-run] sudo ufw allow 1714:1764/tcp comment 'KDE Connect'"
  echo "[dry-run] sudo ufw allow 1714:1764/udp comment 'KDE Connect'"
  exit 0
fi
command -v kdeconnect-cli >/dev/null
command -v ufw >/dev/null
sudo ufw allow 1714:1764/tcp comment 'KDE Connect'
sudo ufw allow 1714:1764/udp comment 'KDE Connect'
echo '==> KDE Connect firewall rules ready; pair devices through OmaConnect'
