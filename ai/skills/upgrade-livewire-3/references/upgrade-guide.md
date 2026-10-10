# Livewire v2 → v3 Official Upgrade Guide

This is the complete official upgrade guide, kept verbatim for reference. The SKILL.md summarizes the high-traffic changes; consult this file for the full detail and edge cases.

## Automated upgrade tool

After installing Livewire version 3, run the following command, and you will receive prompts to upgrade each breaking change automatically:

```shell
php artisan livewire:upgrade
```

Although the above command can upgrade much of your application, the only way to ensure a complete upgrade is to follow the step-by-step guide.

## Upgrade PHP

Livewire now requires that your application is running on PHP version 8.1 or greater.

## Update Livewire to version 3

```shell
composer require livewire/livewire "^3.0"
```

> Most major third-party Livewire packages either support Livewire 3 or are working on it. Some packages may take longer to release support.

## Clear the view cache

```shell
php artisan view:clear
```

## Merge new configuration

If your application has a published configuration file (`config/livewire.php`), update it for the following changes.

### New configuration

```php
'legacy_model_binding' => false,
'inject_assets' => true,
'inject_morph_markers' => true,
'navigate' => false,
'pagination_theme' => 'tailwind',
```

Reference: https://github.com/livewire/livewire/blob/master/config/livewire.php

### Changed configuration

#### New class namespace

Default `class_namespace` changed from `App\Http\Livewire` to `App\Livewire`. You may keep the old namespace; if you update it, move your components to `app/Livewire`:

```php
'class_namespace' => 'App\\Http\\Livewire', // [remove]
'class_namespace' => 'App\\Livewire',       // [add]
```

#### New layout view path

Default full-page layout changed from `resources/views/layouts/app.blade.php` to `resources/views/components/layouts/app.blade.php`:

```php
'layout' => 'layouts.app',            // [remove]
'layout' => 'components.layouts.app', // [add]
```

### Removed configuration

- **`app_url`** — replaced by runtime configuration of Livewire's update endpoint.
- **`asset_url`** — replaced by runtime configuration of the script asset endpoint.
- **`middleware_group`** — replaced by the more flexible update-endpoint customization.
- **`manifest_path`** — Livewire 3 no longer uses a manifest file.
- **`back_button_cache`** — no longer necessary now that `wire:navigate` exists.

## Livewire app namespace

v2 components lived under `App\Http\Livewire`. v3 defaults to `App\Livewire`. Either move components or set:

```php
'class_namespace' => 'App\\Http\\Livewire',
```

### Discovery

There is no manifest in v3 — nothing to "discover." Remove any `livewire:discover` references from build scripts.

## Page component layout view

When rendering Livewire components as full pages (`Route::get('/posts', ShowPosts::class);`), the layout file moved from `resources/views/layouts/app.blade.php` to `resources/views/components/layouts/app.blade.php`. Move the file or set `'layout' => 'layouts.app'`.

## Eloquent model binding

v2 supported `wire:model` binding directly to Eloquent model properties:

```php
public Post $post;

protected $rules = [
    'post.title' => 'required',
    'post.description' => 'required',
];
```

```html
<input wire:model="post.title">
<input wire:model="post.description">
```

v3 disables this in favor of individual properties or Form Objects, but you can restore the v2 behavior:

```php
'legacy_model_binding' => true,
```

## AlpineJS

Livewire 3 ships with AlpineJS by default. Remove any manual Alpine includes so they don't conflict.

### Including Alpine via a script tag

```html
<script defer src="https://cdn.jsdelivr.net/npm/alpinejs@3.x.x/dist/cdn.min.js"></script> <!-- remove -->
```

### Including plugins via a script tag

v3 ships with these Alpine plugins out of the box: Anchor, Collapse, Focus, Intersect, Mask, Morph, Persist. Remove any matching `<script>` tags. Keep an eye on Livewire's `package.json` for newly bundled plugins.

### Accessing the Alpine global via a script tag

This still works — Livewire registers Alpine's global internally:

```html
<script>
    document.addEventListener('alpine:init', () => {
        Alpine.data(...)
    })
</script>
```

### Including via JS bundle

If you imported Alpine or bundled plugins via NPM, remove them — Livewire includes them by default.

#### Accessing Alpine via JS bundle

To register custom Alpine plugins via your bundle, first replace `@livewireScripts` with `@livewireScriptConfig` in your layout:

```blade
    @livewireScripts      <!-- remove -->
    @livewireScriptConfig <!-- add -->
</body>
```

Then import from Livewire's ESM module:

```js
import { Livewire, Alpine } from '../../vendor/livewire/livewire/dist/livewire.esm';
import customPlugin from './plugins/custom-plugin'

Alpine.plugin(customPlugin)

Livewire.start()
```

You no longer call `Alpine.start()` — Livewire starts Alpine automatically.

## `wire:model`

In v3, `wire:model` is deferred by default. To match v2 behavior, use `wire:model.live`:

```html
<input wire:model="...">      <!-- v2 --> → <input wire:model.live="..."> <!-- v3 -->
<input wire:model.defer="..."> <!-- v2 --> → <input wire:model="...">      <!-- v3 -->
<input wire:model.lazy="...">  <!-- v2 --> → <input wire:model.blur="..."> <!-- v3 -->
```

## `@entangle`

`@entangle` is also deferred by default now:

```blade
@entangle(...)        <!-- v2 --> → @entangle(...).live <!-- v3 -->
@entangle(...).defer  <!-- v2 --> → @entangle(...)      <!-- v3 -->
```

## Events

v2 had `emit()` and `dispatchBrowserEvent()`. v3 unifies both into `dispatch()`.

```php
// Dispatching...
class CreatePost extends Component
{
    public Post $post;

    public function save()
    {
        $this->dispatch('post-created', postId: $this->post->id);
    }
}

// Listening...
class Dashboard extends Component
{
    #[On('post-created')]
    public function postAdded($postId)
    {
        //
    }
}
```

Three main changes:

1. `emit()` → `dispatch()` (`emitTo()` → `dispatch()->to()`, `emitSelf()` → `dispatch()->self()`)
2. `dispatchBrowserEvent()` → `dispatch()`
3. All event parameters must be named

PHP find/replace:

```php
$this->emit('post-created');                                 // → $this->dispatch('post-created');
$this->emitTo('foo', 'post-created');                        // → $this->dispatch('post-created')->to('foo');
$this->emitSelf('post-created');                             // → $this->dispatch('post-created')->self();
$this->emit('post-created', $post->id);                      // → $this->dispatch('post-created', postId: $post->id);
$this->dispatchBrowserEvent('post-created');                 // → $this->dispatch('post-created');
$this->dispatchBrowserEvent('post-created', ['postId' => $post->id]); // → $this->dispatch('post-created', postId: $post->id);
```

Blade find/replace:

```html
<button wire:click="$emit('post-created')">          → <button wire:click="$dispatch('post-created')">
<button wire:click="$emit('post-created', 1)">       → <button wire:click="$dispatch('post-created', { postId: 1 })">
<button wire:click="$emitTo('foo', 'post-created', 1)"> → <button wire:click="$dispatch('post-created', { postId: 1 })->to('foo')">
<button x-on:click="$wire.emit('post-created', 1)">  → <button x-on:click="$dispatch('post-created', { postId: 1 })">
```

### `emitUp()`

Removed entirely. Events are browser events and bubble up by default. Remove every `$this->emitUp(...)` / `$emitUp(...)`.

### Testing events

```php
->assertEmitted('post-created')              // → ->assertDispatched('post-created')
->assertEmittedTo(Foo::class, 'post-created')// → ->assertDispatchedTo(Foo::class, 'post-created')
->assertNotEmitted('post-created')           // → ->assertNotDispatched('post-created')
->assertEmittedUp()                          // removed
```

### URL query string

In v3, properties bound to the query string only appear once changed from the page-load value, removing the need for `except`:

```php
public $search = '';

protected $queryString = [
    'search' => ['except' => ''], // [remove]
    'search',                     // [add]
];
```

To always show a property (v2 behavior), use `['keep' => true]`:

```php
protected $queryString = [
    'search' => ['keep' => true],
];
```

## Pagination

The pagination system was updated to support multiple paginators per component.

### Update published pagination views

If you published Livewire's pagination views, reference the new ones at:
https://github.com/livewire/livewire/tree/master/src/Features/SupportPagination/views

### Accessing `$this->page` directly

The `$page` property was replaced with a `$paginators` array:

```php
$this->page = 2;              // → $this->paginators['page'] = 2;
```

Prefer the provided methods:

```php
$this->getPage();   // getter
$this->setPage(2);  // setter
```

### `wire:click.prefetch`

Removed entirely. Your app still works, just without prefetch performance.

```html
<button wire:click.prefetch=""> → <button wire:click="...">
```

## Component class changes

### The component `$id` property

```php
$this->id;       // → $this->getId();
```

### Duplicate method and property names

PHP allows a class property and method with the same name. In v3 this breaks calling methods from the frontend via `wire:click`. Use distinct names:

```php
public $search = ''; // [remove — conflicts with search() method]
public $query = '';  // [add]

public function search() {
    // ...
}
```

## JavaScript API changes

### `livewire:load`

```js
document.addEventListener('livewire:load', () => {...}) // → 'livewire:init'
```

### Page expired hook

`Livewire.onPageExpired()` was removed in favor of `request` hooks:

```js
Livewire.hook('request', ({ fail }) => {
    fail(({ status, preventDefault }) => {
        if (status === 419) {
            preventDefault()
            confirm('Your custom page expiration behavior...')
        }
    })
})
```

### New lifecycle hooks

```js
Livewire.hook('component.initialized', (component) => {})       // → Livewire.hook('component.init', ({ component, cleanup }) => {})
Livewire.hook('element.initialized', (el, component) => {})     // → Livewire.hook('element.init', ({ el, component }) => {})
Livewire.hook('element.updating', (fromEl, toEl, component) => {}) // → Livewire.hook('morph.updating', ({ el, toEl, component }) => {})
Livewire.hook('element.updated', (el, component) => {})         // → Livewire.hook('morph.updated', ({ el, component }) => {})
Livewire.hook('element.removed', (el, component) => {})         // → Livewire.hook('morph.removed', ({ el, component }) => {})

// The four message.* hooks collapse into 'commit':
Livewire.hook('message.sent', ...)       // removed
Livewire.hook('message.failed', ...)     // removed
Livewire.hook('message.received', ...)   // removed
Livewire.hook('message.processed', ...)  // removed

Livewire.hook('commit', ({ component, commit, respond, succeed, fail }) => {
    // 'message.sent' equivalent
    succeed(({ snapshot, effects }) => {
        // 'message.received' equivalent
        queueMicrotask(() => {
            // 'message.processed' equivalent
        })
    })
    fail(() => {
        // 'message.failed' equivalent
    })
})
```

## Localization

If your app uses a locale prefix (`https://example.com/en/...`), v2 auto-preserved it for `livewire/update`. v3 does not — override the update endpoint:

```php
Route::group(['prefix' => LaravelLocalization::setLocale()], function () {
    // Your other localized routes...

    Livewire::setUpdateRoute(function ($handle) {
        return Route::post('/livewire/update', $handle);
    });
});
```
