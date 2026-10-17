# Audit my Omarchy dotfiles before the first install

You are on a freshly installed Omarchy 4.x machine. My dotfiles repo is cloned
at `~/Code/dotfiles-omarchy` and **has not been run yet**. A coding agent wrote
it on macOS, without access to Omarchy, from Omarchy's source code and
documentation. Your job: check it against this real machine, report what is
wrong, and fix it once I approve.

Read `README.md` first, then every file the installer uses: `install.sh`,
`update.sh`, `lib/common.sh`, `scripts/*`, `packages/*`, everything under
`stow/`, `config/` and `templates/`, plus `install.sh` and `plugins.sh` of the
dotfiles-ai repo next to this one. Don't trust comments or the README:
check what the code actually does.

## Rules

- You are in plan mode: inspect and report only. Change nothing until I approve.
- Never run `install.sh`, `update.sh`, anything in `scripts/`, or
  `setup-project`. No `sudo`. Don't install, update or remove packages. Don't
  change system or user configuration, SSH keys, `gh` auth or git signing.
  Don't push.
- Read-only commands are fine: reading `/usr/share/omarchy` and `~/.config`,
  `--help` output, `pacman -Q`/`-Si`, `systemctl --user status`, `bash -n`,
  `shellcheck` if it is installed, parsing JSON and TOML.
- Don't install anything just to run a check; ask me first.

## Keep my choices

- **Omarchy defaults first.** The repo only adds to Omarchy. Prefer Omarchy's
  own commands and hooks over custom code, and don't replace a file Omarchy
  owns when a one-line hook works. Keep it simple, and keep every step safe to
  re-run.
- These are intentional; only change them for a concrete problem:
  - bash, not zsh
  - foot as the default terminal, with Ghostty on Super+Alt+Return
  - the Nord theme
  - Zed as editor
  - Lerd as the only PHP 8.3 and MySQL environment
  - Omarchy's mise stubs for `claude`, `codex` and `gh`
  - my aliases, including `c` and `t` overriding Omarchy's
- `php artisan migrate:fresh --seed` in `setup-project` is intentional. Only
  check that it can never reach anything but Lerd's local database.
- Worktrunk is installed, but the worktree workflow comes later; don't build it.
  My main working branch is `develop`.

## Assumptions to check

These were made without a real machine, so check each one here:

1. **Omarchy commands and their arguments:** `omarchy-pkg-add`,
   `omarchy-pkg-aur-add`, `omarchy-pkg-drop`, `omarchy-webapp-install` /
   `-remove`, `omarchy-install-editor-zed`, `omarchy-default-editor`,
   `omarchy-install-service-1password`, `omarchy-theme-set nord`,
   `omarchy-theme-current`, `omarchy-update`, and the hook directory
   `~/.config/omarchy/hooks/post-update.d/`.
2. **Files Omarchy owns that we hook into:**
   - `~/.bashrc`: one `source` line at the end.
   - `~/.config/git/config`: an `include`.
   - `~/.config/herdr/config.toml`: an appended block that must stay valid
     TOML and must not redefine a table.
   - `~/.config/hypr/bindings.lua`: replaced by ours. Check that `o.bind`,
     `hl.unbind`, `{ launch = }`, `{ webapp = }` and the rebound keys exist and
     are free.
3. **Package names** in `packages/pacman.txt` and `packages/aur.txt`
   (e.g. `worktrunk-bin`, `gcr-4`, `go-yq`): do they exist, are they already
   installed, do any conflict?
4. **PATH:** Lerd's shims (`~/.local/share/lerd/bin`) must win over mise for
   `php`, `composer` and `node`. Starship must pick up our `STARSHIP_CONFIG`.
5. **Lerd:** the installer's prompts, `lerd use 8.3`, `lerd park ~/Sites`,
   `lerd service start mysql`, `lerd init` / `link` / `env`. Does the `mysql`
   shim connect to Lerd's MySQL without credentials? The `db` function and
   `setup-project` rely on that.
6. **AI tools:**
   - the JSON output of `claude plugin list --json` and
     `claude plugin marketplace list --json`
   - whether Codex reads skills from `~/.codex/skills`
   - `herdr plugin install` and `herdr integration install`
   - whether Claude Code, herdr or omazed replace a symlinked file (like
     `settings.json`) instead of writing through it
7. **SSH / GitHub:** is `gcr-ssh-agent.socket` available? The `gh` scopes and
   `gh ssh-key add --type signing`.
8. **Stow:** which files already exist in `$HOME` and would conflict? Make sure
   the backup in `lib/common.sh` can never lose data.

## Report, then stop

Keep it short. Mark what you verified apart from what you are guessing, and
give file and line references.

1. **Blockers:** must be fixed before installing.
2. **Should fix:** wrong assumptions, fragile or non-idempotent code, risks
   after `omarchy-update`.
3. **Security and data safety.**
4. **Verified:** what you confirmed on this machine.
5. **Can't verify without running:** and how I will notice if it fails.
6. **Proposed changes:** prioritized, with the files and the reason.
7. **Install order:** which `./install.sh --only <step>` to run in what order,
   with a check after each step.

Don't propose new features. Correctness and compatibility come first.

## After I approve

Make focused fixes on a new branch (not `main`). Update the README where
behavior changes, run the checks again, show me the diff, and commit. Don't
push and don't run the installer.
