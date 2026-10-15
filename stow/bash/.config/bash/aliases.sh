# Aliases, adapted from freekmurze/dotfiles and my old Mac setup.
# Omarchy's defaults are loaded first (see /usr/share/omarchy/default/bash/aliases):
# ls/lsa/lt (eza), cd (zoxide), ff (fzf), g (git), d (docker), h (herdr),
# cx (claude), cy (codex), n (nvim), open (xdg-open), ...

# Laravel / PHP (php, composer and mysql are Lerd shims)
alias art="php artisan"
alias tinker="php artisan tinker"
alias pam="php artisan migrate"
alias pam:r="php artisan migrate:refresh"
alias pam:roll="php artisan migrate:rollback"
alias pam:rs="php artisan migrate:refresh --seed"
alias pam:f="php artisan migrate:fresh"
alias pam:fs="php artisan migrate:fresh --seed"
alias pp="php vendor/bin/pest --parallel"
alias t="php vendor/bin/phpunit"            # overrides Omarchy's tmux alias
alias tf="php vendor/bin/phpunit --filter"
alias phpunit="php vendor/bin/phpunit"
alias pint="php vendor/bin/pint"
alias cu="composer update"
alias cr="composer require"
alias ci="composer install"
alias cda="composer dump-autoload -o"
alias phpserve="php -S localhost:8888"
alias tunnel="lerd share"
alias sites="cd ~/Sites"
alias workon="open-project"

# JavaScript
alias nr="npm run"
alias nrd="npm run dev"
alias nrb="npm run build"

# AI agents
alias c="claude"                           # overrides Omarchy's opencode alias
alias ccc="claude --continue"              # cc is the C compiler
alias cxy="codex --dangerously-bypass-approvals-and-sandbox"

# Git
alias gll="git log --oneline --decorate --graph"
alias gpo="git push origin"
alias push="git push"
alias pull="git pull"
alias uncommit="git reset --soft HEAD~1"
alias nah="git reset --hard; git clean -df"
alias lg="lazygit"

# Editor and files
alias zed="zeditor"                       # Arch names the Zed binary zeditor
alias o="open ."
alias l="eza -la --icons=auto --group-directories-first --hyperlink"
alias ll="eza -l --icons=auto --group-directories-first --hyperlink"
alias cat="bat --style=plain --paging=never"
alias top="btm"
alias htop="btm"

# SSH
alias sshconfig='$EDITOR ~/.ssh/config'
alias copykey="wl-copy < ~/.ssh/id_ed25519.pub && echo 'Public key copied to clipboard.'"
alias hostfile='sudo $EDITOR /etc/hosts'

# Network
alias myip="curl -s ifconfig.me/ip; echo"
alias localip="ip -br -4 addr show scope global"
alias flushdns="resolvectl flush-caches"

# Dotfiles
alias dotfiles='cd "$DOTFILES"'

# Enable aliases to be sudo'ed
alias sudo='sudo '
