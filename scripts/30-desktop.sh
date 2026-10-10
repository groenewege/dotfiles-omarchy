#!/usr/bin/env bash
# Desktop apps and look: Zed, 1Password, web apps, theme.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

THEME="nord"

# Zed, through Omarchy's installer (also installs omazed, which keeps Zed's
# theme in sync with the Omarchy theme).
if have zeditor; then
  ok "Zed already installed"
else
  omarchy-install-editor-zed
fi
if [[ $(omarchy-default-editor) != zeditor ]]; then
  omarchy-default-editor zed
fi
ok "Zed is the default editor"

# 1Password app + CLI (and its Chromium extension policy).
if have 1password; then
  ok "1Password already installed"
else
  omarchy-install-service-1password
fi

# Ghostty next to foot. foot stays the default terminal (Super+Return);
# Ghostty opens with Super+Alt+Return (see stow/hypr/.config/hypr/bindings.lua).
# To make Ghostty the default instead: omarchy-default-terminal ghostty
if have ghostty; then
  ok "Ghostty already installed"
else
  omarchy-pkg-add ghostty
  ok "Ghostty installed"
fi
# Omarchy's Ghostty config follows the Omarchy theme and font.
if [[ ! -e $HOME/.config/ghostty ]]; then
  cp -Rp "${OMARCHY_PATH:-/usr/share/omarchy}/config/ghostty" "$HOME/.config/"
  ok "Ghostty config copied from Omarchy"
fi

# Web apps from packages/webapps.txt.
apps_dir="$HOME/.local/share/applications"
while IFS='|' read -r name url icon exec mime; do
  name=$(trim "$name") url=$(trim "$url") icon=$(trim "$icon") mime=$(trim "$mime")
  exec=$(trim "$exec") && exec=${exec//\$HOME/$HOME}
  if [[ -f "$apps_dir/$name.desktop" ]]; then
    ok "web app already installed: $name"
  else
    omarchy-webapp-install "$name" "$url" "$icon" "$exec" "$mime"
    ok "installed web app: $name"
  fi
done < <(list_from "$DOTFILES/packages/webapps.txt")

# Gmail replaces HEY as the handler for mailto: links.
if [[ -f "$apps_dir/Gmail.desktop" && $(xdg-mime query default x-scheme-handler/mailto) != Gmail.desktop ]]; then
  xdg-mime default Gmail.desktop x-scheme-handler/mailto
  ok "Gmail now opens mailto: links"
fi

# Login screen keyboard. SDDM runs its own Hyprland with Omarchy's
# /usr/share/sddm/hyprland.lua, which sets no layout (so: US QWERTY). Point it at
# config/sddm/hyprland.lua, which loads Omarchy's file and adds our layout.
# The override reuses Omarchy's CompositorCommand with only the config path
# swapped, and is skipped if that command no longer looks as expected.
greeter_src="$DOTFILES/config/sddm/hyprland.lua"
greeter_dest=/etc/sddm/dotfiles-hyprland.lua
greeter_conf=/etc/sddm.conf.d/20-dotfiles-keyboard.conf
omarchy_greeter=/usr/share/sddm/hyprland.lua
compositor=$(grep -h '^CompositorCommand=' /etc/sddm.conf.d/10-wayland.conf 2>/dev/null | tail -1 || true)
if [[ $compositor == *"--config $omarchy_greeter"* ]]; then
  if ! cmp -s "$greeter_src" "$greeter_dest"; then
    sudo install -Dm644 "$greeter_src" "$greeter_dest"
  fi
  conf=$(printf '# Installed by dotfiles (scripts/30-desktop.sh). Overrides 10-wayland.conf.\n[Wayland]\n%s\n' \
    "${compositor/"--config $omarchy_greeter"/--config $greeter_dest}")
  if [[ $(cat "$greeter_conf" 2>/dev/null) != "$conf" ]]; then
    printf '%s\n' "$conf" | sudo tee "$greeter_conf" >/dev/null
  fi
  ok "login screen uses the keyboard layout from $(pretty "$greeter_src")"
else
  warn "SDDM's compositor command changed; login screen keyboard not set (check /etc/sddm.conf.d/10-wayland.conf)"
fi

# Theme. Only set it once, so a theme picked later from the Omarchy menu sticks.
theme_marker="$HOME/.local/state/dotfiles/theme-set"
if [[ -f $theme_marker ]]; then
  ok "theme already set once ($(omarchy-theme-current)); not touching it"
else
  omarchy-theme-set "$THEME"
  mkdir -p "$(dirname "$theme_marker")" && touch "$theme_marker"
  ok "theme set to $THEME"
fi
