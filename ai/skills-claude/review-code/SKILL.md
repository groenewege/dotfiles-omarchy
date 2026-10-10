---
name: review-code
description: Multi-lane review of a change set (correctness, project best practices, security, and with --spec conformance to a brief) run as parallel reviewers, merged into one prioritised punch list, reported only, never applied. Different from the built-in /code-review (a single correctness pass that can also fix) and from review-laravel-upgrade (framework upgrade audits). Defaults to the uncommitted working tree, falls back to the last commit; also accepts a commit hash, a number of last commits, a ref range, a branch, or a path. --spec <file | notion-url> adds a lane that checks the change against the brief it implements.
argument-hint: "[<hash> | <N last commits> | <a..b> | <branch> | <path>] [--spec <file | notion-url>]"
disable-model-invocation: true
---

# Reviewing a change set

Run three independent reviews of the same change set, plus a fourth when a spec
is given, merge them, and hand the user a report they can act on. The lanes are
deliberately narrow: one hunts bugs, one checks the project's conventions, one
looks for vulnerabilities, and the Spec lane checks that the change does what the
brief asked, no less and no more. Keeping them apart is what makes each one
thorough; a single reviewer asked to do all of it at once tends to do the easy
one (conventions) and skim the rest. Code can pass every defect lane and still
build the wrong thing, which only the Spec lane sees.

**This review is strictly read-only.** Do not change any code, config, tests,
or other project files, not even an obvious one-line fix for something you
find. The only file the review may create is the HTML report in Step 5.
Findings describe the fix; the user applies it.

Arguments given: `$ARGUMENTS`

## Step 1 — Resolve the scope

Run the scope script from the repository you are reviewing:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/scope.sh" $ARGUMENTS
```

It prints the mode, the target, the exact diff command, and the changed file
list. Resolution rules, so you can sanity-check what it chose:

| Arguments | Mode | What is reviewed |
|---|---|---|
| none, working tree dirty | `worktree` | staged + unstaged changes, plus untracked files |
| none, working tree clean | `commit` | the last commit |
| a number `N` | `range` | the last N commits |
| `a..b` | `range` | that range |
| a hash or tag | `commit` | that commit |
| a branch name | `branch` | the branch against its fork point from develop/main/master |
| one or more paths | `path` | those files, whole content as they are now |
| any of the above plus `--spec <value>` | unchanged | the script ignores the pair; see Step 1b |

If the script exits non-zero, stop and show the user its error. Do not guess a
target. If the user's request is something the script cannot express (for
example "the two commits before the last one"), translate it into a range or
hash yourself and pass that.

The file list is the whole universe of this review. Unrelated work in progress
elsewhere in the working tree is off limits for findings and must not be
mentioned. Keep the script's output; every lane gets it verbatim.

## Step 1b — Resolve the spec (only with `--spec`)

Without `--spec`, skip this step; the Spec lane does not run and the report says
so. With it, load the spec text yourself, so the lane receives it verbatim and
needs no Notion access of its own:

- **A file path**: read it in full. `/task` writes one with the brief (GOAL,
  REQUIREMENTS, OUT OF SCOPE) and the decisions taken at its plan gate.
- **A Notion URL**: fetch the page with the Notion tools: its title, the brief
  sections of the body (GOAL, REQUIREMENTS, OUT OF SCOPE), and its comments,
  which may record later decisions. Leave out REFERENCES; they are paths, not
  requirements.

If the spec cannot be loaded (file missing, no Notion tools, page empty), say so
and run the other three lanes; the report states "Spec: not run" with the reason.
Never review against a spec you guessed.

## Step 2 — Run the lanes in parallel

Read `references/lanes.md` once yourself, so you know what each lane is
supposed to return. Then launch three `Agent` calls, four when a spec was
loaded, **in a single message**, `subagent_type: general-purpose`, one per lane.
Each prompt contains:

1. The repository root and the full scope output from Step 1, verbatim.
2. The instruction to read `${CLAUDE_SKILL_DIR}/references/lanes.md`,
   section 1 (shared rules) and its own lane section (2, 3, 4, or 5).
3. The shared constraints restated in one line, because a subagent that skims
   the reference still needs to see them: review only the listed files, report
   only, never edit, punch list with `file:line`, evidence bar.
4. What to return: the punch list, the "Worth a look" list, and the "Clean"
   line, in the format from section 1.

Lane specifics:

- **Lane 1, Correctness.** Tell it the scope mode and the argument to pass to
  the `code-review` skill if that skill is available to it (section 2 has the
  mapping), and that it must never pass `--fix`.
- **Lane 2, Best practices.** Tell it the repository root so it can locate
  `composer.json`, a `laravel-best-practices` skill, `CLAUDE.md`, and
  `.ai/guidelines`. If the project is not Laravel and has no `CLAUDE.md`,
  still launch it; section 3 tells it to report "no rule set" and stop.
- **Lane 3, Security.** Tell it the scope mode, so it knows whether the
  `security-review` skill fits (`worktree` and `branch` only) or it must review
  inline against the checklist.
- **Lane 4, Spec.** Only when Step 1b loaded a spec. Paste the spec text in
  full; it has no other access to it.

Do not do any reviewing yourself while they run. Wait for all of them.

## Step 3 — Aggregate

Apply section 6 of `references/lanes.md`: deduplicate across the three defect
and convention lanes (keep the correctness finding over the convention one on the
same line, the security finding over both), order Security → Spec → Correctness →
Conventions, keep each lane's internal ranking, and classify every surviving item
as a clear correction, a judgment call, or a false positive. Spec findings are
never merged into or dropped in favour of another lane's finding, and never the
reverse: a missing requirement and a bug on the same line are two findings.

Before you accept a lane's finding, glance at the cited lines yourself. A lane
occasionally reports a line from the old side of the diff or from a file it was
told to ignore; fix the reference or drop the item. Do not re-run the lanes'
work, just confirm the pointer is right.

## Step 4 — Report in the conversation

Use this structure. No "Test plan" section.

```
## Review: <target, one line>

<one-paragraph verdict: is this safe to ship, does it do what the brief asked,
and what is the single most important thing to fix>

### Security
- **S1** `path:line` — <defect>. <who sends what and what they get>.
  Fix: <described>.
- skipped: `path:line` — <what was flagged> — <judgment call / false positive, why>
(or: Clean. Checked: <dimensions>.)

### Spec
- **R1** `path:line` (or "nowhere in the change") — <missing / partial / not
  asked for / wrong / open question settled silently>. Spec: "<quoted line>".
  Fix: <described>.
(or: Matches the spec. Checked: <n> requirements, out of scope.)
(or: Not run: no spec given / <why it could not be loaded>.)

### Correctness
- **C1** `path:line` — <defect>. <input/state → wrong outcome>. Fix: <described>.
(or: Clean. Checked: <dimensions>.)

### Conventions
- **V1** `path:line` — <breach>, per <rule cited>. Fix: <described>.
(or: Clean. Checked against: <rule set used>.)

### Could not verify
- <what, and what would be needed>
```

Every group is present even when empty, because "clean" and "not checked" must
read differently. Keep the fix descriptions concrete enough to apply without
re-reading the finding. If a lane could not run (skill unavailable, no rule
set), say so under its group rather than silently reporting clean.

## Step 5 — HTML page when the report is long

A short report belongs in the conversation. Once it grows past a few
paragraphs (rule of thumb: more than six findings in total, or more than
about forty lines), the terminal stops being a good place to read it:

1. Fill `${CLAUDE_SKILL_DIR}/assets/report-template.html`. Replace every
   `{{PLACEHOLDER}}`; the comment at the bottom of the template shows the
   snippet for a finding, a clean group, a skipped list, and the could-not-verify
   list. Remove that comment from the output. Set the verdict class to
   `has-security` when there is at least one security finding, else
   `has-spec` when there is a spec finding, else `has-correctness` when there
   is a correctness finding, else leave it empty. `{{SPEC_SOURCE}}` is the spec
   file or Notion URL; without a spec it is "none", `{{SPEC}}` holds the
   "Not run" line and `{{N_SPEC}}` is `–`.
2. Write it to `<repository root>/review-code-report.html`. The scope script
   already excludes that file from future reviews. Then `open` it.
3. In the conversation, keep only the verdict paragraph, one line per group
   with counts (and the top finding's id and file if any), the "Could not
   verify" list, and the path of the HTML file.

The HTML report is the only file this skill may write.
