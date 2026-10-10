# Functions, adapted from freekmurze/dotfiles and my old Mac setup.

# Run the test suite with Pest when present, PHPUnit otherwise.
p() {
  if [[ -f vendor/bin/pest ]]; then
    php vendor/bin/pest --compact "$@"
  else
    php vendor/bin/phpunit "$@"
  fi
}

# Same, filtered: pf "user can log in"
pf() {
  if [[ -f vendor/bin/pest ]]; then
    php vendor/bin/pest --compact --filter "$@"
  else
    php vendor/bin/phpunit --filter "$@"
  fi
}

# List routes, optionally filtered: routes admin
routes() {
  if (($# == 0)); then
    php artisan route:list
  else
    php artisan route:list | grep -i -- "$1"
  fi
}

# Run the Laravel scheduler every minute in the foreground.
scheduler() {
  while :; do
    php artisan schedule:run
    echo "Sleeping 60 seconds..."
    sleep 60
  done
}

# Databases on Lerd's MySQL (the mysql shim connects to it by default).
db() {
  case "$1" in
    refresh) mysql -e "drop database if exists \`$2\`; create database \`$2\`" ;;
    create)  mysql -e "create database \`$2\`" ;;
    drop)    mysql -e "drop database \`$2\`" ;;
    list)    mysql -N -e "show databases" ;;
    *)
      echo "Usage: db {refresh|create|drop|list} [database_name]"
      return 1
      ;;
  esac
}

# Commit everything. Without a message, Claude writes one from the diff
# (falls back to "wip").
commit() {
  local message="$*" diff_input spinner_pid

  git add -A

  if [[ -z $message ]] && command -v claude &>/dev/null && ! git diff --cached --quiet; then
    diff_input=$(
      echo "=== Summary ==="
      git diff --cached --stat
      printf '\n=== Diff (truncated if large) ===\n'
      git diff --cached | head -c 50000
    )

    # Spinner in a detached subshell, so bash prints no job messages.
    spinner_pid=$(
      (
        frames="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
        while :; do
          for ((i = 0; i < ${#frames}; i++)); do
            printf '\r%s Generating commit message...' "${frames:i:1}"
            sleep 0.1
          done
        done
      ) >/dev/tty 2>&1 &
      echo $!
    )
    trap 'kill "$spinner_pid" 2>/dev/null; printf "\r\033[K"; trap - INT' INT

    message=$(claude -p --no-session-persistence \
      "Write a single-line commit message for this diff. Output ONLY the message, no quotes, no explanation, no markdown." \
      <<<"$diff_input")

    kill "$spinner_pid" 2>/dev/null
    printf '\r\033[K'
    trap - INT
  fi

  git commit -m "${message:-wip}"
}

# Delete local branches whose remote branch is gone.
git-prune-local() {
  git fetch -p && git branch -vv | grep ': gone]' | awk '{print $1}' | xargs -r git branch -D
}

# Clone a GitHub repo: clone owner/repo [dir]
clone() {
  gh repo clone "$1" "${@:2}"
}

# Create a directory and enter it.
mkd() {
  mkdir -p "$@" && cd "$@" || return
}

# All the DNS info for a domain.
digga() {
  dig +nocmd "$1" any +multiline +noall +answer
}

# Forget a host's SSH key (after a server rebuild).
removehost() {
  ssh-keygen -R "$1"
}

# Fuzzy-find a directory below the current one and cd into it (Ctrl+G).
# Omarchy's fzf setup also has Alt+C for the same thing.
fcd() {
  local dir
  dir=$(fd --type d --hidden --exclude .git --exclude node_modules --exclude vendor | fzf --height 40% --reverse) &&
    builtin cd -- "$dir" || return
}
[[ $- == *i* ]] && bind '"\C-g": "\C-e\C-ufcd\C-m"'
