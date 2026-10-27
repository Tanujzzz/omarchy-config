# Changelog

## 2026-10-27 — approved development tools and connectivity
- Added only the approved packages: kdeconnect, php, composer, php-sqlite,
  xdebug, mkcert, ddev-bin, and orca-ide-bin. `ensure-apps.sh` now reads
  `packages/keep.txt`; `:latest` entries query current package candidates on
  reruns as well as fresh installs. Existing entries retain install-if-missing
  behavior. No release numbers are pinned.
- Added `ensure-development.sh`: a dedicated PHP extension/Xdebug drop-in
  (avoids duplicate extension declarations), floating `node@latest` via Mise,
  Docker service/group readiness, and mkcert system trust. Verifies Composer,
  PHP, Node/npm and DDEV; creates no DDEV/Drupal projects, databases or containers.
- Added `ensure-connectivity.sh`: KDE Connect TCP/UDP 1714–1764 UFW rules;
  device pairing remains interactive. Does not enable an inactive firewall.
- Added `ensure-plugins.sh`: Instrument Cluster and OmaConnect from their
  upstream default branches, with validation and fast-forward updates.
  Previously copied plugin directories are backed up before migration to git.
  Only the clock/center anchor and missing OmaConnect bar entry are configured;
  existing layout, theme, idle settings and other plugins are preserved.
- Guarded stale terminal launcher cleanup during dry-run so previewing these
  additions does not delete launchers. Added isolated regression checks for
  configuration preservation, repeat runs, package scope and dry-run behavior.
- Repository changes only; the live installer was not executed during this update.

## 2026-09-17 — idle suspend timeout 30 min → 15 min
- First idle test showed screen off but CPU on — but 30 min had not elapsed,
  so that was the pre-suspend lock state, not a failed suspend.
- Default `IDLE_SUSPEND_SEC` 1800 → 900 in `scripts/ensure-idle-suspend.sh`;
  applied live (`timeout = 900`, service restarted).
- Robustness fix in the script: hypridle does not hot-reload its config, so
  a changed `hypridle.conf` now triggers `systemctl --user restart
  hypridle.service` (previously `enable --now` was a no-op on the running
  service and the new timeout would not have taken effect).

## 2026-09-16 — idle auto-suspend fix
- Symptom: manual menu suspend worked (screen + CPU off), but idle timeout
  only blanked the screen while the CPU kept running.
- Root cause: Omarchy's shell idle service handles screensaver (150s) + lock
  (300s) only — no suspend step exists; logind `IdleAction` stays `ignore`.
- Fix (live-validated): `hypridle` installed + `~/.config/hypr/hypridle.conf`
  with one listener (`systemctl suspend` after 1800s idle) + user service
  enabled. Proof: a temporary 20s marker listener fired on idle; stay-awake
  guard verified in both modes; service reports `found 1 rules`, active.
- Encoded: `scripts/ensure-idle-suspend.sh` (idempotent, `DRY_RUN`,
  `IDLE_SUSPEND_SEC` override, warns if < 300s lock), wired into
  `install.sh`; `repo:hypridle` added to `packages/keep.txt`; template in
  `config/hypr/hypridle.conf`; docs in `hypr-setup.md`.

## 2026-09-15 — v1 build (Omarchy-only)
- Baseline snapshot saved to `baseline/` (bindings, hyprland.lua, kitty.conf, shell.json, bashrc).
- Keybinds overlay applied live, `hyprctl configerrors` clean: browser SUPER+B,
  files SUPER+F, fullscreen SUPER+SHIFT+F, close SUPER+Q, VS Code SUPER+W,
  Discord SUPER+D, Spotify SUPER+S (scratchpad dropped), screenshots SUPER+SHIFT+S.
- fastfetch guard added to `~/.bashrc`; fish config (starship + fastfetch) written
  to `~/.config/fish/config.fish` (pending fish install for live use).
- Scripts added: ensure-shell-terminal, limine-timeout (15s), ensure-apps,
  prune-apps (dep-guarded), link-keybinds; orchestrated by `install.sh`.
- Deferred to interactive `install.sh` run (needs sudo/password): fish + fisher
  install, Kitty fish wiring, Limine timeout apply, app installs/prunes, chsh.
- Dual-boot step added: opt-in `limine-scan` prompt (default No, `/dev/tty`),
  runs before timeout, entry diff, default order untouched, TTY-gated.
- Added `nano` to repo ensure list.
- Aesthetics batch (live-validated): 12px rounding + opaque-window toggle in
  looknfeel.lua; duck-logo fastfetch (Master/Host/os/shell/wm/uptime/cpu/
  discrete-gpu/media/colors); bar 1.25x via shell.toml tokens.
- Fix: fastfetch keys now icon+label with ASCII-safe `\u` icon escapes
  (bare glyphs were stripped in transit); fish greeting silenced.
- Fix: per-module `keyWidth: 10` so values align in a column (global
  `display.keyWidth` is unknown in fastfetch 2.68).
- Widened to `keyWidth: 25`, keys in Miasma accent `#78824b`, blank `break`
  between every row for breathing room.
- Retuned per feedback: `keyWidth: 15`; keys alternate Miasma accent `#78824b`
  / bright `#c2c2b0` (inline `{#NN}` codes are dropped in keys; `{$N}` stays
  literal — alternating `keyColor` is the robust path); restored `colors`
  module (rebuild script had dropped the dict form); grouped breaks instead
  of per-row (logo 16x14 to match).
- Final tune: single accent `#78824b` for all keys, no internal breaks
  (contiguous block + swatch), logo back to 22x20.
- Monitor max-refresh step: per-monitor explicit modes at native res
- Coverage fix: imv Tensaku-disable encoded in ensure-aesthetics.sh (was
  live-only). Full audit 2026-09-15: every live change maps to a script step;
  end-to-end dry-run green and idempotent.
- Prune list += omacut, tensaku, cliamp, moonlight-qt, foot (+ fallout fixes:
  unbound dead Music-TUI bind, disabled imv Ctrl+E tensaku action, stale
  terminal .desktop cleanup). Pending your interactive run (needs sudo).
  (HDMI-A-1 → 1920x1080@180 live), marker-delimited managed block preserving
  hand edits, fail-loud detection, backup + rollback. Review fixes: Hz
  precision, tmpfile status propagation, block-via-file (no stdin clash),
  post-validation repo sync, `grep -qF --` marker match.
- Codex script review applied: curl|bash repo bootstrap, chsh reads /dev/tty,
  per-command sudo for Limine edit, ERR-trap restore, exact `^timeout: N$`
  verification, LIMINE_TIMEOUT numeric validation, fail-closed dep-guard.
