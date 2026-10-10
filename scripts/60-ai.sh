#!/usr/bin/env bash
# AI tooling: skills for Claude Code and Codex, Claude plugins, Codex config,
# herdr plugins and agent integrations.
#
# claude, codex and gh are Omarchy's mise stubs: the first call installs the
# real tool, and `omarchy-update` keeps it up to date.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

# Symlink a directory, backing up whatever was there before.
link_dir() {
  local src=$1 target=$2
  if [[ -L $target && $(readlink -f "$target") == "$(readlink -f "$src")" ]]; then
    return 0
  fi
  [[ -e $target || -L $target ]] && backup "$target"
  mkdir -p "$(dirname "$target")"
  ln -s "$src" "$target"
  ok "linked $(pretty "$target")"
}

# Skills: ai/skills is shared, ai/skills-claude and ai/skills-codex hold
# variants that differ per agent.
for skill in "$DOTFILES"/ai/skills/*/; do
  name=$(basename "$skill")
  link_dir "${skill%/}" "$HOME/.claude/skills/$name"
  link_dir "${skill%/}" "$HOME/.codex/skills/$name"
done
for skill in "$DOTFILES"/ai/skills-claude/*/; do
  link_dir "${skill%/}" "$HOME/.claude/skills/$(basename "$skill")"
done
for skill in "$DOTFILES"/ai/skills-codex/*/; do
  link_dir "${skill%/}" "$HOME/.codex/skills/$(basename "$skill")"
done
ok "skills linked"

# Claude Code plugins. The first call installs Claude Code itself (mise stub).
claude --version >/dev/null
known=$(claude plugin marketplace list --json | jq -r '.[].repo // empty')
while IFS= read -r repo; do
  if grep -qxF "$repo" <<<"$known"; then
    ok "marketplace already added: $repo"
  else
    claude plugin marketplace add "$repo"
  fi
done < <(list_from "$DOTFILES/packages/claude-marketplaces.txt")

installed=$(claude plugin list --json | jq -r '.[] | .id // .pluginId // empty')
while IFS= read -r plugin; do
  if grep -qxF "$plugin" <<<"$installed"; then
    ok "plugin already installed: $plugin"
  else
    claude plugin install "$plugin"
  fi
done < <(list_from "$DOTFILES/packages/claude-plugins.txt")

# Codex rewrites config.toml itself (project trust, hook hashes), so it is
# copied once instead of linked.
if [[ -f $HOME/.codex/config.toml ]]; then
  ok "Codex config already exists; not overwriting"
else
  mkdir -p "$HOME/.codex"
  cp "$DOTFILES/templates/codex-config.toml" "$HOME/.codex/config.toml"
  ok "Codex config created from template"
fi

# herdr: the herdr-plus plugin and the Claude/Codex agent-state hooks.
if herdr plugin list 2>/dev/null | grep -q 'cloudmanic.herdr-plus'; then
  ok "herdr-plus already installed"
else
  herdr plugin install cloudmanic/herdr-plus --yes
fi
herdr integration install claude
herdr integration install codex
ok "herdr integrations installed"

# Claude Code and herdr may have rewritten settings.json instead of editing it.
relink_if_replaced claude .claude/settings.json
