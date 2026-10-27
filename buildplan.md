# Build Plan — Omarchy-only portable setup (v1, reviewed)

Date: 2026-09-15. Machine: Omarchy 4.0.3-1, Hyprland 0.56.2.
Installer: `install.sh` (bash, `set -euo pipefail`), idempotent check-then-act,
`--dry-run` support, timestamped backups + manifest restore.
Rule: every change is validated on the live machine FIRST, then encoded into the script.
Reviewed by Codex (Orca orchestration runs `run_30570d374b75`, `run_29f42d79424a`,
`run_4e67c9d0fe9c`) — all agreed with improvements applied.

## Repo layout

```
install.sh
scripts/
  ensure-shell-terminal.sh
  limine-timeout.sh
  ensure-apps.sh
  prune-apps.sh
  link-keybinds.sh
  ensure-idle-suspend.sh
config/
  hypr/bindings.lua
  kitty/kitty.conf
  fish/config.fish
  omarchy/shell.json        # snapshot only, Omarchy-owned pattern
packages/
  keep.txt                  # must-keep + confirmed keeps
  remove.txt                # prune candidates (guarded)
baseline/                   # read-only snapshot of live configs at build start
hypr-setup.md               # what/why/commands/how-to incl. prior bindings
CHANGELOG.md                # every change tracked
buildplan.md                # this file
```

## P1 — shell / terminal
- `omarchy install terminal kitty` always (also when kitty is present) so kitty becomes
  the registered default; Ghostty fallback only if kitty install fails.
- `~/.config/kitty/kitty.conf` += `shell /usr/bin/fish` (keep Omarchy theme include).
- Install via pacman helper: `fish`, `fastfetch`; fisher core (fish plugin manager, no themes);
  `starship init fish | source` in fish config (Starship already installed; no Tide).
- fastfetch interactive-only guard in `~/.bashrc` and `fish/config.fish`.
- `chsh -s /usr/bin/fish` stays a runtime password prompt; never automated silently.
- Manual path (user runs themselves): `sudo pacman -S --needed fish && chsh -s /usr/bin/fish`.

## P2 — bootloader (Limine, NOT grub)
- Step 0 (proven): `timeout:` is a valid Limine directive (CONFIG.md + template
  `/usr/share/omarchy/default/limine/limine.conf:2` `#timeout: 3`). The
  `/etc/limine-entry-tool.d/` drop-ins only carry entry-tool options
  (KERNEL_CMDLINE etc.), NOT limine.conf directives — so the timeout goes into
  the `/boot/limine.conf` header, which entry managers preserve across updates.
- Dual-boot (`scripts/dualboot-scan.sh`, runs BEFORE timeout): opt-in prompt
  `[y/N, default No]` on `/dev/tty` — fresh dual-boot install? Run
  `limine-scan` (auto-detects Windows/Ubuntu/anything on any disk, single or
  separate). User answers the scan's own selections. Backup before scan, entry
  diff after, default boot entry left untouched, re-confirm if a foreign entry
  already exists, skip when no TTY. No disk-specific logic.
- Backup `/boot/limine.conf`; set (or insert) `timeout: 15` in the header.
  No forced regen (avoids overwrite risk); post-verify + confirm on next reboot;
  restore backup on failure; re-run script if a future update ever drops it.

## P3 — apps ensure (install if missing)
- Check `yay` exists first (needed for AUR); install yay if missing.
- AUR via `yay`/`omarchy-pkg-aur-add`: `zen-browser-bin`, `visual-studio-code-bin`.
- Repo via `omarchy-pkg-add`: `discord`, `spotify`, `vlc`, `kitty`, `fish`, `fastfetch`.
- Untouched keeps: `libreoffice-fresh`, `evince`, `obsidian`, docker stack
  (`docker`, `docker-compose`, `lazydocker`), `localsend`, `ufw`, printing stack,
  all dev tools (`mise`, `lazygit`, `tmux`, `btop`, `fzf`, `ripgrep`, `bat`, `eza`,
  `zoxide`, `tldr`, `nvim`).
- Bitwarden: skipped (not installed). Chromium: kept; Zen set default via
  `xdg-settings` + verified with `omarchy launch browser`.

## P4 — prune (remove ONLY if installed AND dep-clean)
- Candidates: `mpv` (expect SKIP: required by `mpv-mpris`), `obs-studio`, `kdenlive`,
  `pinta`, `xournalpp`.
- Guard per package: `pacman -Q` present? then `pacman -Qi` reverse-deps / Required By
  empty and not in Omarchy-critical set? else SKIP + warn. Uses `omarchy-pkg-drop`
  (source-agnostic, works for AUR too).
- Gaming/services: mostly absent → skip, not remove.

## P5 — keybinds (`~/.config/hypr/bindings.lua` ONLY, update-safe overlay)
Loaded after `default.hypr.omarchy`, so `omarchy update` never wipes them.
Pattern: `hl.unbind` existing first, then `o.bind`. Validate every change with
`hyprctl reload` + `hyprctl configerrors` until clean.

| Action | Key | Prior binding (unbind first) |
|---|---|---|
| Terminal | `SUPER+RETURN` | keep |
| Launcher/menu | `SUPER+SPACE` | keep |
| Browser (Zen default) | `SUPER+B` | unbind `SUPER+SHIFT+RETURN`, `SUPER+SHIFT+B` dupes |
| Files (Nautilus) | `SUPER+F` | unbind `SUPER+F` fullscreen |
| Fullscreen | `SUPER+SHIFT+F` | unbind `SUPER+SHIFT+F` file manager (swap) |
| Close window | `SUPER+Q` | remove `SUPER+W` close |
| VS Code (`code`) | `SUPER+W` | free after close moved |
| Editor (generic) | `SUPER+SHIFT+N` | keep |
| Discord | `SUPER+D` | free |
| Spotify (`spotify`) | `SUPER+S` | unbind `SUPER+S` + `SUPER+ALT+S` scratchpad (dropped; commented restore snippet kept) |
| Screenshots | `SUPER+SHIFT+S` + keep `PRINT` | unbind `SUPER+SHIFT+S` Google Maps |
| Universal copy/paste/cut | `SUPER+C/V/X` | keep |
| Lock `SUPER+CTRL+L`, floating `SUPER+T` | — | keep |
| Workspaces `SUPER+1..0`, move `SUPER+SHIFT+1..0` | — | keep |

## P6 — docs
- `hypr-setup.md`: what changed, what each command does, per-feature how-to, prior bindings table.
- `CHANGELOG.md`: dated entry per change/app.

## P7 — idle auto-suspend (2026-09-16)
- Root cause: Omarchy shell idle = screensaver (150s) + lock (300s) only;
  logind `IdleAction=ignore`; Hyprland feeds no idle hints to logind.
- Fix: `hypridle` (repo pkg, in `packages/keep.txt`) +
  `config/hypr/hypridle.conf` template (`__IDLE_SUSPEND_SEC__`, default 900)
  rendered to `~/.config/hypr/hypridle.conf` + `hypridle.service` (user)
  enabled. Config change restarts the service (no hot-reload in hypridle). Suspend guard respects Omarchy stay-awake state file; fullscreen
  inhibits honored (defaults); lock/wake via `omarchy-system-lock` /
  `omarchy-system-wake`. Script: `scripts/ensure-idle-suspend.sh`
  (idempotent, `DRY_RUN`, `IDLE_SUSPEND_SEC` override, warns if < 300s),
  wired into `install.sh` after aesthetics.

## Validation gates
- `hyprctl reload && hyprctl configerrors` clean after P5.
- `omarchy restart terminal`; Zen default check; fish + fastfetch in both shells.
- Normal + `--dry-run` reinstall paths; rollback from manifest.

## Approved extension — 2026-10-27

Scope: kdeconnect, php, composer, php-sqlite, xdebug, ddev-bin, mkcert,
Node.js/npm, Instrument Cluster, OmaConnect, and Orca only. No version pins.
The historical live-first workflow above is not used for this extension:
only repository files are changed, with isolated validation before the user
chooses to run the installer.

- `packages/keep.txt` is now executable input for `ensure-apps.sh`. Optional
  `:latest` policy updates the approved additions; original entries retain
  install-if-missing behavior. No automatic full-system/partial-sync upgrade.
- `scripts/ensure-development.sh`: PHP extension drop-in, floating Mise Node,
  existing Docker readiness, system CA trust, CLI verification. No Drupal or
  DDEV project provisioning, no extra apps, browser extensions or themes.
- `scripts/ensure-connectivity.sh`: only KDE Connect UFW port rules.
- `scripts/ensure-plugins.sh`: current default-branch installs/updates of the
  two approved plugins; backups for copied plugins; preserve unrelated shell
  configuration using `scripts/setup-config.py`.
- All three steps run after app installation in `install.sh` and support
  read-only dry-run. The existing prune dry-run launcher deletion is guarded.
- Validation: shell syntax, isolated PHP/shell config transforms, package
  manager stubs, plugin validation failures/migration, and dry-run snapshots.
  Installation against a fresh privileged Omarchy system remains a manual check.
