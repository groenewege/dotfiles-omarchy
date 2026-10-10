-- Hyprland config for the SDDM login screen, installed to
-- /etc/sddm/dotfiles-hyprland.lua by scripts/30-desktop.sh.
--
-- Omarchy's greeter config sets no keyboard layout, so the password field uses
-- US QWERTY. Keep Omarchy's settings and add the layout from
-- stow/hypr/.config/hypr/input.lua (keep the two in sync).
local omarchy_greeter = "/usr/share/sddm/hyprland.lua"
local file = io.open(omarchy_greeter, "r")
if file then
  file:close()
  dofile(omarchy_greeter)
end

hl.config({
  input = {
    kb_layout = "fr",
    kb_variant = "mac",
  },
})
