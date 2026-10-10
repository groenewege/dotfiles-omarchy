# Filament v3 to v4 — Official Upgrade Guide

> Source: https://filamentphp.com/docs/4.x/upgrade-guide

## New Requirements

- PHP 8.2+
- Laravel v11.28+
- Tailwind CSS v4.1+, if you're currently using Tailwind CSS v3.0 with Filament. This doesn't apply if you're just using a Filament panel without a custom theme CSS file.
- Filament no longer requires `doctrine/dbal`, but if your application still does, and you don't have it installed directly, you should add it to your `composer.json` file.

## Running the Automated Upgrade Script

> The upgrade script is not a replacement for the upgrade guide. It handles many small changes that aren't mentioned in the upgrade guide, but it doesn't handle all breaking changes. You should still read the manual upgrade steps to see what changes you need to make to your code.

> Some plugins you're using may not be available in v4 just yet. You could temporarily remove them from your `composer.json` file until they've been upgraded, replace them with similar plugins that are v4-compatible, wait for the plugins to be upgraded before upgrading your app, or even write PRs to help the authors upgrade them.

The first step to upgrade your Filament app is to run the automated upgrade script:

```bash
composer require filament/upgrade:"^4.0" -W --dev

vendor/bin/filament-v4

# Run the commands output by the upgrade script, they are unique to your app
composer require filament/filament:"^4.0" -W --no-update
composer update
```

> When using Windows PowerShell, you may need to use `~4.0` instead of `^4.0` since PowerShell ignores `^` characters.

> If installing the upgrade script fails, make sure that your PHPStan version is at least v2, or your Larastan version is at least v3. The script uses Rector v2, which requires PHPStan v2 or higher.

Filament v4 introduces a new default directory structure for your Filament resources and clusters. If you want to migrate to the new directory structure:

```bash
php artisan filament:upgrade-directory-structure-to-v4 --dry-run
php artisan filament:upgrade-directory-structure-to-v4
```

> This directory upgrade script is not able to perfectly update any references to classes in the same namespace that were present in resource and cluster files, and those references will need to be updated manually after the script has run. You should use tools like PHPStan to identify references to classes that are broken after the upgrade.

You can now `composer remove filament/upgrade --dev` as you don't need it anymore.

## Publishing the Configuration File

```bash
php artisan vendor:publish --tag=filament-config
```

The `default_filesystem_disk` in v4 is set to the `FILESYSTEM_DISK` variable instead of `FILAMENT_FILESYSTEM_DISK`. To preserve the v3 behavior:

```php
return [
    'default_filesystem_disk' => env('FILAMENT_FILESYSTEM_DISK', 'public'),
];
```

v4 introduces a `file_generation` section:

```php
use Filament\Support\Commands\FileGenerators\FileGenerationFlag;

return [
    'file_generation' => [
        'flags' => [
            FileGenerationFlag::EMBEDDED_PANEL_RESOURCE_SCHEMAS,
            FileGenerationFlag::EMBEDDED_PANEL_RESOURCE_TABLES,
            FileGenerationFlag::PANEL_CLUSTER_CLASSES_OUTSIDE_DIRECTORIES,
            FileGenerationFlag::PANEL_RESOURCE_CLASSES_OUTSIDE_DIRECTORIES,
            FileGenerationFlag::PARTIAL_IMPORTS,
        ],
    ],
];
```

## Breaking Changes — High Impact

### File visibility is now private by default for non-local disks

The file visibility settings for non-local disks (such as `s3`) have been changed to `private` by default. This affects:

- `FileUpload` form field (including `SpatieMediaLibraryFileUpload`)
- `ImageColumn` table column (including `SpatieMediaLibraryImageColumn`)
- `ImageEntry` infolist entry (including `SpatieMediaLibraryImageEntry`)

To preserve the old behavior globally:

```php
use Filament\Forms\Components\FileUpload;
use Filament\Infolists\Components\ImageEntry;
use Filament\Tables\Columns\ImageColumn;

FileUpload::configureUsing(fn (FileUpload $fileUpload) => $fileUpload
    ->visibility('public'));

ImageColumn::configureUsing(fn (ImageColumn $imageColumn) => $imageColumn
    ->visibility('public'));

ImageEntry::configureUsing(fn (ImageEntry $imageEntry) => $imageEntry
    ->visibility('public'));
```

### Custom themes need to be upgraded to Tailwind CSS v4

Previously, custom theme CSS files contained:

```css
@import '../../../../vendor/filament/filament/resources/css/theme.css';

@config 'tailwind.config.js';
```

Now, they should contain:

```css
@import '../../../../vendor/filament/filament/resources/css/theme.css';

@source '../../../../app/Filament/**/*';
@source '../../../../resources/views/filament/**/*';
```

Check the `content` paths in your old `tailwind.config.js` file and add them as `@source` entries. You don't need to include `vendor/filament` as a `@source`.

Run the Tailwind upgrade tool:

```bash
npx @tailwindcss/upgrade
```

The `tailwind.config.js` file for your theme is no longer used. Move customizations to the CSS file.

### Tailwind CSS classes from Filament views no longer available without a custom theme

In v3, Filament's Blade views contained Tailwind CSS classes directly in the HTML, which meant your custom Tailwind classes that matched would work automatically.

In v4, Filament's Tailwind classes have been moved into CSS files using `@apply`. To fix this, create a custom theme:

```bash
php artisan make:filament-theme
```

In your theme CSS file, add `@source` entries pointing to your files:

```css
@import '../../../../vendor/filament/filament/resources/css/theme.css';

@source '../../../../app/Filament/**/*';
@source '../../../../resources/views/filament/**/*';
@source '../../../../resources/views/components/**/*';
@source '../../../../resources/views/livewire/**/*';
```

### Changes to table filters are deferred by default

The `deferFilters()` method from v3 is now the default. To disable:

```php
use Filament\Tables\Table;

public function table(Table $table): Table
{
    return $table->deferFilters(false);
}
```

Global:

```php
Table::configureUsing(fn (Table $table) => $table->deferFilters(false));
```

### Grid, Section and Fieldset no longer span all columns by default

In v4, these components consume one column by default. Use `->columnSpanFull()` for full width.

Global:

```php
use Filament\Schemas\Components\Fieldset;
use Filament\Schemas\Components\Grid;
use Filament\Schemas\Components\Section;

Fieldset::configureUsing(fn (Fieldset $fieldset) => $fieldset->columnSpanFull());
Grid::configureUsing(fn (Grid $grid) => $grid->columnSpanFull());
Section::configureUsing(fn (Section $section) => $section->columnSpanFull());
```

### The `unique()` validation rule now ignores records by default

In v4, `ignoreRecord` defaults to `true`. Pass `ignoreRecord: false` to disable.

Global:

```php
use Filament\Forms\Components\Field;

Field::configureUsing(fn (Field $field) => $field
    ->uniqueValidationIgnoresRecordByDefault(false));
```

### The `all` pagination page option removed by default

```php
$table->paginationPageOptions([5, 10, 25, 50, 'all']);
```

### Spatie Translatable Plugin deprecated

Replace with [Lara Zeus Translatable Plugin](https://github.com/lara-zeus/spatie-translatable).

## Breaking Changes — Medium Impact

### `columnSpan()` now targets >= `lg` devices by default

In v3, `columnSpan(2)` affected all screen sizes. Now it's consistent with `columns()` and affects `lg+` only. If you had `columnSpan(['lg' => 2])`, simplify to `columnSpan(2)`.

### Enum field state

In v4, field state is always returned as the enum instance (not the raw value):

```php
Select::make('status')
    ->options(Status::class)
    ->afterStateUpdated(function (?Status $state) {
        // $state is always an instance of Status, or null
    });
```

### URL parameter names have changed

- `activeRelationManager` → `relation`
- `activeTab` → `tab`
- `isTableReordering` → `reordering`
- `tableFilters` → `filters`
- `tableGrouping` → `grouping`
- `tableGroupingDirection` → `groupingDirection`
- `tableSearch` → `search`
- `tableSort` → `sort`

### Automatic tenancy global scoping and association

In v4, Filament automatically scopes all queries to the current tenant and associates new records with the current tenant using model events.

### Radio `inline()` method behavior

In v4, `inline()` only puts radio buttons inline with each other (not with the label). Use `->inlineLabel()` as well if needed.

Global:

```php
use Filament\Forms\Components\Radio;

Radio::configureUsing(fn (Radio $radio) => $radio
    ->inlineLabel(fn (): bool => $radio->isInline()));
```

### Import and export job retries

v3: retried continuously for 24 hours. v4: retried 3 times with 60 second backoff.

## Breaking Changes — Low Impact

### `ImageColumn::limitedRemainingText()` and `ImageEntry::limitedRemainingText()` `isSeparate` parameter removed

If a stack exists, the text will always be stacked on top.

### `RichEditor::disableGrammarly()` removed

No replacement since TipTap doesn't support disabling Grammarly.

### Overriding `make()` methods

The signature changed to `public static function make(?string $name = null): static` for:
- `Field::make()`
- `MorphToSelect::make()`
- `Placeholder::make()`
- `Builder\Block::make()`
- `Entry::make()`
- `Column::make()`
- `Constraint::make()`
- `ExportColumn::make()`
- `ImportColumn::make()`

Override `getDefaultName()` for default names and `setUp()` for default configuration instead.

### Import/export job authentication

In v4, the `Login` event is no longer fired from import/export jobs.

### Tables have default primary key sorting

Disable with `$table->defaultKeySort(false)`.

### Authorization `can*()` methods

Override `get*AuthorizationResponse()` methods instead:
- `canCreate()` → `getCreateAuthorizationResponse()`
- `canViewAny()` → `getViewAnyAuthorizationResponse()`
- `canDelete()` → `getDeleteAuthorizationResponse()`

### Translation code changes

- European Portuguese: `pt_PT` → `pt`
- Nepalese: `np` → `ne`
- Norwegian: `no` → `nb`
- Khmer: `kh` → `km`

### Deprecated table configuration methods removed

- `getTableRecordUrlUsing()` → `$table->recordUrl()`
- `getTableRecordClassesUsing()` → `$table->recordClasses()`
- `getTableRecordActionUsing()` → `$table->recordAction()`
- `isTableRecordSelectable()` → `$table->checkIfRecordIsSelectableUsing()`
