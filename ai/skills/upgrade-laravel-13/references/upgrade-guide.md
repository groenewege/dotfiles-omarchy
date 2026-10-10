# Laravel 13.x Upgrade Guide — From 12.x

This is the complete official upgrade guide for reference.

## Upgrading Using AI

You can automate the upgrade using Laravel Boost (`^2.0`). Use the `/upgrade-laravel-v13` slash command in Claude Code, Cursor, OpenCode, Gemini, or VS Code.

## High Impact Changes

### Updating Dependencies

**Likelihood Of Impact: High**

Update in `composer.json`:

- `laravel/framework` to `^13.0`
- `laravel/boost` to `^2.0`
- `laravel/tinker` to `^3.0`
- `phpunit/phpunit` to `^12.0`
- `pestphp/pest` to `^4.0`

### Updating the Laravel Installer

```shell
composer global update laravel/installer
```

Or update Laravel Herd to latest release.

### Request Forgery Protection

**Likelihood Of Impact: High**

CSRF middleware renamed from `VerifyCsrfToken` to `PreventRequestForgery`. Now includes `Sec-Fetch-Site` header verification.

`VerifyCsrfToken` and `ValidateCsrfToken` remain as deprecated aliases.

```php
use Illuminate\Foundation\Http\Middleware\PreventRequestForgery;

// Replace VerifyCsrfToken::class with PreventRequestForgery::class
->withoutMiddleware([PreventRequestForgery::class]);
```

Middleware configuration API now provides `preventRequestForgery(...)`.

## Medium Impact Changes

### Cache `serializable_classes` Configuration

**Likelihood Of Impact: Medium**

Default cache config now includes `serializable_classes` set to `false`. Prevents PHP deserialization gadget chain attacks if `APP_KEY` is leaked.

If storing PHP objects in cache, explicitly allow-list classes:

```php
'serializable_classes' => [
    App\Data\CachedDashboardStats::class,
    App\Support\CachedPricingSnapshot::class,
],
```

Migrate to arrays or explicit allow-lists if previously unserializing arbitrary objects.

## Low Impact Changes

### Cache Prefixes and Session Cookie Names

**Likelihood Of Impact: Low**

Default prefixes changed:

```php
// Laravel <= 12.x
Str::slug((string) env('APP_NAME', 'laravel'), '_').'_cache_';
Str::slug((string) env('APP_NAME', 'laravel'), '_').'_database_';
Str::slug((string) env('APP_NAME', 'laravel'), '_').'_session';

// Laravel >= 13.x
Str::slug((string) env('APP_NAME', 'laravel')).'-cache-';
Str::slug((string) env('APP_NAME', 'laravel')).'-database-';
Str::snake((string) env('APP_NAME', 'laravel')).'_session';
```

Explicitly configure `CACHE_PREFIX`, `REDIS_PREFIX`, and `SESSION_COOKIE` to retain previous behavior.

### Store and Repository Contracts: `touch`

**Likelihood Of Impact: Very Low**

Cache contracts now include `touch` method:

```php
public function touch($key, $seconds);
```

### Container::call and Nullable Class Defaults

**Likelihood Of Impact: Low**

```php
$container->call(function (?Carbon $date = null) {
    return $date;
});
// <= 12.x: Carbon instance
// >= 13.x: null
```

### Dispatcher Contract: `dispatchAfterResponse`

**Likelihood Of Impact: Very Low**

New method: `dispatchAfterResponse($command, $handler = null)`

### ResponseFactory Contract: `eventStream`

**Likelihood Of Impact: Very Low**

New `eventStream` method signature added.

### MustVerifyEmail Contract: `markEmailAsUnverified`

**Likelihood Of Impact: Very Low**

New `markEmailAsUnverified()` method.

### MySQL DELETE Queries With JOIN, ORDER BY, and LIMIT

**Likelihood Of Impact: Low**

`ORDER BY` and `LIMIT` clauses are now included in `DELETE ... JOIN` queries. May throw `QueryException` on engines that don't support this syntax.

### Model Booting and Nested Instantiation

**Likelihood Of Impact: Very Low**

Creating model instances during `boot()` / `boot*()` now throws `LogicException`:

```php
protected static function boot()
{
    parent::boot();
    (new static())->getTable(); // No longer allowed
}
```

### Polymorphic Pivot Table Name Generation

**Likelihood Of Impact: Low**

Inferred names for morph pivot tables with custom pivot classes are now pluralized. Explicitly define `$table` on pivot model if needed.

### Collection Model Serialization Restores Eager-Loaded Relations

**Likelihood Of Impact: Low**

Eager-loaded relations now restored after serialization/deserialization of model collections.

### HTTP Client Response::throw and throwIf Signatures

**Likelihood Of Impact: Very Low**

```php
public function throw($callback = null);
public function throwIf($condition, $callback = null);
```

### Default Auth Notification Subjects

**Likelihood Of Impact: Very Low** (English apps) / **Medium** (apps with JSON translation overrides)

```
// ResetPassword subject
// <= 12.x: "Reset Password Notification"
// >= 13.x: "Reset your password"

// VerifyEmail subject
// <= 12.x: "Verify Email Address"   (still used as the action button label in 13.x)
// >= 13.x: "Verify your email address"
```

Apps translating these via `lang/*.json` silently fall back to English subjects until the new keys are added — `Notification::fake()`-based tests won't catch it because the mail is never rendered.

### Queued Notifications and Missing Models

**Likelihood Of Impact: Very Low**

Now respects `#[DeleteWhenMissingModels]` attribute and `$deleteWhenMissingModels` property.

### JobAttempted Event Exception Payload

**Likelihood Of Impact: Low**

```php
// <= 12.x: $event->exceptionOccurred (boolean)
// >= 13.x: $event->exception (Throwable|null)
```

### QueueBusy Event Property Rename

**Likelihood Of Impact: Low**

`$connection` renamed to `$connectionName`.

### Queue Contract Method Additions

**Likelihood Of Impact: Very Low**

New methods: `pendingSize`, `delayedSize`, `reservedSize`, `creationTimeOfOldestPendingJob`.

### Domain Route Registration Precedence

**Likelihood Of Impact: Low**

Routes with explicit domains now prioritized before non-domain routes.

### withScheduling Registration Timing

**Likelihood Of Impact: Very Low**

Schedules via `ApplicationBuilder::withScheduling()` now deferred until `Schedule` is resolved.

### Manager `extend` Callback Binding

**Likelihood Of Impact: Low**

Custom driver closures now bound to manager instance. Use `use (...)` to capture external values.

### Str Factories Reset Between Tests

**Likelihood Of Impact: Low**

Custom UUID/ULID/random factories reset during test teardown. Set in each test or `setUp()`.

### Js::from Uses Unescaped Unicode By Default

**Likelihood Of Impact: Very Low**

Uses `JSON_UNESCAPED_UNICODE`. Update test expectations for escaped sequences.

### Pagination Bootstrap View Names

**Likelihood Of Impact: Low**

```
// <= 12.x: pagination::default, pagination::simple-default
// >= 13.x: pagination::bootstrap-3, pagination::simple-bootstrap-3
```
