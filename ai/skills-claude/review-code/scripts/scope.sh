#!/usr/bin/env bash
#
# scope.sh — resolve what /review-code should look at.
#
# Prints a plain-text description of the review target (mode, files, and
# the exact git command that produces the diff) for an agent to read.
#
# Resolution rules:
#   no argument, working tree dirty  -> worktree  (staged + unstaged + untracked)
#   no argument, working tree clean  -> commit    (HEAD)
#   integer N                        -> range     (last N commits, HEAD~N..HEAD)
#   a..b / a...b                     -> range
#   commit hash or tag               -> commit
#   branch name                      -> branch    (vs merge-base with develop/main/master)
#   existing path(s)                 -> path      (whole files, working tree)
#
# Usage:
#   scripts/scope.sh [<hash> | <N> | <a..b> | <branch> | <path> ...] [--spec <value>]
#   (--spec is ignored here; the skill reads the spec itself)

set -u

REPORT_FILE="review-code-report.html"

section() { printf '\n=== %s ===\n' "$1"; }
die() { echo "ERROR: $*" >&2; exit 1; }

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    die "not inside a git repository."
fi

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT" || die "cannot cd to repository root."

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

is_branch() { [ -n "$(resolve_ref "$1")" ]; }
is_commit() { git rev-parse --verify --quiet "${1}^{commit}" >/dev/null 2>&1; }

# Print name-status + numstat for a diff spec, excluding the report file.
print_files() {
    # $@ = arguments to `git diff`
    local status numstat
    status="$(git diff --name-status "$@" 2>/dev/null | grep -v -F "$REPORT_FILE" || true)"
    numstat="$(git diff --numstat "$@" 2>/dev/null | grep -v -F "$REPORT_FILE" || true)"
    if [ -z "$status" ]; then
        echo "(no changed files)"
        return
    fi
    echo "$status" | while IFS=$'\t' read -r st path rest; do
        # renames carry two paths; show the new one
        [ -n "${rest:-}" ] && path="$rest"
        lines="$(echo "$numstat" | awk -v p="$path" '$3 == p { printf "+%s/-%s", $1, $2 }')"
        printf '  %-3s %-60s %s\n' "$st" "$path" "${lines:-}"
    done
}

MODE=""
TARGET=""
DIFF_CMD=""
ARGS=()

# Drop "--spec <value>" (or "--spec=<value>"): the spec is read by the skill, not
# here, and must not be mistaken for a path or a ref.
while [ "$#" -gt 0 ]; do
    case "$1" in
        --spec)
            [ "$#" -ge 2 ] || die "--spec needs a value (a file path or a Notion URL)."
            shift 2
            ;;
        --spec=*)
            shift
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

# ----------------------------------------------------------------------------
# No argument: working tree, else last commit.
# ----------------------------------------------------------------------------
if [ "${#ARGS[@]}" -eq 0 ]; then
    if [ -n "$(git status --porcelain --untracked-files=all | grep -v -F "$REPORT_FILE")" ]; then
        MODE="worktree"
        TARGET="uncommitted changes (staged + unstaged + untracked) on $(git rev-parse --abbrev-ref HEAD)"
        DIFF_CMD="git diff HEAD"
    else
        MODE="commit"
        TARGET="HEAD ($(git log -1 --format='%h %s'))"
        DIFF_CMD="git show --format= HEAD"
    fi

# ----------------------------------------------------------------------------
# Single argument: N, range, commit, branch. Several arguments: paths.
# ----------------------------------------------------------------------------
elif [ "${#ARGS[@]}" -eq 1 ]; then
    ARG="${ARGS[0]}"
    if [[ "$ARG" =~ ^[0-9]+$ ]]; then
        [ "$ARG" -ge 1 ] || die "number of commits must be at least 1."
        if ! is_commit "HEAD~$ARG"; then
            die "HEAD~$ARG does not exist (the branch has fewer than $((ARG + 1)) commits)."
        fi
        MODE="range"
        TARGET="last $ARG commit(s): HEAD~$ARG..HEAD"
        DIFF_CMD="git diff HEAD~$ARG..HEAD"
    elif [[ "$ARG" == *".."* ]]; then
        if ! git rev-parse --verify --quiet "$ARG" >/dev/null 2>&1 && ! git rev-list --quiet "$ARG" >/dev/null 2>&1; then
            die "range '$ARG' does not resolve."
        fi
        MODE="range"
        TARGET="range $ARG"
        DIFF_CMD="git diff $ARG"
    elif [ -e "$ARG" ]; then
        MODE="path"
        TARGET="path $ARG (working tree content)"
        DIFF_CMD=""
    elif is_branch "$ARG"; then
        BRANCH_REF="$(resolve_ref "$ARG")"
        BASE_REF=""
        for base in develop main master; do
            [ "$base" = "$ARG" ] && continue
            BASE_REF="$(first_existing "$base")"
            [ -n "$BASE_REF" ] && break
        done
        [ -n "$BASE_REF" ] || die "branch '$ARG' found but no base branch (develop/main/master) to compare against."
        MERGE_BASE="$(git merge-base "$BRANCH_REF" "$BASE_REF" 2>/dev/null)"
        [ -n "$MERGE_BASE" ] || die "no common ancestor between '$ARG' and ${BASE_REF##*/}."
        MODE="branch"
        TARGET="branch $ARG vs ${BASE_REF##*/} (fork point $(git rev-parse --short "$MERGE_BASE"))"
        DIFF_CMD="git diff $MERGE_BASE...$BRANCH_REF"
    elif is_commit "$ARG"; then
        MODE="commit"
        TARGET="commit $(git log -1 --format='%h %s' "$ARG")"
        DIFF_CMD="git show --format= $ARG"
    else
        die "'$ARG' is not a commit, range, branch, path, or number of commits."
    fi
else
    for p in "${ARGS[@]}"; do
        [ -e "$p" ] || die "path '$p' does not exist (several arguments are only accepted as paths)."
    done
    MODE="path"
    TARGET="paths: ${ARGS[*]} (working tree content)"
    DIFF_CMD=""
fi

# ----------------------------------------------------------------------------
# Output
# ----------------------------------------------------------------------------
section "Mode"
echo "$MODE"

section "Repository"
echo "root:   $ROOT"
echo "branch: $(git rev-parse --abbrev-ref HEAD)"

section "Target"
echo "$TARGET"

section "Diff command"
case "$MODE" in
    worktree)
        echo "$DIFF_CMD                       # tracked files, staged + unstaged"
        echo "(untracked files have no diff: read each one in full)"
        ;;
    path)
        echo "(none: read the listed files in full; there is no diff for a path target)"
        ;;
    *)
        echo "$DIFF_CMD"
        ;;
esac

section "Changed files"
case "$MODE" in
    worktree)
        print_files HEAD
        UNTRACKED="$(git ls-files --others --exclude-standard | grep -v -F "$REPORT_FILE" || true)"
        if [ -n "$UNTRACKED" ]; then
            echo "$UNTRACKED" | while IFS= read -r f; do
                if [ -f "$f" ]; then
                    printf '  %-3s %-60s +%s (untracked, new file)\n' "??" "$f" "$(wc -l < "$f" | tr -d ' ')"
                else
                    printf '  %-3s %s\n' "??" "$f"
                fi
            done
        fi
        ;;
    commit)
        COMMIT="${DIFF_CMD#git show --format= }"
        if is_commit "$COMMIT~1"; then
            print_files "$COMMIT~1" "$COMMIT"
        else
            echo "(root commit: every file below is new)"
            git diff-tree --root -r --name-status "$COMMIT" | tail -n +2 | grep -v -F "$REPORT_FILE" | sed 's/^/  /'
        fi
        ;;
    range|branch)
        # shellcheck disable=SC2086
        print_files ${DIFF_CMD#git diff }
        ;;
    path)
        for p in "${ARGS[@]}"; do
            if [ -d "$p" ]; then
                git ls-files -- "$p" | grep -v -F "$REPORT_FILE" | sed 's/^/  /'
            else
                echo "  $p"
            fi
        done
        ;;
esac

section "Excluded"
echo "$REPORT_FILE (the review's own output, never in scope)"
echo "Anything not listed above is out of scope: do not read it for findings, do not report on it."
