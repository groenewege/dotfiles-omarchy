#!/usr/bin/env bash
# AI tooling: instructions, skills and commands for Claude Code and Codex
# (from the dotfiles-ai repo), Claude plugins, Codex config, Lerd's MCP server,
# herdr plugins and agent integrations.
#
# claude, codex and gh are Omarchy's mise stubs: the first call installs the
# real tool, and `omarchy-update` keeps it up to date.
set -euo pipefail
source "$DOTFILES/lib/common.sh"

# AGENTS.md, skills, commands and the Claude plugin lists are shared with the
# Mac through the dotfiles-ai repo, cloned next to this one.
if [[ -d $AI_DIR/.git ]]; then
  ok "dotfiles-ai found at $(pretty "$AI_DIR")"
else
  git clone https://github.com/groenewege/dotfiles-ai.git "$AI_DIR"
fi
"$AI_DIR/install.sh"

# Claude Code plugins. The first call installs Claude Code itself (mise stub).
claude --version >/dev/null
"$AI_DIR/plugins.sh"

# Codex rewrites config.toml itself (project trust, hook hashes), so it is
# copied once instead of linked.
if [[ -f $HOME/.codex/config.toml ]]; then
  ok "Codex config already exists; not overwriting"
else
  mkdir -p "$HOME/.codex"
  cp "$DOTFILES/templates/codex-config.toml" "$HOME/.codex/config.toml"
  ok "Codex config created from template"
fi

# Lerd's MCP server (sites, services, databases, logs, workers) and its skill,
# for Claude Code and Codex only (see install_lerd_skill in lib/common.sh).
if have lerd; then
  if claude mcp get lerd >/dev/null 2>&1; then
    ok "Lerd MCP server already registered in Claude Code"
  else
    claude mcp add --scope user lerd -- lerd mcp
  fi
  # The template has it; Codex configs copied before that don't.
  if grep -qxF '[mcp_servers.lerd]' "$HOME/.codex/config.toml"; then
    ok "Lerd MCP server already in Codex config"
  else
    printf '\n[mcp_servers.lerd]\ncommand = "lerd"\nargs = ["mcp"]\n' >>"$HOME/.codex/config.toml"
    ok "Lerd MCP server added to Codex config"
  fi
  install_lerd_skill
else
  warn "lerd not found; run ./install.sh --only dev, then --only ai"
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
