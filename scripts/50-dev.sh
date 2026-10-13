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

# By default MySQL flushes every commit to disk, twice (redo log and binary
# log), and a flush takes ~50 ms on the T2 MacBook's SSD, so seeders crawl. A
# local database doesn't need that: write the log once a second (a crash loses
# at most that second) and skip the binary log, which is only for replication.
# Creating tables stays slow (~0.2-1 s per migration): MySQL always flushes DDL.
# Lerd never overwrites this tuning file.
mysql_tuning="$HOME/.local/share/lerd/service-tuning/mysql.conf"
before=$(cat "$mysql_tuning" 2>/dev/null || true)
ensure_block "$mysql_tuning" "fast commits" "[mysqld]
innodb_flush_log_at_trx_commit = 2
skip-log-bin"
if [[ $(cat "$mysql_tuning") != "$before" ]]; then
  lerd service restart mysql
  ok "MySQL restarted with the new settings"
fi

mkdir -p "$SITES_DIR"
lerd park "$SITES_DIR"
ok "projects in $(pretty "$SITES_DIR") are served at http://<folder>.test (lerd secure for HTTPS)"

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
