-- Personal keybinding overrides for Omarchy.
-- Loaded AFTER Omarchy defaults (see ~/.config/hypr/hyprland.lua), so these win
-- and survive `omarchy update`. Validate: hyprctl reload && hyprctl configerrors

-- BROWSER on SUPER+B (unbind Omarchy's dupe binds first)
hl.unbind("SUPER + SHIFT + RETURN") -- was: Browser
hl.unbind("SUPER + SHIFT + B") -- was: Browser
o.bind("SUPER + B", "Browser", { omarchy = "browser" })

-- FILE MANAGER <-> FULLSCREEN swap
hl.unbind("SUPER + F") -- was: Full screen
hl.unbind("SUPER + SHIFT + F") -- was: File manager
o.bind("SUPER + F", "File manager", { omarchy = "nautilus" })
o.bind("SUPER + SHIFT + F", "Full screen", hl.dsp.window.fullscreen({ mode = "fullscreen" }))

-- CLOSE on SUPER+Q (SUPER+W goes to VS Code)
hl.unbind("SUPER + W") -- was: Close window
o.bind("SUPER + Q", "Close window", hl.dsp.window.close())
o.bind("SUPER + W", "VS Code", { launch = "code", focus = "Code" })
-- Note: SUPER+SHIFT+N (generic Editor) is kept as-is.

-- DISCORD (SUPER+D was free)
o.bind("SUPER + D", "Discord", { launch = "discord", focus = "discord" })

-- SPOTIFY on SUPER+S (scratchpad dropped by choice; restore snippet below)
hl.unbind("SUPER + S") -- was: Toggle scratchpad
hl.unbind("SUPER + ALT + S") -- was: Move window to scratchpad
o.bind("SUPER + S", "Spotify", { launch = "spotify", focus = "Spotify" })
-- Scratchpad restore (pick a non-conflicting key first, SUPER+S is Spotify now):
-- o.bind("SUPER + ALT + S", "Move window to scratchpad", hl.dsp.window.move({ workspace = "special:scratchpad", follow = false }))

-- SCREENSHOTS on SUPER+SHIFT+S (was Google Maps webapp); PRINT kept as-is
hl.unbind("SUPER + SHIFT + S") -- was: Google Maps
o.bind("SUPER + SHIFT + S", "Screenshot", "omarchy-capture-screenshot")

-- PRUNE FALLOUT: cliamp removed, so unbind its dead Music TUI bind
hl.unbind("SUPER + SHIFT + ALT + M") -- was: Music TUI (cliamp)

-- Kept as-is (no overrides needed): SUPER+RETURN terminal, SUPER+SPACE launcher,
-- SUPER+C/V/X universal clipboard, PRINT screenshot, SUPER+CTRL+L lock,
-- SUPER+T floating, workspaces SUPER+1..0, move SUPER+SHIFT+1..0.
