# Personal shell config, loaded from ~/.bashrc after Omarchy's defaults
# (/usr/share/omarchy/default/bash/*), so anything here overrides them.

# shellcheck source=/dev/null
for file in exports aliases functions; do
  [[ -f ~/.config/bash/$file.sh ]] && source ~/.config/bash/$file.sh
done
unset file

# Secrets and machine-specific settings. Not in the dotfiles repo; see README.
# shellcheck source=/dev/null
[[ -f ~/.config/bash/local.sh ]] && source ~/.config/bash/local.sh

# worktrunk: lets `wt switch` change the shell's directory.
command -v wt &>/dev/null && eval "$(wt config shell init bash)"
