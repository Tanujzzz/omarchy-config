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
