---
name: upgrade-laravel-13
description: Upgrade Laravel v12 code to v13+. Use this skill whenever upgrading a Laravel project from v12 to v13, when copying code or examples from a Laravel 10, 11, or 12 project into a Laravel 13 or newer project, when encountering deprecated Laravel 12 patterns, when referencing old Laravel 12 tutorials or documentation, or when adapting v12-era code snippets found online. Also activate when you see Laravel 12 patterns like `VerifyCsrfToken` or `ValidateCsrfToken` middleware references, `$event->exceptionOccurred` on JobAttempted events, `$event->connection` on QueueBusy events, `pagination::default` view names, cache configs without `serializable_classes`, or `intervention/image` v2 usage (`Image::` facade, `app('image')`). Trigger on any mention of "laravel 12", "laravel v12", "upgrade laravel", "migrate laravel 12", "convert laravel 12", "laravel 13 upgrade", or "upgrade to laravel 13".
---

# Upgrading Laravel v12 to v13+

This skill helps you convert Laravel v12 code to v13 and beyond. Whether you're running a full project upgrade, copying code from a v10/v11/v12 codebase, or adapting an older tutorial, apply these transformations.

For the complete official upgrade guide with all edge cases, read `references/upgrade-guide.md` in this skill's directory.

## ⚠️ Real-World Breakages After a Laravel Shift Run (read this first)

Not in the official upgrade guide. Laravel Shift **streamlines/removes config files** (`config/app.php`, `auth.php`, `cache.php`, …) and relies on env vars + framework-default config merging. Any setting that was hardcoded now silently falls back to the new framework **default** unless an env var supplies it. Each major-version Shift pushes a different default into env, so re-check this on every upgrade.

**Diagnostic tell:** *many* feature tests fail at once, each rendering a generic error page (`<!DOCTYPE html><html lang="...">`) that masks a 500 — or pages show **untranslated keys** instead of text. Don't debug per-test: reproduce **one** request via `php artisan tinker --env=testing` (`app(Kernel::class)->handle($request)` with `Accept: application/json` to get the exception), and one root cause usually explains dozens of failures.

**First, rule out stale compiled artifacts — the cheapest cause of mass failure.** Compiled Blade views in `storage/framework/views` are cached from the *old* framework/package versions and keep old type-hints and namespaces (e.g. a compiled view typing a closure against `Filament\Tables\Actions\Action` while the upgraded code now passes `Filament\Actions\CreateAction`, throwing a `TypeError` deep inside a vendor view). Always run `php artisan view:clear && php artisan config:clear && php artisan route:clear && php artisan cache:clear` *before* triaging — in one real upgrade this single step took failures from **80 → 6**. Clear views again before each re-run while iterating.

**Verify these env vars in EVERY environment** — `.env`, `.env.testing`, **and** prod/staging/CI (these files are git-ignored, so Shift only updates `.env.example`):

- `CACHE_STORE` — defaults to `database` (needs a `cache` table); set `file`/`array` to match old behavior. Bouncer's `Bouncer::cache()` triggers `SQLSTATE … 'cache' doesn't exist`.
- `AUTH_MODEL` — defaults to `App\Models\User`; set `App\User` if the model is in the legacy location, else login 500s with `Class "App\Models\User" not found`.
- `APP_LOCALE` / `APP_FALLBACK_LOCALE` / `APP_FAKER_LOCALE` — default to `en` / `en_US`; non-English apps render translation **keys** instead of text.
- `BROADCAST_CONNECTION`, `DB_URL`, `SESSION_*`, `QUEUE_CONNECTION`, `MAIL_MAILER` — confirm against the values the old hardcoded config used.

Shift's PR comments list the exact env vars it detected ("set the following variables" comment) — that list is the authoritative starting point. Also audit `composer.json` for packages capping at `illuminate/* ^12` that block `composer update` (check Packagist for the lowest `^13`-compatible version; leave intentional `dev-*`/VCS-fork constraints as-is).

**Config-file streamlining can drop more than env defaults — watch `config/filesystems.php` visibility.** A common one: a `local`-driver disk that serves files at `/storage/...` via `'serve' => true` (the Laravel 11+ replacement for a symlinked `public` disk) needs an explicit `'visibility' => 'public'`. If Shift streamlines the file and drops it, the local driver defaults to **private**, creates `0700` directories, and Laravel's serve route returns **HTTP 403** for any served file — uploads save but won't display, with no error in the app. Diagnose with `curl -s -o /dev/null -w "%{http_code}" <file-url>` (403) and `stat` the directory (`drwx------`). Fix in the disk config:

```php
'local' => [
    'driver' => 'local',
    'root' => storage_path('app'),
    'visibility' => 'public', // <-- serve => true 403s without this
    'serve' => true,
    'throw' => false,
],
```

Repair already-uploaded files once with `Storage::disk('local')->setVisibility('<dir>', 'public')`. More broadly, diff every streamlined config file against your pre-upgrade version for silently dropped keys, not just env vars.

## High Impact Changes

### Dependency Versions

Update these in `composer.json`:

| Package | New Version |
|---|---|
| `laravel/framework` | `^13.0` |
| `laravel/boost` | `^2.0` |
| `laravel/tinker` | `^3.0` |
| `phpunit/phpunit` | `^12.0` |
| `pestphp/pest` | `^4.0` |

**Shift bumps Pest to `^4` but leaves `phpunit/phpunit` at `^11` — an unsatisfiable conflict that fails the first `composer update`.** Pest 4 requires `phpunit/phpunit ^12.x` (e.g. `pest v4.7.3` requires `^12.5.29`), so a `composer.json` still pinning `^11.5.3` errors with *"pestphp/pest ^4.0 ... requires phpunit/phpunit ^12.x ... but it conflicts with your root composer.json require (^11.5.3)"*. The table already lists `phpunit/phpunit ^12.0`; the gotcha is that **Shift won't make this edit for you** — it treats PHPUnit 12 as a separate optional Shift — so bump `phpunit/phpunit` to `^12.0` yourself before `composer update` will resolve. This is only the dependency-constraint bump; the PHPUnit 12 *code* transformations stay optional and the suite passes on `^12` without them (confirmed on a real 12→13 Shift: 259 tests green after the bump alone).

**The Pest↔PHPUnit conflict only exists when the project actually uses Pest. On a plain-PHPUnit project (no `pestphp/pest` in `composer.json`), Shift bumps nothing PHPUnit-related and leaves `phpunit/phpunit` at `^11` — and that is fine: `^11` resolves cleanly against Laravel 13 and the suite passes as-is, so no PHPUnit bump is required to complete the upgrade.** Confirmed on a real 12→13 Shift (PHPUnit-only project: `composer update` resolved with `phpunit ^11.5.3` untouched, 336 tests green). Shift still leaves an info comment *recommending* the free PHPUnit 12 Shift, and running on `^11` surfaces `WARN Metadata found in doc-comment ... deprecated ... in PHPUnit 12` warnings — both are advisory, not blockers. So don't reflexively bump PHPUnit to `^12` on every L13 upgrade; it's mandatory only to resolve the Pest conflict, optional otherwise.

If a dependency caps at `illuminate/* ^12` and blocks `composer update`, it must be upgraded before Laravel 13 can be installed. **Do NOT assume Filament v3 caps at Laravel 12 — verify the installed version's constraint first.** Filament **3.3.x added Laravel 13 support**: `filament/filament v3.3.54`'s `composer.json` declares `illuminate/support: ^10.45|^11.0|^12.0|^13.0`, so a project on `filament/filament ^3.3` installs cleanly on Laravel 13 with **no Filament upgrade needed** (confirmed on a real 12→13 Shift — Filament was left untouched and all panels worked). Only if `composer update` actually names Filament as the blocker (an older v3.0–v3.2 pin capping at `illuminate ^12`) should you act — first try raising the constraint to `^3.3`, and reach for the **`upgrade-filament-4` skill** (v3 → v4/v5) only if v3.3 still can't satisfy your other packages.

**Even when `filament/filament` correctly stays on v3, Shift over-bumps third-party Filament *plugins* to their next major — which usually requires Filament 4/5 — and that fails `composer update` on a project staying on Filament 3.** Shift prefers the highest version of each dependency, so a plugin that added L13 support only in a new major (built against Filament 4) gets bumped there, even though `filament/filament` itself stays at `^3.3`. The resolution error names Filament *sub-packages*, not the plugin you're debugging, so it's easy to misread — e.g. `filament/forms v4.x requires filament/actions v4.x`, or `filament/forms[v3.3.54, ..., v5.6.8] — only one can be installed`. Real cases on a 12→13 Shift with `filament/filament ^3.3` (user staying on Filament 3):

- `codewithdennis/filament-select-tree`: `^3.1` → `^4.0` (v4 requires `filament/forms ^4.0`). Corrected to **`^3.2`** — `v3.2.0` requires `filament/forms ^3.0` + `illuminate/contracts ^10|^11|^12|^13`, i.e. Filament 3 **and** Laravel 13. No fork needed.
- `saade/filament-fullcalendar`: Shift pinned it to an **ephemeral dependabot branch** (`dev-dependabot/github_actions/dependabot/fetch-metadata-3.1.0`) that actually requires `filament/filament ^4.0|^5.0`.

Fix: pin each over-bumped plugin back to its **latest Filament-3-compatible release that also supports L13**, not its new major. Verify a candidate's *two* constraints (Filament line **and** Laravel line) straight from Packagist before pinning — a version can satisfy one and not the other:

```bash
curl -s https://repo.packagist.org/p2/<vendor>/<pkg>.json | python3 -c "
import json,sys
for v in json.load(sys.stdin)['packages']['<vendor>/<pkg>']:
    r=v.get('require',{})
    print(v['version'], '| filament=', r.get('filament/forms') or r.get('filament/filament','?'),
          '| illuminate=', r.get('illuminate/contracts') or r.get('illuminate/support','?'))"
```

**Two sub-traps here worth their own note.** (1) **Shift may pin a package to an ephemeral dependabot branch** when that's the only ref its resolver finds with L13 support. Dependabot branches are deleted when their PR merges/closes, so the pin can vanish out from under you — and the branch usually belongs to the *next* major line, silently dragging in Filament 4/5. Never trust a Shift-picked `dev-*` branch blind; inspect what it actually requires (`composer show <pkg> <branch>`, or the Packagist `~dev.json` feed) before running `composer update`. (2) **When NO release of a Filament-3 plugin supports L13 + Filament 3 together, fork it and widen only the Laravel constraint.** Some maintainers never back-ported L13 to their v3 line and jumped straight to a Filament-4 v4 — so v3.x caps at `illuminate ^12` while every L13-capable ref needs Filament 4/5. If you're staying on Filament 3, fork the package, branch off its latest v3, and change one line: widen `illuminate/contracts` (or `illuminate/support`) to add `^13.0`, keeping `filament/filament ^3.0`. Filament 3 already runs on L13, so a Filament-3 plugin needs **no code changes** — this is a pure constraint widening, unlike the boot-fix forks elsewhere in this guide. Add a `vcs` `repositories` entry and pin `dev-<branch>`. Real case: `saade/filament-fullcalendar` → forked to a `3.x-laravel13` branch whose only diff from upstream `3.x` is `illuminate/contracts: ^10.0|^11.0|^12.0|^13.0`; `composer update` then resolved with `filament/filament` still at `3.3.54` and all panels working.

**Remove any temporary `config.audit.ignore` entry once the upgrade pulls the patched version.** A project stuck on an old line often carries a `composer.json` `config.audit.ignore` for an advisory it couldn't yet patch (typically blocked on the very PHP/PHPUnit bump the upgrade performs). After Laravel 13 pulls the fixed version, that ignore is dead weight and hides future advisories on the same package — delete it, then re-run `composer audit` to confirm it's still clean without it. Real case: a `config.audit.ignore` for phpunit CVE-2026-24765 (affects `phpunit <12.5.8`), added while pinned to `phpunit ^11`, became obsolete once Pest 4 pulled `phpunit 12.5.30` — removed, and `composer audit` reported "No security vulnerability advisories found."

### CSRF Middleware Renamed — Request Forgery Protection

The CSRF middleware has been renamed from `VerifyCsrfToken` to `PreventRequestForgery` and now includes `Sec-Fetch-Site` header verification for origin checking. The old names remain as deprecated aliases, but update all direct references:

```php
// v12
use Illuminate\Foundation\Http\Middleware\VerifyCsrfToken;
->withoutMiddleware([VerifyCsrfToken::class]);

// v13
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;
->withoutMiddleware([PreventRequestForgery::class]);
```

The middleware configuration API now provides `preventRequestForgery(...)`.

### Update the Laravel Installer

```shell
composer global update laravel/installer
```

## Medium Impact Changes

### Cache `serializable_classes` Configuration

The v13 default cache config includes a `serializable_classes` option set to `false`. This prevents PHP deserialization attacks if `APP_KEY` is leaked. If your app stores PHP objects in cache, explicitly allow-list the classes:

```php
'serializable_classes' => [
    App\Data\CachedDashboardStats::class,
    App\Support\CachedPricingSnapshot::class,
],
```

Without this, unserializing cached objects will fail. Migrate to arrays or add explicit allow-lists.

**Whether this bites depends entirely on whether `config/cache.php` exists with the key set — so check the file directly, never infer it.** Resolution: `CacheManager::getSerializableClasses()` returns `config('cache.serializable_classes') ?? null`, and every store guards with `if ($this->serializableClasses !== null)` (e.g. `FileStore::unserialize`) before falling through to a plain, unrestricted `unserialize()`. So when the key is absent → `null` → **not restricted**, and cached Eloquent models/collections round-trip fine. When it is published as `false` → **all classes blocked** → breakage.

**A Laravel Shift run *often* publishes the v13 `config/cache.php` with `serializable_classes => false` — but NOT always.** Seen in the wild: a fully Shift-upgraded project (its upgrade branch merged) with **no `config/cache.php` at all**, hence safe. So "Shift ran" does not imply "restrictive config present." Conversely, on a project that previously had *no* `config/cache.php` (streamlined away by an earlier Shift), the 12→13 Shift **created a brand-new minimal `config/cache.php` containing only `'serializable_classes' => false`** — so the restrictive value can appear even where the file didn't exist before. Don't assume in either direction — verify with one command:

```bash
ls config/cache.php                          # absent → key is null → unrestricted → safe
grep serializable_classes config/cache.php   # present → read the actual value (false / [] / allow-list)
```

If the file is absent the regression cannot bite today, but it is **latent**: a later `php artisan config:publish cache` (or a future Shift) would publish the restrictive default and break every object-caching path at once. Guard against that with a committable test (below) rather than relying on the file staying absent.

**Diagnostic symptom (real upgrade):** a `TypeError` on the **second and later** requests only (first request warms the cache and works), e.g. `Argument #1 ($items) must be of type Illuminate\Support\Collection, __PHP_Incomplete_Class given`, surfacing wherever the cached value is type-hinted — commonly a view composer, middleware, or service that does `Cache::remember(...)` returning a Collection/model. The query log shows a `select * from cache where key in (...)` right before the error.

**The test suite will NOT catch this.** Tests run with `CACHE_STORE=array`, and the array store is configured `'serialize' => false`, so nothing is ever unserialized — `Cache::remember()` returns the live in-memory value. The bug only appears with a serializing store (`database`, `file`, `redis`) in the browser. So green tests are no proof here; verify against the real store.

**Verify empirically.** The trap is `Cache::remember()`: in a *single* process it returns the live computed value without unserializing, so it always passes regardless of config. Two ways to force a real `serialize → unserialize` round-trip:

```bash
# Cross-process via tinker — write in one process, read in a separate one:
php artisan tinker --execute 'Cache::put("diag", \App\Models\Foo::query()->limit(2)->get());'
php artisan tinker --execute '$v = Cache::get("diag"); echo get_class($v), PHP_EOL; $v->first()->id;'  # __PHP_Incomplete_Class shows here
```

You do **not** actually need two processes if you bypass `remember()`: an explicit `Cache::store('file')->put($k, $models)` then `->get($k)` round-trips in a *single* process, because `FileStore` has no in-memory layer — `get()` always reads from disk and unserializes (`FileStore::getPayload`). That is what makes this committable as a CI guard test, the durable equivalent of the two-tinker diagnostic:

```php
// tests/Feature/CacheModelSerializationTest.php — passes today (null → unrestricted),
// fails the moment a restrictive config/cache.php is published.
$store = Cache::store('file');                 // a serializing store, unlike the test-default array store
$store->put($key, $modelsWithRelations, 60);
$retrieved = $store->get($key);                // __PHP_Incomplete_Class here if allow-list is missing a class
$store->forget($key);
$this->assertInstanceOf(\Illuminate\Database\Eloquent\Collection::class, $retrieved);
```

Note: the test suite's default `array` store is `'serialize' => false`, so you must request a serializing store (`file`) explicitly — a test left on the default store will pass even when production is broken.

**The allow-list must contain EVERY class in the serialized object graph — including non-obvious custom collection types.** A missing nested class still yields `__PHP_Incomplete_Class`. Gotchas seen in the wild:

- **Models whose trait overrides `newCollection()` return a custom collection class, not the base one.** `staudenmeir/laravel-adjacency-list`'s `HasRecursiveRelationships` makes `Model::get()` return `Staudenmeir\LaravelAdjacencyList\Eloquent\Collection` — so allow-listing `Illuminate\Database\Eloquent\Collection` is *not* enough. The round-trip above prints the actual runtime class to add.
- **Eager-loaded relations add their own collection + model classes** (e.g. a `Page` collection with a loaded `studies` relation needs `Illuminate\Database\Eloquent\Collection` for the relation *plus* `App\Models\Study`).
- **Enum-cast attributes do NOT need listing.** They're stored as raw scalars in `$attributes` and cast on access, so the enum class never appears in the serialized payload.
- **Packages cache objects too — grepping your own `Cache::` calls is not enough.** `silber/bouncer` with `Bouncer::cache()` enabled (common in `AppServiceProvider`) caches each user's roles lookup *forever* as `['ids' => Support\Collection, 'names' => Support\Collection]` (`CachedClipboard::getRolesLookup()` → `sear()`); abilities are stored as plain arrays. So a Bouncer app on a serializing store needs `Illuminate\Support\Collection::class` in the allow-list even if the app itself caches no collections — otherwise every authorization check after the first request breaks. Test it with `app(\Silber\Bouncer\Clipboard::class)->getRolesLookup($user)` round-tripped through `Cache::store('file')`.

Example resolved allow-list from a real upgrade (Eloquent collection of `Page` models with a `studies` relation, plus `pluck()` Support collections elsewhere):

```php
'serializable_classes' => [
    Illuminate\Support\Collection::class,
    Illuminate\Database\Eloquent\Collection::class,
    Staudenmeir\LaravelAdjacencyList\Eloquent\Collection::class, // custom newCollection()
    App\Models\Page::class,
    App\Models\Study::class,
],
```

After fixing, run `php artisan cache:clear` in **every** serializing environment (prod/staging) on deploy so pre-fix entries don't linger until they expire.

### Harden Public (Unauthenticated) Livewire / Filament Components Against Property Tampering

**Applies when the project uses Livewire OR Filament (Filament panels run on Livewire) AND has components reachable without authentication** — public search bars, contact/newsletter forms, filters, public-facing Filament pages, anything rendered on a guest-accessible route. Skip components that sit entirely behind `auth` middleware: they're not a meaningful target. This isn't a v12→v13 API change, but an upgrade is the natural time to fix it because it's the same class of latent production breakage as the cache trap above — invisible in tests, triggered only by real traffic (here, bots).

**Root cause.** Every **public** property on a Livewire component is round-tripped to the browser and is **writable by the client** through Livewire's `updates` channel. Bots fuzz these endpoints and send junk values for properties the developer only ever sets server-side. Two distinct failures result:

1. **Exception-report noise.** Tamper attempts throw `Livewire\Mechanisms\HandleComponents\CorruptComponentPayloadException` (checksum mismatch) and `Livewire\Features\SupportLockedProperties\CannotUpdateLockedPropertyException` (writing a `#[Locked]` prop). Both already render as a **419** (their `render()` is gated on `app.debug`), so the HTTP side is fine — but they're still **reported** to your bug tracker (Flare/Sentry/Bugsnag), burying real errors under bot noise.
2. **View fatals.** A property the server fills with objects (e.g. a results collection of Eloquent models) gets overwritten by the client with an arbitrary type — typically an array of ints. The Blade view then fatals dereferencing `->name` / `->display_name` on an `int`. This is an *unhandled* 500, reported and user-visible.

**Fix 1 — stop reporting the tamper exceptions** (`bootstrap/app.php`, inside the existing `->withExceptions(...)` closure; merge, don't overwrite). These are expected adversarial traffic, not bugs:

```php
->withExceptions(function (Exceptions $exceptions) {
    $exceptions->dontReport([
        \Livewire\Mechanisms\HandleComponents\CorruptComponentPayloadException::class,
        \Livewire\Features\SupportLockedProperties\CannotUpdateLockedPropertyException::class,
    ]);
})
```

This only suppresses **reporting** — the 419 render behaviour is untouched. Do **not** add `ErrorException` or any broad class here; that would hide real bugs.

**Fix 2 — make only genuine user input client-writable.** Audit each public component and reclassify every public property:

- **Input the user actually types/selects** (the search term, the filter value) → stays a plain public property. This is the *only* category the client may write.
- **State derived from that input** (search results, computed lists/totals) → must NOT be a stored public property. Convert it to a `#[Livewire\Attributes\Computed]` method named after the property; reference it as `$this->results` in PHP and `$this->results` in Blade (it's no longer a bare `$results` variable). A computed prop isn't round-tripped, so the client can't set it — an attempt throws `Livewire\Exceptions\PublicPropertyNotFoundException` instead of corrupting view data.
- **Server-only UI state** (a highlighted-index, a current-step counter the server alone advances) → keep it public if Blade needs it, but mark it `#[Livewire\Attributes\Locked]` so the client can't write it.

```php
use Livewire\Attributes\Computed;
use Livewire\Attributes\Locked;

class PathologySearch extends Component
{
    public $search = '';            // user input — the ONLY client-writable property

    #[Locked]
    public $highlightIndex = -1;    // server-only UI state — client must never set it

    #[Computed]
    public function results()       // derived from $search; not stored, not client-writable
    {
        if (strlen(trim($this->search)) < 2) {
            return collect();
        }

        return Model::search(trim($this->search));
    }
}
```

Converting a stored property to computed also lets you delete the `mount()`/`updatedSearch()` plumbing that recomputed it on every change — the computed method derives it on each render automatically.

**Filament specifics.** Public Filament pages (custom `Page` classes, public forms) are Livewire components, so the same rules apply to their public properties. Filament form-state properties bound to fields are legitimately client-writable (that's the form), but any property you set in `mount()`/hooks and never expose as a field should be `#[Locked]`; derived display data should be computed or a method, not a stored public property.

**Verify with tests** (these pass against the hardened code and would have failed before):

```php
use Livewire\Exceptions\PublicPropertyNotFoundException;
use Livewire\Features\SupportLockedProperties\CannotUpdateLockedPropertyException;

it('rejects client writes to the locked index', function () {
    livewire(PathologySearch::class)->set('highlightIndex', 5);
})->throws(CannotUpdateLockedPropertyException::class);

it('does not expose derived results as a client-writable property', function () {
    livewire(PathologySearch::class)->set('results', [1, 2, 3]);
})->throws(PublicPropertyNotFoundException::class);
```

Note the second exception lives at `Livewire\Exceptions\PublicPropertyNotFoundException` (not under `Mechanisms\...`). The test suite's default `array` driver doesn't matter here — this is request-layer behaviour, so a normal `livewire()` test exercises it directly.

To find candidate components, grep the public route surface: `php artisan route:list --except-vendor` for guest-accessible routes, then `grep -rl "extends Component" app/Livewire` and check each for public properties that are assigned server-side rather than typed by the user.

### spatie/laravel-permission v7.4+ Fatally Collides With Jetstream's `HasTeams`

**Applies to any app using `spatie/laravel-permission` alongside `laravel/jetstream`** — an extremely common pairing, and one Shift will walk into because it bumps laravel-permission as part of the L13 dependency sweep.

`spatie/laravel-permission` **7.4.0** added a `teams()` method to the `HasRoles` trait (for relation introspection; when the teams feature is disabled it returns an empty `BelongsToMany`). Jetstream's `HasTeams` trait has defined `teams()` all along. PHP does not resolve trait method collisions silently — it is a **compile-time fatal** the moment the model class loads:

```
Trait method Laravel\Jetstream\HasTeams::teams has not been applied as App\Models\User::teams,
because of collision with Spatie\Permission\Traits\HasRoles::teams
```

Because it fires at class load, *everything* touching `User` dies at once — login, every authenticated route, tinker, even `php artisan` commands that resolve the model. The stack trace points at your `User` class declaration, not at either package, which makes it read like an application bug.

**Two traps worth calling out.** (1) It arrived in a **minor** release (7.4.0), not in the 6 to 7 major, so it is in no upgrade guide and will hit apps already on `^7.0` at an unrelated `composer update` — check by version, not by whether you crossed the major:

```bash
composer show spatie/laravel-permission | grep versions
grep -c 'function teams' vendor/spatie/laravel-permission/src/Traits/HasRoles.php  # 1 = affected
```

(2) It bites **even when both teams features are disabled** (`// Features::teams()` commented out in `config/jetstream.php`, no `teams` key in `config/permission.php`). The collision is structural — PHP does not care that neither method would ever be called.

Fix with an explicit `insteadof` in the model. Pick the winner by which one your code actually calls — Jetstream's, if you have the standard `app/Actions/Jetstream` scaffolding (`DeleteUser` calls `$user->teams()->detach()`):

```php
class User extends Authenticatable
{
    use HasProfilePhoto;
    use HasRoles, HasTeams {
        HasTeams::teams insteadof HasRoles;
    }
    use Notifiable;
}
```

Add `HasRoles::teams as permissionTeams;` inside the same block only if you actually enable spatie's teams feature; otherwise the alias is dead weight. Note that the combined `use HasRoles, HasTeams { ... }` replaces the two separate `use` statements — a conflict-resolution block can only reference traits imported in the same `use`.

### spatie/laravel-csp v2 to v3 Silently *Enforces* a Policy You Never Wrote

**Applies whenever Shift bumps `spatie/laravel-csp` from `^2` to `^3`** (it does, as part of the L13 sweep). v3 renamed the whole configuration surface:

| v2 | v3 |
|---|---|
| `'policy' => SomePolicy::class` (one class) | `'presets' => [SomePreset::class]` (array) |
| `'report_only_policy' => ...` | `'report_only_presets' => [...]` |
| `class X extends Spatie\Csp\Policies\Policy` | `class X implements Spatie\Csp\Preset` |
| `public function configure(): void` plus `$this->addDirective(...)` | `public function configure(Policy $policy): void` plus `$policy->add(...)` |

**There is no error, no deprecation, and no fatal — and that is the whole problem.** The package registers its config with `hasConfigFile()` (spatie/laravel-package-tools), which is a shallow `array_merge`. Your surviving v2 `config/csp.php` has no `presets` key, so the **package default fills it in** — `[Spatie\Csp\Presets\Basic::class]` — while your `report_only_presets` defaults to `[]`. Net effect on a project that was deliberately running report-only:

- `Content-Security-Policy-Report-Only` — **gone**
- `Content-Security-Policy` — **now present and enforcing**, carrying `Basic`'s strict `'self'`-only policy plus script/style nonces
- Your own policy class — **never loaded at all**, so every host you had whitelisted (CDNs, Google Fonts/Maps, tenant subdomains) is now blocked in real browsers

So a change intended as a version bump silently flips a report-only rollout into an enforced policy that is simultaneously stricter than intended and not the one you wrote. Verified directly — with a leftover v2 config in place:

```
csp.presets             = ["Spatie\Csp\Presets\Basic"]
csp.report_only_presets = []
Content-Security-Policy = base-uri 'self';connect-src 'self';default-src 'self';font-src 'self';…
Content-Security-Policy-Report-Only = ABSENT
```

Migration is mechanical — the directive/keyword enums (`Spatie\Csp\Directive`, `Spatie\Csp\Keyword`) are unchanged, so only the class signature and the method name move:

```php
// v2
use Spatie\Csp\Policies\Policy;

class AppPolicy extends Policy
{
    public function configure(): void
    {
        $this->addDirective(Directive::DEFAULT, Keyword::SELF)
            ->addDirective(Directive::SCRIPT, [Keyword::SELF, 'cdn.jsdelivr.net']);
    }
}

// v3
use Spatie\Csp\Policy;
use Spatie\Csp\Preset;

class AppPreset implements Preset
{
    public function configure(Policy $policy): void
    {
        $policy->add(Directive::DEFAULT, Keyword::SELF)
            ->add(Directive::SCRIPT, [Keyword::SELF, 'cdn.jsdelivr.net']);
    }
}
```

Rename the class too: `Policy` is now a *different* v3 concept (the builder handed to `configure()`), so leaving a `Preset` implementation called `AppPolicy` is actively misleading. An env-driven enforce toggle carries over as:

```php
'presets' => env('CSP_ENFORCE', false) ? [App\Support\Csp\AppPreset::class] : [],
'report_only_presets' => env('CSP_ENFORCE', false) ? [] : [App\Support\Csp\AppPreset::class],
```

Also re-declare `nonce_enabled` explicitly: its package default flipped from `false` (v2) to `true` (v3), and enabling nonces voids any `'unsafe-inline'` you depend on. `Spatie\Csp\AddCspHeaders` keeps its namespace, so middleware registration in `bootstrap/app.php` needs no change. Assert **both** modes in a test — a report-only-only test still passes while enforcement is silently on:

```php
$response->assertHeaderMissing('Content-Security-Policy');
$this->assertNotNull($response->headers->get('Content-Security-Policy-Report-Only'));
```

### Laravel's First-Party `Image` Component Hijacks Intervention Image v2's `image` Binding

**Applies to any app still on `intervention/image` v2 (`^2.x`)**, whether it uses the `Image::` facade, `Intervention\Image\Facades\Image`, or `app('image')`. Shift does not bump or flag Intervention, so this survives the upgrade without any error and only fails at runtime, often on a route with no test coverage (an `<img src="/chart?...">` endpoint is typical).

Laravel 13 ships `Illuminate\Image` (present in 13.33.0). It registers a **deferred** `Illuminate\Image\ImageServiceProvider` that binds the container key `image`, the same key Intervention v2's auto-discovered provider uses. Deferred providers load the first time their key is resolved and overwrite the existing binding. So `app('image')` now returns `Illuminate\Image\ImageManager`, and **Intervention's own v2 facade resolves to it too** (both facades proxy `image`). Laravel's manager then builds an Intervention **v4** manager and fails:

```
Call to undefined method Intervention\Image\ImageManager::usingDriver()
  at Illuminate/Image/Drivers/GdDriver.php
```

The stack trace goes `Facade::__callStatic` → `Manager::driver()` → `Illuminate\Image\...`, which points to the framework rather than your call site. Upgrading Intervention doesn't fix this either: Laravel's `Image` API only transforms existing images (`fromPath`/`fromBytes`/`fromUpload`/…) and has no `canvas()` or drawing methods. Code that draws onto a blank canvas has to keep using Intervention directly.

Detect it:

```bash
composer show intervention/image | grep versions          # 2.x = affected
grep -rn "use Image;\|Image::\|app('image')\|Intervention\\\\Image\\\\Facades" app/ routes/ resources/views/
php artisan tinker --execute 'echo get_class(app("image"));'   # Illuminate\Image\ImageManager = hijacked
```

Fix by bypassing the container. Instantiate Intervention v2's manager directly (no dependency change):

```php
use Intervention\Image\ImageManager;

$img = (new ImageManager(['driver' => 'gd']))->canvas(500, 20, '#fff');
// v2 drawing API (rectangle/circle/line/encode) is unchanged
```

Add a feature test that hits each image-producing route and asserts `Content-Type: image/png` plus the `"\x89PNG"` body signature. Without one, the breakage only shows up in production error tracking.

### toin0u/geocoder-laravel 5.x to 13.x Drops the Curl Adapter Your Published Config Still Names

**Applies whenever Shift bumps `toin0u/geocoder-laravel` from `^5` to `^13`** and the project has a published `config/geocoder.php`. Shift does this as part of the L13 sweep and lists it under "updated by a major version". There are no 6.x through 12.x releases; the package jumped to match the Laravel version.

13.x removed `php-http/curl-client` from its dependencies and changed the default adapter to `Geocoder\Laravel\Http\LaravelHttpClient`, a PSR-18 client built on Laravel's `Http` facade. A published v5 config still contains `use Http\Client\Curl\Client;` and `'adapter' => Client::class`. `composer update` removes the curl client, so every geocode call fails at runtime:

```
Target class [Http\Client\Curl\Client] does not exist.
```

**The test suite usually won't catch it.** The common test pattern mocks the facade (`Geocoder::shouldReceive('geocode')`), which never resolves the adapter. On a real 12→13 upgrade the suite was fully green, and the failure only showed up in `migrate:fresh --seed`: a seeder created models whose save listener geocoded the address. In production this breaks every geocode, for example the queued listener that fills lat/lng.

Fix it by editing the published config. The package README recommends this, and it keeps local customizations such as a `'fr'` GoogleMaps locale:

```php
use Geocoder\Laravel\Http\LaravelHttpClient;   // was: use Http\Client\Curl\Client;

'adapter' => LaravelHttpClient::class,          // was: Client::class
```

Alternatively, `composer require php-http/curl-client` keeps the old adapter. Run `php artisan cache:clear` on deploy, as the package advises after a major upgrade.

Add a regression test that goes through the real provider chain. Because the adapter now uses Laravel's `Http`, `Http::fake()` intercepts it. Set an API key in the test, because GoogleMaps is skipped without one:

```php
config(['geocoder.providers' => [Chain::class => [GoogleMaps::class => ['fr', 'test-api-key'], GeoPlugin::class => []]]]);
Http::fake(['maps.googleapis.com/*' => Http::response(['status' => 'OK', 'results' => [[
    'address_components' => [], 'formatted_address' => '…', 'place_id' => 'x', 'types' => ['street_address'],
    'geometry' => ['location' => ['lat' => 48.88564, 'lng' => 2.3213588], 'location_type' => 'ROOFTOP'],
]]])]);
$coordinates = Infectiologist::requestCoordinates('60, rue la condamine, 75017 Paris');
$this->assertSame(48.88564, $coordinates['lat']);
```

This test fails with the old config and passes with the fix.

**Side effect for the `serializable_classes` check:** geocoder 13.x has a `cache.auto_register_serializable_classes` option (default `true`). At boot it merges every Geocoder model class into `cache.serializable_classes`. So `config('cache.serializable_classes')` can return an array of `Geocoder\Model\*` classes plus `Illuminate\Support\Collection` even when `config/cache.php` says `false`. That's expected. Read the file to see what your app configured, and read the runtime value to see what is actually allowed.

**General lesson for any package Shift bumps by a major version:** diff each published `config/<package>.php` against the new `vendor/<pkg>/config/<package>.php`. A published config freezes the old defaults, including class names that the new version may no longer install.

## Low Impact Changes

### Cache Prefixes and Session Cookie Names (the session cookie can end up *malformed*, not just changed)

Default prefixes changed from underscores to hyphens, and the session cookie switched from `Str::slug($name, '_')` to `Str::snake()`:

```php
// v12: laravel_cache_, laravel_database_, laravel_session
// v13: laravel-cache-, laravel-database-, laravel_session (snake)
```

If you define these explicitly you're unaffected; if you rely on defaults, set `CACHE_PREFIX`, `REDIS_PREFIX`, and `SESSION_COOKIE` in `.env`.

**But `Str::snake()` is not a slug function, and for any `APP_NAME` that isn't plain ASCII words it produces an invalid cookie name — sessions break outright rather than merely resetting.** `Str::slug()` (v12) stripped accents and punctuation; `Str::snake()` only inserts underscores before capitals and lowercases, passing everything else through untouched. Real case on a French app:

```php
$name = "ACME : réseaux d'investigateurs";
Str::slug($name, '_').'_session';  // v12: acme_reseaux_dinvestigateurs_session
Str::snake($name).'_session';      // v13: a_c_m_e:_réseaux_d'investigateurs_session
```

Note both the run of single letters (`ACME` becomes `a_c_m_e`, since every character is a capital) and the retained `:`, `'` and `é` — RFC 6265 forbids all three in a cookie name. So the failure mode is not "users get logged out once", it's "the session cookie is rejected."

**Check the computed values rather than eyeballing `APP_NAME`** — one command, after `config:clear`:

```bash
php artisan tinker --execute '
echo "cache : ", config("cache.prefix"), PHP_EOL;
echo "redis : ", config("database.redis.options.prefix"), PHP_EOL;
echo "cookie: ", config("session.cookie"), PHP_EOL;'
```

To preserve pre-upgrade behavior exactly, pin all three to the v12-derived values in **every** environment (`.env`, `.env.testing`, prod/staging/CI — and `.env.example`, the only one Shift touches):

```dotenv
CACHE_PREFIX=acme_reseaux_dinvestigateurs_cache_
REDIS_PREFIX=acme_reseaux_dinvestigateurs_database_
SESSION_COOKIE=acme_reseaux_dinvestigateurs_session
```

A single accented character is enough to trigger it — a second real case: `APP_NAME="XYZ Paris Université"` → v13 cookie `x_y_z_paris_université_session` (v12: `xyz_paris_universite_session`). Derive the pinned values **per environment** with `Str::slug(config('app.name'), '_')`: `.env.testing` often has a different `APP_NAME` (here `"XYZ Paris"` → `xyz_paris_*`), so copying the `.env` values into it would silently change its prefixes.

### Shift PR Comments That Are Often No-Ops (verify, don't blindly act)

Some Shift 12→13 comments are broad heuristics. Check each before spending time on it:

- **"Republish Horizon assets."** Recent Horizon 5.x no longer publishes assets: `php artisan horizon:publish` just prints `Horizon no longer publishes its assets`, and the dashboard layout inlines them via `Horizon::css()` / `Horizon::js()`. Any committed `public/vendor/horizon/` directory is dead weight now. Flag it for deletion to the user rather than trying to regenerate it.
- **"Faker modifiers which received arguments"** (`optional(0.7)`, `unique(true)`…). Shift lists every file that uses a modifier with arguments, not every file that has a problem. Only chained *property* access (`->optional(0.7)->word`) needs converting. Grep with `grep -nE "(unique|optional|valid)\([^)]*\)->[a-zA-Z_]+[^(a-zA-Z_]"` — files whose chains already end in `()` need nothing.
- **"Boot methods found … wrap in `whenBooted`."** Shift flags every model with a `boot()` method. Registering event listeners (`static::creating(fn …)`) during boot is fine; only `observe()` or anything that instantiates the model (see *Model Booting* below) needs changing.

### Container::call and Nullable Class Defaults

Extends the v12 behavior to method injection — `Container::call` now respects nullable defaults:

```php
$container->call(function (?Carbon $date = null) {
    return $date;
});
// v12: Carbon instance
// v13: null
```

### JobAttempted Event Exception Payload

`$event->exceptionOccurred` (boolean) replaced by `$event->exception` (exception object or `null`):

```php
// v12
if ($event->exceptionOccurred) { ... }

// v13
if ($event->exception) { ... }
// Now you can also inspect: $event->exception->getMessage()
```

### QueueBusy Event Property Rename

`$event->connection` renamed to `$event->connectionName`:

```php
// v12: $event->connection
// v13: $event->connectionName
```

### Pagination Bootstrap View Names

```
// v12: pagination::default, pagination::simple-default
// v13: pagination::bootstrap-3, pagination::simple-bootstrap-3
```

### MySQL DELETE with JOIN, ORDER BY, LIMIT

Laravel now includes `ORDER BY` and `LIMIT` clauses in `DELETE ... JOIN` queries for MySQL. Previously these were silently ignored. Some MySQL/MariaDB versions may throw `QueryException` for this syntax.

### Polymorphic Pivot Table Name Generation

Inferred table names for polymorphic pivots with custom pivot classes are now pluralized. Explicitly define `$table` on your pivot model if you depended on singular names.

### Collection Model Serialization

Eager-loaded relations are now restored when Eloquent collections are deserialized (e.g., in queued jobs). Adjust if you depended on relations being absent after deserialization.

### Domain Route Registration Precedence

Routes with explicit domains are now prioritized before non-domain routes. Review route matching if you relied on registration order between domain and non-domain routes.

### Manager `extend` Callback Binding

Custom driver closures registered via `extend()` are now bound to the manager instance. If you used `$this` referring to another object (e.g., service provider), capture values via `use (...)` instead.

### Str Factories Reset Between Tests

Custom `Str` UUID/ULID/random factories are reset during test teardown. Set them in each test or `setUp()` if needed.

### Js::from Uses Unescaped Unicode

`Js::from` now uses `JSON_UNESCAPED_UNICODE`. Update test expectations if they depended on escaped sequences like `\u00e8`.

### Model Booting and Nested Instantiation

Creating model instances inside `boot()` or `boot*()` methods now throws `LogicException` (`The [bootIfNotBooted] method may not be called on model [...] while it is being booted`). Move that logic outside the boot cycle.

**Common real-world trigger: `static::observe()` inside a trait's `boot*()` method.** `Model::observe()` runs `$instance = new static;`, so calling it during boot instantiates the model mid-boot and throws. This frequently lives in third-party/forked packages (e.g. `nanigans/single-table-inheritance`'s `bootSingleTableInheritanceTrait()`). Register the observer's events directly instead so no instance is created during boot:

```php
// Breaks in v13 — instantiates the model during boot
static::observe(new MyObserver());

// Works — registers the event closures without "new static"
$observer = new MyObserver();
static::saving(fn ($model) => $observer->saving($model));
```

**`observe()` is not the only trigger — any `new static()` reached *from* `boot()` throws, even indirectly through a static helper.** Seen in the wild on a 12→13 upgrade: `gazsp/baum`'s `Node::boot()` calls `static::softDeletesEnabled()` to decide whether to register `restoring`/`restored` listeners, and that helper was implemented as `with(new static())->areSoftDeletesEnabled()` — instantiating the model mid-boot. The diagnostic is identical (`bootIfNotBooted ... may not be called on model [App\Models\Page] while it is being booted`), but grepping the model's own `boot()` for `observe`/`new static` finds nothing because the instantiation is one call deep in the parent/base class. When you see this error, trace **every static call** made inside `boot()` into its definition, not just the literal statements in the boot body. The fix is to answer the question statically instead of via an instance:

```php
// Breaks in v13 — new static() during boot, just to read a global scope
public static function softDeletesEnabled()
{
    return with(new static())->areSoftDeletesEnabled();
}

// Works — hasGlobalScope() is static and needs no instance
public static function softDeletesEnabled()
{
    return static::hasGlobalScope(SoftDeletingScope::class);
}
```

When upgrading a project that pins forked packages (VCS repos in `composer.json` with `dev-*` constraints), audit **every** fork's trait/base-class `boot*()` methods for this pattern — not just the ones whose constraint version you bumped. Forks left on `dev-master` are easy to miss.

**A `dev-lXX-compatibility` fork branch existing does NOT mean it's fully patched — verify by actually booting the models.** On the same upgrade the user maintained per-version fork branches (`dev-l13-compatibility`) for several packages. The `single-table-inheritance` l13 branch had correctly converted its `observe()` to direct `static::saving()` registration; the `baum` l13 branch had *not* fixed its boot-time `new static()`. Same naming convention, different completeness. The test suite won't tell you at `composer update` time — the `LogicException` only fires when a model that extends the broken base is first booted, which on this project happened during **`migrate:fresh --seed`**, not during any test's setup. So run the seeders / touch each affected model after the upgrade; don't trust a branch name. The fix belongs in the fork repo (vendor edits get overwritten by `composer install`), so patch the fork's branch and `composer update <pkg>` to pull it.

**Shift may rewrite a VCS-fork `dev-*` constraint into an unsatisfiable Packagist semver.** Shift bumped `gazsp/baum` from `dev-l12-compatibility` to `^2.0`. But the project declares `gazsp/baum` via a `vcs` repository (a personal fork), which is *canonical* and shadows Packagist — and the fork publishes only `dev-*` branches and `1.x` tags, no `2.0`. Result: `composer update` fails with *"the lower priority repo's packages are not installable"* even though `gazsp/baum 2.0.2` exists on Packagist. When a Shift-bumped package is backed by a `vcs` repo entry, the right constraint is almost always that fork's matching `dev-lXX-compatibility` branch, not a Packagist version — check the `repositories` block before trusting Shift's semver bump.

**Don't follow Shift's advice to remove the `repository` entry without checking first.** Shift's dependency comment lists the package under "swapped from a compatibility branch to a stable release" and suggests removing its `repository` entry so Packagist can serve it. Before doing that, compare the Packagist release with the fork. `gazsp/baum 2.0.2` on Packagist is a different codebase from the `l13-compatibility` fork: its `src/` layout differs and it doesn't contain the fork's L13 boot fix in `Extensions/Eloquent/Model::softDeletesEnabled()`. Dropping the fork would have swapped the nested-set library underneath the app. Pin the fork's `dev-l13-compatibility` branch instead (confirmed: `composer update` resolved and the seeders booted every Baum model).

**A VCS fork pinned to `dev-master` (not a version branch) may gain a fresh `dev-lXX-compatibility` branch for the target version — switch to it, don't just bump the forks already on `dev-lNN`.** Shift leaves *all* `dev-*` VCS-fork constraints untouched, so the manual step is yours: for each fork, `git ls-remote --heads <fork-url>` and look for a branch matching the version you're upgrading to. On a real 12→13 upgrade the project had 5 forks — three on `dev-l12-compatibility` (bumped to `dev-l13-compatibility` as expected) **plus one pinned to `dev-master` that had newly published a `dev-l13-compatibility` branch carrying the L13 boot-time `observe()` fix** (`nanigans/single-table-inheritance`); switching its `dev-master` pin to `dev-l13-compatibility` is what actually pulled the fix. The fifth fork had only a `master` branch, so it correctly stayed `dev-master`. Takeaway: a `dev-master` pin is not automatically "already current" — enumerate branches on every fork, because the compat branch you need may not exist under the naming pattern of the *other* forks. After switching, confirm each resolved to the intended branch with `composer show <pkg> | grep versions` (e.g. `* dev-l13-compatibility`), and boot the models (`migrate:fresh --seed`) to prove the branch is actually patched.

### Attribute-Based Model & Controller Configuration (Shift rewrites these)

Laravel 13 adds attribute equivalents for common model/controller properties, and Laravel Shift **automatically rewrites existing code to use them**. They are behavior-preserving — don't be alarmed (or revert them) when reviewing a Shift diff that touches every model:

- Models (from `Illuminate\Database\Eloquent\Attributes\*`): `protected $guarded = []` → `#[Unguarded]`; `$fillable` → `#[Fillable('a', 'b')]`; `$hidden` → `#[Hidden('password', 'remember_token')]`; `$touches` → `#[Touches('parent')]`; `$primaryKey` / `$incrementing` → `#[Table(key: 'uuid', incrementing: false)]`.
- Controllers (from `Illuminate\Routing\Attributes\Controllers\Authorize`): `Gate::authorize('view', $page)` → a method-level `#[Authorize('view', 'page')]`.
- More model attributes: `public $timestamps = false` → `#[WithoutTimestamps]`; `$appends` → `#[Appends('x')]`; `protected $table = 'x'` → `#[Table('x')]`.
- Controller middleware: `implements HasMiddleware` + `public static function middleware(): array { return ['auth']; }` → class-level `#[Middleware('auth')]`. A `new Middleware('guest', except: ['logout'])` becomes `#[Middleware('guest', except: ['logout'])]`, and the `HasMiddleware` interface is removed.
- Console commands: `protected $signature` / `$description` → `#[Signature('api:save')]` / `#[Description('…')]` (from `Illuminate\Console\Attributes\*`).

These are valid v13 idioms; the only thing to verify is that the attribute arguments match the original property values.

**Child models inherit these attributes.** PHP's reflection doesn't inherit attributes, but Laravel's resolution walks up to the parent class. This matters for single-table-inheritance parents (`nanigans/single-table-inheritance`): when Shift moves the parent's `$table` / `$fillable` / `$appends` into attributes, the child models still resolve to the parent's table. Verified on a real upgrade: `FormElement` got `#[Table('form_elements')]`, and its subclasses (`Questionnaire`, `Checkboxquestion`, …) still returned `getTable() === 'form_elements'` with the inherited fillable and appends. To check quickly: `php artisan tinker --execute 'echo (new App\Models\Child)->getTable();'`.

### Auth Notification Email Subjects (renamed translation keys — breaks JSON translations silently)

Two built-in auth notification subjects were renamed in v13:

- `ResetPassword`: subject `"Reset Password Notification"` → `"Reset your password"`
- `VerifyEmail`: subject `"Verify Email Address"` → `"Verify your email address"` (the old string is still used for the action **button**, so it remains in the file — only the subject key is new)

Because these are `Lang::get()` keys, any non-English app translating them via JSON files (`lang/fr.json` etc.) **silently falls back to English subjects** after the upgrade: nothing errors, the old keys still sit in the file looking correct, and tests using `Notification::fake()` never render the mail so they stay green. Found in the wild on a real 10→13 upgrade review — the only miss in an otherwise complete Shift upgrade.

Fix: add the two new keys to every `lang/*.json`, keep `"Verify Email Address"` (still the button label), and drop the now-unused `"Reset Password Notification"`. To catch regressions, assert the rendered subject rather than faking:

```php
test('reset password email subject is translated', function () {
    app()->setLocale('fr');
    $mail = (new ResetPassword('token'))->toMail($user);
    expect($mail->subject)->toBe('Réinitialisation de votre mot de passe');
});
```

### Contract Additions (Very Low Impact)

New methods added to contracts — only affects custom implementations:
- `Dispatcher`: `dispatchAfterResponse()`
- `ResponseFactory`: `eventStream()`
- `MustVerifyEmail`: `markEmailAsUnverified()`
- `Cache\Store`: `touch($key, $seconds)`
- `Queue\Queue`: `pendingSize()`, `delayedSize()`, `reservedSize()`, `creationTimeOfOldestPendingJob()`

## Quick Checklist

When upgrading or porting v12 code to v13+:

1. Update `laravel/framework` to `^13.0`, `pestphp/pest` to `^4.0`, `phpunit/phpunit` to `^12.0`, `laravel/tinker` to `^3.0`. Shift bumps Pest to `^4` but leaves `phpunit/phpunit` at `^11` → first `composer update` fails on the Pest↔PHPUnit conflict; bump PHPUnit to `^12.0` yourself. **This only applies when Pest is present — a plain-PHPUnit project keeps `phpunit ^11`, which resolves and passes on L13 with no bump needed (deprecation warnings are advisory).** Don't assume Filament v3 blocks L13 — v3.3.x supports it (`illuminate/support` allows `^13.0`), so verify the actual `composer update` error before touching Filament. Separately, if staying on Filament 3, expect Shift to over-bump third-party Filament *plugins* to their Filament-4 majors (e.g. `codewithdennis/filament-select-tree ^3.1`→`^4.0`) — the resolution error names `filament/forms`/`filament/actions` v4, not the plugin; pin each back to its latest v3 release that also lists `illuminate ^13`, and fork + widen the Laravel constraint for any plugin with no such release (e.g. `saade/filament-fullcalendar`). Also watch for Shift pinning a package to an ephemeral `dev-dependabot/*` branch, and drop any now-obsolete `config.audit.ignore` once the patched version is pulled.
2. Replace `VerifyCsrfToken` / `ValidateCsrfToken` with `PreventRequestForgery`
3. Check whether `config/cache.php` exists and sets `serializable_classes` (`ls config/cache.php`) — Shift sometimes publishes it as `false`, sometimes leaves it absent, so verify the file, don't assume from the fact Shift ran. If absent it's safe today but latent; if set and you cache objects, allow-list every class in the graph — verify with a round-trip against a serializing store (a `Cache::store('file')` put/get test or two-process tinker), not the test suite's `array` store. Include objects cached by packages (e.g. `Bouncer::cache()` stores roles as `Support\Collection`s)
4. Replace `$event->exceptionOccurred` with `$event->exception` in JobAttempted listeners
5. Replace `$event->connection` with `$event->connectionName` in QueueBusy listeners
6. Update `pagination::default` references to `pagination::bootstrap-3`
7. Check the *computed* cache prefix / session cookie, don't just confirm they're unset (`php artisan tinker --execute 'echo config("session.cookie");'`) — v13's `Str::snake()` mangles any non-plain-ASCII `APP_NAME` into an RFC-6265-invalid cookie name (`"ACME : réseaux d'investigateurs"` becomes `a_c_m_e:_réseaux_d'investigateurs_session`), which rejects sessions outright rather than just resetting them. Pin `CACHE_PREFIX`, `REDIS_PREFIX`, `SESSION_COOKIE` in every environment, deriving each environment's values from its own `APP_NAME`
8. Check `Container::call` with nullable class parameters
9. Review MySQL DELETE+JOIN queries with ORDER BY / LIMIT
10. Check polymorphic pivot table names if using custom pivot classes
11. Ensure model `boot()` methods don't instantiate the model itself — including indirectly via a static helper reached from `boot()` (e.g. a `new static()` inside a base class like Baum's `softDeletesEnabled()`); boot at least one model of each base class (running the seeders is a good forcing function) since this `LogicException` won't surface at `composer update` time. For VCS-forked packages, verify the `dev-lXX-compatibility` branch is actually patched, and check the `repositories` block before trusting a Shift semver bump on a forked package (a `vcs` repo is canonical and shadows Packagist). Shift leaves *all* `dev-*` fork pins untouched, so `git ls-remote --heads` every fork and switch to its target-version compat branch — including forks pinned to `dev-master`, which may have newly published a `dev-lXX-compatibility` branch (that's where the L13 boot fix landed for `single-table-inheritance`); a `dev-master` pin is not automatically current
12. Update test assertions for the renamed auth email subjects if needed — and if the app has JSON translation files (`lang/*.json`), add the new `"Reset your password"` / `"Verify your email address"` keys (grep for the old `"Reset Password Notification"` key to find affected files)
13. If the app uses Livewire or Filament AND has components on unauthenticated routes, harden them against property tampering: `dontReport` the two Livewire tamper exceptions in `bootstrap/app.php`, convert server-derived public properties to `#[Computed]`, and mark server-only UI state `#[Locked]` so `$search`-style user input is the only client-writable property (skip components fully behind `auth`)
14. If the app pairs `spatie/laravel-permission` with `laravel/jetstream`, check whether laravel-permission resolved to **7.4.0 or later** (`grep -c 'function teams' vendor/spatie/laravel-permission/src/Traits/HasRoles.php`) — 7.4.0 added `HasRoles::teams()`, a compile-time fatal collision with Jetstream's `HasTeams::teams()` that kills every code path touching `User`. It arrived in a *minor* release and fires even when both teams features are disabled. Fix with `HasTeams::teams insteadof HasRoles;` in a combined `use HasRoles, HasTeams { ... }` block
15. If Shift bumped `spatie/laravel-csp` from `^2` to `^3`, migrate `config/csp.php` to the `presets` / `report_only_presets` keys and convert the policy class from `extends Spatie\Csp\Policies\Policy` to `implements Spatie\Csp\Preset` (`configure(Policy $policy)`, `$policy->add(...)`). A leftover v2 config throws no error — it shallow-merges to the package's default `Basic` preset and silently starts **enforcing** `Content-Security-Policy` while your report-only header and your own whitelist disappear. Re-declare `nonce_enabled` (default flipped `false` to `true`) and assert both header modes in a test
16. If `intervention/image` is still v2, grep for `Image::`, `use Image;`, `app('image')` and `Intervention\Image\Facades\Image`. Laravel 13's deferred `Illuminate\Image\ImageServiceProvider` overwrites the `image` binding, so every one of those now resolves to Laravel's manager and fails with `Call to undefined method Intervention\Image\ImageManager::usingDriver()`. Replace them with `new Intervention\Image\ImageManager(['driver' => 'gd'])` and cover each image route with a test that asserts a PNG response
17. For every package Shift bumped by a major version (listed in its dependency comment), diff the published `config/<pkg>.php` against the new vendor default. In particular, `toin0u/geocoder-laravel` 5 to 13 removed `php-http/curl-client`, so a published config with `'adapter' => Http\Client\Curl\Client::class` fails at runtime with `Target class [Http\Client\Curl\Client] does not exist`. Switch to `Geocoder\Laravel\Http\LaravelHttpClient`. Facade-mocking tests won't catch it, but `migrate:fresh --seed` or an `Http::fake()` test through the real provider chain will
