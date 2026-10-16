#!/usr/bin/env bash
# Fixes for specific hardware. Each fix checks the machine model first, so on
# other machines this step does nothing.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

model=$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)

# 16-inch MacBook Pro (2019): gmux gives the internal panel to the AMD 5300M.
# Shut Down, reboot and sleep then hang for over a minute (Touch Bar lit, fans
# loud) until the T2 cuts the power and the Mac restarts by itself, and the
# idle AMD GPU draws 14-17 W. Give the panel to the Intel GPU, keep the AMD GPU
# in low power and keep Hyprland off it. Tested 2026-10-12: sleep and Shut Down
# work, the AMD GPU idles at 4 W. See https://github.com/omacom/omarchy/issues/9609
# and https://wiki.t2linux.org/guides/hybrid-graphics/
if [[ $model == MacBookPro16,1 ]]; then
  src="$DOTFILES/config/macbook-pro-16"

  if install_root_file "$src/limine-gpu.conf" /etc/limine-entry-tool.d/dotfiles-gpu.conf; then
    sudo limine-mkinitcpio
    omarchy-state set reboot-required
    warn "boot entry rebuilt: reboot to move the screen to the Intel GPU"
  fi

  # Takes effect at the next boot.
  install_root_file "$src/gpu.rules" /etc/udev/rules.d/70-dotfiles-gpu.rules || true

  uwsm_env="$HOME/.config/uwsm/env.d/50-dotfiles-gpu"
  if cmp -s "$src/uwsm-gpu.sh" "$uwsm_env"; then
    ok "$(pretty "$uwsm_env") is up to date"
  else
    install -Dm644 "$src/uwsm-gpu.sh" "$uwsm_env"
    ok "installed $(pretty "$uwsm_env") (Hyprland uses the Intel GPU from the next login)"
  fi

  # Aquamarine still picks up the AMD GPU when it appears after Hyprland has
  # started, despite AQ_DRM_DEVICES, so also switch its phantom panel off.
  ensure_block "$HOME/.config/hypr/monitors.lua" macbook-pro-16 "$(cat "$src/monitors.lua")" --
else
  ok "no hardware fixes for ${model:-this machine}"
fi
