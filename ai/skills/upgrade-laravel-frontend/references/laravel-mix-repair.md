# Laravel Mix: keep it building

Mix-specific fixes for the repair path. The fresh-copy regeneration and verification are steps 5 and 6 of [SKILL.md](../SKILL.md).

## Point scripts at npm scripts that exist

Laravel Mix projects have `development` / `production` (aliases `dev` / `prod`), not Vite's `build`. Fix every caller (`composer.json` `scripts.setup`, CI, deploy scripts, README) to use `npm run production`, or add a `"build": "npm run production"` alias if the user prefers.

## Pin webpack for Mix 6

`laravel-mix@6.0.49` (latest; unmaintained since 2025) accepts any `webpack@^5`, but a fresh resolve picks a webpack that breaks it:

| webpack | Mix build result |
|---|---|
| ≤ 5.105.x | compiles |
| 5.106.x | `Progress Plugin ... options object that does not match the API schema` (webpackbar's options rejected) |
| ≥ 5.107 | `Cannot find module 'webpack/lib/SizeFormatHelpers'` (file removed) |

Fix in `package.json`, so every nested copy dedupes to one version:

```json
"overrides": { "webpack": "~5.105.4" }
```

Verified October 2026 on Node 24 / npm 11. Before pinning on a later date, check `npm view laravel-mix version`: a newer Mix release may have lifted the incompatibility. The pin stays until the project moves to Vite.

## Mix 5 and older

Mix 5 runs on webpack 4, which needs the legacy OpenSSL provider on Node 17+ (`error:0308010C:digital envelope routines::unsupported`). Prefer moving to Mix 6 (Shift Workbench task `upgrade-to-mix-6` via `/shift:refactor`) over setting `NODE_OPTIONS=--openssl-legacy-provider` in every script. If the user wants that much change anyway, the Vite path of SKILL.md is usually the better use of it.

## `npm audit`

`npm audit` reports many vulnerabilities from the old Mix toolchain. They are out of scope for this repair: mention them, and leave `npm audit fix --force` alone, since it makes breaking upgrades.
