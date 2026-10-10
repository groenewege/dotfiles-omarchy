---
name: upgrade-livewire-4
description: Upgrade Livewire v3 code to v4. Use this skill whenever upgrading a Laravel Livewire project from v3 to v4, when copying code or examples from a Livewire v3 project into a v4 project, when encountering deprecated Livewire v3 patterns, when referencing old Livewire v3 tutorials or documentation, or when adapting v3-era code snippets found online. Also activate when you see Volt imports like `Livewire\Volt\Component` or `Livewire\Volt\Volt`, v3-style `wire:model.blur` without `.live`, unclosed Livewire component tags, `wire:scroll` usage, `$wire.$js()` function calls, or `Livewire.hook('commit'` / `Livewire.hook('request'` patterns. Trigger on any mention of "livewire 3", "livewire v3", "upgrade livewire", "migrate livewire", "convert livewire", or "volt to livewire".
---

# Upgrading Livewire v3 to v4

This skill helps you convert Livewire v3 code to v4. Whether you're running a full project upgrade, copying code from a v3 codebase, or adapting a v3 tutorial, apply these transformations.

## Installation

```bash
composer require livewire/livewire:^4.0
php artisan optimize:clear
```

## High-Impact Changes

### Config file: renamed keys

| v3 Key | v4 Key |
|---|---|
| `'layout'` | `'component_layout'` |
| `'lazy_placeholder'` | `'component_placeholder'` |

The default layout value changed from `'components.layouts.app'` to `'layouts::app'` (points to `resources/views/layouts/app.blade.php`).

`'smart_wire_keys'` now defaults to `true`.

New v4 config options: `component_locations`, `component_namespaces`, `make_command`, `csp_safe`. See the full v4 config at https://github.com/livewire/livewire/blob/main/config/livewire.php

### Routing: use `Route::livewire()`

```php
// v3 - still works but not recommended
Route::get('/dashboard', Dashboard::class);

// v4 - recommended (required for SFC/MFC components)
Route::livewire('/dashboard', Dashboard::class);
Route::livewire('/dashboard', 'pages::dashboard'); // view-based
```

### `wire:model` ignores child events by default

v3 listened to events bubbling up from child elements. v4 only listens on the element itself (like `.self`).

```blade
{{-- v3 - listened to child events --}}
<div wire:model="value">
    <input type="text">
</div>

{{-- v4 - add .deep to restore old behavior --}}
<div wire:model.deep="value">
    <input type="text">
</div>
```

Standard form input bindings (inputs, selects, textareas) are unaffected.

### `wire:scroll` renamed to `wire:navigate:scroll`

```blade
{{-- v3 --}}
<div class="overflow-y-scroll" wire:scroll>

{{-- v4 --}}
<div class="overflow-y-scroll" wire:navigate:scroll>
```

### Component tags must be self-closed

```blade
{{-- v3 - unclosed tag worked --}}
<livewire:component-name>

{{-- v4 - must be closed --}}
<livewire:component-name />
```

## Medium-Impact Changes

### `wire:model` modifiers now control client-side sync timing

In v3, `.blur` and `.change` only controlled network timing while client-side state (`$wire.property`) always synced immediately. In v4, these modifiers control client-side sync too.

To restore v3 behavior, add `.live` before the modifier:

| v3 Syntax | v4 Equivalent |
|---|---|
| `wire:model.blur` | `wire:model.live.blur` |
| `wire:model.change` | `wire:model.live.change` |

`.lazy` is backwards compatible - no changes needed.

### `wire:transition` modifiers removed

v4 uses the browser's View Transitions API instead of Alpine's `x-transition`. Basic `wire:transition` still works, but all modifiers (`.opacity`, `.scale`, `.duration.Xms`, `.origin.top`) are removed.

```blade
{{-- Still works --}}
<div wire:transition>...</div>

{{-- These must be removed --}}
<div wire:transition.opacity>...</div>
<div wire:transition.scale.origin.top>...</div>
<div wire:transition.duration.500ms>...</div>
```

### `stream()` method signature changed

```php
// v3
$this->stream(to: '#container', content: 'Hello', replace: true);
$this->stream('#container', 'Hello'); // positional

// v4
$this->stream(content: 'Hello', replace: true, el: '#container');
$this->stream('Hello', el: '#container'); // positional
```

Named parameter `to:` renamed to `el:`.

### `mount()` signature change (internal)

```php
// v3
public function mount($name, $params = [], $key = null)

// v4
public function mount($name, $params = [], $key = null, $slots = [])
```

Only affects code extending `LivewireManager`.

### Update hooks consolidate array/object changes

When replacing an entire array from the frontend (`$wire.items = ['new', 'values']`), v4 fires `updatingItems`/`updatedItems` once with the full new value instead of per-index. Single-item changes (`wire:model="items.0"`) still fire granular hooks.

## Low-Impact Changes

### Livewire URLs include APP_KEY hash

URLs changed from `/livewire/` to `/livewire-{hash}/`. Update firewall rules, CDN config, or middleware referencing these paths.

```php
// v3
Livewire::setUpdateRoute(function ($handle) {
    return Route::post('/livewire/update', $handle);
});

// v4
Livewire::setUpdateRoute(function ($handle, $path) {
    return Route::post($path, $handle);
});
```

### JavaScript deprecations

**`$wire.$js()` method:**
```js
// v3 (deprecated, still works)
$wire.$js('bookmark', () => { /* ... */ })

// v4
$wire.$js.bookmark = () => { /* ... */ }
```

**`$js` without prefix:**
```js
// v3 (deprecated, still works)
$js('bookmark', () => { /* ... */ })

// v4
$wire.$js.bookmark = () => { /* ... */ }
// or
this.$js.bookmark = () => { /* ... */ }
```

**`commit` hook -> `interceptMessage`:**
```js
// v3 (deprecated)
Livewire.hook('commit', ({ component, commit, respond, succeed, fail }) => {
    respond(() => { /* ... */ })
    succeed(({ snapshot, effects }) => { /* ... */ })
    fail(() => { /* ... */ })
})

// v4
Livewire.interceptMessage(({ component, message, onFinish, onSuccess, onError, onFailure }) => {
    onFinish(() => { /* ... */ })
    onSuccess(({ payload }) => { /* payload.snapshot, payload.effects */ })
    onError(() => { /* server errors */ })
    onFailure(() => { /* network errors */ })
})
```

**`request` hook -> `interceptRequest`:**
```js
// v3 (deprecated)
Livewire.hook('request', ({ url, options, payload, respond, succeed, fail }) => {
    respond(({ status, response }) => { /* ... */ })
    succeed(({ status, json }) => { /* ... */ })
    fail(({ status, content, preventDefault }) => { /* ... */ })
})

// v4
Livewire.interceptRequest(({ request, onResponse, onSuccess, onError, onFailure }) => {
    // request.uri, request.options, request.payload
    onResponse(({ response }) => { /* response.status */ })
    onSuccess(({ response, responseJson }) => { /* ... */ })
    onError(({ response, responseBody, preventDefault }) => { /* ... */ })
    onFailure(({ error }) => { /* network errors */ })
})
```

## Upgrading from Volt

If the project uses Volt, migrate to Livewire v4's built-in single-file components:

1. Replace `Livewire\Volt\Component` with `Livewire\Component`
2. Replace `Volt::route()` with `Route::livewire()` in routes
3. Replace `Volt::test()` with `Livewire::test()` in tests
4. Delete `app/Providers/VoltServiceProvider.php` and remove from `bootstrap/providers.php`
5. Run `composer remove livewire/volt`

## Quick Reference: Search & Replace Patterns

When upgrading a project, scan for these patterns:

| Search for | Replace with |
|---|---|
| `Livewire\Volt\Component` | `Livewire\Component` |
| `Livewire\Volt\Volt` | `Livewire\Livewire` |
| `Volt::route(` | `Route::livewire(` |
| `Volt::test(` | `Livewire::test(` |
| `wire:scroll` (not `wire:navigate:scroll`) | `wire:navigate:scroll` |
| `<livewire:xxx>` (unclosed) | `<livewire:xxx />` |
| `'layout' =>` (in livewire config) | `'component_layout' =>` |
| `'lazy_placeholder' =>` (in livewire config) | `'component_placeholder' =>` |
| `$wire.$js('name', fn)` | `$wire.$js.name = fn` |
| `$js('name', fn)` | `this.$js.name = fn` |
| `Livewire.hook('commit'` | `Livewire.interceptMessage(` |
| `Livewire.hook('request'` | `Livewire.interceptRequest(` |

## New v4 Features Worth Knowing

When writing new code (not just upgrading), v4 offers:

- **Single-file & multi-file components** - `php artisan make:livewire name` (SFC default), `--mfc` for multi-file
- **Islands** - `@island(name: 'stats', lazy: true)` for isolated independently-updating regions
- **Deferred loading** - `<livewire:component defer />` or `#[Defer]` attribute
- **Async actions** - `wire:click.async="method"` or `#[Async]` attribute
- **`wire:sort`** - built-in drag-and-drop sorting
- **`wire:intersect`** - viewport intersection observer
- **`wire:ref`** - element references
- **`.renderless` modifier** - skip re-rendering for fire-and-forget actions
- **`.preserve-scroll` modifier** - keep scroll position during updates
- **`data-loading` attribute** - automatic loading state CSS targeting
- **`$errors` magic** - access error bag from JavaScript
- **`$intercept` magic** - intercept requests from component scripts
