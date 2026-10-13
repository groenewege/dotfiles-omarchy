#!/usr/bin/env bash
# Pull the latest dotfiles, re-run the install steps, then update Omarchy.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"

if [[ -z ${DOTFILES_UPDATED:-} ]]; then
  log "Pulling latest dotfiles"
  git -C "$DOTFILES" pull --ff-only
  # Re-run the freshly pulled version of this script.
  DOTFILES_UPDATED=1 exec "$DOTFILES/update.sh" "$@"
fi

"$DOTFILES/install.sh" "$@"

if have lerd; then
  log "Updating Lerd"
  lerd update || warn "lerd update failed; run it manually"
  # install.sh wrote the skill of the Lerd version from before the update.
  install_lerd_skill
fi

if have composer; then
  log "Updating global Composer packages"
  composer global update --no-interaction || warn "composer global update failed"
fi

log "Updating Omarchy (system packages, mise tools, migrations)"
omarchy-update
