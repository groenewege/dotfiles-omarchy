# Laravel 12.x Upgrade Guide — From 11.x

This is the complete official upgrade guide for reference.

## High Impact Changes

### Updating Dependencies

**Likelihood Of Impact: High**

Update in `composer.json`:

- `laravel/framework` to `^12.0`
- `phpunit/phpunit` to `^11.0`
- `pestphp/pest` to `^3.0`

#### Carbon 3

**Likelihood Of Impact: Low**

Support for Carbon 2.x has been removed. All Laravel 12 applications now require Carbon 3.x. Key changes:
- `diffIn*` methods return floating-point numbers
- `diffIn*` methods may return negative values to indicate time direction
- See Carbon 3 migration guide: https://carbon.nesbot.com/guide/getting-started/migration.html

### Updating the Laravel Installer

Update via Composer:
```shell
composer global update laravel/installer
```

Or re-run php.new for your OS:
```shell
# macOS
/bin/bash -c "$(curl -fsSL https://php.new/install/mac/8.4)"

# Linux
/bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.4)"

# Windows PowerShell (run as administrator)
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://php.new/install/windows/8.4'))
```

Or update Laravel Herd to latest release.

## Medium Impact Changes

### Models and UUIDv7

**Likelihood Of Impact: Medium**

`HasUuids` trait now generates UUIDv7 (ordered). To keep UUIDv4:
```php
use Illuminate\Database\Eloquent\Concerns\HasVersion4Uuids as HasUuids;
```

`HasVersion7Uuids` trait removed — use `HasUuids` instead (same behavior now).

## Low Impact Changes

### Concurrency Result Index Mapping

**Likelihood Of Impact: Low**

`Concurrency::run` with associative array now returns results with their associated keys:
```php
$result = Concurrency::run([
    'task-1' => fn () => 1 + 1,
    'task-2' => fn () => 2 + 2,
]);
// ['task-1' => 2, 'task-2' => 4]
```

### Container Class Dependency Resolution

**Likelihood Of Impact: Low**

Container now respects default values:
```php
class Example
{
    public function __construct(public ?Carbon $date = null) {}
}

$example = resolve(Example::class);
// <= 11.x: $example->date instanceof Carbon
// >= 12.x: $example->date === null
```

### Image Validation Now Excludes SVGs

**Likelihood Of Impact: Low**

```php
use Illuminate\Validation\Rules\File;

'photo' => 'required|image:allow_svg'
// Or:
'photo' => ['required', File::image(allowSvg: true)],
```

### Local Filesystem Disk Default Root Path

**Likelihood Of Impact: Low**

`Storage::disk('local')` now defaults root to `storage/app/private` instead of `storage/app`. Define `local` disk manually to restore old behavior.

### Multi-Schema Database Inspecting

**Likelihood Of Impact: Low**

`Schema::getTables()`, `Schema::getViews()`, `Schema::getTypes()` now include all schemas by default:
```php
$tables = Schema::getTables();                          // all schemas
$tables = Schema::getTables(schema: 'main');            // specific schema
$tables = Schema::getTables(schema: ['main', 'blog']);  // multiple schemas
```

`Schema::getTableListing()` returns schema-qualified names:
```php
Schema::getTableListing();
// ['main.migrations', 'main.users', 'blog.posts']

Schema::getTableListing(schema: 'main', schemaQualified: false);
// ['migrations', 'users']
```

### Nested Array Request Merging

**Likelihood Of Impact: Low**

`$request->mergeIfMissing()` now supports dot notation for nested data:
```php
$request->mergeIfMissing(['user.last_name' => 'Otwell']);
```

### Route Precedence

**Likelihood Of Impact: Low**

Uncached routing now matches first registered route with a given name (consistent with cached routing).

### Authentication

#### DatabaseTokenRepository Constructor

**Likelihood Of Impact: Very Low**

`$expires` parameter now in seconds, not minutes.

### Database Constructor Signature Changes

**Likelihood Of Impact: Very Low**

Primarily for package maintainers.

`Blueprint` constructor requires `Connection` as first argument.

`Grammar` constructor requires `Connection`. `setConnection()` removed:
```php
// <= 11.x
$grammar = new MySqlGrammar;
$grammar->setConnection($connection);

// >= 12.x
$grammar = new MySqlGrammar($connection);
```

Removed/deprecated:
- `Blueprint::getPrefix()` — deprecated
- `Connection::withTablePrefix()` — removed
- `Grammar::getTablePrefix()` and `setTablePrefix()` — deprecated
- `Grammar::setConnection()` — removed

Use `$connection->getTablePrefix()` instead.
