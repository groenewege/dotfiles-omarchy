#!/usr/bin/env bash
# Install and configure everything on an Omarchy machine. Safe to re-run:
# every step checks what is already done.
#
#   ./install.sh                     run all steps
#   ./install.sh --only link,ai      run only these steps
#   ./install.sh --skip ssh-github   run everything except these steps
#   ./install.sh --list              show the steps
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DOTFILES
# shellcheck source=lib/common.sh
source "$DOTFILES/lib/common.sh"

step_name() { local n; n=$(basename "$1" .sh); echo "${n#[0-9][0-9]-}"; }

only="" skip=""
while (($#)); do
  case $1 in
    --only) only=",${2:?--only needs step names},"; shift ;;
    --skip) skip=",${2:?--skip needs step names},"; shift ;;
    --list) for s in "$DOTFILES"/scripts/[0-9][0-9]-*.sh; do step_name "$s"; done; exit 0 ;;
    -h|--help) sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1 (see --help)" ;;
  esac
  shift
done

[[ $EUID -ne 0 ]] || die "Run as your normal user; steps use sudo when they need it."
have omarchy-pkg-add || die "Omarchy commands not found. This repo is meant for an Omarchy machine."

# Ask for the sudo password once and keep it fresh while we run.
sudo -v
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

for script in "$DOTFILES"/scripts/[0-9][0-9]-*.sh; do
  name=$(step_name "$script")
  [[ -n $only && $only != *",$name,"* ]] && continue
  [[ -n $skip && $skip == *",$name,"* ]] && continue
  log "Step: $name"
  bash "$script"
done

log "All done"
echo "  Open a new terminal to load the shell config."
[[ -d $BACKUP_DIR ]] && echo "  Replaced files were backed up to $(pretty "$BACKUP_DIR")"
exit 0
