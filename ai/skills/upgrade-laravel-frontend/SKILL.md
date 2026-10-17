---
name: upgrade-laravel-frontend
description: Upgrade or repair the npm frontend toolchain (Laravel Mix, Vite, Tailwind) of a Laravel project. Use when upgrading npm packages, Mix or Vite; when a fresh install fails at `npm install`/`npm ci` (e.g. `lock file's X does not satisfy Y`); when `npm run build`/`production`/`dev` fails, including Mix's `Cannot find module 'webpack/lib/SizeFormatHelpers'` or `Progress Plugin has been initialized using an options object that does not match the API schema`; or when a `composer setup` script calls an npm script the project lacks.
---

# Upgrade or repair the Laravel frontend toolchain

The goal is a **fresh-machine install**: on a clean checkout, `npm ci` succeeds and the production build compiles. Prove it in a throwaway copy. The developer's own `node_modules` hides what a stranger would hit.

## 1. Identify the toolchain

Record before changing anything:

- Bundler: `webpack.mix.js` (Laravel Mix) or `vite.config.*` (Vite), and the installed versions of `laravel-mix` / `vite` / `laravel-vite-plugin` / `tailwindcss` (`npm ls <pkg>`, or `package.json` when `node_modules` is absent).
- `package-lock.json` `lockfileVersion`, and `engines` / `.nvmrc` against `node -v`.
- Every caller of an npm script: `composer.json` `scripts` (often `setup`), CI workflows, deploy scripts, README. Mix projects have `development` / `production` (aliases `dev` / `prod`), Vite projects have `dev` / `build`.

## 2. Outdated stack: ask before choosing a path

When the project runs Laravel Mix (any version), or a Vite or Tailwind major behind the current one (`npm view <pkg> version`), ask the user with AskUserQuestion:

- **Modernise**: move to current Vite (and, if they want, current Tailwind). Go to step 3.
- **Make the current tools work again**: keep the stack, repair install and build. Go to step 4.

A project already on current Vite skips the question and goes to step 4.

## 3. Modernise

1. Run the Laravel Shift **Vite Converter** with `/shift:run` (shift code `VC`). It replaces Mix directly, so a Mix 5 project needs no Mix 6 step first. Review the resulting PR with `/shift:review`.
2. Sweep for leftovers until each item below is accounted for:
   - Blade: no `mix(` calls remain; assets load through `@vite([...])` with the entry points named in `vite.config.js`.
   - Env: `MIX_*` variables renamed to `VITE_*` in `.env.example` and every JS reference (`process.env.MIX_*` becomes `import.meta.env.VITE_*`).
   - JS: `require(...)` converted to `import`; `window.*` globals still set where Blade inline scripts rely on them.
   - Build output: `public/mix-manifest.json` and old compiled `public/css` / `public/js` removed from git, `public/build` and `public/hot` in `.gitignore`. Static assets Mix used to copy (e.g. `resources/img` to `public/img`) still reach `public/`.
   - npm script callers from step 1 now use `npm run build`.
   - Tailwind `content` / `@source` paths still cover every Blade, JS and vendor view the project styles (Filament themes and plugins scan `vendor/...` views).
3. If the user also wants a Tailwind major upgrade, do it as a separate commit after the Vite build works (`npx @tailwindcss/upgrade` for v3 to v4), so a broken build points at one change.
4. Verify (step 5), then load a few pages in the browser: a successful build doesn't prove that the styles and scripts ran.

## 4. Repair the current tools

- **Laravel Mix**: follow [references/laravel-mix-repair.md](references/laravel-mix-repair.md). It covers the npm script names, the webpack version pin Mix 6 needs, and `npm audit` noise.
- **Vite**:
  - Point every npm script caller at a script that exists.
  - Keep `vite` and `laravel-vite-plugin` on matching majors: read `npm view laravel-vite-plugin@<version> peerDependencies`, and do the same for every `@vitejs/plugin-*` and `@tailwindcss/vite`.
  - Check that the installed Node satisfies `npm view vite@<version> engines`. If it doesn't, the fix is a Node version (and `.nvmrc`), not a package change.
  - A peer-dependency conflict gets resolved by aligning versions in `package.json`. `--force` and `--legacy-peer-deps` only hide it from the next machine.

In both cases, rebuild the lockfile from scratch in the throwaway copy (step 5) rather than patching it in place.

## 5. Fresh-machine verification

Work on a copy that holds tracked files only:

```bash
D=<scratchpad>/cleaninstall
rm -rf "$D" && mkdir -p "$D"
git ls-files -z | xargs -0 -I{} rsync -R {} "$D/"
cd "$D" && rm -rf node_modules package-lock.json && npm install   # regenerate the lockfile
rm -rf node_modules && npm ci && npm run <build script>             # what a fresh machine runs
```

An old lockfile (`lockfileVersion` 1) that `npm install` upgrades in place keeps a stale tree that `npm ci` later rejects with `Invalid: lock file's X does not satisfy Y`. Regenerating it from scratch avoids that.

Done when `npm ci` exits 0, the build reports success (Mix: `Compiled successfully`; Vite: `built in …`), and `package.json` is unchanged by the build (Mix sometimes auto-installs missing loaders into it). On failure, fix `package.json`, regenerate, and verify again.

## 6. Bring it back

Copy `package-lock.json` and any `package.json` change into the project and run `npm ci` there so the local `node_modules` matches. Then commit `composer.json`, `package.json` and `package-lock.json` together, plus the Vite conversion files when you took step 3.
