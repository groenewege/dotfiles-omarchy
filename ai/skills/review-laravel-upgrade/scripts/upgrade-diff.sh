#!/usr/bin/env bash
#
# upgrade-diff.sh — gather everything needed to review a Laravel upgrade.
#
# Determines the branch under review, picks the correct comparison base,
# computes the fork point, and reports dependency version bumps plus the
# changed-file set. Output is plain text meant to be read by an agent.
#
# Base-branch rules (override with $1):
#   - branch name contains "upgrade"  -> compare to develop
#   - branch is develop               -> compare to main (or master)
#   - anything else                   -> try develop, then main/master
#
# Usage:
#   scripts/upgrade-diff.sh [base-branch]

set -u

KEY_PACKAGES="php laravel/framework filament/filament livewire/livewire livewire/volt pestphp/pest phpunit/phpunit laravel/boost laravel/tinker laravel/breeze laravel/sanctum"

section() { printf '\n=== %s ===\n' "$1"; }

# Resolve a branch name to a ref that actually exists (local first, then origin/).
resolve_ref() {
    local name="$1"
    if git rev-parse --verify --quiet "refs/heads/$name" >/dev/null; then
        printf 'refs/heads/%s' "$name"
    elif git rev-parse --verify --quiet "refs/remotes/origin/$name" >/dev/null; then
        printf 'refs/remotes/origin/%s' "$name"
    else
        printf ''
    fi
}

first_existing() {
    for name in "$@"; do
        local ref
        ref="$(resolve_ref "$name")"
        if [ -n "$ref" ]; then
            printf '%s' "$ref"
            return 0
        fi
    done
    printf ''
}

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ERROR: not inside a git repository." >&2
    exit 1
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"

section "Branch under review"
echo "current: $CURRENT_BRANCH"

# Pick the comparison base.
BASE_REF=""
if [ "$#" -ge 1 ] && [ -n "${1:-}" ]; then
    BASE_REF="$(resolve_ref "$1")"
    [ -z "$BASE_REF" ] && echo "WARNING: requested base '$1' not found; falling back to auto-detect." >&2
fi

if [ -z "$BASE_REF" ]; then
    case "$CURRENT_BRANCH" in
        *upgrade*)
            BASE_REF="$(first_existing develop main master)" ;;
        develop)
            BASE_REF="$(first_existing main master)" ;;
        main|master)
            BASE_REF="$(first_existing develop)" ;;
        *)
            BASE_REF="$(first_existing develop main master)" ;;
    esac
fi

if [ -z "$BASE_REF" ]; then
    echo "ERROR: could not resolve a comparison base (tried develop/main/master)." >&2
    echo "Re-run with an explicit base: scripts/upgrade-diff.sh <base-branch>" >&2
    exit 1
fi

BASE_NAME="${BASE_REF##*/}"
echo "base:    $BASE_NAME ($BASE_REF)"

# Fork point: only changes introduced on this branch since it diverged.
MERGE_BASE="$(git merge-base HEAD "$BASE_REF" 2>/dev/null)"
if [ -z "$MERGE_BASE" ]; then
    echo "WARNING: no common ancestor with $BASE_REF; diffing against branch tip instead." >&2
    MERGE_BASE="$BASE_REF"
fi
echo "fork point: $MERGE_BASE"
echo "(review the diff: git diff $MERGE_BASE...HEAD)"

# Dependency version bumps, before -> after.
pkg_line_base() { git show "$MERGE_BASE:composer.json" 2>/dev/null | grep -E "\"$1\"[[:space:]]*:" | head -1 | sed 's/^[[:space:]]*//; s/,$//'; }
pkg_line_head() { grep -E "\"$1\"[[:space:]]*:" composer.json 2>/dev/null | head -1 | sed 's/^[[:space:]]*//; s/,$//'; }

section "Dependency version changes (composer.json: base -> HEAD)"
if [ ! -f composer.json ]; then
    echo "(no composer.json in working tree)"
else
    for pkg in $KEY_PACKAGES; do
        before="$(pkg_line_base "$pkg")"
        after="$(pkg_line_head "$pkg")"
        if [ "$before" != "$after" ]; then
            printf '  %-22s\n      before: %s\n      after:  %s\n' "$pkg" "${before:-<absent>}" "${after:-<absent>}"
        fi
    done
    echo "(packages not listed above are unchanged between base and HEAD)"
fi

section "Candidate upgrade-step boundaries (commits that changed the laravel/framework constraint)"
git log --oneline --no-decorate -G '"laravel/framework"' "$MERGE_BASE..HEAD" -- composer.json 2>/dev/null || true
echo "(Each commit above is likely the edge of one upgrade step — review each step's diff against ITS OWN guide,"
echo " e.g. git diff <prev-step>..<this-step>. A guide item skipped in one step hides when the whole range is read at once.)"

section "Lock-file consistency & dependency health (audit non-first-party packages too)"
if command -v composer >/dev/null 2>&1; then
    echo "- composer validate (is composer.lock in sync with composer.json?):"
    composer validate --no-check-publish --no-check-all 2>&1 | sed 's/^/    /' | head -20
    echo "- direct dependencies behind their latest (composer outdated --direct; may need network/vendor):"
    composer outdated --direct --no-interaction 2>/dev/null | sed 's/^/    /' | head -40 || echo "    (unavailable — run 'composer outdated --direct' manually)"
else
    echo "(composer binary not found — manually confirm composer.lock is in sync and every third-party package supports the target Laravel)"
fi
echo "(Flag any third-party package with no release for the target Laravel, anything abandoned, or constraints still pinned to the old major / widened to * just to resolve.)"

section "Config files changed (inspect for silently dropped keys)"
git diff --name-only "$MERGE_BASE...HEAD" -- config/ 2>/dev/null || true
echo "(also check for config files that were DELETED — streamlined configs lose hardcoded keys)"

section "Changed file counts by area"
git diff --name-status "$MERGE_BASE...HEAD" 2>/dev/null \
    | awk '{
        path=$2
        if (path ~ /^app\/Filament\//) a["app/Filament"]++
        else if (path ~ /^app\/Livewire\// || path ~ /^app\/Http\/Livewire\//) a["app/Livewire"]++
        else if (path ~ /^app\//) a["app (other)"]++
        else if (path ~ /^resources\/views\//) a["resources/views"]++
        else if (path ~ /^resources\/js\//) a["resources/js"]++
        else if (path ~ /^config\//) a["config"]++
        else if (path ~ /^database\//) a["database"]++
        else if (path ~ /^tests\//) a["tests"]++
        else if (path ~ /^routes\//) a["routes"]++
        else a["other"]++
    } END { for (k in a) printf "  %-20s %d\n", k, a[k] }' \
    | sort

section "Full changed file list"
git diff --name-status "$MERGE_BASE...HEAD" 2>/dev/null || true

section "Commit log on this branch"
git log --oneline --no-decorate "$MERGE_BASE..HEAD" 2>/dev/null | head -40 || true

echo
echo "Done. Use the version changes above to decide which upgrade-* skills to activate,"
echo "then scan the WHOLE codebase (not just the diff) for the deprecated patterns each skill lists."
