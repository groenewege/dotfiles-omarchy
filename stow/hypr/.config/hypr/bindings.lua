-- Personal keybinding overrides, loaded by Omarchy's ~/.config/hypr/hyprland.lua
-- after its defaults. See all bindings: omarchy menu keybindings --print

-- HEY is removed (packages/webapps-remove.txt): point the email and calendar
-- keys at Gmail and Google Calendar instead.
hl.unbind("SUPER + SHIFT + E")
o.bind("SUPER + SHIFT + E", "Email", { webapp = "https://mail.google.com/" })
hl.unbind("SUPER + SHIFT + ALT + E")
o.bind("SUPER + SHIFT + ALT + E", "New email", { webapp = "https://mail.google.com/mail/?view=cm" })
hl.unbind("SUPER + SHIFT + C")
o.bind("SUPER + SHIFT + C", "Calendar", { webapp = "https://calendar.google.com/" })

-- Notion (SUPER + SHIFT + N is Omarchy's editor key)
o.bind("SUPER + SHIFT + ALT + N", "Notion", { webapp = "https://www.notion.so/groenewege/" })

-- Ghostty next to foot (Super+Return stays foot). Replaces Omarchy's tmux key;
-- herdr is on Super+Ctrl+Return.
hl.unbind("SUPER + ALT + RETURN")
o.bind("SUPER + ALT + RETURN", "Ghostty", { launch = "ghostty" })

-- Agent usage panel (Claude/Codex/Fireworks limits), same as clicking the bar icon
o.bind("SUPER + CTRL + U", "Agent usage", "omarchy-shell shell toggle omarchy.agents")
