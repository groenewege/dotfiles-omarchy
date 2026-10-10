#!/usr/bin/env bash
# Remove preinstalled Omarchy web apps and packages we don't use.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

apps_dir="$HOME/.local/share/applications"

while IFS= read -r name; do
  if [[ -f "$apps_dir/$name.desktop" ]]; then
    OMARCHY_REMOVE_NOTIFY=false omarchy-webapp-remove "$name"
    ok "removed web app: $name"
  else
    ok "web app already gone: $name"
  fi
done < <(list_from "$DOTFILES/packages/webapps-remove.txt")

mapfile -t drop_pkgs < <(list_from "$DOTFILES/packages/remove.txt")
if ((${#drop_pkgs[@]})); then
  omarchy-pkg-drop "${drop_pkgs[@]}"
  ok "removed packages (if present): ${drop_pkgs[*]}"
fi
