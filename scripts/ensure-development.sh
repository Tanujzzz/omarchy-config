#!/bin/bash
# Basic PHP/Node/DDEV readiness only: no projects, databases or containers created.
set -euo pipefail
[[ "${1:-}" != "--dry-run" ]] || export DRY_RUN=1
DRY_RUN="${DRY_RUN:-0}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ "$DRY_RUN" == 1 ]]; then
  echo '[dry-run] configure /etc/php/conf.d/zz-omarchy-configuration.ini (extensions + Xdebug debug mode; preserve other PHP settings)'
  echo '[dry-run] verify PHP modules and Composer'
  echo '[dry-run] mise use --global --fuzzy node@latest; verify Node.js and npm'
  echo '[dry-run] verify existing Docker/Compose; enable docker.service and ensure user docker group membership'
  echo '[dry-run] TRUST_STORES=system mkcert -install (system trust only)'
  echo '[dry-run] verify DDEV executable; no project setup or containers started'
  exit 0
fi

for command in php composer mise docker mkcert ddev python3; do
  command -v "$command" >/dev/null || { echo "Missing prerequisite: $command (run ensure-apps.sh first)" >&2; exit 1; }
done
docker compose version >/dev/null

PHP_INI=/etc/php/conf.d/zz-omarchy-configuration.ini
TMP_INI=$(mktemp)
trap 'rm -f "$TMP_INI"' EXIT
python3 "$REPO_DIR/scripts/setup-config.py" php /etc/php "$(php -n -m)" >"$TMP_INI"
if ! cmp -s "$TMP_INI" "$PHP_INI"; then
  if [[ -f "$PHP_INI" ]]; then sudo cp -a "$PHP_INI" "$PHP_INI.bak.$(date +%s%N)"; fi
  sudo install -m 644 "$TMP_INI" "$PHP_INI"
fi
php -r '
foreach (["bcmath", "curl", "iconv", "intl", "pdo_mysql", "pdo_sqlite", "zip", "xdebug"] as $module) {
    if (!extension_loaded($module)) { fwrite(STDERR, "Missing PHP extension: $module\n"); exit(1); }
}
if (ini_get("xdebug.mode") !== "debug") { fwrite(STDERR, "Xdebug debug mode not active\n"); exit(1); }
'
composer --version

# Explicit floating request overrides Mise's optional pin setting.
mise use --global --fuzzy node@latest
mise exec node@latest -- node --version
mise exec node@latest -- npm --version

sudo systemctl enable --now docker.service
SETUP_USER=$(id -un)
if ! id -nG "$SETUP_USER" | tr ' ' '\n' | grep -qx docker; then
  sudo usermod -aG docker "$SETUP_USER"
fi
if ! id -nG | tr ' ' '\n' | grep -qx docker; then
  echo '==> Docker group configured. Log out and back in before using DDEV.'
  sg docker -c 'docker info >/dev/null'
else
  docker info >/dev/null
fi

# Only the system trust store: no browser profile or extension changes.
TRUST_STORES=system mkcert -install
ddev version
echo '==> Development tools ready; no DDEV project has been configured or started'
