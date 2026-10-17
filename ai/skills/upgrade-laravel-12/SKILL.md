---
name: upgrade-laravel-12
description: Upgrade Laravel v11 code to v12+. Use this skill whenever upgrading a Laravel project from v11 to v12, when copying code or examples from a Laravel 10 or 11 project into a Laravel 12 or newer (13) project, when encountering deprecated Laravel 11 patterns, when referencing old Laravel 11 tutorials or documentation, or when adapting v11-era code snippets found online. Also activate when you see Laravel 11 patterns like `HasUuids` trait producing UUIDv4, `HasVersion7Uuids` trait usage, Carbon 2.x usage, `Grammar::setConnection()` calls, `Connection::withTablePrefix()` calls, `image` validation passing SVGs, or `Storage::disk('local')` defaulting to `storage/app`. Trigger on any mention of "laravel 11", "laravel v11", "upgrade laravel", "migrate laravel 11", "convert laravel 11", or "laravel 12 upgrade".
---

# Upgrading Laravel v11 to v12+

This skill helps you convert Laravel v11 code to v12 and beyond. Whether you're running a full project upgrade, copying code from a v10/v11 codebase, or adapting an older tutorial, apply these transformations.

For the complete official upgrade guide with all edge cases, read `references/upgrade-guide.md` in this skill's directory.

## ⚠️ Real-World Breakages After a Laravel Shift Run (read this first)

Not in the official upgrade guide. Laravel Shift **streamlines/removes config files** (`config/app.php`, `auth.php`, `cache.php`, …) and relies on env vars + framework-default config merging. Any setting that was hardcoded now silently falls back to the new framework **default** unless an env var supplies it. Each major-version Shift pushes a different default into env, so re-check this on every upgrade.

**Diagnostic tell:** *many* feature tests fail at once, each rendering a generic error page (`<!DOCTYPE html><html lang="...">`) that masks a 500 — or pages show **untranslated keys** instead of text. Don't debug per-test: reproduce **one** request via `php artisan tinker --env=testing` (`app(Kernel::class)->handle($request)` with `Accept: application/json` to get the exception), and one root cause usually explains dozens of failures.

**Verify these env vars in EVERY environment** — `.env`, `.env.testing`, **and** prod/staging/CI (these files are git-ignored, so Shift only updates `.env.example`):

- `CACHE_STORE` — defaults to `database` (needs a `cache` table); set `file`/`array` to match old behavior. Bouncer's `Bouncer::cache()` triggers `SQLSTATE … 'cache' doesn't exist`.
- `AUTH_MODEL` — defaults to `App\Models\User`; set `App\User` if the model is in the legacy location, else login 500s with `Class "App\Models\User" not found`.
- `APP_LOCALE` / `APP_FALLBACK_LOCALE` / `APP_FAKER_LOCALE` — default to `en` / `en_US`; non-English apps render translation **keys** instead of text.
- `BROADCAST_CONNECTION`, `DB_URL`, `SESSION_*`, `QUEUE_CONNECTION`, `MAIL_MAILER` — confirm against the values the old hardcoded config used.
- `APP_TIMEZONE` is **removed in L12**. The timezone defaults to `UTC` unless `'timezone'` is hardcoded in `config/app.php`; Shift keeps it there as a true customization if it was already set. Check `config('app.timezone')`, because a European app that silently switches to UTC shifts every displayed date and scheduled job.
- `MAIL_ENCRYPTION` is **removed**, replaced by `MAIL_SCHEME`, which takes different values (`smtp`/`smtps`, not `tls`/`ssl`). `null` needs no action. If prod sets `tls`, leave `MAIL_SCHEME` unset, since STARTTLS is negotiated automatically. Use `smtps` only for implicit TLS on port 465.

To check all of these at once for one environment: `php artisan tinker --env=<env> --execute="echo json_encode(['cookie'=>config('session.cookie'),'cache_prefix'=>config('cache.prefix'),'cache'=>config('cache.default'),'auth_model'=>config('auth.providers.users.model'),'locale'=>config('app.locale'),'tz'=>config('app.timezone'),'collation'=>config('database.connections.mysql.collation'),'local_root'=>config('filesystems.disks.local.root')]);"`

Shift's PR comments list the exact env vars it detected ("set the following variables" comment) — that list is the authoritative starting point. Also audit `composer.json` for packages capping at `illuminate/* ^11` that block `composer update` (check Packagist for the lowest `^12`-compatible version; leave intentional `dev-*`/VCS-fork constraints as-is).

### Shift PR warnings that are often false positives — verify, don't just act

Shift's comments are written for the general case, and several do not apply to an app whose config files Shift already slimmed. Check each against the running app before changing anything.

- **`CACHE_PREFIX` / `REDIS_PREFIX` / `SESSION_COOKIE` "now use dashes".** That change landed in the **`laravel/laravel` skeleton** config files, not in the framework's bundled defaults. An app whose `config/cache.php` and `config/session.php` Shift deleted reads `vendor/laravel/framework/config/*.php`, which still uses `'_'` — so the values do **not** change, nobody is logged out, and no cache is missed. Verify before pinning anything: `php artisan tinker --execute="echo config('session.cookie').' '.config('cache.prefix');"`. Pin the env vars only if that actually prints dashes.
- **`DB_COLLATION` "the default changed".** The `utf8mb4_0900_ai_ci` → `utf8mb4_unicode_ci` switch shipped in **later Laravel 11**, so a project already on ~11.42+ absorbed it in the *previous* upgrade. Check the base branch's lockfile (`git show <base>:composer.lock | grep -A2 '"name": "laravel/framework"'`) before calling a live-DB mismatch an L12 regression. Compare the real database (`SELECT @@collation_database`) with `config('database.connections.mysql.collation')`, and pin `DB_COLLATION` to the database's actual value only if you need the old comparison semantics.
- **"Republish your Horizon/Nova assets."** Current Horizon (v5.4x) no longer ships published assets — `php artisan horizon:publish` just prints `Horizon no longer publishes its assets. You may stop calling the horizon:publish command.` Run `php artisan view:clear` and move on.
- **The `image`/SVG comment** lists every file merely *mentioning* image or svg; see "Image Validation Excludes SVGs" below for how narrow the real scope is.
- **"Faker modifiers which received arguments"** (`optional(0.7)`, `unique(true)`, …) lists every file that uses such a modifier, even when the chained call is already a method (`->optional(0.7)->sentence()`). Only property access after the modifier (`->optional(0.7)->name`) needs converting, and `grep -nE '(optional|unique|valid)\([^)]*\)->[a-zA-Z_]+([^a-zA-Z_(]|$)'` finds just those. There are usually none.
- **"Static calls to scope methods may need `query()`"**: Shift already rewrites the direct `Model::scopeName()` calls it finds, including in migrations and seeders. Confirm with a grep for the scope names the comment lists (`::(scopeA|scopeB)\b` across `app database routes resources tests`). An empty result means nothing is left to do.
- **"Container respects default constructor values"** lists nearly every controller. It only matters for classes whose constructors have **nullable, defaulted, class-typed** parameters that the app relied on the container to fill, which is rare in app code. Skim the list rather than auditing every file.

### `HasMiddleware` conversion leaves the app non-bootable

When a project registered middleware in controller constructors, Shift converts it to the `HasMiddleware` interface + `middleware()` static method — but on apps with a **custom base controller** it leaves two fatal artifacts. The diagnostic tell is `Class "App\Http\Controllers\Controller" not found` during `composer dump-autoload`/`package:discover`, then once that's fixed, `Error: Cannot call constructor` (a 500 on every authed route).

1. **Base `Controller` extends itself.** Shift rewrites `app/Http/Controllers/Controller.php` to `use App\Http\Controllers\Controller as BaseController; class Controller extends BaseController` — a self-reference. In L11+ the base controller extends nothing. Make it a plain `abstract class Controller {}` (drop `AuthorizesRequests`/`ValidatesRequests` too — grep `$this->authorize(`/`$this->validate(` first; if unused, they're safe to drop). When they **are** used, Shift itself rewrites the call sites to the facades (`$this->authorize(...)` → `Gate::authorize(...)`, adding the `Illuminate\Support\Facades\Gate` import; `$this->validate(...)` → `$request->validate(...)`) — a behavior-preserving completion of the trait removal, so don't revert it. Note this can happen on a **later** Shift run: if a previous major's upgrade already slimmed the base controller, the `Gate::authorize()` conversions show up in *this* PR's diff, not the one that removed the traits.

2. **Child controllers keep an empty `__construct()` calling `parent::__construct()`.** Shift moves the `$this->middleware(...)` lines into `middleware()` but leaves the now-empty constructor shell. Since the base no longer has a constructor, `parent::__construct()` fatals. Grep `parent::__construct` across `app/Http/Controllers` and delete each dead constructor — this *completes* Shift's transformation, it doesn't revert it.

3. **Shared view data is silently lost.** If the old base-controller middleware shared variables with every view (e.g. `view()->share('user', ...)`), L12 **no longer inherits middleware from parent controllers**, so child-controller routes lose it. Don't rely on the base controller's `middleware()` reaching children. **Prefer a `web`-group middleware** (`$middleware->web(append: [ShareUserWithViews::class])` in `bootstrap/app.php`) that keeps calling `view()->share(...)`, because it keeps the old behavior exactly. A `View::composer('*', fn ($view) => $view->with('user', ...))` is **not** equivalent: shared data has the *lowest* precedence, but a composer's `with()` *overwrites* data a controller passed explicitly. For example, a view rendered with `'user' => $otherUser` would silently show the logged-in user instead. The loss is silent. Views usually guard with `isset(...)`, so the header just renders without its notification badge and no test goes red. Add a feature test that asserts the shared output, and confirm it fails when the middleware is commented out.

**Artisan is unusable until this is fixed.** Every `php artisan` call (`make:middleware`, `tinker`, `test`) dies in `package:discover` with the self-reference error. Write the fixed base controller (and any new middleware) by hand first, then run `composer dump-autoload`. The children's constructors are usually uniform empty shells (`__construct() { parent::__construct(); }`, sometimes with a blank line). After confirming none has parameters or other statements, a single `perl -0pi` multi-line substitution over `grep -rl 'parent::__construct' app/Http/Controllers` removes them all. In zsh, pipe the list through `xargs` (`grep -rl … | xargs perl -0pi -e '…'`), because zsh does not word-split an unquoted `$files` and perl gets one long filename. Shift also leaves unused `use Illuminate\Routing\Controllers\Middleware;` imports in every converted controller, and `pint --dirty` cleans them up.

**Quieter variant — the base keeps a public empty constructor.** Shift does not always emit the self-referencing base class above. It may instead leave `class Controller { public function __construct() {} }`: traits and inheritance stripped, but an empty **public** constructor retained. Nothing fatals, because the children's `parent::__construct()` still resolves — so this passes CI and ships silently. Shift flags it only in a PR comment ("the base `Controller` contained public methods which may be used as controller actions … mark your base controller as `abstract`"); the "public method" it means is that constructor. Finish it by making the base `abstract class Controller {}` **and** deleting the children's dead constructors **in the same change**. Removing the base constructor alone turns every `parent::__construct()` into `Error: Cannot call constructor` on every authed route; deleting only the children leaves a non-abstract base that Shift will flag again on the next run.

**Constructor-body variant: the base keeps its old constructor body.** Shift may remove the base's inheritance and traits but leave its constructor untouched, so it still calls `$this->middleware(function ($request, $next) { … view()->share(...) … })`. That method came from `Illuminate\Routing\Controller` and no longer exists, and the failure depends on the child:
- Children **without** their own constructor inherit the base one and return a 500 with `Call to undefined method App\Http\Controllers\XController::middleware()`.
- Children that `implements HasMiddleware` and call `parent::__construct()` do **not** fail. PHP sends `$this->middleware($closure)` to the child's own **static** `middleware()`, which ignores the argument and returns its array. The closure never runs, and the shared view data disappears with no error.

The fix is the same three edits made together: move the closure body into a `web`-group middleware (item 3), make the base `abstract class Controller {}`, and delete the children's constructors. A test on a `HasMiddleware` child (`assertViewHas('user', $member)`) catches the silent case. A test on a child without its own constructor catches the fatal one.

### Abandoned date packages block Carbon 3

`jenssegers/date` (and similar Carbon-2 wrappers) cap `nesbot/carbon` at `^2`, so `composer update` dies with a Carbon `2.x` vs `^3` conflict. The package is abandoned precisely because Carbon now localizes natively. Remove it and replace its localized `format()` calls with Carbon's `translatedFormat()` (respects the current app locale, same as the wrapper did):

```php
// before: Jenssegers Date facade
Date::parse($model->updated_at)->format('d F Y');   // "3 juin 2026" in fr
// after: native Carbon (the attribute is already a Carbon instance)
$model->updated_at->translatedFormat('d F Y');
```

When every call formats numerically (`Date::parse($x)->format('Y-m-d')`), leave the views as they are. Laravel's default aliases already map `Date` to `Illuminate\Support\Facades\Date`, so once the package's `'Date'` alias is removed, `Date::parse()` goes to Carbon 3. Only month or day *names* need `translatedFormat()`. Add a test that renders one of these dates, because these views are often not otherwise exercised.

Also remove the package's leftover registrations or the app won't boot: its facade alias in `config/app.php` and its service provider in `bootstrap/providers.php` (or `withProviders([...])` in `bootstrap/app.php`). The tell is `Class "Jenssegers\Date\DateServiceProvider" not found` during `package:discover`.

### `nunomaduro/larastan` is abandoned — rename to `larastan/larastan` v3

Larastan **v2 caps at `illuminate/* ^11`**, so `composer update` dies resolving `laravel/framework ^12` against `nunomaduro/larastan ^2.x`. The package was **renamed** — `nunomaduro/larastan` is abandoned in favor of `larastan/larastan`, and only **v3** supports Laravel 12. Two coupled edits:

1. In `composer.json`, replace `"nunomaduro/larastan": "^2.x"` with `"larastan/larastan": "^3.0"`.
2. In `phpstan.neon`, update the include path — the vendor dir changed with the package name:
   ```neon
   includes:
       - ./vendor/larastan/larastan/extension.neon   # was vendor/nunomaduro/larastan/...
   ```

Miss step 2 and PHPStan fails with `File '…/vendor/nunomaduro/larastan/extension.neon' does not exist`. (Larastan v3 also requires `phpstan/phpstan ^2.2`, which `composer update -W` pulls in automatically.)

### Pest 3 forces `psr/simple-cache ^3.0` — widen the root pin

The Laravel skeleton's root `composer.json` pins `"psr/simple-cache": "^2.0"`. Bumping `pestphp/pest` to `^3.0` pulls `pest-plugin-mutate`, which **requires `psr/simple-cache ^3.0`**, so `composer update` fails with a conflict on `psr/simple-cache`. The `^2.0` pin is an arbitrary skeleton default — every real consumer (`laravel/framework`, `maatwebsite/excel`, `phpoffice/phpspreadsheet`) accepts `^1.0|^2.0|^3.0`. Verify with `composer why psr/simple-cache`, then widen the root to `"psr/simple-cache": "^3.0"` and re-run with `composer update -W`.

### `laravel-lang/common` caps `illuminate/support` at `^11` via its publisher

Shift lists `laravel-lang/common` among the packages it **did not update**, so the project's old `^4.0` constraint survives into the v12 PR — and it blocks `composer update`. The chain: `laravel-lang/common ^4.0` requires `laravel-lang/publisher ^14.x`, which requires `illuminate/support ^8|^9|^10|^11` — no `^12`. The tell is a resolver error naming `laravel-lang/publisher` and `illuminate/support` (`laravel/framework replaces illuminate/support and thus cannot coexist`), **not** a direct mention of `laravel-lang/common`. Laravel 12 support landed in `laravel-lang/common ^6.0` (pulls `publisher ^16.5`, Testbench `^11`). Bump the constraint to `"laravel-lang/common": "^6.0"` and re-run with `composer update -W`. This is a dev-only i18n package, so the bump is low-risk; updating it to clear the conflict is within a Shift review's scope (Shift explicitly flagged it as un-updated).

### Shift bumps a package to a new major that *still* caps below the target Laravel

Distinct from the "packages Shift did **not** update" list: Shift **does** bump some packages by a major version, but the version it picks can *itself* still cap `illuminate/*` below the target — so its own bump doesn't clear the conflict, and the misleading part is that the constraint now looks freshly updated. Seen with `troccoli/blade-health-icons`: Shift rewrote `^2.0` → `^4.0`, but **v4.0.0 requires `illuminate/support ^10.0|^11.0`** — no `^12`. `composer update` then dies with `troccoli/blade-health-icons v4.0.0 requires illuminate/support ^10.0|^11.0 -> ... cannot coexist with laravel/framework[v12.x]`, naming the package Shift *just* bumped. Don't assume a Shift-bumped constraint actually supports the target — verify the **resolved** version's own `illuminate/*` requirement (`curl -s https://repo.packagist.org/p2/<vendor>/<pkg>.json | ...`, or `composer show <pkg> --all`). For this package the real L12 target is `^5.0` (`illuminate ^11|^12`); `^6.0` is `^12|^13` for the following L13 run. Pick the **lowest** major that includes the target so you don't drag in unrelated breaking changes — bumping straight to the newest can overshoot. This completes Shift's transformation (it flagged the dep), so it's expected review work, not an override.

### Stale facade aliases after a package major bump are usually dead config

A major bump can delete the class that a `config/app.php` alias names. For example, DomPDF v3 removed `Barryvdh\DomPDF\Facade` (it is now `Barryvdh\DomPDF\Facade\Pdf`), yet `'PDF' => Barryvdh\DomPDF\Facade::class` survives Shift. Before calling this a breakage, check the package's `composer.json` for `extra.laravel.aliases`. `RegisterFacades` merges package-discovered aliases **after** `app.aliases`, so a discovered alias with the same name wins and the stale entry is never read. Point the entry at the real class or delete it, and report the change as cleanup. To confirm, revert the entry and run a test that hits the facade: if it stays green, the entry was dead config.

### Shift rewrites VCS-fork constraints to a public stable version that can't resolve

When a project pins a package to a **fork branch** (e.g. `"gazsp/baum": "dev-l11-compatibility"` backed by a `repositories: [{type: vcs, url: github.com/you/baum}]` entry), Shift may rewrite the constraint to a public stable release like `"^2.0"`. That fails because the VCS fork is the **canonical higher-priority repo** and has no matching `2.0` tag — the tell is *"has higher repository priority. The packages from the higher priority repository do not match your constraint and are therefore not installable. That repository is canonical…"*. These forks typically follow a **per-version branch convention** (`l10-compatibility`, `l11-compatibility`, `l12-compatibility`, …). Check the fork for the matching branch — `git ls-remote --heads <fork-url>` — and point the constraint at `dev-l12-compatibility` rather than the public release. This is one of the rare cases where you *override* a Shift change; flag it to the user, since the fork pin is intentional.

**Even when the swap resolves cleanly, ask before dropping the fork.** Shift's rewrite is not always broken. If the package has a real Packagist release with a permissive constraint — `gazsp/baum` 2.0.2 requires `illuminate/support >=5.8`, which happily matches L12 — then removing the `repositories` entry lets `composer update` succeed and the whole test suite pass. It is still the wrong default: the fork was pinned deliberately, usually carries project-specific patches, and dropping it silently changes which code ships. Treat "you may need to remove the corresponding `repository` entry" in Shift's PR comment as a **question for the maintainer**, not an instruction — check whether the fork has an `l<N>-compatibility` branch for the target and prefer pinning to it. Green tests do not establish that the swap was the owner's intent.

**Stale-pin variant (quieter, and the more common one):** Shift **leaves these fork pins untouched** — they land on its "packages not updated by Shift" list — so whatever `dev-l<N>-compatibility` branch was pinned for the *previous* upgrade survives into the new PR and now lags the target. A repo pinned to `dev-l11-compatibility` (set during the L11 upgrade) comes back from an L12 Shift *still* on `dev-l11-compatibility`, so `composer update` resolves the fork's L11 branch, whose own `composer.json` requires `illuminate/* ^11` and conflicts with `^12`. There's no rewrite-to-stable tell — the constraint just looks plausibly current. On every Shift, grep `composer.json` for `dev-l<N>-compatibility` pins and confirm `<N>` matches the **target** version, not the previous one. Bump each to the target's branch (verify it exists first with `git ls-remote --heads`). Completing the bump is expected review work — Shift flagged these as un-updated, so it's not an override.

Read the pinned branch's own constraint before bumping: `gh api 'repos/<owner>/<repo>/contents/composer.json?ref=<branch>' --jq .content | base64 -d`. Some forks widen the existing branch instead of cutting a new one. For example, an `l11-compatibility` branch that requires `illuminate/* ^11|^12|^13` already resolves on L12, so when the fork has no `l12-compatibility` branch, keep that pin.

**`dev-master`/`dev-main` pins backed by a `repositories` VCS entry are not candidates for a "swap `dev-*` for a stable release" pass.** Shift-review workflows tell you to replace `dev-*` constraints with a Packagist stable release when one exists. For a package whose source is the project's own VCS fork, that swap either fails to resolve, because the canonical fork has no matching tag, or quietly drops the fork's patches. Match each `dev-*` package's name against the `repositories` URLs first, and skip any that come from a fork. Then read the pinned branch's own constraint. An open-ended one (`illuminate/support >=5.5`) already resolves on L12, so leave the pin alone, even if the fork has a newer `l<N>-compatibility` branch for a *later* target (e.g. `l13-compatibility` with no `l12`). Moving to that branch early drags in a later major's changes.

## High Impact Changes

### Dependency Versions

Update these in `composer.json`:

| Package | New Version |
|---|---|
| `laravel/framework` | `^12.0` |
| `phpunit/phpunit` | `^11.0` |

PHPUnit 11 deprecates doc-comment metadata (`/** @test */`), and PHPUnit 12 removes it. Name the tests you write during the review `test_*` (or use `#[Test]`), even when the other tests in the file still use `/** @test */`. Leave converting the existing tests to the PHPUnit 11 Shift that the PR suggests.
| `pestphp/pest` | `^3.0` |

### Carbon 3 Now Required

Carbon 2.x support has been removed. Laravel 12 requires Carbon 3.x. Key differences:
- `diffIn*` methods return floats and can be negative (indicating time direction)
- Cast or use `abs()` where needed:

```php
// Carbon 2 (Laravel 10/11): always positive int
$days = $start->diffInDays($end); // 5

// Carbon 3 (Laravel 12): float, can be negative
$days = (int) abs($start->diffInDays($end)); // 5
```

### Update the Laravel Installer

```shell
composer global update laravel/installer
```

Or re-run `php.new` installation for your OS if using that approach.

## Medium Impact Changes

### Models and UUIDv7

The `HasUuids` trait now generates UUIDv7 (ordered) instead of UUIDv4. This is a behavioral change — existing UUIDv4 IDs in the database are fine, but new IDs will be v7 format.

**To keep UUIDv4 behavior:**
```php
use Illuminate\Database\Eloquent\Concerns\HasUuids; // [remove]
use Illuminate\Database\Eloquent\Concerns\HasVersion4Uuids as HasUuids; // [add]
```

**If using `HasVersion7Uuids`:** remove it and use `HasUuids` instead — it now provides the same v7 behavior.

## Low Impact Changes

### Container Dependency Resolution

The DI container now respects default values of constructor parameters instead of resolving them:

```php
class Example
{
    public function __construct(public ?Carbon $date = null) {}
}

$example = resolve(Example::class);

// v11: $example->date instanceof Carbon (container resolved it)
// v12: $example->date === null (default value respected)
```

If you rely on the container auto-resolving nullable parameters, explicitly bind or remove the default value.

### Image Validation Excludes SVGs

The `image` validation rule no longer accepts SVGs by default.

**v11:** SVGs pass `image` validation
**v12:** SVGs rejected unless explicitly allowed:

```php
use Illuminate\Validation\Rules\File;

'photo' => 'required|image:allow_svg'
// Or:
'photo' => ['required', File::image(allowSvg: true)],
```

**Scope is narrower than it looks — don't blindly add `:allow_svg` everywhere.** This only affects a literal Laravel `image` / `File::image()` validation rule. It does **not** affect Filament's `FileUpload->image()`, Spatie MediaLibrary uploads (`SpatieMediaLibraryFileUpload`, `addMedia()`, `getFirstMediaUrl()`), or any non-validation use of the word "image" (collection names, enum cases returning `.svg` filenames, `<img>` output). Shift's "Automate more with AI" comment flags every file *mentioning* image/svg — a broad keyword match that is mostly false positives. Before editing, `grep` for actual `'image'`/`File::image(` rules inside FormRequests and `->rules([...])`; if there are none, there is nothing to change. When rules *do* exist, let the stored data decide rather than guessing: `SELECT collection_name, mime_type, COUNT(*) FROM media GROUP BY 1,2` (or the app's own uploads table). No `image/svg+xml` rows means SVG was never accepted in practice, so leaving the rules untouched preserves real behavior and `:allow_svg` would *widen* it.

### Local Query Scopes → `#[Scope]` Attribute

Shift rewrites local scopes from the `scope`-prefix convention to the v12 `#[Scope]` attribute. This is a **behavior-preserving modernization, not a breaking change** — the old prefix style still works in v12, and call sites are identical (`Model::query()->hasMatching()` either way). Don't treat it as suspicious in a Shift PR, and don't revert it.

```php
use Illuminate\Database\Eloquent\Attributes\Scope;

// v11
public function scopeHasMatching(Builder $query): Builder { /* ... */ }

// v12 (Shift rewrite): scope prefix dropped, method becomes protected
#[Scope]
protected function hasMatching(Builder $query): Builder { /* ... */ }
```

### Local Filesystem Disk Default Root

`Storage::disk('local')` now defaults to `storage/app/private` instead of `storage/app`. To restore old behavior, explicitly define the `local` disk in `config/filesystems.php`:

```php
'local' => [
    'driver' => 'local',
    'root' => storage_path('app'),
],
```

### Multi-Schema Database Inspecting

`Schema::getTables()`, `Schema::getViews()`, and `Schema::getTypes()` now return results from all schemas by default. Filter with the `schema` argument:

```php
$tables = Schema::getTables(schema: 'main');
```

`Schema::getTableListing()` now returns schema-qualified names:
```php
Schema::getTableListing();
// ['main.migrations', 'main.users'] instead of ['migrations', 'users']

Schema::getTableListing(schema: 'main', schemaQualified: false);
// ['migrations', 'users']
```

### Concurrency Result Index Mapping

`Concurrency::run()` with an associative array now preserves keys in results:

```php
$result = Concurrency::run([
    'task-1' => fn () => 1 + 1,
    'task-2' => fn () => 2 + 2,
]);
// v11: [2, 4]
// v12: ['task-1' => 2, 'task-2' => 4]
```

### Nested Array Request Merging

`$request->mergeIfMissing()` now supports dot notation for nested data:
```php
$request->mergeIfMissing(['user.last_name' => 'Otwell']);
// v11: creates key literally named 'user.last_name'
// v12: merges into nested array $request->input('user.last_name')
```

### Route Precedence

When multiple routes share the same name, uncached routing now matches the **first** registered route (consistent with cached routing). Previously uncached matched the last one.

### Database Constructor Signatures (Package Maintainers)

`Blueprint`, `Grammar`, and related classes now require a `Connection` instance in their constructors. `Grammar::setConnection()` and `Connection::withTablePrefix()` are removed:

```php
// v11
$grammar = new MySqlGrammar;
$grammar->setConnection($connection);

// v12
$grammar = new MySqlGrammar($connection);
```

Use `$connection->getTablePrefix()` instead of `$grammar->getTablePrefix()`.

### DatabaseTokenRepository Expires in Seconds

The `$expires` parameter is now in seconds, not minutes.

## Quick Checklist

When upgrading or porting v11 code to v12+:

1. Update `laravel/framework` to `^12.0`, `phpunit/phpunit` to `^11.0`, `pestphp/pest` to `^3.0`
2. Ensure Carbon 3 compatibility — check `diffIn*` usages for float/negative returns
3. Check models using `HasUuids` — switch to `HasVersion4Uuids` if v4 UUIDs needed
4. Remove `HasVersion7Uuids` usage — replace with `HasUuids`
5. Check `image` validation rules — add `:allow_svg` if SVGs should be accepted
6. Check `Storage::disk('local')` usage — root changed from `storage/app` to `storage/app/private`
7. Check `Concurrency::run()` with associative arrays — results now keyed
8. Check `mergeIfMissing()` with dot-notation keys — now treated as nested paths
9. Check nullable constructor parameters with defaults — container respects defaults now
10. Check named route precedence — first match wins, not last
