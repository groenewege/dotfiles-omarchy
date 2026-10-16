#!/usr/bin/env bash
# Reach this machine from my other machines over Tailscale: an SSH server
# (keys only, reachable only through the tailnet), so the Mac can run
# `ssh omarchy` and `herdr --remote omarchy`. Interactive the first time
# (Tailscale login in the browser).
set -euo pipefail
source "$DOTFILES/lib/common.sh"

# 1. Tailscale, through Omarchy's installer: it also lets me run `tailscale`
#    without sudo, receives Taildrop files in ~/Downloads, adds the bar icon and
#    an admin console web app.
if systemctl is-enabled --quiet tailscaled.service 2>/dev/null; then
  ok "Tailscale installed"
else
  log "Installing Tailscale (open the login link it prints)"
  omarchy-install-service-tailscale
fi

if tailscale status >/dev/null 2>&1; then
  ok "Tailscale connected as $(tailscale status --json | jq -r '.Self.DNSName | rtrimstr(".")')"
else
  log "Connecting to Tailscale (open the login link it prints)"
  sudo tailscale up --accept-routes
fi

# 2. SSH server, keys only. Its host keys are normally made when it first
#    starts, but `sshd -t` needs them already; this skips existing ones.
sudo ssh-keygen -A
changed=false
install_root_file "$DOTFILES/config/remote-access/sshd.conf" /etc/ssh/sshd_config.d/10-dotfiles.conf && changed=true
sudo sshd -t || die "sshd rejects its config; fix config/remote-access/sshd.conf"
if $changed && systemctl is-active --quiet sshd.service; then
  sudo systemctl reload sshd.service
  ok "sshd reloaded"
fi
if systemctl is-enabled --quiet sshd.service && systemctl is-active --quiet sshd.service; then
  ok "sshd running"
else
  sudo systemctl enable --now sshd.service
  ok "sshd enabled and started"
fi

# 3. Firewall: Omarchy's ufw blocks incoming connections; let SSH in through
#    Tailscale only, not from the local network.
#    (ufw skips a rule it already has.)
if sudo ufw status | grep '^Status: active' >/dev/null; then
  sudo ufw allow in on tailscale0 to any port 22 proto tcp comment 'SSH over Tailscale' >/dev/null
  ok "ufw allows SSH through Tailscale"
else
  warn "ufw is not active: sshd is reachable from the local network too (keys only)"
fi

# 4. Keys allowed in.
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
mapfile -t keys < <(list_from "$DOTFILES/config/remote-access/authorized_keys")
for key in "${keys[@]}"; do
  ensure_line "$HOME/.ssh/authorized_keys" "$key"
done
if ((${#keys[@]})); then
  chmod 600 "$HOME/.ssh/authorized_keys"
else
  warn "no keys in config/remote-access/authorized_keys yet: add the Mac's public key (README > Remote access)"
fi

# 5. Stay awake with the lid closed while on the charger.
if install_root_file "$DOTFILES/config/remote-access/logind-lid.conf" /etc/systemd/logind.conf.d/50-dotfiles-lid.conf; then
  sudo systemctl reload systemd-logind.service
  ok "logind reloaded: closing the lid on the charger no longer suspends"
fi
