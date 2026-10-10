# Laravel 11.x Upgrade Guide — From 10.x

This is the complete official upgrade guide for reference.

## High Impact Changes

### Updating Dependencies

**PHP 8.2.0 Required**

Laravel now requires PHP 8.2.0 or greater.

**curl 7.34.0 Required**

Laravel's HTTP client now requires curl 7.34.0 or greater.

**Composer Dependencies**

Update the following in `composer.json`:

- `laravel/framework` to `^11.0`
- `nunomaduro/collision` to `^8.1`
- `laravel/breeze` to `^2.0` (If installed)
- `laravel/cashier` to `^15.0` (If installed)
- `laravel/dusk` to `^8.0` (If installed)
- `laravel/jetstream` to `^5.0` (If installed)
- `laravel/octane` to `^2.3` (If installed)
- `laravel/passport` to `^12.0` (If installed)
- `laravel/sanctum` to `^4.0` (If installed)
- `laravel/scout` to `^10.0` (If installed)
- `laravel/spark-stripe` to `^5.0` (If installed)
- `laravel/telescope` to `^5.0` (If installed)
- `livewire/livewire` to `^3.4` (If installed)
- `inertiajs/inertia-laravel` to `^1.0` (If installed)

Cashier Stripe, Passport, Sanctum, Spark Stripe, and Telescope **no longer automatically load migrations from their own migrations directory**. Publish their migrations:

```bash
php artisan vendor:publish --tag=cashier-migrations
php artisan vendor:publish --tag=passport-migrations
php artisan vendor:publish --tag=sanctum-migrations
php artisan vendor:publish --tag=spark-migrations
php artisan vendor:publish --tag=telescope-migrations
```

Remove `doctrine/dbal` if previously added — Laravel is no longer dependent on it.

### Application Structure

Laravel 11 introduces a new default application structure with fewer default files. However, Laravel 10 applications upgrading to Laravel 11 should **not** attempt to migrate their application structure — Laravel 11 supports the Laravel 10 structure.

### Floating-Point Types

**Likelihood Of Impact: High**

The `double` and `float` migration column types have been rewritten for cross-database consistency.

`double` now creates a `DOUBLE` column without total/places arguments:
```php
$table->double('amount');
```

`float` now accepts an optional `$precision` instead of `$total`/`$places`:
```php
$table->float('amount', precision: 53);
```

`unsignedDecimal`, `unsignedDouble`, and `unsignedFloat` are removed. Use `->unsigned()`:
```php
$table->decimal('amount', total: 8, places: 2)->unsigned();
$table->double('amount')->unsigned();
$table->float('amount', precision: 53)->unsigned();
```

### Modifying Columns

**Likelihood Of Impact: High**

When modifying a column with `->change()`, you must explicitly include all modifiers you want to keep. Missing attributes will be dropped.

v10 behavior — attributes preserved:
```php
$table->integer('votes')->nullable()->change();
```

v11 behavior — must re-state all:
```php
$table->integer('votes')
    ->unsigned()
    ->default(1)
    ->comment('The vote count')
    ->nullable()
    ->change();
```

Index modifiers can be used to add/drop indexes:
```php
$table->bigIncrements('id')->primary()->change();
$table->char('postal_code', 10)->unique(false)->change();
```

Alternative: squash migrations with `php artisan schema:dump`.

### SQLite Minimum Version

SQLite 3.26.0 or greater is required.

### Updating Sanctum

Update to `^4.0`. Publish migrations:
```bash
php artisan vendor:publish --tag=sanctum-migrations
```

Update `config/sanctum.php` middleware:
```php
'middleware' => [
    'authenticate_session' => Laravel\Sanctum\Http\Middleware\AuthenticateSession::class,
    'encrypt_cookies' => Illuminate\Cookie\Middleware\EncryptCookies::class,
    'validate_csrf_token' => Illuminate\Foundation\Http\Middleware\ValidateCsrfToken::class,
],
```

## Medium Impact Changes

### Carbon 3

Laravel 11 supports both Carbon 2 and Carbon 3. With Carbon 3, `diffIn*` methods return floating-point numbers and may return negative values to indicate time direction.

### Password Rehashing

Laravel 11 auto-rehashes passwords during authentication if the hashing algorithm's work factor has changed. If the password field isn't named `password`:
```php
protected $authPasswordName = 'custom_password_field';
```

Disable with `'rehash_on_login' => false` in `config/hashing.php`.

### Per-Second Rate Limiting

`GlobalLimit` and `Limit` constructors now accept seconds instead of minutes:
```php
new GlobalLimit($attempts, 2 * 60);
new Limit($key, $attempts, 2 * 60);
```

`decayMinutes` property renamed to `decaySeconds`.

`ThrottlesExceptions` and `ThrottlesExceptionsWithRedis` constructors also accept seconds:
```php
new ThrottlesExceptions($attempts, 2 * 60);
new ThrottlesExceptionsWithRedis($attempts, 2 * 60);
```

### Spatie Once Package

Laravel 11 has a built-in `once()` function. Remove `spatie/once` from `composer.json`.

## Low Impact Changes

### Doctrine DBAL Removal

All Doctrine DBAL classes and methods removed. Use native schema methods instead:
- `Schema::getTables()` (replaces `getAllTables()`)
- `Schema::getViews()` (replaces `getAllViews()`)
- `Schema::getTypes()` (replaces `getAllTypes()`)
- `Schema::getColumns()`
- `Schema::getIndexes()`
- `Schema::getForeignKeys()`

Remove `dbal.types` from database config if present.

### Eloquent Model `casts` Method

Base Eloquent model now defines a `casts()` method. Rename any relationship named `casts` to avoid conflict.

### Spatial Types

Specific spatial methods replaced with `geometry` and `geography`:
```php
$table->geometry('shapes');
$table->geography('coordinates');
$table->geometry('dimension', subtype: 'polygon', srid: 0);
$table->geography('latitude', subtype: 'point', srid: 4326);
```

`isGeometry` and `projection` PostgreSQL modifiers removed.

### The `Enumerable` Contract

`dump` method updated to accept variadic `...$args`:
```php
public function dump(...$args);
```

### The `UserProvider` Contract

New `rehashPasswordIfRequired` method:
```php
public function rehashPasswordIfRequired(Authenticatable $user, array $credentials, bool $force = false);
```

### The `Authenticatable` Contract

New `getAuthPasswordName` method:
```php
public function getAuthPasswordName()
{
    return 'password';
}
```

### AuthenticationException Class

`redirectTo` method now requires a `Request` instance:
```php
$path = $e->redirectTo($request);
```

### Cache Key Prefixes

DynamoDB, Memcached, and Redis cache stores no longer auto-append `:` to prefix.

### Database Connection Interface

New `scalar` method:
```php
public function scalar($query, $bindings = [], $useReadPdo = true);
```

### Mailer Contract

New `sendNow` method:
```php
public function sendNow($mailable, array $data = [], $callback = null);
```

### Publishing Service Providers

Use `ServiceProvider::addProviderToBootstrapFile(Provider::class)` for v11+ apps.

### BatchRepository Interface

New `rollBack` method:
```php
public function rollBack();
```

### Synchronous Jobs in Database Transactions

Synchronous queue jobs now respect `after_commit` configuration.

### MariaDB Dedicated Driver

Optional: use `'driver' => 'mariadb'` for MariaDB-specific features. Note: `uuid` creates native UUID columns (not `char(36)`).

### Passport

Update to `^12.0`. Password grant type disabled by default:
```php
public function boot(): void
{
    Passport::enablePasswordGrant();
}
```

### Telescope

Update to `^5.0`. Publish migrations:
```bash
php artisan vendor:publish --tag=telescope-migrations
```

### Cashier Stripe

Update to `^15.0`. Publish migrations:
```bash
php artisan vendor:publish --tag=cashier-migrations
```

### Spark Stripe

Update to `^5.0`. Publish migrations:
```bash
php artisan vendor:publish --tag=spark-migrations
```
