---
name: upgrade-filament-4
description: Upgrade Filament v3 code to v4/v5. Use this skill whenever upgrading a Laravel Filament project from v3 to v4 or v5, when copying code or examples from a Filament v3 project into a v4/v5 project, when encountering deprecated Filament v3 patterns, when referencing old Filament v3 tutorials or documentation, or when fixing namespace errors after a Filament upgrade. Also activate when you see v3-era namespaces like `Filament\Forms\Components\Section`, `Filament\Forms\Components\Grid`, `Filament\Tables\Actions\*`, or `Filament\Forms\Components\Fieldset`. Trigger on any mention of "filament 3", "filament v3", "upgrade filament", "migrate filament", or "convert filament".
---

# Upgrading Filament v3 to v4/v5

This skill helps you convert Filament v3 code to v4/v5. Whether you're running a full project upgrade, copying code from a v3 codebase, or adapting a v3 tutorial, apply these transformations.

For the complete official upgrade guide with all edge cases, read `references/upgrade-guide.md` in this skill's directory.

## Critical Namespace Changes

These are the most common source of errors when moving v3 code to v4/v5. Apply these substitutions to every file:

### Layout components moved to `Filament\Schemas\Components\`

| v3 Namespace | v4/v5 Namespace |
|---|---|
| `Filament\Forms\Components\Section` | `Filament\Schemas\Components\Section` |
| `Filament\Forms\Components\Grid` | `Filament\Schemas\Components\Grid` |
| `Filament\Forms\Components\Fieldset` | `Filament\Schemas\Components\Fieldset` |
| `Filament\Forms\Components\Tabs` | `Filament\Schemas\Components\Tabs` |
| `Filament\Forms\Components\Wizard` | `Filament\Schemas\Components\Wizard` |
| `Filament\Infolists\Components\Section` | `Filament\Schemas\Components\Section` |
| `Filament\Infolists\Components\Grid` | `Filament\Schemas\Components\Grid` |
| `Filament\Infolists\Components\Fieldset` | `Filament\Schemas\Components\Fieldset` |
| `Filament\Infolists\Components\Tabs` | `Filament\Schemas\Components\Tabs` |

### Schema utilities moved to `Filament\Schemas\Components\Utilities\`

| v3 Namespace | v4/v5 Namespace |
|---|---|
| `Filament\Forms\Get` | `Filament\Schemas\Components\Utilities\Get` |
| `Filament\Forms\Set` | `Filament\Schemas\Components\Utilities\Set` |

### Actions unified under `Filament\Actions\`

In v4/v5, **all actions** live under `Filament\Actions\`. Never use sub-namespaces like `Filament\Tables\Actions\`, `Filament\Forms\Actions\`, or `Filament\Infolists\Actions\`.

| v3 Namespace | v4/v5 Namespace |
|---|---|
| `Filament\Tables\Actions\DeleteAction` | `Filament\Actions\DeleteAction` |
| `Filament\Tables\Actions\EditAction` | `Filament\Actions\EditAction` |
| `Filament\Tables\Actions\ViewAction` | `Filament\Actions\ViewAction` |
| `Filament\Tables\Actions\CreateAction` | `Filament\Actions\CreateAction` |
| `Filament\Tables\Actions\BulkAction` | `Filament\Actions\BulkAction` |
| `Filament\Forms\Actions\Action` | `Filament\Actions\Action` |
| Any `Filament\*\Actions\*Action` | `Filament\Actions\*Action` |

### Icons use the Heroicon enum

```php
// v3
->icon('heroicon-o-pencil-square')

// v4/v5
use Filament\Support\Icons\Heroicon;
->icon(Heroicon::PencilSquare)
```

## High-Impact Breaking Changes

### 1. Layout components no longer span all columns by default

In v3, `Grid`, `Section`, and `Fieldset` consumed the full width. In v4/v5 they consume one column. Add `->columnSpanFull()` to restore the old behavior:

```php
// v3 — implicitly full width
Section::make('Details')
    ->schema([...])

// v4/v5 — explicitly full width
Section::make('Details')
    ->columnSpanFull()
    ->schema([...])
```

**Symptom:** top-level sections that used to stack now pack two-up (a resource form's root is a multi-column grid in v4, and each section now occupies one cell). The intentional inner layout — a section's own `->columns(2)` controlling its *children* — is unaffected; only the section's *own* span changed. Don't touch the inner `->columns()`.

**Prefer the global fix** when you want v3 parity across the whole panel — it fixes every resource at once, so you don't chase the same "2 columns instead of 1" report resource by resource. In `AppServiceProvider::boot()`:

```php
use Filament\Schemas\Components\Fieldset;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;

Section::configureUsing(fn (Section $section) => $section->columnSpanFull());
Grid::configureUsing(fn (Grid $grid) => $grid->columnSpanFull());
Fieldset::configureUsing(fn (Fieldset $fieldset) => $fieldset->columnSpanFull());
```

Verify it took effect without clicking through the UI — a freshly made component should report a full span:

```bash
php artisan tinker --execute="var_export(\Filament\Schemas\Components\Section::make('x')->getColumnSpan());"
# => array ( 'default' => 'full', )
```

### 2. File visibility is private by default on non-local disks

`FileUpload`, `ImageColumn`, and `ImageEntry` now default to `private` visibility on non-local disks (e.g. `s3`). If files should be publicly accessible, add `->visibility('public')`.

**Related local-disk gotcha (Laravel 11+ `serve => true` returns 403).** When uploads go to a `local`-driver disk that serves files at `/storage/...` via `'serve' => true` (the modern replacement for a symlinked `public` disk), a missing `'visibility'` key makes the local driver default to **private** — it then creates `0700` directories, and Laravel's serve route returns **HTTP 403** for the uploaded files (the image saves but won't display). This often surfaces after a Shift run streamlines `config/filesystems.php` and drops the `'visibility' => 'public'` that an older `public` disk had. Fix in the disk config, not per-field:

```php
'local' => [
    'driver' => 'local',
    'root' => storage_path('app'),
    'visibility' => 'public', // <-- without this, serve => true 403s on uploads
    'serve' => true,
    'throw' => false,
],
```

Diagnose with `curl -s -o /dev/null -w "%{http_code}" <file-url>` (403 = private) and `stat` the directory (`drwx------` = private). Files already uploaded under the private directory stay private — fix them once with `Storage::disk('local')->setVisibility('page_elements', 'public')`.

**Pin the upload disk globally in a service provider instead of per field.** A `FileUpload` (and `SpatieMediaLibraryFileUpload`) with no explicit `->disk()` writes to the app default (`FILESYSTEM_DISK`, often `local`). After a Laravel-11 Shift drops the hand-written `public` disk (see the upgrade-laravel-11 skill), uploads silently land in `storage/app/<dir>` instead of `storage/app/public/<dir>`, breaking both new saves and lookups of existing `public`-disk media — with **no error thrown**. Rather than adding `->disk('public')` to every field across every resource, set it once in `AppServiceProvider::boot()`, mirroring the global `Section::configureUsing()` parity fix in High-Impact change #1:

```php
use Filament\Forms\Components\FileUpload;

FileUpload::configureUsing(function (FileUpload $component): void {
    $component->disk('public');
});
```

This covers every current and future `FileUpload` in the panel (a per-field `->disk(...)` still overrides it where needed). `spatie/laravel-medialibrary` uploads are governed separately by `config/media-library.php` (`disk_name`, default `env('MEDIA_DISK', 'public')`), so once the `public` disk exists they resolve correctly without this hook — but restoring the disk is the prerequisite for both. Verify without clicking through the UI:

```bash
php artisan tinker --execute="var_export(\Filament\Forms\Components\FileUpload::make('x')->getDisk()->getConfig()['root'] ?? null);"
# => '.../storage/app/public'
```

### 3. Table filters are deferred by default

Users must click a button to apply filters. To restore instant filtering:

```php
$table->deferFilters(false);
```

### 4. `unique()` validation now ignores the current record by default

In v3 you needed `ignoreRecord: true`. In v4/v5 this is the default. If you relied on the old behavior (not ignoring), pass `ignoreRecord: false`.

### 5. Custom themes must use Tailwind CSS v4

v3 theme CSS:
```css
@import '../../../../vendor/filament/filament/resources/css/theme.css';
@config 'tailwind.config.js';
```

v4/v5 theme CSS:
```css
@import '../../../../vendor/filament/filament/resources/css/theme.css';

@source '../../../../app/Filament/**/*';
@source '../../../../resources/views/filament/**/*';
```

Run `npx @tailwindcss/upgrade` to migrate Tailwind config. The `tailwind.config.js` file is no longer used — move customizations to CSS.

### 6. Tailwind classes in your own Filament Blade views are no longer compiled

In v3, Filament's Blade views had Tailwind classes inline, so the utilities you used in custom views (widgets, custom pages, custom column/field views) were present in the compiled CSS. In v4/v5 Filament's CSS is built with `@apply` and only contains the classes **Filament itself** uses. So in a custom view, a class Filament happens to use (`text-sm`, `font-semibold`, `px-4`, `dark:text-white`) still renders, but one it doesn't (`w-16`, `h-16`, sometimes even `flex`) silently does nothing — a confusing "some classes work, some don't" symptom. The admin panel also does **not** load your public `app.css`, so utilities compiled there aren't available inside Filament.

Three fixes, smallest first:

1. **One-off sizing/spacing → inline `style`.** For a single element (e.g. a logo `<img>`), `style="width: 4rem; height: 4rem;"` is the proportionate fix and needs no rebuild. (`w-16` = `4rem`.)
2. **Match an existing Filament component → reuse its `fi-*` design-system classes.** These ship in the compiled CSS, so borrowing them renders identically *including dark mode*. To make a custom widget look like the account widget, put `class="fi-account-widget"` on `<x-filament-widgets::widget>` (its CSS makes the section content `flex items-center gap-x-3`) and use `fi-account-widget-heading` / `fi-account-widget-user-name` for the text. Read the class definitions in `vendor/filament/filament/resources/css/widgets/*.css` to see what each does.
3. **A whole custom page/widget needs many utilities, but a custom theme isn't viable → scoped `<style>` block in the Blade view.** `php artisan make:filament-theme` produces a **Tailwind v4** theme, and you can only have one `tailwindcss` major installed — so if the project's public site is still on **Tailwind v3**, adopting a Filament theme means migrating the entire public site to Tailwind v4 (large, out of scope for a styling fix). For one or two self-contained custom views, write a scoped `<style>` block at the top of the Blade view instead. Namespace every rule under a wrapper class so it can't leak into the rest of the panel, and use Filament's CSS custom properties (with a literal fallback) to track the theme:

```blade
<x-filament-panels::page>
    <style>
        .fi-backups-page .my-info-box { background: #eff6ff; border: 1px solid #bfdbfe; color: #1e40af; }
        .dark .fi-backups-page .my-info-box { background: rgba(30,58,138,.15); color: #bfdbfe; }
        .fi-backups-page .my-link { color: #2563eb; color: rgb(var(--primary-600)); } /* literal fallback, then theme primary */
    </style>

    <div class="fi-backups-page"> ... </div>
</x-filament-panels::page>
```

This needs no build step and no Tailwind-version change. Use it only for genuinely custom pages — for forms/tables/infolists, prefer Filament's own components, which are styled by the shipped CSS.

4. **You need arbitrary utilities across *many* custom views AND can move to Tailwind v4 → create a custom theme.** `php artisan make:filament-theme`, add `@source` entries for `app/Filament/**/*` and `resources/views/filament/**/*`, register it with `->viteTheme(...)` in the panel provider, then `npm run build`.

### 7. The `all` pagination option is removed by default

Add it back per-table:
```php
$table->paginationPageOptions([5, 10, 25, 50, 'all']);
```

## Medium-Impact Changes

### `columnSpan()` now targets >= `lg` devices by default

In v3: `columnSpan(2)` affected all screen sizes.
In v4/v5: `columnSpan(2)` affects `lg` and above only (consistent with `columns()`).

If you were using `columnSpan(['lg' => 2])`, simplify to `columnSpan(2)`.

### Enum field state always returns the enum instance

In v3, enum fields inconsistently returned either the raw value or an enum instance. In v4/v5 it's always the enum instance:

```php
Select::make('status')
    ->options(Status::class)
    ->afterStateUpdated(function (?Status $state) {
        // $state is always a Status instance or null
    });
```

### URL parameter names changed

| v3 Parameter | v4/v5 Parameter |
|---|---|
| `activeRelationManager` | `relation` |
| `activeTab` | `tab` |
| `isTableReordering` | `reordering` |
| `tableFilters` | `filters` |
| `tableGrouping` | `grouping` |
| `tableGroupingDirection` | `groupingDirection` |
| `tableSearch` | `search` |
| `tableSort` | `sort` |

This isn't only about reading params — it bites hardest when you **build** a link to a pre-filtered list page, e.g. a header `Action` that cross-links between two resources. The deep-link array keeps its nested `['value' => ...]` shape; only the top-level key changes from `tableFilters` to `filters`:

```php
// v3 — opens the target page UNFILTERED in v4 (no error, silent)
->url(fn (RebFiche $record): string => route('filament.admin.resources.decide-fiches.index', [
    'tableFilters' => ['molecule_id' => ['value' => $record->molecule_id]],
]))

// v4/v5
->url(fn (RebFiche $record): string => route('filament.admin.resources.decide-fiches.index', [
    'filters' => ['molecule_id' => ['value' => $record->molecule_id]],
]))
```

Grep for the old key names as **string literals** (`'tableFilters'`, `'tableSearch'`, etc.), not just `::getUrl()` calls — these often live inside `route()` arguments in page/action classes.

### Radio `inline()` behavior changed

In v3: `inline()` put buttons inline with each other AND the label.
In v4/v5: `inline()` only puts buttons inline with each other. Add `->inlineLabel()` if you also want them inline with the label.

### Authorization: `can*()` methods replaced by `get*AuthorizationResponse()`

If you override `canCreate()`, `canViewAny()`, `canDelete()`, etc. on a Resource or RelationManager, these aren't always called in v4/v5. Move logic to model policies, or override `getCreateAuthorizationResponse()`, `getViewAnyAuthorizationResponse()`, etc. instead.

### Automatic tenancy scoping (mechanism changed — `scopeEloquentQueryToTenant` is NOT removed)

The headline change: tenancy is now enforced by a **global scope on the model** plus **`creating`/`created` model events**, not by the resource's query builder. In v3 only the resource's own queries were scoped (table, record resolution, global search) because the resource's `getEloquentQuery()` applied the tenant filter — any direct `Model::query()` was unscoped and you had to scope it by hand. In v4/v5 every query to a tenant-aware model is scoped automatically, and new records are auto-associated with the current tenant. **Remove the manual per-query scoping** you added in v3 to compensate.

Two members of `Filament\Resources\Resource\Concerns\BelongsToTenant` are commonly confused here — they are different tools, and **neither replaces the other**:

- **`scopeEloquentQueryToTenant(Builder $query, ?Model $tenant): Builder` still exists and overriding it is still supported.** It is the place to customize *how* the tenant scope filters a model's queries (e.g. a non-standard ownership relationship). What changed is *where it's invoked from*: v3 called it from the resource's `getEloquentQuery()`; v4 calls it from the model global scope registered by `registerTenancyModelGlobalScope()`. A v3 override that returns a customized `Builder` keeps working — just don't rely on overriding `getEloquentQuery()` to add or remove tenant scoping, and don't assume it's the only place tenancy is applied.

- **`protected static bool $isScopedToTenant = false;` disables tenancy for one resource** (a resource shared across all tenants). This is *not* a replacement for `scopeEloquentQueryToTenant()` — one turns scoping off, the other customizes the scoping query. It is also **not new to v4** (v3 had it). To invert the default panel-wide, call `Resource::scopeToTenant(false)` in a service provider `boot()` and opt resources back in with `protected static bool $isScopedToTenant = true;`.

Because scoping is now a global scope, the escape hatches changed: to run a single unscoped query, use `->withoutGlobalScope(filament()->getTenancyScopeName())` — **not** `withoutGlobalScopes()`, which drops the tenant scope and leaks data across tenants. For a model that has no resource but should still be tenant-scoped inside the panel, register the global scope yourself from tenant middleware (`->tenantMiddleware([...], isPersistent: true)`).

## Low-Impact Changes

### `make()` method signature change

If you extend `Field`, `Entry`, `Column`, `Constraint`, `ExportColumn`, `ImportColumn`, `Placeholder`, `MorphToSelect`, or `Builder\Block` and override `make()`, update the signature:

```php
// v4/v5 signature
public static function make(?string $name = null): static
```

Prefer overriding `getDefaultName()` for default names and `setUp()` for default configuration instead of overriding `make()`.

### Tables have default primary key sorting

Disable with `$table->defaultKeySort(false)` if your table has no primary key.

### Import/export job retries

v3: retried continuously for 24 hours. v4/v5: retried 3 times with 60s backoff.

### RichEditor moved from Trix to TipTap — stored values are now wrapped in block HTML

The editor switched engines, which changes the **stored output**: a value that was saved as plain `foo` in v3 is now saved as `<p>foo</p>`. This breaks tests and assertions that expect the raw string. Update expectations to the wrapped form:

```php
// v3
$this->assertDatabaseHas('posts', ['body' => 'hello']);

// v4/v5
$this->assertDatabaseHas('posts', ['body' => '<p>hello</p>']);
```

The wrapped HTML is valid and renders identically on the frontend (it's output as HTML), so update the assertions rather than trying to strip the tags. Also note `RichEditor::disableGrammarly()` was removed with no replacement.

### Deprecated table config methods removed

| Removed Method | Replacement |
|---|---|
| `getTableRecordUrlUsing()` | `$table->recordUrl()` |
| `getTableRecordClassesUsing()` | `$table->recordClasses()` |
| `getTableRecordActionUsing()` | `$table->recordAction()` |
| `isTableRecordSelectable()` | `$table->checkIfRecordIsSelectableUsing()` |

### `Select` over a recursive CTE (adjacency-list trees) throws

If a `Select::make()->relationship(modifyQueryUsing: fn ($q) => $q->tree())` builds its options from a recursive CTE (e.g. `staudenmeir/laravel-adjacency-list`'s `->tree()`), v4/v5 throws when resolving the **currently selected** option's label. Filament fetches that single record with `->where($model->getQualifiedKeyName(), $value)` — i.e. `where "pages"."id" = ?` — but the outer query selects `from laravel_cte`, where the qualified column `pages.id` does not exist:

```
SQLSTATE[42S22]: Column not found: 1054 Unknown column 'pages.id' in 'where clause'
  (... select * from `laravel_cte` where `pages`.`id` = 15 ...)
```

**Preferred fix — drop `->relationship()`, use `->options()`.** For a plain FK column (e.g. `parent_id`), the relationship buys nothing: Filament writes the column straight from form state either way. Switching to `->options()` removes the broken by-key CTE lookup entirely and collapses the workaround to a single label hook:

```php
Select::make('parent_id')
    ->searchable()
    ->options(function (?Page $record): array {
        return Page::query()
            ->tree()
            ->orderBy('order_path')
            ->when($record, fn (Builder $query) => $query->where('id', '!=', $record->id))
            ->get()
            ->mapWithKeys(fn (Page $page): array => [$page->id => str_repeat(' - ', $page->depth) . $page->title])
            ->all();
    })
    ->getOptionLabelUsing(fn ($value): ?string => Page::find($value)?->title)
    ->live(),
```

Why this is better than keeping `->relationship()`:

- **One label hook, not two.** With `->relationship()` you must override *both* `getOptionLabelFromRecordUsing` (dropdown/preloaded records) **and** `getOptionLabelUsing` (the selected value) — the second only to dodge the CTE by-key query. `->options()` has no record path, so only `getOptionLabelUsing` remains, as a fallback.
- **Cheaper selected-label resolution.** `->options()` is eager and already contains the selected row's depth-indented label, so on edit pages the label renders straight from that array. The `getOptionLabelUsing` fallback is a single indexed `Page::find($value)` — *not* the full-tree `->tree()->get()->firstWhere()` load the relationship workaround forced.
- **Don't compute `depth` in the fallback.** `depth`/`order_path` are CTE-only pseudo-columns; on a plain `Page::find()` `depth` is `null`, so `str_repeat(' - ', $page->depth)` emits a PHP 8 deprecation and no prefix. Return `?->title` only — indentation is meaningless for a single closed-select line anyway. The dropdown options still get full depth indentation via `->options()`.
- **Drop `->preload()`** — `->options()` is already eager, so preload is moot.

**Fallback fix (only if you must keep `->relationship()`):** resolve the selected label from the loaded tree in PHP so Filament never runs the by-key query against the CTE. Costs a full-tree load per label and still needs the `getOptionLabelFromRecordUsing` companion for the dropdown:

```php
->getOptionLabelUsing(function ($value): ?string {
    $record = Page::query()->tree()->orderBy('order_path')->get()->firstWhere('id', $value);

    return $record ? str_repeat(' - ', $record->depth) . $record->title : null;
})
```

### Spatie Translatable Plugin deprecated

Replace `filament/spatie-laravel-translatable-plugin` with `lara-zeus/spatie-translatable`.

## Running the Automated Upgrade Script

For full project upgrades, run:

```bash
composer require filament/upgrade:"^4.0" -W --dev
vendor/bin/filament-v4
# Follow the commands output by the script
composer require filament/filament:"^4.0" -W --no-update
composer update
```

**`vendor/bin/filament-v4` is interactive** — it prompts for a comma-separated list of directories to process. When driving it non-interactively, pipe the answer (an empty line accepts the default `app` structure): `printf '\n' | vendor/bin/filament-v4`. It aborts with `MissingInputException` if it gets no input.

**It only rewrites the directories you give it — `tests/` is NOT included by default.** Test files then keep v3 namespaces (e.g. `Filament\Tables\Actions\DeleteAction`) and fail at runtime with `ActionNotResolvableException` or a `TypeError`. Run it a second time over your tests: `printf 'tests\n' | vendor/bin/filament-v4` (Rector is idempotent, so re-processing `app/` is harmless if you pass `app,tests`).

**Companion `filament/*` plugins must all move to `^4.0` together.** Bumping `filament/filament` while leaving e.g. `filament/spatie-laravel-media-library-plugin` at `^3.x` makes `composer update` fail on a `filament/support` version conflict. Bump every `filament/*` requirement in `composer.json` to `^4.0` before updating. (Laravel Shift bumps `filament/filament` but may leave the companion plugins behind.)

**After `composer update`, republish assets and clear caches — or the panel renders with no CSS/JS.** A common post-upgrade symptom is the admin panel loading completely unstyled because the v4 default theme assets were never published:

```bash
php artisan filament:assets          # publishes public/css/filament/** and public/js/filament/**
php artisan filament:optimize-clear  # clears cached component/Blade-icon registrations
php artisan view:clear
```

Then hard-refresh the browser to drop the stale/empty cached asset.

Optionally migrate to the new directory structure:

```bash
php artisan filament:upgrade-directory-structure-to-v4 --dry-run
php artisan filament:upgrade-directory-structure-to-v4
```

Then clean up:

```bash
composer remove filament/upgrade --dev
```

After running the automated script, still apply the manual changes from this guide.

## Configuration File

Publish with `php artisan vendor:publish --tag=filament-config`. Key settings to review:

- `default_filesystem_disk` — changed from `FILAMENT_FILESYSTEM_DISK` to `FILESYSTEM_DISK`
- `file_generation.flags` — controls how new files are generated (embedded schemas, directory structure, partial imports)

## Checklist When Converting v3 Code

1. Update all namespace imports (layout, actions, utilities, icons)
2. Add `->columnSpanFull()` to Section/Grid/Fieldset where needed
3. Add `->visibility('public')` to FileUpload/ImageColumn/ImageEntry if using non-local disks; if the app default disk isn't where uploads belong (e.g. the `public` disk was restored after a Shift run), pin it globally with `FileUpload::configureUsing(fn ($c) => $c->disk('public'))` in `AppServiceProvider::boot()`
4. Handle enum field state as enum instances, not raw values
5. Update any `columnSpan(['lg' => N])` to `columnSpan(N)` (now equivalent)
6. Check for `unique()` rules — add `ignoreRecord: false` if v3 behavior was intended
7. Update URL parameter references (`activeRelationManager` → `relation`, etc.)
8. Move `can*()` authorization overrides to policies or `get*AuthorizationResponse()`
9. Update theme CSS files from Tailwind v3 to v4 syntax
10. Update `make()` overrides to accept `?string $name = null`
