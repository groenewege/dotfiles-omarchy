# omarchy-dotfiles

The things I do after I install [Omarchy](https://omarchy.org) (4.x): my tools,
my Laravel development environment and my configuration, installed with one
command that can be re-run safely.

**Philosophy: Omarchy defaults first.** Omarchy already ships a good shell
(bash + starship + zoxide + fzf + eza), terminal (foot), multiplexer (herdr),
themes and AI CLIs. This repo only adds what's missing and layers personal
settings on top, so `omarchy-update` keeps working and the repo stays small.

| Area | What this repo does |
|---|---|
| Shell | Omarchy's bash, plus my aliases, functions and exports in `~/.config/bash/` |
| Prompt | Omarchy's starship prompt + PHP version, command duration, exit code, ahead/behind |
| Terminal | foot (Omarchy default, Super+Return) and Ghostty (Super+Alt+Return) |
| Theme | Nord, set once (pick another from the Omarchy menu any time) |
| Keyboard / trackpad | French Mac AZERTY (also on the login screen), natural scrolling |
| Editor | Zed, installed through Omarchy (omazed keeps its theme in sync) |
| PHP / MySQL | [Lerd](https://lerd.sh): PHP 8.3, MySQL, `https://<project>.test` for every folder in `~/Sites` |
| AI | Claude Code, Codex (Omarchy's auto-updating stubs), my skills and plugins, herdr + herdr-plus, worktrunk |
| Apps | 1Password, Gmail and Notion web apps; HEY and Basecamp removed |
| Git / SSH | ed25519 key, GitHub over SSH, signed commits; server list in a private file |

## Fresh install

> **First Omarchy machine?** Follow [docs/first-install.md](docs/first-install.md)
> instead: it has an agent audit this repo against the real machine before
> anything is installed. The steps below are for later machines.

### 1. Install Omarchy

On an Intel MacBook (this wipes macOS):

1. In macOS Recovery (Cmd-R at boot), open Startup Security Utility: turn
   Secure Boot off and allow booting from external media.
2. Write the Omarchy ISO to a USB stick, hold Option at boot and choose
   **EFI Boot**.
3. Follow the installer. Omarchy installs the Broadcom Wi-Fi driver and the
   T2 / SPI keyboard fixes for Macs automatically. F1–F12 work as function keys
   (`fnmode=2`); hold Fn for media keys.

See the [Omarchy manual](https://omarchy.org/manual/) for details.

### 2. Clone this repo

The repo is public, so no GitHub login is needed:

```bash
git clone https://github.com/groenewege/dotfiles-omarchy.git ~/Code/dotfiles-omarchy
cd ~/Code/dotfiles-omarchy
```

The `ssh-github` step switches this clone to SSH later, so you can push from it.

### 3. Run the installer

```bash
./install.sh
```

It asks for your sudo password once, then runs every step in `scripts/`.
Expect these prompts:

- **Lerd installer** (several questions, and sudo for its system setup):
  - **Y** to let Lerd manage DNS (sites at `https://<name>.test`).
  - **Y** to let Lerd manage Node.js versions. Otherwise `node` stays mise's,
    not Lerd's.
  - **Y** to the TLD question, **N** to the Lerd desktop app (or Y if you want it).
  - It also adds a Lerd item to the Omarchy bar.
- **SSH key passphrase**: choose one. The agent can remember it in the keyring.
- **GitHub login**: a browser window opens for `gh auth login` (SSH this time)
  with permission to add your SSH key.

Files that were in the way are moved to `~/.dotfiles-backup/<timestamp>/`.

### 4. Finish by hand

- [ ] Log out and back in (SSH agent, shell config everywhere).
- [ ] Sign in to 1Password (desktop app) and enable its browser extension.
- [ ] Create `~/.config/bash/local.sh` for secrets (see [Secrets](#secrets)).
- [ ] Copy your server list to `~/.ssh/config.d/hosts` (see [SSH hosts](#ssh-hosts)).
- [ ] Add the new SSH key to Forge (Account > SSH Keys, then to each server).
      `copykey` copies it to the clipboard. Do the same on servers not managed by Forge.
- [ ] Run `claude` and `codex` once to log in.
- [ ] Open Zed and sign in; the PHP and Laravel extensions install themselves.
- [ ] `lerd doctor` should be all green.
- [ ] Set up your projects: `setup-project owner/repo` (see [Laravel with Lerd](#laravel-with-lerd)).
- [ ] In the repo, `git status` now shows `stow/claude/.claude/settings.json`
      as modified: herdr added its hook (so it can show what Claude is doing).
      Review it with `git diff` and commit it. This only happens on the first install.

## How it works

```
install.sh                 runs scripts/NN-*.sh in order (--only, --skip, --list)
update.sh                  git pull, install.sh, lerd update, composer global update, omarchy-update
lib/common.sh              helpers: list_from, ensure_line, ensure_block, stow_package…
packages/                  plain lists, read by the scripts
  pacman.txt               extra packages from the Arch/Omarchy repos
  aur.txt                  extra packages from the AUR
  remove.txt               preinstalled packages to remove
  webapps.txt              web apps to install (Name | URL | icon …)
  webapps-remove.txt       preinstalled web apps to remove
  claude-marketplaces.txt  Claude Code plugin marketplaces
  claude-plugins.txt       Claude Code plugins
scripts/
  10-packages.sh           install pacman.txt and aur.txt
  20-cleanup.sh            remove webapps-remove.txt and remove.txt
  30-desktop.sh            Zed, 1Password, web apps, Gmail as mailto handler, login screen keyboard, theme
  40-link.sh               stow everything in stow/, hook into Omarchy-owned files
  50-dev.sh                Lerd, PHP 8.3, MySQL, park ~/Sites, global Composer tools
  60-ai.sh                 skills, Claude plugins, Codex config, herdr plugin + integrations
  70-ssh-github.sh         SSH key + agent, gh login, upload auth and signing key
stow/<package>/            files laid out as in $HOME, symlinked with GNU stow
config/herdr.toml          block appended to Omarchy's herdr config
config/sddm/               login screen (SDDM) keyboard layout, copied to /etc
ai/AGENTS.md               shared instructions → ~/.claude/CLAUDE.md and ~/.codex/AGENTS.md
ai/skills/                 skills for both Claude Code and Codex
ai/skills-claude/          Claude-only variants
ai/skills-codex/           Codex-only variants
templates/                 files copied once instead of linked, and examples
docs/                      first-install guide and the audit prompt for agents
```

Every step checks before acting, so `./install.sh` can be run again at any
time. Run one step with `./install.sh --only link` (names: `./install.sh --list`).
When you go step by step, run `ssh-github` before `link`: `link` turns on commit
signing with `~/.ssh/id_ed25519`, which `ssh-github` creates.

### Two ways of managing a config file

1. **We own the whole file → stow.** Everything under `stow/` is symlinked into
   `$HOME` file by file (`stow --no-folding`), so editing `~/.config/zed/settings.json`
   edits the repo. Run `git status` in the repo to see what changed.
2. **Omarchy owns the file → one hook line or block.** We never replace these, so
   Omarchy updates keep working:
   - `~/.bashrc` gets `source ~/.config/bash/init.sh` (one line, at the end).
   - `~/.config/git/config` gets `[include] path = dotfiles.gitconfig`.
   - `~/.config/herdr/config.toml` gets a marked block from `config/herdr.toml`.
   - Hyprland loads our `~/.config/hypr/bindings.lua` and `input.lua` itself
     (Omarchy only puts commented examples in them).
   - The login screen: SDDM runs its own Hyprland with Omarchy's
     `/usr/share/sddm/hyprland.lua`, which sets no keyboard layout. The
     `desktop` step copies `config/sddm/hyprland.lua` (Omarchy's file plus our
     layout) to `/etc/sddm/` and points SDDM at it with
     `/etc/sddm.conf.d/20-dotfiles-keyboard.conf`. Change the layout in both
     `input.lua` and that file.

   Installers (Lerd, worktrunk…) also append to `~/.bashrc`. That is fine:
   those lines stay on this machine and don't end up in the repo.

Some files are **copied once** instead (`templates/codex-config.toml`), because
the app rewrites them constantly.

### After an Omarchy update

Some Omarchy migrations and tools (e.g. omazed after an update) replace a
config file with `sed -i` or `mv`, which turns our symlink into a plain copy.
The `post-update` hook (`~/.config/omarchy/hooks/post-update.d/dotfiles-check`)
lists such files after every `omarchy-update`. To fix one: compare it with the
repo, copy over anything worth keeping, then run `./install.sh --only link`.

Claude Code and herdr can do the same to `~/.claude/settings.json`;
`./install.sh --only ai` copies such a file back into the repo and re-links it,
so `git diff` shows what changed.

Omarchy may also bring back removed web apps; `./install.sh --only cleanup`
removes them again.

## Everyday use

```bash
./update.sh          # pull this repo, re-run install, update Lerd, Composer and Omarchy
dotfiles             # cd into this repo
```

### Adding things

| To add… | Do this, then run |
|---|---|
| A package | add it to `packages/pacman.txt` (or `aur.txt`) | `./install.sh --only packages` |
| A web app | add a line to `packages/webapps.txt` | `./install.sh --only desktop` |
| Remove a preinstall | add it to `packages/remove.txt` or `webapps-remove.txt` | `./install.sh --only cleanup` |
| A config file | put it in `stow/<app>/` at its path under `$HOME` | `./install.sh --only link` |
| An alias or function | edit `~/.config/bash/aliases.sh` / `functions.sh` (it's the repo file) | open a new terminal |
| A skill | add a folder to `ai/skills/` | `./install.sh --only ai` |
| A Claude plugin | add it to `packages/claude-plugins.txt` | `./install.sh --only ai` |
| A whole new step | add `scripts/NN-name.sh` (source `lib/common.sh`, keep it idempotent) | `./install.sh --only name` |

### Shell cheat sheet

Omarchy's defaults stay available: `ls`/`lt` (eza), `cd` (zoxide), `ff` (fzf
with preview), `g` (git), `h` (herdr), `cx` (claude), `cy` (codex), `n` (nvim),
`open`, and fzf's Ctrl+R (history), Ctrl+T (files) and Alt+C (cd).

Added by this repo (see `stow/bash/.config/bash/`):

| | |
|---|---|
| Laravel | `art`, `tinker`, `pam` `pam:fs` `pam:f` `pam:r` `pam:rs` `pam:roll`, `routes [filter]`, `scheduler` |
| Tests | `p` (pest or phpunit), `pf <filter>`, `pp` (parallel), `t`/`tf` (phpunit) |
| Composer / npm | `ci` `cu` `cr` `cda`, `nr` `nrd` `nrb` |
| Git | `commit [msg]` (no message: Claude writes one), `gll`, `nah`, `uncommit`, `push`, `pull`, `gpo`, `git-prune-local`, `clone owner/repo`, `lg` |
| Databases | `db create|drop|refresh|list <name>` (Lerd MySQL) |
| AI | `c` (claude), `cxy` (codex without approvals) |
| Projects | `setup-project [owner/repo]` (clone + full Lerd setup) |
| Misc | `mkd`, `zed`, `o`, `sites`, `copykey`, `myip`, `localip`, `flushdns`, `digga`, `removehost`, Ctrl+G (fuzzy cd) |

Overridden Omarchy aliases: `c` (was opencode) and `t` (was tmux).

## Secrets

This repo is public: nothing secret or client-specific is committed. Put secrets in `~/.config/bash/local.sh`, which is
not part of the repo and is loaded by the shell config. You can read them from
1Password:

```bash
# ~/.config/bash/local.sh
export SHIFT_API_TOKEN="$(op read 'op://Private/Laravel Shift/token' 2>/dev/null)"
```

### SSH hosts

`~/.ssh/config` (from this repo) only has defaults and loads every file in
`~/.ssh/config.d/`. Keep your server list there, in a private file:

```bash
# On the Mac: everything before the "Host *" block
sed '/^Host \*/,$d' ~/.ssh/config > ~/Desktop/hosts

# On the Omarchy machine, after copying the file over (scp, USB stick, or a
# 1Password document):
mv hosts ~/.ssh/config.d/hosts && chmod 600 ~/.ssh/config.d/hosts
```

### herdr-plus projects

Project files (one per Laravel project, opened with prefix+up in herdr) are
personal, so they aren't in the repo. Start from `templates/herdr-project.toml`.

## Laravel with Lerd

Lerd runs nginx, PHP-FPM and MySQL in rootless Podman containers and puts
`php`, `composer`, `node` and `mysql` shims in `~/.local/share/lerd/bin` (first
on `PATH`). Every folder in `~/Sites` is served at `https://<folder>.test`.

### Setting up a project

```bash
setup-project groenewege/my-app      # clone into ~/Sites/my-app and set it up
setup-project                        # set up the project in the current folder
```

`setup-project` (in `stow/bin/.local/bin/`) runs, in order:

1. Clone with `gh repo clone` (or `git clone` for a URL), unless you're already in the project.
2. Copy `.env.example` to `.env` when there's no `.env` yet.
3. `lerd init` the first time: it asks for the PHP version, HTTPS and services,
   and saves the answers in `.lerd.yaml`. Commit that file; next time (or on
   another machine) `lerd link` applies it without asking. Answer **N** when
   `lerd init` offers "Run lerd setup?": the next steps do that work.
4. `composer install`, `lerd env` (points `.env` at Lerd's MySQL etc.), and
   `php artisan key:generate` when `APP_KEY` is empty.
5. `php artisan migrate:fresh --seed` (this empties the database first). It
   refuses to run when `DB_URL` is set, or when `DB_HOST` isn't Lerd's MySQL
   (`lerd-*`, `127.0.0.1`, `localhost`) and the project doesn't use SQLite.
6. `php artisan storage:link`.
7. `npm ci` (or `npm install`), then `npm run build`, or `npm run production` for older Mix projects.
8. `php artisan boost:install`, when the project requires `laravel/boost`.

Lerd's own `lerd setup` does something similar with a checklist, but it runs
`migrate` instead of `migrate:fresh --seed` and doesn't install Boost.

```bash
lerd isolate 8.4     # use another PHP version for this project
lerd env             # point .env at Lerd's services
lerd secure          # HTTPS for the current site
lerd share           # public tunnel (alias: tunnel)
lerd doctor          # diagnose
```

Lerd also serves git worktrees automatically at `<branch>.<site>.test`.

Don't install PHP any other way (mise, `omarchy-install-dev-env php|laravel`):
it would take `php` away from Lerd. `which php` should print
`~/.local/share/lerd/bin/php`.

## Next: the agent coding workflow (phase 2)

Planned, not built yet. The tools are already installed:

- worktrunk (`wt`) for git worktrees, with a project `.config/wt.toml`
  template: copy ignored files, `lerd worktree setup`, a `_testing` database,
  pint and tests before merge.
- A `develop` default-branch helper (`wt config state default-branch set develop`).
- A Linux port of my `workon` script (Zed, browser at `APP_URL`, herdr / herdr-plus
  workspace, a database GUI).
- Optional: the worktrunk Claude plugin, T3 Code (`omarchy-install-ai-t3-code`),
  Tailscale + `lerd lan:share` for remote access.
- Linux stand-ins for Tower (lazygit / Zed's git panel) and TablePlus.
