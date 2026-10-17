---
name: laravel-conventions
description: Cross-project Laravel conventions. Use when writing or reviewing paginated or sorted Eloquent/query-builder queries, public Livewire components, or agent guidance files (AGENTS.md, CLAUDE.md, Boost guidelines) in a Laravel project, and before running its test suite or calling a test failure pre-existing.
---

# Laravel conventions

Rules that hold in every Laravel project unless its own guidelines say otherwise.

## Pagination needs a unique tie-breaker

A paginated query sorted on a non-unique column (dates, statuses, names) ends with a tie-breaker on the primary key:

```php
Post::orderByDesc('published_at')->orderBy('posts.id')->paginate();
```

The database doesn't guarantee the order of rows with equal sort values across `LIMIT`/`OFFSET` queries, so without the tie-breaker rows get duplicated or skipped from page to page. This applies to `paginate()`, `simplePaginate()`, `cursorPaginate()`, Filament and Livewire tables with a default sort, and `chunk()`. Qualify the column (`posts.id`) when the query joins.

## Re-seed before running tests

Run `php artisan migrate:fresh --seed --env=testing` at the start of a test session, and always before calling a failure pre-existing. Seed data is often date-relative (upcoming events, current academic year), so a test database seeded days ago fails tests that pass on a fresh seed.

## Lock server-set Livewire properties

Every public property of a Livewire component can be changed by the browser. On components a guest can reach (routes without `auth`), mark each property the server sets and the user shouldn't change with `#[Locked]`: model ids, tenant, filters fixed by the page, limits, flags. Leave genuine form state (what the user types) unlocked.

A tampered value must not bypass a check, such as an id that skips an `is_visible` scope. Add a feature test that sets a locked property and asserts the exception. Optionally list `Livewire\Features\SupportLockedProperties\CannotUpdateLockedPropertyException` in `dontReport` in `bootstrap/app.php` so tampering doesn't flood error reporting.

## Agent guidance in Boost projects

When the project uses Laravel Boost (`laravel/boost` in `composer.json`, a `.ai/guidelines/` folder), `AGENTS.md`, `CLAUDE.md` and the other agents' files are generated: `php artisan boost:update` overwrites direct edits. Write project guidance in `.ai/guidelines/*.md` (e.g. `.ai/guidelines/project.md`), then ask the user to run `php artisan boost:update` or run it yourself.
