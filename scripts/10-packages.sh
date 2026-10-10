#!/usr/bin/env bash
# Install the extra packages listed in packages/pacman.txt and packages/aur.txt.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

mapfile -t pacman_pkgs < <(list_from "$DOTFILES/packages/pacman.txt")
mapfile -t aur_pkgs < <(list_from "$DOTFILES/packages/aur.txt")

if ((${#pacman_pkgs[@]})); then
  omarchy-pkg-add "${pacman_pkgs[@]}"
  ok "repo packages installed: ${pacman_pkgs[*]}"
fi

if ((${#aur_pkgs[@]})); then
  omarchy-pkg-aur-add "${aur_pkgs[@]}"
  ok "AUR packages installed: ${aur_pkgs[*]}"
fi
