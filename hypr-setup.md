# Hypr Setup — Omarchy personal overlay

Single-command setup: `curl -fsSL <raw-url>/install.sh | bash`
(Or clone + `bash install.sh`; preview with `bash install.sh --dry-run`.)
Scope: **Omarchy-only**. All configs sit in user files loaded *after* Omarchy
defaults, so `omarchy update` never overwrites them.

## What changed and why

### Shell / terminal (`scripts/ensure-shell-terminal.sh`)
- Kitty set as default via `omarchy install terminal kitty` (writes
  `~/.config/xdg-terminals.list`). Fallbacks (Ghostty etc.) only if Kitty install fails.
- Fish installed (`omarchy-pkg-add fish`); Kitty pointed at it via
  `shell /usr/bin/fish` in `~/.config/kitty/kitty.conf` (Omarchy theme include kept).
- Fisher **core only** (fish plugin manager; no Tide — Starship already covers the prompt).
- Starship enabled in fish via `starship init fish | source`.
- fastfetch on every interactive terminal: guard block in `~/.bashrc` + fish `config.fish`.
- Login shell: `chsh -s /usr/bin/fish` (interactive prompt at install; manual: same command).

### Boot menu (`scripts/dualboot-scan.sh`, `scripts/limine-timeout.sh`)
- Omarchy uses **Limine, not GRUB**. `timeout: 15` set in the `/boot/limine.conf`
  header (backup taken first, verified after, restored on failure).
- `/etc/limine-entry-tool.d/` drop-ins were deliberately NOT used: they only carry
  entry-tool options (KERNEL_CMDLINE…), not limine.conf directives.
- Dual-boot: on fresh installs the script asks `[y/N]` whether to run
  `limine-scan` (detects Windows/Ubuntu/anything on any disk); you answer its
  own prompts. Default boot order is left untouched — reorder manually if wanted.
- BitLocker note: if your Windows drive is encrypted, keep your 48-digit
  recovery key handy before re-scanning boot entries. Check via
  `blkid | grep -i bitlocker` (empty = not encrypted) or Windows
  Settings → Privacy & security → Device encryption.

### Apps (`scripts/ensure-apps.sh`, `scripts/prune-apps.sh`, `packages/`)
- Installed if missing — repo: kitty, fish, fastfetch, nano, discord, spotify, vlc;
  AUR (yay): `zen-browser-bin`, `visual-studio-code-bin`.
- Zen set as default browser (`xdg-settings`); **chromium kept** (webapp engine).
- Bitwarden skipped (not installed). Gaming/services skipped (absent).
- Removed only if installed AND dependency-clean: mpv (expected SKIP — required by
  `mpv-mpris`), obs-studio, kdenlive, pinta, xournalpp. Kept: libreoffice-fresh,
  evince, obsidian, docker stack, localsend, ufw, printing, all dev tools.

### Approved additions (2026-10-27)

The installer adds only the following items to the existing setup:

| Item | Source | Basic configuration |
|---|---|---|
| KDE Connect | Official `kdeconnect` package | UFW TCP/UDP ports 1714–1764; pair devices manually |
| PHP | Official `php` package | Enable bcmath, curl, iconv, intl, pdo_mysql and zip |
| Composer | Official `composer` package | Verify CLI availability |
| PHP SQLite | Official `php-sqlite` package | Enable pdo_sqlite |
| Xdebug | Official `xdebug` package | Load extension and set debug mode |
| DDEV | AUR `ddev-bin` | Verify executable, existing Docker/Compose and user access |
| mkcert | Official `mkcert` package | Generate/reuse local CA and trust it in the system store |
| Node.js and npm | Existing Omarchy Mise installation | Install/select floating `node@latest` globally |
| Instrument Cluster | `Tanujzzz/omarchy-instrument-cluster-plugin` | Replace stock clock and set its center anchor |
| OmaConnect | `jitendradara12/omaconnect` | Add its bar entry if absent |
| Orca | AUR `orca-ide-bin` | Install the packaged app and desktop launcher |

No versions are pinned. New package entries use the manifest format
`<repo|aur>:<package>:latest`, which also checks installed packages for updates;
existing two-field entries still install only if missing. Official packages
resolve against the configured pacman sync database and AUR packages use yay.
Start from an up-to-date Omarchy installation (`omarchy update`); this installer
does not perform a system-wide upgrade or a partial `pacman -Sy` refresh.
Node's explicit `@latest` request selects the latest release rather than merely
reusing an older installed version, and `--fuzzy` keeps the global setting unpinned.
Plugins clone the current upstream default branch and fast-forward on reruns;
local edits or unexpected git origins stop the update instead of discarding work.

`ensure-development.sh` writes only
`/etc/php/conf.d/zz-omarchy-configuration.ini`, preserving `php.ini` and other
drop-ins. It accounts for built-in/already declared extensions before adding
load directives. Docker and Compose are existing Omarchy prerequisites: the
script enables the Docker service and adds the current user to its group if
needed. New group membership requires logging out and back in for normal shells.
The script never runs `ddev config`, `ddev start`, Composer project installation,
or any Drupal setup. No database, project or container is created.

mkcert uses `TRUST_STORES=system`: browser profiles and extensions are not
modified. The CA is generated per machine; private keys are not stored here.
UFW creates IPv6 rules too when its existing IPv6 setting is enabled, and an
inactive firewall is left inactive.

`ensure-plugins.sh` preserves all other shell configuration. A non-git plugin
copy is saved under
`~/.local/state/omarchy-configuration/backups/plugins/` before migration;
changed shell JSON gets a timestamped sibling backup. The JSON patch preserves
the clock's formatting, existing OmaConnect settings/placement, bar position,
other widgets, theme and idle settings. No other plugins are installed.

Each new shell step accepts `--dry-run` or `DRY_RUN=1`. Preview the full existing
installer using `bash install.sh --dry-run`. Run isolated checks without changing
the live setup using `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests -v`.

References: [DDEV installation](https://docs.ddev.com/en/stable/users/install/ddev-installation/),
[mkcert trust stores](https://github.com/FiloSottile/mkcert#supported-root-stores),
[Mise use](https://mise.jdx.dev/cli/use.html),
[Instrument Cluster](https://github.com/Tanujzzz/omarchy-instrument-cluster-plugin),
[OmaConnect](https://github.com/jitendradara12/omaconnect).

### Keybinds (`config/hypr/bindings.lua` → `~/.config/hypr/bindings.lua`)
Update-safe overlay: `hl.unbind` defaults first, then `o.bind`. Validate with
`hyprctl reload && hyprctl configerrors`.

### Monitors (`scripts/ensure-monitors.sh`)
- Detects max refresh at native resolution per monitor from
  `hyprctl monitors all` and writes explicit modes (e.g. `1920x1080@180`).
- Touches only the managed marker block in `~/.config/hypr/monitors.lua`;
  hand-written lines and live scale vars are preserved; backup + rollback
  on `configerrors` failure. Reruns are idempotent (block replaced, not duped).

| Action | Key | Was |
|---|---|---|
| Browser | SUPER+B | SUPER+SHIFT+RETURN / SUPER+SHIFT+B (unbound) |
| Files | SUPER+F | SUPER+F was Full screen |
| Fullscreen | SUPER+SHIFT+F | was File manager (swap) |
| Close | SUPER+Q | SUPER+W (freed) |
| VS Code | SUPER+W | free |
| Editor (generic) | SUPER+SHIFT+N | kept |
| Discord | SUPER+D | free |
| Spotify | SUPER+S | was Toggle scratchpad (dropped; restore snippet in file) |
| Screenshots | SUPER+SHIFT+S (+PRINT kept) | was Google Maps |
| Copy/paste/cut | SUPER+C/V/X | kept (terminal-aware; CTRL+C is SIGINT in terminals) |
| Terminal, launcher, lock, floating, workspaces/move | unchanged | kept |

### Aesthetics (`scripts/ensure-aesthetics.sh`)
- Rounding 12px + fully opaque windows in `config/hypr/looknfeel.lua`
  (user overlay; toggle = comment out the opacity block to restore translucency).
- Fastfetch `~/.config/fastfetch/config.jsonc` + duck logo (`duck.png`,
  kitty-icat — renders in Kitty; other terminals fall back to text logo):
  Master (username) → Host (hostname) → os → shell → wm → uptime → cpu →
  gpu (discrete only via `hideType`, vendor-agnostic) → now-playing
  (`{artist} - {title}`, hidden when idle) → color swatch. No kernel/packages.
  Keys use Nerd Font icons stored as `\u` escapes (ASCII-safe in git).
- Fish: default greeting silenced (`set -g fish_greeting ""`) — fastfetch is
  the greeting.
- Bar 1.25x via `~/.config/omarchy/shell.toml` `[bar]` tokens
  (`size-horizontal = 33`, `size-vertical = 35`; both set so position changes
  stay scaled; shell font-scale multiplies on top). Hot-reloads.

### Idle auto-suspend (`scripts/ensure-idle-suspend.sh`)
- Root cause: Omarchy's shell idle service only does screensaver (150s) +
  lock (300s) — nothing ever suspends, so idle machines blanked the screen
  but kept the CPU running. Manual menu suspend (`systemctl suspend`) always
  worked; only the automatic step was missing. (logind `IdleAction` is not
  used: Hyprland doesn't feed it idle hints, and it would ignore fullscreen
  video inhibits.)
- Fix: `hypridle` (repo package) with `~/.config/hypr/hypridle.conf` holding a
  single listener — `systemctl suspend` after 900s (15 min) idle.
  Override: `IDLE_SUSPEND_SEC=3600 bash scripts/ensure-idle-suspend.sh`.
- Suspend is skipped while Omarchy "stay-awake" is on
  (`omarchy toggle idle stay-awake`); fullscreen/video inhibits pause the
  timer; `before_sleep_cmd`/`lock_cmd` re-lock via `omarchy-system-lock` and
  `after_sleep_cmd` runs `omarchy-system-wake` on resume.
- Service: `systemctl --user enable --now hypridle.service`
  (starts with graphical session). Check:
  `journalctl --user -u hypridle.service | grep 'found .* rules'`.

## Command reference
- `omarchy menu keybindings --print` — list effective keybinds
- `hyprctl reload && hyprctl configerrors` — validate Hyprland config
- `omarchy restart terminal` — reload terminals
- `omarchy launch browser` — should open Zen
- `xdg-settings get default-web-browser` — should print `zen.desktop`
