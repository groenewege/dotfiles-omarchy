---
name: upgrade-livewire-3
description: Upgrade Livewire v2 code to v3. Use this skill whenever upgrading a Laravel Livewire project from v2 to v3, when copying code or examples from a Livewire v2 project into a v3 project, when encountering deprecated Livewire v2 patterns, when referencing old Livewire v2 tutorials or documentation, or when adapting v2-era code snippets found online. Also activate when you see v2 patterns like the `App\Http\Livewire` namespace, legacy emit, emitTo, emitUp, or dispatchBrowserEvent calls, `wire:model.defer`, `wire:model.lazy`, `$emit(`/`$emitUp(` in Blade, `@entangle(...)` without a modifier, `assertEmitted`/`assertNotEmitted` in tests, the `livewire:load` JS event, `Livewire.onPageExpired(`, or old `Livewire.hook('message.*'`/`element.*` hooks. Trigger on any mention of "livewire 2", "livewire v2", "upgrade livewire", "migrate livewire", or "convert livewire".
---

# Upgrading Livewire v2 to v3

This skill helps you convert Livewire v2 code to v3. Whether you're running a full project upgrade, copying code from a v2 codebase, or adapting a v2 tutorial, apply these transformations.

For the complete official upgrade guide with every edge case, read `references/upgrade-guide.md` in this skill's directory.

## Automated First Pass

Livewire ships a command that handles much of the mechanical work. Run it after installing v3, then verify the rest by hand — it does not catch everything:

```bash
composer require livewire/livewire "^3.0"
php artisan view:clear
php artisan livewire:upgrade
```

Livewire v3 requires **PHP 8.1+**.

## High-Impact Changes

### Namespace moved: `App\Http\Livewire` → `App\Livewire`

The default component namespace changed. Two valid paths:

- **Move components** to `app/Livewire/` (recommended), or
- **Keep the old location** by setting `'class_namespace' => 'App\\Http\\Livewire'` in `config/livewire.php`.

Whichever you pick, update `namespace` declarations and references to match.

### Events unified into `dispatch()`

v2 had two methods (`emit()` for Livewire, `dispatchBrowserEvent()` for the browser). v3 has one: `dispatch()`. **All event parameters must now be named.**

```php
$this->emit('post-created');                          // → $this->dispatch('post-created');
$this->emit('post-created', $post->id);               // → $this->dispatch('post-created', postId: $post->id);
$this->emitTo('foo', 'post-created');                 // → $this->dispatch('post-created')->to('foo');
$this->emitSelf('post-created');                      // → $this->dispatch('post-created')->self();
$this->dispatchBrowserEvent('post-created');          // → $this->dispatch('post-created');
$this->dispatchBrowserEvent('saved', ['id' => $id]);  // → $this->dispatch('saved', id: $id);
```

In Blade / Alpine:

```blade
wire:click="$emit('post-created')"              {{-- → wire:click="$dispatch('post-created')" --}}
wire:click="$emit('post-created', 1)"           {{-- → wire:click="$dispatch('post-created', { postId: 1 })" --}}
wire:click="$emitTo('foo', 'post-created', 1)"  {{-- → wire:click="$dispatch('post-created', { postId: 1 })->to('foo')" --}}
x-on:click="$wire.emit('post-created', 1)"      {{-- → x-on:click="$dispatch('post-created', { postId: 1 })" --}}
```

**Listening** uses the `#[On]` attribute instead of the `$listeners` property:

```php
use Livewire\Attributes\On;

#[On('post-created')]
public function postAdded($postId) { /* ... */ }
```

`emitUp()` / `$emitUp()` are **removed entirely** — events are browser events now and bubble up by default. Delete every instance.

### `wire:model` is deferred by default

This is the most error-prone change because the same syntax now means something different. v2's live-by-default `wire:model` became v3's `wire:model.live`:

| v2 | v3 |
|---|---|
| `wire:model="..."` (live) | `wire:model.live="..."` |
| `wire:model.defer="..."` | `wire:model="..."` |
| `wire:model.lazy="..."` | `wire:model.blur="..."` |

Apply the same logic to `@entangle`, which is also deferred by default now:

```blade
@entangle(...)        {{-- → @entangle(...).live --}}
@entangle(...).defer  {{-- → @entangle(...) --}}
```

## Medium-Impact Changes

### Eloquent model binding disabled by default

v2 allowed `wire:model="post.title"` bound directly to an Eloquent model property. v3 disables this in favor of individual properties or a [Form Object](https://livewire.laravel.com/docs/forms#extracting-a-form-object). For a fast, behavior-preserving upgrade, re-enable the v2 behavior in `config/livewire.php`:

```php
'legacy_model_binding' => true,
```

### AlpineJS now ships with Livewire — remove your copy

v3 bundles Alpine and these plugins: Anchor, Collapse, Focus, Intersect, Mask, Morph, Persist. Conflicts arise if you also include Alpine.

- Remove Alpine `<script>` CDN tags and the matching plugin tags.
- If Alpine was imported in your JS bundle, remove `import Alpine from 'alpinejs'`, plugin imports, and `Alpine.start()`.
- Accessing the `Alpine` global from a `<script>` (e.g. `alpine:init` + `Alpine.data(...)`) still works unchanged.
- To register **custom** Alpine plugins via your bundle, swap `@livewireScripts` for `@livewireScriptConfig` in your layout, then import from Livewire's ESM build and call `Livewire.start()` (not `Alpine.start()`). See the reference guide.

### Full-page component layout path moved

The default layout for full-page components moved:

```
resources/views/layouts/app.blade.php             (v2)
resources/views/components/layouts/app.blade.php   (v3)
```

Either move the file, or set `'layout' => 'layouts.app'` in `config/livewire.php`.

### Test event assertions renamed

```php
->assertEmitted('post-created')            // → ->assertDispatched('post-created')
->assertEmittedTo(Foo::class, 'created')   // → ->assertDispatchedTo(Foo::class, 'created')
->assertNotEmitted('post-created')         // → ->assertNotDispatched('post-created')
->assertEmittedUp(...)                     // removed — delete
```

### Query string properties hide default values

In v3, a property bound to the query string only appears in the URL once its value changes from the initial load, removing the need for `['except' => '']`:

```php
protected $queryString = [
    'search' => ['except' => ''],  // → 'search',
];
```

To force a property to always appear (v2 behavior), use `['keep' => true]`.

## Low-Impact Changes

### Config file changes

If `config/livewire.php` is published, reconcile it against the [v3 default](https://github.com/livewire/livewire/blob/master/config/livewire.php):

- **New keys:** `legacy_model_binding`, `inject_assets`, `inject_morph_markers`, `navigate`, `pagination_theme`.
- **Changed defaults:** `class_namespace` (`App\Http\Livewire` → `App\Livewire`), `layout` (`layouts.app` → `components.layouts.app`).
- **Removed keys (delete them):** `app_url`, `asset_url`, `middleware_group`, `manifest_path`, `back_button_cache`.

### `livewire:discover` removed

There's no manifest in v3. Remove any `livewire:discover` calls from build/deploy scripts.

### Component class API

```php
$this->id;   // → $this->getId()
$this->page = 2;  // → $this->setPage(2);  (getter: $this->getPage())
```

Avoid a public method and public property sharing the same name (e.g. `$search` + `search()`) — this breaks `wire:click` calls in v3. Rename one.

### `wire:click.prefetch` removed

Drop the `.prefetch` modifier; the click still works, just without prefetching.

```blade
<button wire:click.prefetch="...">  {{-- → <button wire:click="..."> --}}
```

### JavaScript hooks & events

```js
document.addEventListener('livewire:load', ...)   // → 'livewire:init'
Livewire.onPageExpired(() => {...})               // → use the 'request' hook's fail() with status 419
```

The internal lifecycle hooks were redesigned (`component.initialized` → `component.init`, `element.updating` → `morph.updating`, the four `message.*` hooks collapse into `commit`, etc.). See the reference guide's "JavaScript API changes" section for the full mapping.

### Localized URL prefixes

If your app serves routes under a locale prefix (`/en/...`), v3 no longer auto-preserves it on the update endpoint. Override the route:

```php
Livewire::setUpdateRoute(function ($handle) {
    return Route::post('/livewire/update', $handle);
});
```

## Quick Reference: Search & Replace Patterns

When upgrading a project, scan for these patterns:

| Search for | Replace with |
|---|---|
| `namespace App\Http\Livewire` | `namespace App\Livewire` (or keep via config) |
| `$this->emit(` | `$this->dispatch(` (named params) |
| `$this->emitTo('x', 'evt')` | `$this->dispatch('evt')->to('x')` |
| `$this->emitSelf(` | `$this->dispatch(...)->self(` |
| `$this->emitUp(` / `$emitUp(` | remove (auto-bubbles) |
| `$this->dispatchBrowserEvent(` | `$this->dispatch(` (named params) |
| `$emit(` (Blade) | `$dispatch(` |
| `wire:model="x"` (needs live) | `wire:model.live="x"` |
| `wire:model.defer="x"` | `wire:model="x"` |
| `wire:model.lazy="x"` | `wire:model.blur="x"` |
| `@entangle(x)` (needs live) | `@entangle(x).live` |
| `@entangle(x).defer` | `@entangle(x)` |
| `wire:click.prefetch=` | `wire:click=` |
| `assertEmitted(` | `assertDispatched(` |
| `assertNotEmitted(` | `assertNotDispatched(` |
| `assertEmittedTo(` | `assertDispatchedTo(` |
| `livewire:load` | `livewire:init` |
| `$this->id` (in component) | `$this->getId()` |

## Quick Checklist

1. Bump PHP to 8.1+ and require `livewire/livewire "^3.0"`, then `php artisan view:clear`.
2. Run `php artisan livewire:upgrade`, then verify everything below by hand.
3. Move components to `App\Livewire` or pin `class_namespace` in config.
4. Convert all `emit*` / `dispatchBrowserEvent` to `dispatch()` with **named** params; convert `$listeners` to `#[On]`; delete `emitUp`.
5. Fix `wire:model` / `@entangle` defaults (`.live` for old default behavior, drop `.defer`, `.lazy` → `.blur`).
6. Set `legacy_model_binding => true` if you bind `wire:model` to Eloquent properties.
7. Remove any manually-included AlpineJS and its bundled plugins.
8. Move the full-page layout to `components/layouts/app.blade.php` or pin `layout` in config.
9. Reconcile `config/livewire.php` (new/changed/removed keys); remove `livewire:discover` from build scripts.
10. Rename event test assertions (`assertEmitted*` → `assertDispatched*`).
11. Simplify `$queryString` `['except' => '']` entries.
12. Update JS: `livewire:load` → `livewire:init`, redesigned hooks, `onPageExpired` → request hook.
