# omarchy-configuration fish config (Omarchy-only)
# Fisher (plugin manager, core only) + Starship prompt + fastfetch greeting.

# Silence the default "Welcome to fish..." greeting (fastfetch is the greeting)
set -g fish_greeting ""

if status is-interactive
    if command -q starship
        starship init fish | source
    end
    if command -q fastfetch
        fastfetch
    end
end
