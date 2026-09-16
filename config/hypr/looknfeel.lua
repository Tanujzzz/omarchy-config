-- Personal look'n'feel overrides. Loaded AFTER Omarchy defaults
-- (see ~/.config/hypr/hyprland.lua), so these win and survive `omarchy update`.
-- Validate: hyprctl reload && hyprctl configerrors

hl.config({
  decoration = {
    -- Rounded window corners (px). Omarchy default is 0.
    rounding = 12,
  },
})

-- Fully opaque windows. Omarchy tags every window +default-opacity
-- (0.985 active / 0.96 inactive) and gives both browser families their own
-- 1.0/0.985 rule, so all three need overriding.
-- TOGGLE: delete or comment out this block to restore Omarchy translucency.
o.window(".*", { tag = "-default-opacity" })
o.window({ tag = "chromium-based-browser" }, { opacity = "1.0 1.0" })
o.window({ tag = "firefox-based-browser" }, { opacity = "1.0 1.0" })
