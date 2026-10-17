-- MacBookPro16,1: once the Intel GPU has the panel (apple_gmux.force_igd), the
-- AMD GPU reports a phantom panel. Keep Hyprland from using it. Look its name
-- up: eDP-1 and eDP-2 swap between boots, depending on which GPU is ready
-- first, and disabling the wrong one leaves a black screen.
for card = 0, 7 do
  for n = 1, 8 do
    local file = io.open(string.format("/sys/bus/pci/devices/0000:03:00.0/drm/card%d/card%d-eDP-%d/status", card, card, n), "r")
    if file then
      file:close()
      hl.monitor({ output = "eDP-" .. n, disabled = true })
    end
  end
end
