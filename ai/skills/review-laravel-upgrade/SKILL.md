---
name: review-laravel-upgrade
description: Review a Laravel framework upgrade (and any Filament/Livewire/Pest upgrades that rode along with it) to catch anything that was missed, half-done, or regressed. Use this skill whenever the user asks to review, double-check, audit, or verify an upgrade — phrases like "review my upgrade", "did I miss anything upgrading", "check the laravel-upgrade branch", "audit the framework upgrade", "I bumped Laravel from 10 to 13, did I forget anything", or "make sure the Filament/Livewire migration is complete". Also use after running any of the upgrade-* skills, before merging an upgrade branch, or when a project was just moved across major versions and you want a completeness/regression pass. The skill figures out the right branch to compare against, detects which frameworks were bumped and to what versions, pulls in the matching upgrade-* skills as checklists, and reports missed transformations, likely regressions, and config/env risks.
---

# Reviewing a Laravel Upgrade

The goal is to act as a second pair of eyes after a major-version upgrade: confirm every required transformation was actually applied across the **whole** codebase (not just the files that happened to get touched), surface likely regressions, and flag config/env risks. Be concrete and skeptical — an upgrade that "looks done" often has stragglers in files the person never opened.

**This review is strictly read-only.** Do not change any code, config, tests, or other project files — not even "obvious" fixes for issues you find. The only file you create is the HTML report (Step 6). Report findings; let the user decide what to fix.

## Step 1 — Establish the diff and what was upgraded

Run the bundled script. It picks the comparison base from the branch name, computes the fork point, and reports dependency bumps and the changed-file set:

```bash
scripts/upgrade-diff.sh
```

Base-branch rules the script follows (pass an explicit base as `$1` to override):

- Branch name contains `upgrade` (e.g. `laravel-upgrade`) → compare to **develop**.
- Branch is `develop` → compare to **main** (or **master**).
- Otherwise → try develop, then main/master.

It diffs against the **merge-base** (fork point), so you review only what this branch introduced, not unrelated changes already on the base. If the script can't resolve a base, ask the user which branch to compare against rather than guessing.

Read the "Dependency version changes" block — that's your map. It tells you the *from* and *to* major versions for `laravel/framework`, `filament/filament`, `livewire/livewire`, `pestphp/pest`, PHP, etc. Everything downstream keys off this.

### Map the git history into discrete upgrade steps

A single branch often contains **several sequential major-version steps** (e.g. 10→11, 11→12, 12→13), each a group of commits. The script's "Candidate upgrade-step boundaries" block lists the commits that changed the `laravel/framework` constraint — each marks the edge of one step. **Audit each step against its own upgrade guide, not the whole range as one change.** Diff each step in isolation (`git diff <prev-step>..<this-step>`) and check it against the guide for *that* hop. This is how you catch a guide item that was skipped in one specific step — reading the collapsed end-to-end diff hides a transformation that a later step happened to touch the same file for. When you report a finding, name the step it belongs to. If the boundaries aren't obvious from the script, reconstruct them from `git log` (Shift commits, version bumps) or ask the user which commits bound each step.

### Audit third-party dependencies, not just first-party

First-party bumps are the easy part; upgrades break on community packages. From the script's lock-consistency / dependency-health block (and `composer.json` directly), check:

- **`composer.lock` is in sync** with `composer.json` (the script runs `composer validate`) — a stale lock means the audited versions aren't what will actually install.
- **Every third-party `require` / `require-dev` package** has a release that supports the target Laravel — flag anything **abandoned**, unmaintained, or still **pinned to an old-major constraint** (e.g. `^10.0` left behind on a Laravel 13 project) that only resolves because of a loose `*` or a held-back transitive dep.
- Constraints that were widened to `*` or `dev-` branches just to force resolution — those are upgrade smells worth surfacing.

## Step 2 — Activate the matching upgrade skills

For each framework that jumped a major version, the corresponding `upgrade-*` skill holds the authoritative list of transformations, gotchas, and search-and-replace patterns. **Activate every skill that covers a version the project passed through** — these are cumulative, not just the destination version.

| Detected bump | Activate |
|---|---|
| Laravel 10 → 11 (or through it) | `upgrade-laravel-11` |
| Laravel 11 → 12 (or through it) | `upgrade-laravel-12` |
| Laravel 12 → 13 (or through it) | `upgrade-laravel-13` |
| Filament 3 → 4/5 | `upgrade-filament-4` |
| Livewire 2 → 3 | `upgrade-livewire-3` |
| Livewire 3 → 4 | `upgrade-livewire-4` |

Example: a Laravel **10 → 13** jump means reading `upgrade-laravel-11`, `upgrade-laravel-12`, **and** `upgrade-laravel-13` — each version added its own breaking changes, and a straight 10→13 hop skips the intermediate guides a person would normally read one at a time. If the project also moved Filament 3→4 and Livewire 2→3, pull those in too.

Pair each skill with the matching **step** from Step 1: review the 10→11 step's diff against `upgrade-laravel-11`, the 11→12 step against `upgrade-laravel-12`, and so on. The 10→11 hop is usually the highest-risk one (new application skeleton), so weight it accordingly.

If none of the bumped versions map to an installed skill (e.g. an older or newer jump than the skills cover), say so and review from first principles using the official upgrade guides — don't silently skip the dimension.

Treat each skill's "Quick Reference / Search & Replace" table and checklist as your literal checklist for the next step.

## Step 3 — Scan the whole codebase for missed transformations

This is the heart of the review. For every deprecated pattern the activated skills flag, grep the **entire** project — not just changed files. A stray `$this->emit(` in a component nobody touched is exactly the kind of thing a manual upgrade misses.

Run greps for the patterns most likely to linger. Adapt to what the skills list; representative examples:

- **Laravel:** `VerifyCsrfToken` / `ValidateCsrfToken` references, `$casts` property instead of `casts()` method, `Storage::disk('local')` assumptions, deleted config files whose keys were hardcoded before.
- **Laravel 10→11 application skeleton (audit consistency, not just presence).** Don't just grep for a leftover `app/Http/Kernel.php` — check the skeleton was migrated *completely and consistently*, because Shift can leave a working-but-half-migrated state. Confirm that **whichever model the project landed on** is wired end-to-end:
    - If it adopted the new slim skeleton: `bootstrap/app.php` registers middleware (`->withMiddleware(...)`), exceptions (`->withExceptions(...)`), routing, and scheduling — and the old `app/Http/Kernel.php`, `app/Console/Kernel.php`, `app/Http/Middleware/*` defaults, and `app/Exceptions/Handler.php` are gone, not orphaned alongside it.
    - Scheduled commands moved to `routes/console.php` (or a `withSchedule` closure), not stranded in a deleted `Console/Kernel.php::schedule()`.
    - Custom middleware/middleware-groups/aliases and exception `report`/`render` customisations from the old Kernel/Handler were actually carried over into `bootstrap/app.php`, not silently dropped.
    - Flag the half-state explicitly: new `bootstrap/app.php` **and** a surviving `Http/Kernel.php` together is a red flag — one of them is dead code and its registrations may not be taking effect.
- **Filament 3→4:** old namespaces `Filament\Forms\Components\Section`/`Grid`/`Fieldset`, `Filament\Tables\Actions\*`, `Filament\Forms\Actions\*` — anything the `upgrade-filament-4` skill says moved.
- **Livewire 2→3:** `App\Http\Livewire` namespace, `$this->emit(`, `emitTo`, `emitUp`, `dispatchBrowserEvent(`, `wire:model.defer`/`.lazy`, `@entangle(...)` without a modifier, `assertEmitted` in tests, `livewire:load`.
- **Livewire 3→4:** unclosed `<livewire:...>` tags, `wire:scroll`, `Livewire\Volt\` imports, `Livewire.hook('commit'`/`'request'`.

For each hit, decide: is it genuinely missed, or intentionally retained via a compatibility config (e.g. Livewire's `legacy_model_binding`, keeping the old `class_namespace`)? Check the relevant config before flagging — the skills note which behaviors can be preserved by config rather than code changes.

Also run the project's own tooling if the skills/CLAUDE.md mention it (e.g. `vendor/bin/filacheck --fix`, `php artisan livewire:upgrade`) and note anything it reports.

## Step 4 — Inspect config and the diff for regressions

Beyond find-and-replace, look for behavior changes:

- **Config drift / streamlined files.** Major upgrades (and Laravel Shift) often rewrite or delete config files, dropping hardcoded settings that then silently fall back to new framework defaults. Diff each changed config file against the base, and check for *deleted* config files. The `upgrade-laravel-13` skill documents the high-value traps in detail — notably `config/cache.php` `serializable_classes`, `config/filesystems.php` `'visibility' => 'public'` on served local disks, and env-var defaults (`CACHE_STORE`, `AUTH_MODEL`, `APP_LOCALE`, etc.). Also compare the old effective logging stack to the new `LOG_STACK` / logging config: if the old stack included production reporting channels such as `flare`, `sentry`, `bugsnag`, `papertrail`, or a custom alert channel, flag any committed default that drops them. Treat this as production-env dependent rather than automatically broken — if production intentionally sets `LOG_STACK=single,flare` (or equivalent), mark it verified; otherwise exception reporting may silently stop. Walk those before concluding.
- **Logic changes in the diff.** Read the actual `git diff` for app code that changed during the upgrade. Upgrades sometimes "fix" a deprecation by rewriting logic — verify those rewrites preserve behavior (signature changes, return-type changes, renamed events/properties, casts).
- **Stale compiled artifacts.** Note whether caches need clearing (`php artisan view:clear config:clear route:clear cache:clear`) — compiled Blade views from old package versions cause `TypeError`s that masquerade as code bugs.

## Step 5 — Verify with the test suite

Run the project's tests according to its conventions (check `CLAUDE.md` — this project runs `php artisan migrate:fresh --seed --env=testing` first, then `php artisan test --compact`). A green suite is reassuring but **not** sufficient: the `upgrade-laravel-13` skill explains why some regressions (e.g. cache serialization) only appear with a serializing store in the browser and pass under the test-default `array` store. Call out anything that needs manual/browser verification.

Report failures with their actual output. If you can't run tests, say so and list what should be run manually.

## Step 6 — Report

Use this structure so the user can act on it quickly:

```
# Upgrade Review: <from> → <to>

## Scope
- Branch <current> compared to <base> (fork point <sha>)
- Detected bumps: Laravel 10→13, Filament 3→4, Pest 2→4, PHP 8.1→8.3, ...
- Skills consulted: upgrade-laravel-11/12/13, upgrade-filament-4

## 🔴 Missed transformations (must fix)
- <file:line> — <deprecated pattern> → <required replacement> (per <skill>)

## 🟠 Likely regressions / behavior changes
- <description, file:line, why it's risky>

## 🟡 Config & environment risks
- <dropped key / env default / cache-serialization concern>

## 🟢 Verified clean
- <dimensions checked and found complete>

## Verification
- Tests: <result, or what to run manually>
- Recommended manual checks: <browser/cache/etc.>

## Could not verify — need from you
- <claim/dimension you couldn't confirm and exactly what's needed: prod env values, which commits bound a step, network access for `composer outdated`, a serializing cache store, etc.>
```

Always close with the "Could not verify" section even if short — an honest list of open questions and what you'd need to resolve them is more useful than an over-confident all-clear. If you're unsure whether something is a real finding, say so rather than guessing. Prioritize by severity. For every "missed" item, cite the file and the specific skill rule it violates so the fix is unambiguous. Distinguish "definitely wrong" from "worth a look" — false alarms erode trust in the review. If a dimension is fully clean, say so explicitly; silence reads as "not checked."

### HTML report

In addition to the markdown summary in the conversation, write a readable standalone HTML version of the report to the project root (e.g. `upgrade-review-report.html`). Requirements:

- Self-contained: inline CSS, no external assets or JavaScript, opens directly in a browser.
- Same structure and content as the report above — scope table with version bumps, the 🔴/🟠/🟡/🟢 sections (use colored markers), and the verification results.
- Lead with a one-paragraph verdict so the reader gets the conclusion without scrolling.
- Tag findings that were already fixed vs. worth a look vs. to do, and cite files/commits as `<code>` so they're easy to spot.

This HTML file is the **only** file the review may create or modify — never edit project code, config, tests, or documentation as part of the review (see the read-only rule at the top).

## Optional — fan out for large upgrades

When several frameworks were upgraded at once and the codebase is large, the dimensions are independent — Laravel core, Filament, and Livewire each have separate pattern sets. Consider dispatching one subagent per dimension (each activating its upgrade-* skill and scanning the whole codebase for that framework's patterns), then merging their findings into the single report above. For small or single-framework upgrades, just do it inline.
