#!/usr/bin/env bash
# SSH key, SSH agent and GitHub. Interactive the first time (passphrase,
# browser login); later runs only check that everything is still in place.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

KEY="$HOME/.ssh/id_ed25519"
EMAIL="gunther@groenewege.com"
TITLE="$(uname -n) (omarchy)"

# 1. Key, protected by a passphrase you choose.
if [[ -f $KEY ]]; then
  ok "SSH key exists: $(pretty "$KEY")"
else
  log "Creating SSH key (choose a passphrase)"
  ssh-keygen -t ed25519 -C "$EMAIL" -f "$KEY"
fi

# 2. Agent: gcr-ssh-agent asks for the passphrase in a dialog and can remember
#    it in the keyring. Same setup as Omarchy's newer omarchy-setup-security-ssh-agent.
systemctl --user enable --now gcr-ssh-agent.socket
agent_env="$HOME/.config/environment.d/90-gcr-ssh-agent.conf"
if [[ -f $agent_env ]]; then
  ok "SSH agent already configured"
else
  mkdir -p "$(dirname "$agent_env")"
  # shellcheck disable=SC2016 # expanded by systemd, not by us
  echo 'SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/gcr/ssh' >"$agent_env"
  ok "SSH agent configured (log out and back in to use it everywhere)"
fi

# 3. GitHub CLI login, using SSH for git.
if gh auth status --hostname github.com >/dev/null 2>&1; then
  ok "gh is logged in to GitHub"
else
  log "Logging in to GitHub (a browser window opens)"
  gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key \
    --scopes admin:public_key,admin:ssh_signing_key
fi

# gh needs these scopes to manage keys; ask for them if an older login lacks them.
scopes=$(gh auth status --hostname github.com 2>&1 | grep -i 'token scopes' || true)
if [[ $scopes != *admin:public_key* || $scopes != *admin:ssh_signing_key* ]]; then
  gh auth refresh --hostname github.com --scopes admin:public_key,admin:ssh_signing_key
fi

# 4. Upload the public key, for authentication and for commit signing.
pub=$(cut -d' ' -f2 "$KEY.pub")
if gh api user/keys --jq '.[].key' | grep -qF "$pub"; then
  ok "key already on GitHub"
else
  gh ssh-key add "$KEY.pub" --type authentication --title "$TITLE"
  ok "authentication key added to GitHub"
fi
if gh api user/ssh_signing_keys --jq '.[].key' | grep -qF "$pub"; then
  ok "signing key already on GitHub"
else
  gh ssh-key add "$KEY.pub" --type signing --title "$TITLE"
  ok "signing key added to GitHub"
fi

# The dotfiles repo is cloned over HTTPS (it is public); push over SSH from now on.
remote=$(git -C "$DOTFILES" remote get-url origin 2>/dev/null || true)
if [[ $remote == https://github.com/* ]]; then
  repo=${remote#https://github.com/}
  git -C "$DOTFILES" remote set-url origin "git@github.com:${repo%.git}.git"
  ok "dotfiles remote now uses SSH: git@github.com:${repo%.git}.git"
else
  ok "dotfiles remote: ${remote:-none}"
fi

# Commits are verified locally against this list (see dotfiles.gitconfig).
ensure_line "$HOME/.ssh/allowed_signers" "$EMAIL $(cut -d' ' -f1,2 "$KEY.pub")"

echo
echo "  Remaining manual step: add this key to your Forge servers"
echo "  (Forge > Account > SSH Keys, then add it to each server):"
echo
echo "    $(cat "$KEY.pub")"
