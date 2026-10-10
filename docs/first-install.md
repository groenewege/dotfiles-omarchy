# First install on a new Omarchy machine

This repo was written on a Mac, without access to a real Omarchy installation.
So the first time, let an agent check it against the actual machine **before**
running anything. Later machines can skip step 4 and follow the
[README](../README.md#fresh-install) directly.

## 1. Install and update Omarchy

Install Omarchy (see [README > Install Omarchy](../README.md#1-install-omarchy)
for the Intel MacBook notes). Then:

1. Make sure you are online (the installer usually connects Wi-Fi already; otherwise use the network icon in the top bar).
2. Update, so the audit sees the current Omarchy version:

   ```bash
   omarchy-update
   ```

   Reboot if it asks you to.

## 2. Clone this repo

The repo is public, so no GitHub login is needed:

```bash
git clone https://github.com/groenewege/dotfiles-omarchy.git ~/Code/dotfiles-omarchy
cd ~/Code/dotfiles-omarchy
```

## 3. Copy your server list (optional now)

Copy your SSH hosts into `~/.ssh/config.d/hosts`. See
[README > SSH hosts](../README.md#ssh-hosts) for how to make that file. This
can wait until after the install, but you'll need it before connecting to any
server.

## 4. Let an agent audit the repo

Start Claude Code in **plan mode**: it can read and inspect everything, but it
can't change anything until you approve its plan. The prompt is in
[audit-prompt.md](audit-prompt.md), so there's nothing to copy-paste:

```bash
cd ~/Code/dotfiles-omarchy
claude --permission-mode plan "$(cat docs/audit-prompt.md)"
```

The first `claude` command installs Claude Code (Omarchy ships it as a
placeholder that installs on first use) and opens a browser to log in.

Then:

1. Read the report. It ends with blockers, proposed changes and an install order.
2. Answer its questions, and ask for changes to the plan if needed.
3. Approve the plan. The agent makes the fixes on a new branch, shows you the
   diff and commits. Nothing is pushed, and nothing is installed.

If the commit fails because git doesn't know who you are yet, let the agent run
`git config --global user.name "Gunther Groenewege"` and
`git config --global user.email gunther@groenewege.com` first.

## 5. Install

Run the steps in the order the report recommends, checking after each one:

```bash
./install.sh --list           # the step names
./install.sh --only packages  # one step at a time, in the recommended order
```

Run `ssh-github` before `link`: `link` turns on commit signing, and
`ssh-github` creates the key it signs with. Log out and back in after `link`, so
the SSH agent is used everywhere.

Or run everything at once with `./install.sh`. The prompts to expect, and the
by-hand checklist afterwards, are in the
[README](../README.md#3-run-the-installer).

## 6. Push the fixes

The `ssh-github` step creates your SSH key, adds it to GitHub, and switches
this repo's remote from HTTPS to SSH. After that you can push the agent's
branch:

```bash
git push -u origin <branch>
```

Then merge it into `develop` and `main` as usual.
