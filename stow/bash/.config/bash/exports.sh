# Environment variables and PATH.

# Prepend a directory to PATH (once).
path_prepend() {
  case ":$PATH:" in
    *":$1:"*) ;;
    *) PATH="$1:$PATH" ;;
  esac
}

# Lerd's php, composer, node and mysql shims must win over anything else.
path_prepend "$HOME/.config/composer/vendor/bin"
path_prepend "$HOME/.local/share/lerd/bin"
export PATH

# Location of this dotfiles repo (found through the symlink of this file).
DOTFILES="$(readlink -f ~/.config/bash/exports.sh)"
export DOTFILES="${DOTFILES%/stow/bash/*}"

# Our starship prompt (Omarchy's prompt plus a few extra modules).
export STARSHIP_CONFIG="$HOME/.config/starship/starship.toml"

# Larger shared history.
export HISTSIZE=50000
export HISTFILESIZE=100000
export HISTCONTROL=ignoreboth:erasedups
