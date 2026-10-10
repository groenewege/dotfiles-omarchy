---
name: upgrade-laravel-11
description: Upgrade Laravel v10 code to v11+. Use this skill whenever upgrading a Laravel project from v10 to v11, when copying code or examples from a Laravel 10 project into a Laravel 11 or newer (12, 13) project, when encountering deprecated Laravel 10 patterns, when referencing old Laravel 10 tutorials or documentation, or when adapting v10-era code snippets found online. Also activate when you see Laravel 10 patterns like `app/Http/Kernel.php` middleware registration, `$casts` property instead of `casts()` method, `float`/`double` migrations with `$total`/`$places` arguments, `Schema::getAllTables()`, `doctrine/dbal` usage, or `config/app.php` provider arrays. Trigger on any mention of "laravel 10", "laravel v10", "upgrade laravel", "migrate laravel 10", or "convert laravel 10".
---

# Upgrading Laravel v10 to v11+

This skill helps you convert Laravel v10 code to v11 and beyond. Whether you're running a full project upgrade, copying code from a v10 codebase, or adapting a v10 tutorial, apply these transformations.

For the complete official upgrade guide with all edge cases, read `references/upgrade-guide.md` in this skill's directory.

## ⚠️ Real-World Breakages After a Laravel Shift Run (read this first)

These are the highest-cost issues from actual upgrades — they are **not** in the official upgrade guide. Laravel Shift aggressively **streamlines/removes config files** (`config/app.php`, `auth.php`, `cache.php`, `session.php`, …) and `lang/*`, relying on env vars + Laravel 11's framework-default config merging. Any setting that used to be hardcoded now silently falls back to a Laravel 11 **default** unless an env var supplies it. (Note: this contradicts the "structure migration not needed" principle below — Shift opts you into the new structure whether or not you needed it.)

**Diagnostic tell:** after the upgrade, *many* feature tests fail at once, each "expected page" rendering as a full generic error page (`<!DOCTYPE html><html lang="...">`) that masks a 500 — or pages show **untranslated keys** (`admin.admin_title`) instead of text. Don't debug per-test. Reproduce **one** request via `php artisan tinker --env=testing` (`app(Kernel::class)->handle($request)`), read the real status/exception (request `Accept: application/json` to get the exception as JSON), and you'll usually find a single root cause behind dozens of failures.

**Env vars to set in EVERY environment** — `.env`, `.env.testing`, **and** prod/staging/CI. These files are git-ignored, so Shift never touches them; it only updates `.env.example`. Verify each:

| Env var | Renamed from | Default if unset | Symptom / fix |
|---|---|---|---|
| `CACHE_STORE` | `CACHE_DRIVER` | `database` | Needs a `cache` table → `SQLSTATE … 'cache' doesn't exist`. Bouncer's `Bouncer::cache()` triggers it. Set `file` (or `array` in testing) to match old behavior. |
| `BROADCAST_CONNECTION` | `BROADCAST_DRIVER` | `null` | Broadcasting misconfigured. |
| `DB_URL` | `DATABASE_URL` | — | Connection URL ignored. |
| `AUTH_MODEL` | (new) | `App\Models\User` | Login 500s with `Class "App\Models\User" not found` when the model lives at the legacy `App\User`. Set `AUTH_MODEL=App\User` — or, more robustly, declare the default in `config/auth.php` (`'providers' => ['users' => ['driver' => 'eloquent', 'model' => env('AUTH_MODEL', App\User::class)]]`; `auth.providers` is deep-merged) so no environment can miss it and the env var becomes unnecessary. |
| `APP_LOCALE` | (was hardcoded in `config/app.php`) | `en` | Non-English app renders translation **keys** instead of text; tests asserting localized strings fail. Set e.g. `APP_LOCALE=fr`. |
| `APP_FALLBACK_LOCALE` / `APP_FAKER_LOCALE` | (was hardcoded) | `en` / `en_US` | Same class of issue, but **read the original `config/app.php` — don't assume.** `fallback_locale` is usually `en` *independently* of `locale` (a French app commonly ran `locale => 'fr'`, `fallback_locale => 'en'`, `faker_locale => 'fr_FR'`). Set `APP_FALLBACK_LOCALE` to whatever the original file had, **not** to mirror `APP_LOCALE` — a fallback equal to the active locale is useless (missing keys render as raw keys instead of degrading to a real translation). `faker_locale` *does* typically match the app (e.g. `fr_FR`) — **but check the project's actual language first** (CLAUDE.md / ask). Old config files can carry leftovers copied from another project: an English-only app had `faker_locale => 'fr_FR'`, and the user wanted `en_US`. A value that contradicts the documented app language is a leftover, not an intent to preserve. |
| `LOG_STACK` | (was hardcoded in `config/logging.php`) | `single` | The `stack` channel silently loses its extra channels (e.g. `flare`/Sentry). Set e.g. `daily,flare` **in production**. Local dev usually doesn't want Flare (and often runs `LOG_CHANNEL=single`, making `LOG_STACK` irrelevant) — don't add it to `.env`/`.env.testing`, and keep `.env.example` (the local template) on `single`; list the prod value in the hand-off instead. |
| `BCRYPT_ROUNDS` | (was hardcoded in `config/hashing.php`) | `12` | New hashes use cost 12 instead of the project's prior cost; set to match (e.g. `10`). |

**`MAIL_ENCRYPTION` is dead in L11's framework `config/mail.php`.** When Shift streamlines `config/mail.php` away, the SMTP mailer reads `'scheme' => env('MAIL_SCHEME')` instead of `'encryption' => env('MAIL_ENCRYPTION', 'tls')`. No error — the var is just ignored. With `MAIL_SCHEME` unset, Laravel derives it from the port (`465` → `smtps`, anything else → `smtp` with opportunistic STARTTLS), so the usual `587`+`tls` / `465`+`ssl` setups keep working. Only a non-standard port/encryption combination needs `MAIL_SCHEME` set explicitly. Mention the stale `MAIL_ENCRYPTION` in the hand-off so nobody "fixes" mail by editing a var that no longer does anything.

Shift's PR comments list the exact env vars it detected (look for the "set the following variables" comment) — that list is the authoritative starting point.

**Don't treat `.env.example` as a correct reference — Shift rewrites it to the new *English* framework defaults, which is wrong for a non-English app and is itself a committed, latent risk.** Streamlining `config/app.php` moves the locale out of code and into env, and Shift's regenerated `.env.example` ships `APP_LOCALE=en`, `APP_FALLBACK_LOCALE=en`, `APP_FAKER_LOCALE=en_US`. Because `.env.example` *is* committed, every fresh clone, CI checkout, staging rebuild, or new prod env seeded from it inherits English — rendering untranslated keys or `en_US` faker data — even after you've fixed the git-ignored `.env`/`.env.testing`. Fix the committed `.env.example` too — but mirror the **original `config/app.php`**, not a blanket "make everything French": typically `APP_LOCALE=fr`, `APP_FALLBACK_LOCALE=en` (the original fallback, usually English — see the table note), `APP_FAKER_LOCALE=fr_FR`. Then reconcile each actual environment against it. This is the locale counterpart to the `.env.testing`/`phpunit.xml` split below: the value being in *a* file doesn't mean it's in the file the next environment will read.

### `.env.testing` and `phpunit.xml` are separate config sources — Shift updates only one
The testing environment is driven by two distinct sources, read at different times:
- **`phpunit.xml`** `<env>` vars apply **only when Pest/PHPUnit runs the suite**. Shift **does** update these to the new names (`CACHE_STORE`, etc.).
- **`.env.testing`** is loaded by `php artisan … --env=testing` — e.g. a `migrate:fresh --seed --env=testing` step many projects run *before* the suite to seed the test DB. It's git-ignored, so Shift **never** touches it.

The trap: a project that seeds its test DB this way breaks on the **seeding step** (classically `Table '…cache' doesn't exist` — `.env.testing` still has `CACHE_DRIVER`, so the unset `CACHE_STORE` falls back to `database`) **even though `phpunit.xml` looks correct and the test run itself is fine**. Apply every rename from the table above to `.env.testing` as well — not just `phpunit.xml` — and replicate them in CI.

Note that `.env` and `.env.testing` being gitignored has a second consequence: **your fixes to them are invisible in the PR diff and do not travel**. Only `.env.example` is committed. Every deployed environment — staging, production, CI — needs the renames applied by hand, or it fails there exactly as it did locally. Call this out explicitly when handing off an upgrade; it is the most common reason a green branch breaks on deploy.

**Shift bumps `phpunit/phpunit` to `^10.5` but leaves `phpunit.xml` on the PHPUnit 9 schema**, so every single test run prints `Your XML configuration validates against a deprecated schema`. One command fixes it, independently of whether you run the full PHPUnit 10 Shift: `vendor/bin/phpunit --migrate-configuration` (it writes `phpunit.xml.bak` — delete it, and add `/.phpunit.cache` to `.gitignore` for the `cacheDirectory` it introduces). The migration preserves every `<env>` var and rewrites `<coverage>` to `<source>`; re-run the suite to confirm.

⚠️ **Append to `.gitignore` newline-safely.** Laravel's stock `.gitignore` (and ones tools like Boost append to) often has **no trailing newline**, so `echo "/.phpunit.cache" >> .gitignore` glues the entry onto the last line — e.g. `opencode.json/.phpunit.cache` — which silently breaks **both** ignores. Use `[ -n "$(tail -c1 .gitignore)" ] && echo >> .gitignore; echo "/.phpunit.cache" >> .gitignore` (or the Edit tool), then confirm with `git check-ignore -v .phpunit.cache <previous-last-entry>`.

### Shift drops the `public` disk (and often the `default` key + `links` array) from `config/filesystems.php` (uploads silently move)
Shift's "Streamline config files" commit regenerates `config/filesystems.php`. When reconciling against a customized file it does **not** restore the full L11 skeleton — it can strip the entire top of the file, leaving only `local` and `testing`, and removing **all** of these in one go:

- the hand-written **`public` disk** (`root => storage_path('app/public')`, `url => …/storage`, `visibility => public`),
- the **`'default'` key** (`'default' => env('FILESYSTEM_DISK', 'local')`),
- the **`'links'` array** (`public_path('storage') => storage_path('app/public')`),
- the stock **`s3`** disk.

There is no error — everything silently falls back:

- **Filament `FileUpload`** with no explicit `->disk()` writes to the app default disk (`FILESYSTEM_DISK=local`) → files land in `storage/app/<dir>` instead of `storage/app/public/<dir>`, and the `public/storage` symlink can't reach them, so front-end `asset('storage/…')` links 404.
- **`spatie/laravel-medialibrary`** keeps resolving its disk via `env('MEDIA_DISK', 'public')` (its config default is the string `'public'`). With no `public` disk defined, existing `media` rows (whose `disk` column is `public`, files at `storage/app/public/XX/XXX`) can no longer be located, and new uploads misbehave the same way.
- **Missing `'default'` key** → `config('filesystems.default')` is `null`, so any **unnamed** `->store('dir')` / `->storeAs(...)` call (e.g. an Excel-import controller doing `$request->file->store('import')`) breaks — there's no default disk to resolve. This is a *separate* breakage from the `public` disk; check for it even when media looks fine.
- **Missing `'links'` array** → `php artisan storage:link` has nothing to create/verify (an already-present symlink keeps working, but a fresh deploy/CI box won't get one).

⚠️ **Version nuance — on a current 11.x the framework backfills all three, so the symptoms above may not appear. Declare them explicitly anyway.** `Illuminate\Foundation\Bootstrap\LoadConfiguration` merges your config files over the framework's own `config/*.php`, and `mergeableOptions()` deep-merges a specific set of second-level keys — `filesystems => ['disks']` among them (alongside `auth.guards/providers/passwords`, `cache.stores`, `database.connections`, `logging.channels`, `mail.mailers`, `queue.connections`, `broadcasting.connections`). Top-level keys absent from your file (`default`, `links`) come straight from the base config. So on 11.15+ a stripped `config/filesystems.php` still resolves a working `public` disk, and `config('filesystems.default')` is **not** null.

This matters in two directions:

- **Don't "verify" by reading `config()` and conclude there is nothing to do.** `config('filesystems.disks.public.root')` returning the right path proves the merge is working, not that the config is safe. The merge did not exist in early 11.x, so a project upgraded onto 11.0–11.14 breaks exactly as described above — which is why this shows up as a recurring, seemingly version-independent problem across projects.
- **The merged default is subtly wrong.** The framework's `public` disk builds its url as `env('APP_URL').'/storage'` with **no `rtrim`**. A trailing slash in `APP_URL` yields `https://site.test//storage/…` in every media URL. Local `.env` is usually clean while production is not, so this passes every local check and only shows up in prod. The explicit definition below uses `rtrim(env('APP_URL', 'http://localhost'), '/')` and is strictly safer.

Declaring them explicitly also survives the rest of the upgrade chain: merge semantics already changed once inside 11.x, and L12/L13 are still ahead.

**Diagnostic tell (early 11.x, or any version once you stop relying on the merge):** old images/files in the admin panel show as broken, and newly uploaded files appear under `storage/app/` instead of `storage/app/public/`. No exception is thrown — the disk name just resolves to a non-existent config and falls through to defaults. Confirm the regression by diffing the Shift commit: `git show <shift-commit> -- config/filesystems.php`.

Check the symlink separately from the config, since a missing `links` array leaves nothing for `storage:link` to create: `ls -ld public/storage`. A repo can carry media rows on the `public` disk with real files under `storage/app/public/` and **no symlink at all** — every `asset('storage/…')` dead — because `public/storage` is gitignored and nobody re-ran the command. Verify it on each deployed environment, not just locally.

**`ls -ld` is not enough — the link can exist but dangle.** A `public/storage` created on an old VM/Homestead/Vagrant box (or another project) points at an absolute path that no longer exists (e.g. `-> /home/vagrant/Sites/<old-project>/storage/app/public`). `ls -ld` happily prints it, every `asset('storage/…')` still 404s, and it predates the upgrade so it's easy to misattribute. Check the target resolves: `test -e public/storage && echo ok || echo DANGLING` (or `readlink public/storage`), and repair with `php artisan storage:link --force`.

**Fix:** restore the stripped pieces in `config/filesystems.php` — the `'default'` key, the `public` disk, and the `'links'` array (skip `s3` if the project has no AWS env vars / S3 usage):
```php
'default' => env('FILESYSTEM_DISK', 'local'),

// inside 'disks' => [ ... ]
'public' => [
    'driver' => 'local',
    'root' => storage_path('app/public'),
    'url' => rtrim(env('APP_URL', 'http://localhost'), '/').'/storage',
    'visibility' => 'public',
    'throw' => false,
],

'links' => [
    public_path('storage') => storage_path('app/public'),
],
```
Then confirm `php artisan storage:link` exists and `MEDIA_DISK`/`FILESYSTEM_DISK` still point where intended. A previous troubleshooting session may have papered over this by adding `'visibility' => 'public'` to the `local` disk so the misplaced files were at least servable — once the `public` disk is restored and uploads target it again, **revert that** `local` workaround back to the stock private default. Verify via the serializing-path style: open an existing media record and upload a new one in the admin, and assert files land under `storage/app/public/`.

**Guard with a config-shape test** (the suite can't catch this on its own): projects run tests with `MEDIA_DISK=testing` against a `testing` disk that *does* exist, so the suite stays green even with `public` gone. Add a feature test that asserts the **raw config array** — `config('filesystems.disks.public.driver') === 'local'`, `.root === storage_path('app/public')`, `.visibility === 'public'`, `config('filesystems.default')` is not null, and `config("filesystems.disks." . config('media-library.disk_name'))` resolves. (Same philosophy as a `serializable_classes` cache guard test.)

Be honest about what that test proves on a merge-capable version: because the framework backfills the disk, these assertions pass whether or not your own file declares it, so the test does **not** catch a future Shift strip of `public`. Its real value is the two things the merge can't cover — an env var pointing `MEDIA_DISK`/`FILESYSTEM_DISK` at a disk nobody defined, and the url shape. Assert the url too, since the merged default is the one that lacks `rtrim`:

```php
$this->assertSame(
    rtrim(config('app.url'), '/').'/storage/example.png',
    Storage::disk('public')->url('example.png'),
);
```

## Package Incompatibilities (audit `composer.json`)

Some packages cap at `illuminate/* ^10` and block `composer update`. Resolve each before assuming a framework conflict:

- **`silber/bouncer`** — `v1.0.1` only supports ≤ L10; use `^1.0.4` (supports L11/12/13).
- **`spatie/laravel-demo-mode`** — no Laravel 11 release exists; remove it (and its middleware alias + `config/demo-mode.php`) or fork it. First confirm it's actually wired: if no route/group applies the `demoMode` middleware alias anywhere, removing the package + alias + config is safe and preferred over forking.
- **`chencha/share`** — upstream caps at L9 (`6.1.0` → `illuminate/support ^6|^7|^8|^9`) and the common `laravel-shift/social-share` fork only reaches L10 on its `l10-compatibility` branch with no `l11` branch. The `groenewege/social-share` fork has `l11`/`l12`/`l13-compatibility` branches (`illuminate/support … ^11.0`). Point the VCS `repositories` entry at `groenewege/social-share` and set `"chencha/share": "dev-l11-compatibility"`. As always, if the facade (`Share::…`) is registered but never actually called, removing the package + its `config/app.php` alias + `ShareServiceProvider` is the cleaner path. Before switching forks, enumerate remote branches to confirm the target exists: `git ls-remote --heads <fork-url>`.
- **`laravel-shift/Googlmapper`** — caps at L10 and has no maintained L11+ release. Switch to the `groenewege/Googlmapper` fork, which has per-version compatibility branches (e.g. `l11-compatibility`). In `composer.json`, add the fork as a VCS repository and point the requirement at the matching branch:
  ```json
  "repositories": [
      { "type": "vcs", "url": "https://github.com/groenewege/Googlmapper" }
  ],
  "require": {
      "laravel-shift/googlmapper": "dev-l11-compatibility"
  }
  ```
  Use the branch matching the target Laravel version (e.g. `dev-l11-compatibility` for L11). Keep whatever package name the project already requires — some projects require it as `laravel-shift/googlmapper`, others as **`cornford/googlmapper`** (the fork's `composer.json` name); the VCS repository overrides it either way. Also check the existing `repositories` URL: it may still point at `https://github.com/laravel-shift/Googlmapper.git` (which has no L11 branch) — repoint it to `groenewege/Googlmapper`. Leave this fork constraint in place; don't let a later Shift run "normalize" it back to a tagged `laravel-shift/Googlmapper` release.
- **`troccoli/blade-health-icons`** — `^2.0` caps at `illuminate/support ^10.0`; bump to `^4.0` (the lowest release whose constraint includes `^11.0`; `^5.0` adds `^12.0`). Shift lists it under "not updated … may be incompatible" but does not bump it, so `composer update` fails with a plain `illuminate/support ^10.0` conflict until you raise the constraint yourself.
- **`laravelcollective/html`** — abandoned, caps at `illuminate/view ^10`. Shift flags it and suggests its paid HTML Converter (→ `spatie/laravel-html`), but it's often used hundreds of times (`Form::label/text/open/model/select…`) across public and admin views. The low-risk path: the **`groenewege/html`** fork has an `l11-compatibility` branch (v6.4.1 + `illuminate/*` widened to `^6…^13`, no code changes needed) — add `{ "type": "vcs", "url": "https://github.com/groenewege/html" }` and require `"laravelcollective/html": "dev-l11-compatibility"`. The same branch works for L12/L13. Community drop-ins exist (`nekhbet/laravel-collective-html` reaches only L12, `mfonte/laravel-collective-html` only L11) — they'd block a later upgrade. Count usage first (`grep -rEo "(Form|Html)::[a-zA-Z]+" resources app | wc -l`) and ask the user which route to take.
- **`laravelium/sitemap`** — abandoned upstream; Shift lists it as "not updated". The **`groenewege/laravel-sitemap`** fork has an `l11-compatibility` branch (`illuminate/support|filesystem ^8…^13`; the package only uses stable contracts, so widening the constraint is enough). Require `"laravelium/sitemap": "dev-l11-compatibility"`. It's typically used via `App::make('sitemap')` in `routes/web.php`, so it can't simply be dropped.
- **Creating a missing compat branch on one of your forks:** `git ls-remote --heads <fork>` first; if the target branch is missing, clone the latest compat branch into the scratchpad, `git checkout -b l11-compatibility`, widen every `illuminate/*` (and `laravel/framework` require-dev) constraint to `…|^11.0|^12.0|^13.0` so later Shifts don't need new branches, scan `src/` for removed framework APIs, commit and push. Pushing to the user's GitHub is outward-facing — ask first.
- For any package, check Packagist (`composer show <pkg> --all`, or the `repo.packagist.org/p2/<pkg>.json` API) for the lowest version whose `illuminate/*` constraint includes `^11.0`. Leave intentional `dev-*`/VCS-fork constraints (your own forks) as-is.

## `composer update` Resolution Blockers (beyond package caps)

Two non-obvious things can make `composer update` fail even after every package version cap is resolved:

### Stale `config.platform.php` pin
A leftover `config.platform.php` in `composer.json` (e.g. `"8.1.2"`) overrides your *real* PHP version during resolution, so L11's `php ^8.2` fails even on PHP 8.3:

```
Root composer.json requires php ^8.2 but your php version
(8.1.2; overridden via config.platform, actual: 8.3.24) does not satisfy that requirement.
```

Bump it to the target deploy PHP (the L11 skeleton uses `"8.2"`) or remove the `platform` block to resolve against the real runtime. Shift does **not** update this value.

### A security advisory can block an entire release line
Composer 2.x refuses to install versions flagged by a security advisory (`… not loaded, because they are affected by security advisories`). Because Laravel 11 is **EOL**, some advisories have **no patched 11.x release** — e.g. `PKSA-mdq4-51ck-6kdq` (CRLF injection in the default email rule) covers all `>=11.0.0,<12.0.0`, so `composer update` cannot resolve `laravel/framework ^11` at all (the cascading `pestphp/pest-plugin-laravel` conflict is the same root cause).

Key nuance: `policy.advisories.ignore-id` in `composer.json` is honored by `composer audit`, but **resolve-time blocking is effectively binary** in recent Composer (2.10) — the per-ID ignore does *not* unblock resolution. To proceed you must either:
- pass `--no-blocking` on that one command (persists nothing — preferred), or set `COMPOSER_NO_BLOCKING=1`, or
- set `policy.advisories.block: false` (disables blocking for *all* advisories — too broad).

The real fix is to **keep upgrading**: the patch only exists in Laravel 12.60+/13.10+, so generate the lock with `--no-blocking` to verify the L11 step, then run the Laravel 12 Shift next and let it regenerate the lock. Don't leave a permanent advisory bypass in `composer.json`.

In practice, run `composer update --no-blocking -W` (i.e. *with* `--with-all-dependencies`). The advisory filters every `laravel/framework` version out of the candidate set, which cascades into conflicts for any package locked to a transitive dep that requires the framework (e.g. `pxlrbt/filament-excel` → `anourvalar/eloquent-serialize`). Those surface as *separate* "Problem" blocks that look like independent package incompatibilities but are the **same root cause** — once `--no-blocking` lets the framework versions load, `-W` lets the locked transitives move to match, and the whole set resolves in one shot. Don't start hand-editing those package constraints before trying `-W`.

**`--no-blocking` is required on _every_ update against an EOL line — including targeted single-package updates, not just the initial full one.** A later `composer update <one-package>` (e.g. syncing the lock after pointing a constraint at a pushed fork branch) hits the exact same advisory wall, because resolution still has to load a compatible `laravel/framework` for the locked rest of the graph. The tell is different and misleading: instead of a framework "Problem 1" you get a stack of `"<pkg> is locked to version X and an update of this package was not requested"` blocks for packages you never touched — `laravel/scout`, `msurguy/honeypot`, `pestphp/pest-plugin-laravel`, `pxlrbt/filament-excel`, etc. Each reads like an independent conflict; all are the framework advisory block seen through a locked transitive (`illuminate/pagination`, `illuminate/config`, …). The fix is not to touch any of those constraints — it's to re-run the same command with `--no-blocking` (and `-W`, so the targeted update is allowed to nudge locked deps). Bake the flag into every hand-off command and every CI `composer update` step until the project reaches a patched release (Laravel 12.60+ / 13.10+).

### A VCS-fork repository shadows a package Shift bumped to a tagged release
When a package is pinned to your own fork (a `repositories` `vcs` entry + a `dev-<branch>` constraint), Shift may "helpfully" rewrite the constraint to a real tagged release it found on Packagist — e.g. `gazsp/baum: dev-l10-compatibility` → `^2.0`. But a `vcs` repository is **canonical and higher-priority** than Packagist, so if the fork doesn't expose a version matching the new constraint, resolution fails (note: this is *not* a missing-version error — the version exists on Packagist, it's just shadowed):
```
... satisfiable by gazsp/baum[2.0.2] from composer repo (packagist) but gazsp/baum[dev-..., 1.1.5]
from vcs repo (github ...) has higher repository priority. The packages from the higher priority
repository do not match your constraint and are therefore not installable.
```
`--with-all-dependencies` does **not** get past this — the repo-priority rule blocks it regardless. Two fixes, depending on whether you still need the fork:
- **Fork still required** (the official package caps below the target Laravel, like Googlmapper): add a matching compatibility branch to the fork (e.g. `l11-compatibility`) and point the constraint at `dev-l11-compatibility` — overriding Shift's tagged constraint. Confirm the branch exists first: `git ls-remote --heads <fork-url> | grep compat`.
- **Official release now supports the target**: check the Packagist release's own constraint (`gazsp/baum 2.0.2` requires `illuminate/support >=5.8`, which includes L11) — the fork *may* be obsolete. Remove its `repositories` entry so the Packagist release resolves, and keep Shift's tagged constraint.

⚠️ **A compatible constraint is not enough — confirm the fork actually contains that release.** Compare the release commit with the fork branch: `gh api repos/<you>/<fork>/compare/<release-sha>...<fork-branch> --jq '.status, .ahead_by, .behind_by'`. For **`gazsp/baum`** the `groenewege/baum` fork has **diverged** from 2.0.2 (fork ahead 9 / behind 82): it's built on the old 1.x line with custom commits, including a nestable re-order bugfix from sebdesign/baum. Switching to `^2.0` swaps in a different code line, not a newer version of the same one. **Keep the fork**: `"gazsp/baum": "dev-l11-compatibility"` (the branch exists, also `l12`/`l13`), overriding Shift's `^2.0`, and flag the override to the user.

This is the same fork-vs-official decision as the Googlmapper note above, but triggered in reverse: there Shift *kept* the fork constraint, here it *replaced* it. Either way, decide per-package whether the official release reaches the target Laravel version.

### When a fork carries several custom commits, evaluate each one — "official caught up" is per-commit, not per-package
The fork-vs-official decision above assumes the fork exists for one reason (L11 compat). Real forks often carry **multiple unrelated commits**, and the right answer can be *split*: some are now upstreamed (drop them), others never were (keep them). Don't decide for the whole package — `git log <fork-branch>` against the upstream base and classify **each** commit:
- **Now upstream** → drop. (Example: a `french language` translation commit — official later shipped its own `resources/lang/fr/…`. Confirm by diffing the fork's file against the installed package's file; if upstream's exists and is complete, the fork commit is dead weight even if the wording differs. Prefer a published-lang-file override to a fork for pure wording tweaks.)
- **Still absent upstream _and_ still used by the app** → must be carried forward. Confirm "still used" by grepping the app for the feature that depends on it (e.g. `->afterStateUpdated(…)` attached to the forked component for auto-save). If a test doesn't cover it, the regression from dropping it is silent — verify by hand.

**Carry a still-needed patch forward by re-deriving it against the _current_ upstream release, not by cherry-picking the old commit.** A fork branch that's ~2 years stale sits on a base upstream has since refactored, so the old commit's anchors have **moved and multiplied**. Real example: the original patch added one line after `$component->state(...)` in **5** spots; by the current release the monolithic component had been split into a `Component` base class + `Concerns/*`, and the mutation surface had grown to **9** sites (add, add-child, edit, delete, indent, dedent, move-up, move-down, plus the drag-reorder handler that moved into the base class's `builder::sort` listener). Blindly cherry-picking the 5-site commit would half-apply and silently miss reorder/indent auto-save. Instead: check out the current upstream tag, re-find every equivalent site (`grep -rn '\$component->state(' src/`), apply the change to all of them **except** non-user-initiated ones (skip the hydration/default-init `state([])`), and `php -l` each file.

Then, so the fork survives the *next* Shifts too, widen the fork's **own** `illuminate/contracts` (or `illuminate/support`) constraint to the full target range (`^10.0|^11.0|^12.0|^13.0`) before pushing. Point the app at it with a `dev-<branch>` constraint + VCS `repositories` entry, and verify by installing from the pushed branch (`composer update <pkg> --no-blocking -W`) and re-running the suite — the pushed fork commit hash may differ from your local one, so confirm the patch is actually present in `vendor/` (`grep -rc <marker> vendor/<pkg>/src/`) rather than trusting the version string.

## `spatie/laravel-medialibrary` v10 → v11 (spatie/image v2 → v3)

The `Spatie\Image\Manipulations::FIT_*` constants are gone — replace with the `Spatie\Image\Enums\Fit` enum in every model's `registerMediaConversions()`:

```php
// v10
use Spatie\Image\Manipulations;
->fit(Manipulations::FIT_MAX, 600, 600)   // FIT_FILL, FIT_CROP, …

// v11+
use Spatie\Image\Enums\Fit;
->fit(Fit::Max, 600, 600)                  // Fit::Fill, Fit::Crop, Fit::Contain, Fit::Stretch, Fit::FillMax
```

`->width()`, `->height()`, `->quality()`, `->sharpen()` are unchanged. Symptom if missed: `Class "Spatie\Image\Manipulations" not found` (often surfaces first during seeding).

## `spatie/laravel-permission` v5 → v6 (migration uses a removed static property)

Symptom — `migrate:fresh`, CI, or a fresh install fatals with:
```
Access to undeclared static property Spatie\Permission\PermissionRegistrar::$pivotPermission
```
In v6 the published `create_permission_tables` migration stopped reading pivot column names from the **static** `PermissionRegistrar::$pivotPermission` / `$pivotRole` (now instance properties) and reads **local variables** from config instead. Your already-published migration still uses the old static access, and Shift bumps the package without rewriting published migrations.

**Fix — edit the existing migration in place; do NOT add a new one.** The v5 and v6 **schemas are identical** (per Spatie: *"no changes to the package's structure since v5"*), so this is a code-only change and **production needs no DB migration** — the tables are already correct. Editing the old file only matters for paths that *re-run* migrations (local resets, CI, `RefreshDatabase`, new environments). A new migration would be wrong: there's no structural delta to apply. In the migration's `up()`:
```php
// remove the import:  use Spatie\Permission\PermissionRegistrar;
// add after $columnNames is defined:
$pivotRole = $columnNames['role_pivot_key'] ?? 'role_id';
$pivotPermission = $columnNames['permission_pivot_key'] ?? 'permission_id';
// then replace every  PermissionRegistrar::$pivotPermission → $pivotPermission
//                     PermissionRegistrar::$pivotRole       → $pivotRole
// and add those vars to the use(...) clause of each closure that references them.
```
This holds only if the migration is the **stock** one (no UUID switch, no custom index-name lengths). If customized, merge by hand against the new stub.

Other v6 breaks worth grepping for (most won't apply, but the namespace one is easy to miss):
- Middleware namespace renamed `Spatie\Permission\Middlewares\` → `Middleware\` (singular) — update the `$middleware->alias([...])` block in `bootstrap/app.php` (or `Kernel.php` on the old structure) and any route/import references. Symptom: every role/permission-guarded route 500s with `Target class [Spatie\Permission\Middlewares\RoleMiddleware] does not exist` — this can fail *hundreds* of tests at once, masking that it's a single one-line fix.
- Role/Permission **ids must be passed as integers**; numeric strings (e.g. from HTML form fields) are looked up as *names* → `There is no permission named '123'`. Cast form data back to int before grant/assign/sync/revoke.
- Remove any `->registerPermissions()` calls from tests (no longer needed, and must be deleted).
- If you extended the Role/Permission models or implemented their contracts, reconcile the changed method signatures.

## Filament plugin bumped a major version + a custom theme → its styling silently disappears

When a Laravel upgrade drags a **Filament plugin** across several versions (e.g. `saade/filament-adjacency-list` from an old v3.1-era fork to v3.3, or any plugin Shift bumps), a plugin that renders through a **custom Filament theme** can come back **functionally intact but visually gutted** — controls unstyled, nesting/indentation gone, hover-revealed action buttons (edit/delete) missing entirely. It looks like a broken JS/asset publish; it usually isn't.

**Root cause:** newer plugin versions often drop their self-contained published stylesheet and style everything with **Tailwind utility classes written directly in their Blade views** (`flex`, `border`, `rounded-lg`, and critically `hidden … group-hover:flex` for the on-hover action bar). Those utilities only reach the browser if **your theme's Tailwind build scans the plugin's views**. A custom theme's `content`/`@source` list typically covers `app/Filament`, your app views, and `vendor/filament/**` — but **not** `vendor/<vendor>/<plugin>/**`, so Tailwind purges every class the plugin needs. The old plugin version masked this because it shipped a compiled CSS; the version jump exposes it. (`FilamentAsset`-published JS/CSS in `public/` is a *separate* mechanism and republishes fine via `filament:upgrade` — don't chase it.)

**Diagnostic tell:** the component still *works* (rows reorder, forms submit) but is missing borders/indent/hover icons; the published `public/js/<vendor>/…` and `public/css/<vendor>/…` files updated correctly; and the plugin's Blade views contain raw Tailwind utilities (`grep -r 'group-hover:' vendor/<vendor>/<plugin>/resources/views/`).

**Fix:** add the plugin's views to the **custom theme's** Tailwind sources and rebuild.
- Tailwind **v4** theme (`theme.css` with `@source`): `@source '../../../../vendor/<vendor>/<plugin>/resources/views/**/*.blade.php';`
- Tailwind **v3** theme (`resources/css/filament/<panel>/tailwind.config.js`): add `'./vendor/<vendor>/<plugin>/resources/views/**/*.blade.php'` to the `content` array. **Don't** paste the README's `@source` line into a v3 project — it's v4-only syntax and silently does nothing.

Then `npm run build` (the compiled `theme-*.css` should grow and its hash change — that's the confirmation the classes were picked up), and **hard-refresh** the panel (Cmd/Ctrl+Shift+R) since the old theme CSS is browser-cached. Prod picks it up automatically if `npm run build` is in the `post-update-cmd`/deploy step. A no-op suite won't catch this (it's pure CSS), so verify visually — or assert the built theme contains a plugin marker class.

## Shift removes `AuthServiceProvider` / `EventServiceProvider` — re-register what auto-discovery can't find

When Shift adopts the L11 structure it **deletes** `app/Providers/AuthServiceProvider.php` and `EventServiceProvider.php`, migrating the obvious pieces (e.g. a `Gate::before` closure moves into `AppServiceProvider::boot()`). But anything L11's auto-discovery can't reconstruct is **silently dropped** — no error, the feature just stops firing. Diff the deleted providers against `origin/master` (`git show origin/master:app/Providers/AuthServiceProvider.php`) and re-register two things in `AppServiceProvider::boot()`:

- **Custom policy mappings** whose model→policy pair breaks the `App\Models\X` → `App\Policies\XPolicy` convention. L11's guesser replaces the model's last namespace segment, so `Illuminate\Notifications\DatabaseNotification => DatabaseNotificationPolicy` guesses `Illuminate\Notifications\Policies\DatabaseNotificationPolicy` (doesn't exist) and is never discovered. Re-add `Gate::policy(DatabaseNotification::class, DatabaseNotificationPolicy::class);`. (Policies for app models in the standard location *do* auto-discover — only the non-conventional ones need this.)
- **Event listeners**, when the old `EventServiceProvider::shouldDiscoverEvents()` returned `false`. ⚠️ **Correction — in the streamlined L11 structure, listener discovery defaults *ON*, not off.** `Application::configure()` calls `->withEvents()` for you (Application.php ~L244), and the framework `EventServiceProvider` has `protected static $shouldDiscoverEvents = true`, so it scans `app/Listeners` by default even though `bootstrap/app.php` never mentions events. This has **two** consequences, both the opposite of "listeners vanish":
    - Every listener class in `app/Listeners` whose `handle()`/`__invoke()` type-hints an event gets auto-registered — including ones the old `$listen` array **deliberately omitted** (dormant WIP/feature-flagged listeners that only existed because `shouldDiscoverEvents()` was `false`). Those silently **activate**. Real example: a `SubscribeToNewsletter` listener sitting next to `SendPasswordNotification` in `app/Listeners`, never in `$listen`, starts firing on the same event after upgrade. (A `config()` guard inside it may mask this until someone flips the env flag — a latent behavior change, not a safe no-op.)
    - Blindly "re-adding `Event::listen()` for each old `$listen` entry" now **double-registers** everything discovery already found.

  **Faithful fix for a `shouldDiscoverEvents: false` project:** disable discovery explicitly with `->withEvents(discover: false)` in `bootstrap/app.php`, **then** register the exact original `$listen` set via `Event::listen(...)` in `AppServiceProvider::boot()`. This reproduces the old wiring precisely — dormant listeners stay dormant, and nothing is registered twice. Don't rely on discovery to "just find them": it finds too much. **`php artisan event:list` is the authoritative before/after check** — compare its `App\…` rows against the deleted provider's `$listen` array and confirm they match exactly (no extras, no dupes).

  **Diagnostic tell:** a dropped listener often surfaces as a *notification* assertion failure (`The expected [App\Notifications\X] notification was not sent`) where the notification class name matches **neither** the event nor the listener — because the chain is event → listener → *sends a third-named notification* (e.g. `NewStudentCreated → SendPasswordNotification → UserCreated`). Don't grep for the notification name; trace which event *should* fire it and check that event's listener is registered. The suite catches these only if a test asserts the notification/side-effect — purely behavioral wiring with no test stays silently broken, so `php artisan event:list` is the authoritative check.

**The trap — do NOT re-register `Registered => SendEmailVerificationNotification`.** Laravel 11's framework `EventServiceProvider::configureEmailVerification()` already registers it automatically, so copying it back from the old `$listen` array sends the verification email **twice**. Re-register only your *application's* listeners. Verify the final wiring with `php artisan event:list` (a `ShouldQueue` class-string listener legitimately prints two rows — the class and its `@handle` — that is not a double registration; a genuine duplicate is the same listener under two separate registrations).

## Shift removes `RouteServiceProvider` — `withRouting()` drops whole route files and per-group middleware

The single highest-impact silent loss of an L11 Shift, and the one most likely to look like "the upgrade broke everything". Shift replaces a custom `RouteServiceProvider` with the stock `withRouting()` call:

```php
->withRouting(
    web: __DIR__.'/../routes/web.php',
    api: __DIR__.'/../routes/api.php',
    commands: __DIR__.'/../routes/console.php',
    health: '/up',
)
```

That registers **exactly two route files with stock middleware**. Anything else the old provider did inside `$this->routes(...)` is gone:

- **Additional route files are never registered at all.** A project with `routes/admin.php` under a `prefix('admin')->name('admin.')` group loses every one of those routes.
- **Extra middleware on a standard group disappears.** `Route::middleware('web', 'tenant')->group(base_path('routes/web.php'))` becomes plain `web` — the `tenant` middleware silently stops running on every web request, even though `withMiddleware()` may still *define* the `tenant` group.

Shift **does** flag this in a PR comment (it quotes your original registry back at you) but automates nothing, so it is easy to skim past among a dozen informational comments.

**Diagnostic tell:** a large fraction of the suite fails with `RouteNotFoundException: Route [admin.foo.index] not defined` — a *route name* error, not a 404. Because named routes are resolved by shared layouts and nav partials, this also fails tests that never touch the missing area. Count routes before and after as the authoritative check, the way `event:list` is authoritative for listeners:

```bash
git stash && php artisan route:list | wc -l      # pre-upgrade count
# …after…
php artisan route:list | wc -l
php artisan route:list | grep -c 'admin\.'       # per-group spot check
```

**Fix — reproduce the original registry in the `then` callback**, and **remove `web:` from `withRouting()`** when you register `web.php` yourself, or it is registered twice:

```php
use Illuminate\Support\Facades\Route;

->withRouting(
    api: __DIR__.'/../routes/api.php',
    commands: __DIR__.'/../routes/console.php',
    health: '/up',
    then: function () {
        Route::middleware(['web', 'tenant'])
            ->group(base_path('routes/web.php'));

        Route::middleware(['web', 'auth', 'can:access_admin'])
            ->prefix('admin')
            ->name('admin.')
            ->group(base_path('routes/admin.php'));
    },
)
```

Read the deleted provider first (`git show origin/master:app/Providers/RouteServiceProvider.php`) and port every group verbatim — prefix, name prefix, and the full middleware list. The `api:` argument already applies the `api` prefix and middleware, so only move it into `then` if it was customised.

**Shift may also delete `routes/api.php` / `routes/channels.php` outright** and leave `// api:` / `// channels:` commented out in `withRouting()`. It does this when it judges them default stubs (e.g. only the stock `Route::middleware('auth:api')->get('/user', …)`, or only the `App.User.{id}` channel with `BroadcastServiceProvider` already disabled). Usually correct, but verify: `git show origin/master:routes/api.php` — if it held **any** real route (webhooks, mobile/JS endpoints, anything a client calls), restore the file and uncomment `api:`; for channels, restore only if broadcasting is actually enabled. The route-count check above catches this too (the `/api/user` stub accounts for a drop of exactly 1).

## Key Principle: Application Structure

Laravel 11 introduced a new streamlined application structure, but Laravel 10 applications upgrading to v11 do **not** need to migrate their structure. Laravel 11+ fully supports the v10 file layout. Don't refactor `app/Http/Kernel.php`, service providers, or config files unless the project has already adopted the new structure.

## High Impact Changes

### Dependency Versions

PHP 8.2+ is required. Update these in `composer.json`:

| Package | New Version |
|---|---|
| `laravel/framework` | `^11.0` |
| `nunomaduro/collision` | `^8.1` |
| `laravel/sanctum` | `^4.0` |
| `laravel/passport` | `^12.0` |
| `laravel/telescope` | `^5.0` |
| `laravel/cashier` | `^15.0` |
| `laravel/dusk` | `^8.0` |
| `laravel/jetstream` | `^5.0` |
| `laravel/octane` | `^2.3` |
| `laravel/scout` | `^10.0` |
| `laravel/spark-stripe` | `^5.0` |
| `livewire/livewire` | `^3.4` |
| `inertiajs/inertia-laravel` | `^1.0` |

Remove `doctrine/dbal` if present — Laravel no longer depends on it.

### Package Migrations Must Be Published

Cashier Stripe, Passport, Sanctum, Spark Stripe, and Telescope no longer auto-load their migrations. Publish them:

```bash
php artisan vendor:publish --tag=sanctum-migrations
php artisan vendor:publish --tag=passport-migrations
php artisan vendor:publish --tag=cashier-migrations
php artisan vendor:publish --tag=telescope-migrations
php artisan vendor:publish --tag=spark-migrations
```

### Modifying Columns — All Attributes Must Be Explicit

This is a critical behavioral change. When using `->change()` on a column, you must now re-declare **all** modifiers (unsigned, default, comment, etc.) or they will be dropped.

**v10 (attributes were preserved automatically):**
```php
$table->integer('votes')->nullable()->change();
```

**v11+ (must re-state all attributes):**
```php
$table->integer('votes')
    ->unsigned()
    ->default(1)
    ->comment('The vote count')
    ->nullable()
    ->change();
```

If you don't want to update old migrations, squash them: `php artisan schema:dump`

### Floating-Point Types Rewritten

`double` and `float` no longer accept `$total` and `$places` arguments.

**v10:**
```php
$table->double('amount', 8, 2);
$table->float('amount', 8, 2);
```

**v11+:**
```php
$table->double('amount');
$table->float('amount', precision: 53); // optional precision
```

`unsignedDecimal`, `unsignedDouble`, and `unsignedFloat` methods are removed. Chain `->unsigned()` instead:
```php
$table->double('amount')->unsigned();
```

## Medium Impact Changes

### Carbon 3 Compatibility

`diffIn*` methods now return floats and can return negative values. If using Carbon 3, cast or `abs()` as needed:
```php
// v10 with Carbon 2: always returns positive int
$days = $start->diffInDays($end); // 5

// v11 with Carbon 3: returns float, can be negative
$days = (int) abs($start->diffInDays($end)); // 5
```

### Rate Limiting — Seconds Instead of Minutes

`GlobalLimit`, `Limit`, `ThrottlesExceptions`, and `ThrottlesExceptionsWithRedis` constructors now accept **seconds** instead of minutes. The `decayMinutes` property is renamed to `decaySeconds`.

**v10:**
```php
new Limit($key, $attempts, 2); // 2 minutes
```

**v11+:**
```php
new Limit($key, $attempts, 2 * 60); // 120 seconds
```

Use static constructors like `Limit::perMinute()` and `Limit::perSecond()` to avoid confusion.

### Spatie Once Package Conflict

Laravel 11 has a built-in `once()` helper. Remove `spatie/once` from `composer.json` if present.

## Low Impact Changes

### Eloquent Model `casts` Method

The base model now defines a `casts()` method. If any model has a **relationship** named `casts`, rename it to avoid conflict. The `casts()` method approach for defining casts is now preferred over the `$casts` property.

### Doctrine DBAL Removal

All Doctrine DBAL classes and methods are removed. Use native schema methods:

| Removed | Replacement |
|---|---|
| `Schema::getAllTables()` | `Schema::getTables()` |
| `Schema::getAllViews()` | `Schema::getViews()` |
| `Schema::getAllTypes()` | `Schema::getTypes()` |
| `$connection->getDoctrineColumn()` | `Schema::getColumns()` |
| `$connection->getDoctrineSchemaManager()` | `Schema::getIndexes()`, `Schema::getForeignKeys()` |

### Spatial Types Unified

Replace specific spatial methods with `geometry` or `geography`:

```php
// v10
$table->point('location');
$table->polygon('area');

// v11+
$table->geometry('location', subtype: 'point', srid: 4326);
$table->geometry('area', subtype: 'polygon', srid: 0);
```

### Sanctum Middleware Config

Update `config/sanctum.php`:
```php
'middleware' => [
    'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
    'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
    'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
],
```

### Password Rehashing

Laravel 11 auto-rehashes passwords on login. If your password column isn't named `password`, set `$authPasswordName` on the User model:
```php
protected $authPasswordName = 'custom_password_field';
```

Or disable with `'rehash_on_login' => false` in `config/hashing.php`.

## New v11 Structure (for new projects only)

If the project uses the v11+ structure (no `app/Http/Kernel.php`):

- **Middleware** → configured in `bootstrap/app.php` via `->withMiddleware()`
- **Service providers** → registered in `bootstrap/providers.php`
- **Console kernel** → removed; use `routes/console.php`
- **Config files** → only publish config files you need to customize
- Commands in `app/Console/Commands/` are auto-discovered

## Quick Checklist

When you encounter v10 code going into a v11+ project:

1. Check `float`/`double` migration calls for removed `$total`/`$places` args
2. Check `->change()` migrations — all column attributes must be explicit
3. Replace `unsignedDouble`/`unsignedFloat`/`unsignedDecimal` with `->unsigned()` chain
4. Replace `Schema::getAllTables()` and similar Doctrine methods
5. Remove `doctrine/dbal` references
6. Check `Limit` constructor calls — seconds not minutes
7. Remove `spatie/once` if present
8. Check for model relationships named `casts` (conflict with new base method)
9. Replace spatial column methods with `geometry`/`geography`
10. Publish package migrations if using Sanctum, Passport, Telescope, Cashier, or Spark

## Triage Shift's "review these files" comments before editing

Several Shift checklist comments are **conservative lists, not confirmed problems** — verify with one grep before touching anything:

- **Faker modifiers** (`optional()`, `unique()`, `valid()` with arguments): the listed files are frequently already correct. Only a *property* access after the modifier needs fixing: `grep -nE "(optional|unique|valid)\([^)]*\)->[a-zA-Z_]+([^a-zA-Z_(]|$)" <files>`. No hits → tick the box, no change.
- **`array` return type on `broadcastOn()`/`via()`**: list dozens of files, but only those that `return` a bare object break: `grep -A4 'function broadcastOn\|function via' … | grep return | grep -v 'return \['`. The typical offender is the `make:event` stub's `return new PrivateChannel('channel-name');` on an event that doesn't even implement `ShouldBroadcast` — a latent `TypeError`, not a live bug. Wrap it in `[...]`.
- **Deprecated `Rule`/`InvokableRule` validation contracts**: optional in L11, but converting to `ValidationRule` is mechanical (`passes()`+`message()` → `validate(..., Closure $fail)`); guard `array_key_exists` with `is_array($value)` since the new signature types `$value` as `mixed`, and add a small unit test via `Validator::make()` since custom rules are rarely covered directly.
- **`lang/en/validation.php` "could not upgrade"**: if Shift already slimmed it to `custom`/`attributes`, it merges with framework defaults and needs nothing.
- **"Republish Horizon assets"**: Horizon ≥ 5.2x inlines its CSS/JS via `Horizon::css()`/`Horizon::js()` in its layout. There's nothing to publish, and a committed `public/vendor/horizon/` directory is stale dead weight (offer to delete it; don't republish).
- **Listener `$listen` + `shouldDiscoverEvents(): false`**: if *every* class in `app/Listeners` is in `$listen`, default discovery registers exactly the original set. Confirm with `event:list` (one row per listener, `@handle` suffix) and change nothing. `withEvents(discover: false)` is only needed when dormant listeners exist.

## Post-Shift Verification Checklist

The code checklist above won't catch what a Shift run *removes*. After `composer update` succeeds, run these before trusting a green suite — each has a specific authoritative check, because all of these fail silently:

**Capture baselines _before_ checking out the Shift branch** (while the old code and `vendor/` still match): `php artisan route:list --json > routes_before.json` and `php artisan event:list`. After the upgrade, diff by `method + uri` rather than raw counts, so a dropped route offset by a new one (`/up`) can't hide:
```bash
php -r '$f=fn($p)=>array_map(fn($r)=>$r["method"]." ".$r["uri"],json_decode(file_get_contents($p),true)); $a=$f($argv[1]); $b=$f($argv[2]); echo "removed: ",implode(", ",array_diff($a,$b)),"\nadded: ",implode(", ",array_diff($b,$a)),"\n";' routes_before.json routes_after.json
```

1. **Routes** — `php artisan route:list | wc -l` against the pre-upgrade count, plus a per-group grep. Catches route files `withRouting()` never registered and middleware dropped from a group.
2. **Listeners** — `php artisan event:list`, compared row by row against the deleted `EventServiceProvider::$listen`. Catches both dropped listeners and newly auto-discovered ones that were deliberately dormant.
3. **Policies** — any model→policy pair that breaks the `App\Models\X` → `App\Policies\XPolicy` convention needs an explicit `Gate::policy()`.
4. **Env vars** — every rename applied to `.env`, `.env.testing`, `.env.example` **and** each deployed environment. `APP_LOCALE` in particular, for a non-English app.
5. **Filesystems** — `default`, `public` and `links` declared explicitly; `test -e public/storage` (the symlink must *resolve*, not just exist) on every environment.
6. **Middleware namespaces** — grep `bootstrap/app.php` aliases against what the upgraded packages actually ship (`spatie/laravel-permission` v6 renamed `Middlewares\` → `Middleware\`).

If a large number of tests fail at once, resist debugging them individually. Reproduce **one** request through the kernel with an `Accept: application/json` header to get the real exception — the failures almost always share a single root cause, and the rendered error page hides it.
