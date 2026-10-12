-- MacBookPro16,1: once the Intel GPU has the panel (apple_gmux.force_igd), the
-- AMD GPU reports a phantom eDP-2. Keep Hyprland from using it.
hl.monitor({ output = "eDP-2", disabled = true })