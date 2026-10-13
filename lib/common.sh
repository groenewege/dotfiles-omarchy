#!/usr/bin/env bash
# Shared helpers for install.sh and scripts/*.sh. Source this file, don't run it.

DOTFILES="${DOTFILES:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)}"
export DOTFILES BACKUP_DIR

log()  { printf '\n\033[1;34m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '  \033[32m✓\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*" >&2; }
die()  { printf '  \033[31m✗\033[0m %s\n' "$*" >&2; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

# Show a path with ~ instead of $HOME.
pretty() { local tilde='~'; printf '%s' "${1/#$HOME/$tilde}"; }

# Strip leading and trailing whitespace.
trim() { local s=$1; s=${s#"${s%%[![:space:]]*}"}; printf '%s' "${s%"${s##*[![:space:]]}"}"; }

# Print the entries of a list file: one per line, '#' starts a comment.
list_from() {
  [[ -f $1 ]] || return 0
  sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e 's/^[[:space:]]*//' "$1" | grep -v '^$' || true
}

# Append a line to a file unless it is already present.
ensure_line() {
  local file=$1 line=$2
  mkdir -p "$(dirname "$file")"
  touch "$file"
  if grep -qxF -- "$line" "$file"; then
    ok "$(pretty "$file") already contains: $line"
  else
    printf '%s\n' "$line" >>"$file"
    ok "added to $(pretty "$file"): $line"
  fi
}

# Write a named block between markers at the end of a file, replacing an
# earlier version of the same block. Used for files Omarchy owns, so we only
# touch our own lines. The optional 4th argument is the comment prefix for the
# markers (default '#'; '--' for Lua).
ensure_block() {
  local file=$1 name=$2 content=$3 comment=${4:-#}
  local begin="$comment >>> dotfiles: $name >>>" end="$comment <<< dotfiles: $name <<<"
  local tmp
  mkdir -p "$(dirname "$file")"
  touch "$file"
  tmp=$(mktemp)
  awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' "$file" >"$tmp"
  printf '%s\n%s\n%s\n' "$begin" "$content" "$end" >>"$tmp"
  if cmp -s "$tmp" "$file"; then
    ok "$(pretty "$file") block '$name' is up to date"
  else
    cat "$tmp" >"$file"
    ok "updated block '$name' in $(pretty "$file")"
  fi
  rm -f "$tmp"
}

# A free path in the backup dir for <rel>; a name that is already taken gets a
# .1, .2... suffix, so a backup never overwrites an earlier one.
backup_dest() {
  local dest="$BACKUP_DIR/$1" n=1
  while [[ -e $dest || -L $dest ]]; do dest="$BACKUP_DIR/$1.$((n++))"; done
  mkdir -p "$(dirname "$dest")"
  printf '%s' "$dest"
}

# Move a file out of the way into the backup dir (keeps its path under $HOME).
backup() {
  local target=$1 dest
  dest=$(backup_dest "${1#"$HOME"/}")
  mv -n "$target" "$dest"
  [[ -e $target || -L $target ]] && die "could not back up $(pretty "$target")"
  warn "backed up $(pretty "$target") to $(pretty "$dest")"
}

# Symlink every file of stow/<pkg> into $HOME. Existing files that are not
# already our symlinks are backed up first, so stow never hits a conflict.
stow_package() {
  local pkg=$1 dir="$DOTFILES/stow/$1" src rel target
  while IFS= read -r -d '' src; do
    rel=${src#"$dir"/}
    target="$HOME/$rel"
    if [[ -e $target || -L $target ]] && [[ $(readlink -f "$target") != "$(readlink -f "$src")" ]]; then
      backup "$target"
    fi
  done < <(find "$dir" \( -type f -o -type l \) ! -name .DS_Store -print0)
  stow --dir "$DOTFILES/stow" --target "$HOME" --no-folding --restow --ignore='\.DS_Store' "$pkg"
  ok "stowed $pkg"
}

# Some tools save a file by writing a new one and renaming it over the old,
# which replaces our symlink with a plain file. Take that file's content into
# the repo (so `git diff` shows what the tool changed) and link it again.
relink_if_replaced() {
  local pkg=$1 rel=$2 target="$HOME/$2" src="$DOTFILES/stow/$1/$2"
  if [[ -f $target && ! -L $target ]]; then
    # Keep the repo's version too, in case it had uncommitted edits.
    cp -p "$src" "$(backup_dest "dotfiles-repo/stow/$pkg/$rel")"
    cp "$target" "$src"
    rm "$target"
    stow --dir "$DOTFILES/stow" --target "$HOME" --no-folding --restow "$pkg"
    warn "$(pretty "$target") had been replaced by a plain file; its content is now in the repo (check git diff)"
  fi
}

# Lerd's skill (how to use its MCP server) for Claude Code and Codex. It ships
# with the lerd binary, so it is generated, not kept in ai/skills/:
# `lerd mcp:inject` writes it into a scratch folder and we copy it out.
# (`lerd mcp:enable-global` would also install it, but it sets up every AI
# client it knows and adds the same text to ~/.codex/AGENTS.md, a repo file.)
install_lerd_skill() {
  local tmp agent
  tmp=$(mktemp -d)
  if lerd mcp:inject --path "$tmp" >/dev/null; then
    for agent in claude codex; do
      install -Dm644 "$tmp/.claude/skills/lerd/SKILL.md" "$HOME/.$agent/skills/lerd/SKILL.md"
    done
    ok "Lerd skill installed for Claude Code and Codex"
  else
    warn "lerd mcp:inject failed; Lerd skill not updated"
  fi
  rm -rf "$tmp"
}
