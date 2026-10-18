# Cheat sheet

Shell commands and keyboard shortcuts for daily use. **Super** is the Cmd key on
the MacBook keyboard. Rows marked ★ are added by this repo; the rest are
Omarchy's or the app's defaults.

Forgot one? **Super+K** searches every desktop shortcut, **Super+Ctrl+K** lists
herdr's, and Zed's command palette (**Ctrl+Shift+P**) shows each command's key.

- [Mac habits](#mac-habits)
- [Our own shortcuts](#our-own-shortcuts)
- [Omarchy](#omarchy)
- [Terminals](#terminals)
- [herdr](#herdr)
- [Zed](#zed)
- [lazysql](#lazysql)
- [superfile](#superfile)
- [Claude Code](#claude-code)
- [Shell](#shell)

## Mac habits

Linux uses Ctrl where macOS uses Cmd, and the MacBook keyboard has no
Home/End/PageUp/PageDown keys: **Fn+arrows** sends them.

| On the Mac | Here |
|---|---|
| Cmd+C / V / X | Ctrl+C / V / X in apps, or **Super+C / V / X** everywhere (also in terminals) |
| Cmd+← / → (start/end of line) | Fn+← / → (Home / End) |
| Cmd+Shift+← / → (select to start/end of line) | Fn+Shift+← / → |
| Option+← / → (by word) | Ctrl+← / → (add Shift to select) |
| Cmd+↑ / ↓ (start/end of document) | Fn+Ctrl+← / → (Ctrl+Home / End) |
| Cmd+Space (Spotlight) | Super+Space (Omarchy menu), Super+Alt+Space (apps) |
| Cmd+Q / Cmd+W | Super+W closes the window |
| Cmd+Tab | Alt+Tab (next window) |
| Clipboard history | Super+Ctrl+V |

In a terminal the shell handles these keys: they move the cursor but don't
select.

## Our own shortcuts

Everything this repo adds or changes, in one place.

| Keys | Does | Defined in |
|---|---|---|
| Super+Shift+E | Gmail (replaces HEY) | `stow/hypr/.config/hypr/bindings.lua` |
| Super+Shift+Alt+E | New Gmail message (replaces HEY) | same |
| Super+Shift+C | Google Calendar (replaces HEY Calendar) | same |
| Super+Shift+Alt+N | Notion | same |
| Super+Alt+Return | Ghostty (replaces Omarchy's tmux key) | same |
| Super+Ctrl+U | Agent usage panel (Claude/Codex limits) | same |
| Ctrl+Shift+C (Zed) | Copy the file's relative path (replaces the collab panel) | `stow/zed/.config/zed/keymap.json` |
| Ctrl+Shift+R (Zed, editor) | Run the nearest task (e.g. the test under the cursor) | same |
| Ctrl+Shift+F (Zed, editor) | Run the tests in the current file (`php artisan test`) | same, task in `tasks.json` |
| Ctrl+Space ↑ (herdr) | herdr-plus: projects | `config/herdr.toml` |
| Ctrl+Space ↓ (herdr) | herdr-plus: quick actions | same |
| Ctrl+G (bash) | Fuzzy cd into a subfolder | `stow/bash/.config/bash/functions.sh` |
| `/client-email` (Claude) | French email to a client summarising recent commits | `stow/claude/.claude/commands/` |

In Zed, our Ctrl+Shift+F takes over project-wide search while the cursor is in
an editor. Search the project from the project panel, or with "project search"
in the command palette.

## Omarchy

### Apps and menus

| Keys | Does |
|---|---|
| Super+Space | Omarchy menu |
| Super+Alt+Space | Apps menu |
| Super+Escape | System menu (lock, suspend, restart…) |
| Super+K | Search all keybindings |
| Super+Return | Terminal (foot) |
| Super+Ctrl+Return | herdr |
| Super+Shift+Return / Super+Shift+B | Browser (add Alt for private) |
| Super+Shift+N | Editor (Zed) |
| Super+Shift+F | File manager (add Alt to open it in the current folder) |
| Super+Shift+/ | Passwords (1Password) |
| Super+Shift+D | Docker |
| Super+Ctrl+E | Emojis |
| Super+Ctrl+Q | Calculator |
| Super+Ctrl+Shift+Space | Theme menu |
| Super+Ctrl+Space | Background switcher |

### Windows

| Keys | Does |
|---|---|
| Super+W | Close window |
| Super+arrows | Focus window in that direction |
| Super+Shift+arrows | Swap window in that direction |
| Alt+Tab / Shift+Alt+Tab | Next / previous window |
| Super+F | Full screen (Super+Alt+F: full width) |
| Super+T | Toggle floating / tiling |
| Super+J | Toggle split direction |
| Super+O | Pop window out (float and pin on top) |
| Super+− / Super+= | Grow / shrink window horizontally (add Shift for vertically) |
| Super+drag / Super+right-drag | Move / resize with the mouse |
| Super+G | Group windows into tabs (Super+Alt+Tab: next in group) |
| Super+S | Scratchpad (Super+Alt+S: send window to it) |
| Super+Backspace | Toggle transparency |
| Ctrl+Alt+Delete | Close all windows |

### Workspaces

| Keys | Does |
|---|---|
| Super+1…9 | Go to workspace |
| Super+Shift+1…9 | Move window to workspace (add Alt to stay where you are) |
| Super+Tab / Super+Shift+Tab | Next / previous workspace |
| Super+Ctrl+Tab | Back to the former workspace |

### Clipboard, screenshots, system

| Keys | Does |
|---|---|
| Super+C / V / X | Universal copy / paste / cut (works in terminals too) |
| Super+Ctrl+V | Clipboard history |
| Super+Ctrl+C | Capture menu (screenshot, screen recording, text/OCR, QR code, color picker) |
| Super+Ctrl+L | Lock |
| Super+Ctrl+W / B / A | Network / Bluetooth / Audio |
| Super+Ctrl+N | Toggle night light |
| Super+Ctrl+I | Toggle locking when idle |
| Super+Shift+Space | Toggle the top bar |
| Super+, | Dismiss the last notification (Super+Shift+,: all) |
| Super+Ctrl+, | Do not disturb |

## Terminals

foot (Super+Return) and Ghostty (Super+Alt+Return):

| Keys | Does |
|---|---|
| Ctrl+Shift+C / V | Copy / paste (or Super+C / V) |
| Ctrl+= / Ctrl+− | Bigger / smaller text |

## herdr

The prefix is **Ctrl+Space**: press it, release, then press the key. Omarchy
sets herdr up like its old tmux config: tabs are tmux windows, workspaces are
tmux sessions. Super+Ctrl+K lists every binding; prefix ? shows herdr's help.

| Keys | Does |
|---|---|
| Alt+Enter / Alt+Shift+Enter | Split pane side by side / stacked (prefix h / v) |
| Ctrl+Alt+arrows | Focus pane in that direction |
| Ctrl+Alt+Shift+arrows | Resize pane |
| prefix z | Zoom the pane |
| prefix x or Alt+Esc | Close pane |
| prefix c | New tab |
| Alt+1…9 | Go to tab |
| Alt+← / → | Previous / next tab (add Shift to move the tab) |
| prefix r | Rename tab |
| prefix Shift+C | New workspace |
| Alt+↑ / ↓ | Previous / next workspace |
| prefix [ | Copy mode (scroll back, select) |
| prefix d | Detach (herdr keeps running) |
| prefix ↑ ★ | herdr-plus: projects |
| prefix ↓ ★ | herdr-plus: quick actions (open site, GitHub repo, export / import database…) |

## Zed

Zed's Linux keys are its macOS keys with Ctrl instead of Cmd.

| Keys | Does |
|---|---|
| Ctrl+P | Open a file |
| Ctrl+Shift+P | Command palette |
| Ctrl+R | Recent projects |
| Ctrl+Shift+E | Project panel (Ctrl+B: hide/show the left dock) |
| Ctrl+Alt+B / Ctrl+J | Hide/show the right / bottom dock |
| Ctrl+Shift+G | Git panel |
| Ctrl+` | Terminal panel |
| Ctrl+? | Agent panel |
| Ctrl+Enter | Inline AI edit |
| Ctrl+F / Ctrl+H | Find / replace in the file |
| Ctrl+Shift+O | Go to a symbol in the file |
| Ctrl+T | Go to a symbol in the project |
| Ctrl+G | Go to line |
| F12 | Go to definition |
| F2 | Rename symbol |
| Ctrl+. | Code actions |
| Ctrl+D | Select the next match (Ctrl+Shift+L: all matches) |
| Alt+↑ / ↓ | Move line up / down |
| Ctrl+Shift+K | Delete line |
| Ctrl+/ | Toggle comment |
| Ctrl+Shift+T | Reopen closed tab |
| Ctrl+Shift+C ★ | Copy relative path |
| Ctrl+Shift+R ★ | Run the nearest task |
| Ctrl+Shift+F ★ | Test the current file |

## lazysql

`project-db`, or the **db** tab in herdr. `?` shows every key, `q` quits.

| Keys | Does |
|---|---|
| H / L | Focus the table list / the table |
| 1 … 5 | Records / Columns / Constraints / Foreign keys / Indexes |
| / | Filter the rows with a WHERE clause (Esc in the filter clears it) |
| K / J | Sort ascending / descending on the column |
| > / < | Next / previous page |
| c | Edit the cell (Enter to keep the change) |
| C | Set the cell to NULL, empty or DEFAULT |
| o / O / d | Insert a row / duplicate it / delete it |
| Ctrl+S | **Save**: write the pending changes to the database |
| Ctrl+E | SQL editor (Ctrl+R runs the query) |
| E | Export to CSV (~/Downloads) |
| Y | Copy rows as SQL INSERTs, JSON, CSV… |

## superfile

`spf` opens a terminal file manager. `?` shows every key, `q` quits, and
`Q` ★ quits into the folder you were browsing.

| Keys | Does |
|---|---|
| j / k, ↑ / ↓ | Move down / up |
| l / Enter, h / Backspace | Open the file or folder / go to the parent folder |
| / | Search the current folder |
| z | Jump to a folder with zoxide |
| . | Show or hide dotfiles |
| o / R | Sort options / reverse the sort |
| v | Selection mode (J / K extend it, A selects all) |
| Ctrl+N / Ctrl+R | New file (end the name with `/` for a folder) / rename |
| Ctrl+C / Ctrl+X / Ctrl+V | Copy / cut / paste |
| Ctrl+D / D | Move to the trash / delete permanently |
| Ctrl+A / Ctrl+E | Compress / extract |
| e / E | Open the file / the folder in `$EDITOR` |
| c / Ctrl+P | Copy the folder's path / the file's path |
| n / w | Open / close a file panel; Tab and Shift+← switch between them |
| s / P | Focus the sidebar / pin the folder to it |
| f | Show or hide the preview |
| : | Run a shell command in the folder |

## Claude Code

| Keys | Does |
|---|---|
| Shift+Tab | Cycle permission modes (normal, auto-accept, plan) |
| Esc | Stop Claude |
| Shift+Enter | New line without sending (Ghostty; elsewhere type `\` then Enter) |
| Esc Esc | Go back to an earlier message |
| `!` at the start | Run a shell command; its output lands in the conversation |
| `@` | Mention a file |
| Ctrl+G | Edit the prompt in `$EDITOR` |
| Ctrl+C twice | Quit |

Claude Code and Codex know Lerd through its MCP server: ask them to tail the
logs, snapshot the database, restart the queue worker or find slow queries.
`/mcp` lists the servers.

## Shell

Omarchy's defaults stay available: `ls`/`lt` (eza), `cd` (zoxide), `ff` (fzf
with preview), `g` (git), `d` (docker), `h` (herdr), `cx` (claude), `cy`
(codex), `n` (nvim), `open`, and fzf's Ctrl+R (history), Ctrl+T (files) and
Alt+C (cd).

Added by this repo (see `stow/bash/.config/bash/`):

| | |
|---|---|
| Laravel | `art`, `tinker`, `pam` `pam:fs` `pam:f` `pam:r` `pam:rs` `pam:roll`, `routes [filter]`, `scheduler`, `pint` |
| Tests | `p` (pest or phpunit), `pf <filter>`, `pp` (parallel), `t`/`tf` (phpunit) |
| Composer / npm | `ci` `cu` `cr` `cda`, `nr` `nrd` `nrb` |
| Git | `commit [msg]` (no message: Claude writes one), `gll`, `nah`, `uncommit`, `push`, `pull`, `gpo`, `git-prune-local`, `clone owner/repo`, `lg` |
| Databases | `db create\|drop\|refresh\|list <name>` (Lerd MySQL), `project-db [export\|import <file>]` (lazysql, dumps) |
| AI | `c` (claude), `ccc` (claude --continue), `cxy` (codex without approvals) |
| Projects | `setup-project [owner/repo]` (clone + full Lerd setup), `open-project [folder]` / `workon` (herdr, Zed and the site), `sites`, `dotfiles` |
| Lerd | `tunnel` (`lerd share`), `phpserve` (plain `php -S` on port 8888) |
| Files | `l` / `ll` (eza), `cat` (bat), `top` (btm), `about` (fastfetch), `mkd`, `zed`, `o` (open the folder), Ctrl+G (fuzzy cd), `spf` (superfile; Q quits into its folder) |
| SSH | `copykey`, `sshconfig`, `removehost <host>`, `hostfile` |
| Network | `myip`, `localip`, `flushdns`, `digga <domain>` |

Overridden Omarchy aliases: `c` (was opencode) and `t` (was tmux).
