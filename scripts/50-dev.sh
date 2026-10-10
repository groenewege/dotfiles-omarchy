#!/usr/bin/env bash
# Laravel development environment: Lerd (PHP-FPM, nginx, .test domains and
# MySQL in rootless Podman), plus global Composer tools.
#
# Don't also install PHP through mise or `omarchy-install-dev-env php|laravel`:
# a second PHP would take `php` away from Lerd's shims.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

PHP_VERSION="8.3"
SITES_DIR="$HOME/Sites"
COMPOSER_GLOBALS=(laravel/installer laravel/forge-cli)

export PATH="$HOME/.local/share/lerd/bin:$HOME/.local/bin:$PATH"

if have lerd; then
  ok "Lerd already installed ($(lerd --version 2>/dev/null | head -1))"
else
  log "Installing Lerd"
  echo "  The installer asks a few questions. Answer Y to let Lerd manage DNS,"
  echo "  so sites are served at https://<name>.test."
  curl -fsSL https://lerd.sh/install.sh | bash
fi

lerd start
lerd use "$PHP_VERSION"
lerd service start mysql
# `lerd install` only writes client shims for services that already exist, and
# mysql didn't yet. The db function and setup-project need these.
lerd shims add mysql
lerd shims add mysqldump
ok "Lerd running with PHP $PHP_VERSION and MySQL"

mkdir -p "$SITES_DIR"
lerd park "$SITES_DIR"
ok "projects in $(pretty "$SITES_DIR") are served at https://<folder>.test"

# With a terminal on stdin, Lerd's composer shim adds colours and \r\n line
# endings, so read the list without one.
installed=$(composer global show --name-only --no-ansi 2>/dev/null </dev/null | tr -d '\r' || true)
for pkg in "${COMPOSER_GLOBALS[@]}"; do
  if grep -qxF "$pkg" <<<"$installed"; then
    ok "composer global package already installed: $pkg"
  else
    composer global require --no-interaction "$pkg"
    ok "installed composer global package: $pkg"
  fi
done
