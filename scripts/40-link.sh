#!/usr/bin/env bash
# Link the config files from stow/ into $HOME, and hook our config into the
# files Omarchy owns (~/.bashrc, git config, herdr config) with one small block each.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

have stow || die "stow is missing; run ./install.sh --only packages first"

# ~/.ssh must stay private before stow creates it. ~/.ssh/config.d holds the
# private hosts file that ~/.ssh/config includes (not in this repo).
mkdir -p "$HOME/.ssh/config.d" && chmod 700 "$HOME/.ssh" "$HOME/.ssh/config.d"

for pkg in "$DOTFILES"/stow/*/; do
  stow_package "$(basename "$pkg")"
done

# Bash: Omarchy's ~/.bashrc stays as it is; we only append one line.
# Lines that installers (Lerd, worktrunk...) append end up there too, not in this repo.
ensure_line "$HOME/.bashrc" '[[ -f ~/.config/bash/init.sh ]] && source ~/.config/bash/init.sh'

# Git: keep Omarchy's ~/.config/git/config and include ours after it.
git_config="$HOME/.config/git/config"
touch "$git_config"
if git config --file "$git_config" --get-all include.path | grep -qxF dotfiles.gitconfig; then
  ok "git config already includes dotfiles.gitconfig"
else
  git config --file "$git_config" --add include.path dotfiles.gitconfig
  ok "git config now includes dotfiles.gitconfig"
fi

# herdr: keep Omarchy's config.toml and add our settings.
herdr_config="$HOME/.config/herdr/config.toml"
if [[ -f $herdr_config ]]; then
  # Top-level keys must come before the first [table], so this one is prepended.
  if ! grep -q '^onboarding' "$herdr_config"; then
    sed -i '1i onboarding = false' "$herdr_config"
    ok "herdr onboarding disabled"
  fi
  ensure_block "$herdr_config" herdr "$(cat "$DOTFILES/config/herdr.toml")"
  if have herdr; then herdr server reload-config >/dev/null 2>&1 || true; fi
else
  warn "no herdr config found at $(pretty "$herdr_config"); skipped"
fi
