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
# touch our own lines.
ensure_block() {
  local file=$1 name=$2 content=$3
  local begin="# >>> dotfiles: $name >>>" end="# <<< dotfiles: $name <<<"
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

# Move a file out of the way into the backup dir (keeps its path under $HOME).
backup() {
  local target=$1 rel=${1#"$HOME"/}
  mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
  mv "$target" "$BACKUP_DIR/$rel"
  warn "backed up ~/$rel to $(pretty "$BACKUP_DIR")/$rel"
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
    cp "$target" "$src"
    rm "$target"
    stow --dir "$DOTFILES/stow" --target "$HOME" --no-folding --restow "$pkg"
    warn "$(pretty "$target") had been replaced by a plain file; its content is now in the repo (check git diff)"
  fi
}
