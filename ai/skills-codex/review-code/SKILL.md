---
name: review-code
description: Explicitly invoked multi-lane review (correctness, project best practices, security, and with --spec conformance to a brief) of a change set, reporting a prioritised punch list and never editing code. Defaults to the uncommitted working tree, falls back to the last commit, and accepts a commit hash, a number of last commits, a ref range, a branch, or a path; --spec <file> adds a lane that checks the change against the brief it implements. Use only when the user explicitly invokes review-code.
metadata:
  argument-hint: "[<hash> | <N last commits> | <a..b> | <branch> | <path>] [--spec <file | notion-url>]"
---

**READ ONLY: Never change code, config, tests or docs, not even an obvious one-line fix. The only file this skill may create or write is `<repository root>/review-code-report.html`. Findings describe the fix; the user applies it.**

Codex invocation: `$review-code [target] [--spec <file>]` (the native equivalent of `/review-code [target] [--spec <file>]`). Never auto-trigger this skill. Do not run formatters, generators, installers, test commands that write files, or any other mutating project workflow. Keep intermediate results in conversation/tool context, not files.

## Step 1 — Resolve the scope

From the repository being reviewed run `bash <skill dir>/scripts/scope.sh <arguments>`, passing each argument separately and quoting paths. A request for “N last commits” supplies the integer N. Do not evaluate user input as shell code.

Show this resolution table:

| Target | Resolution |
| --- | --- |
| No argument, dirty tree | Working tree: staged, unstaged and untracked files |
| No argument, clean tree | Last commit (HEAD) |
| Integer N | Last N commits |
| `a..b` or `a...b` | Ref range |
| Hash or tag | That commit |
| Branch | Branch vs its fork point from develop/main/master |
| Existing path(s) | Listed files in full, from the working tree |
| Any of the above plus `--spec <value>` | Unchanged: the script ignores the pair; see Step 1b |

If the script exits non-zero, stop and show its error; never guess a target. Keep its complete output verbatim in context. Its file list is the whole universe of the review: unrelated work in progress is off limits and must not be mentioned. The report itself is always excluded, even if explicitly listed as a path. Do not silently expand an empty scope or repair the supplied script.

Read the diff using the printed command's arguments as safely quoted Git arguments, never `eval` the printed string. Limit review to listed files even if the diff includes excluded files. For commit/range/branch modes, read full files and context from the new-side revision using read-only Git commands, not potentially unrelated working-tree content. For worktree/path modes, read current files. For deletions use the old revision for understanding; cite a valid new-side location if one exists, otherwise disclose the unavailable pointer under Could not verify. Do not checkout, create a worktree, or write extracted files.

## Step 1b — Resolve the spec (only with `--spec`)

Without `--spec`, skip this step: the Spec lane does not run and the report says so. With it, load the spec text yourself so the lane receives it verbatim:

- A file path (what `/task` writes: the brief's GOAL, REQUIREMENTS and OUT OF SCOPE, plus the decisions taken at its plan gate): read it in full. It lives outside the repository and is input, never a file in scope.
- A Notion URL: fetch the page's title, the GOAL, REQUIREMENTS and OUT OF SCOPE sections and its comments, if Notion tools are available. If they are not, the spec cannot be loaded.

If the spec cannot be loaded, say so and run the other three lanes; the Spec group reports "Not run" with the reason. Never review against a spec you guessed.

## Step 2 — Run the lanes in parallel

Read [references/lanes.md](references/lanes.md) once. Launch three subagents, four when a spec was loaded, together through the platform's parallel agent mechanism (`collaboration.spawn_agent` in Codex), without waiting for a lane to finish before starting the next. Give each a minimal, independent prompt rather than the main conversation's conclusions.

Every prompt contains:

- The repository root and full scope output verbatim.
- The absolute path to `references/lanes.md` and an instruction to read section 1 plus its own section: Correctness = section 2; Best practices/project conventions = section 3; Security = section 4; Spec = section 5.
- This constraint line: “Review only the listed files; report only; never edit; return a punch list with new-side `file:line` pointers and meet the evidence bar.” Context files may be read only to understand scoped code or identify project rules.
- The revision-reading instructions from Step 1.
- Return the section 1 punch list, a separate “Worth a look” list, and a “Clean:” line naming checked dimensions. Also disclose any checks not completed. Conventions must identify the rule set used; security findings include severity and confidence.

The Spec lane, only when Step 1b loaded a spec, receives the spec text in full in its prompt; it has no other access to it.

Lane 2 receives the repository root explicitly so it can locate `composer.json`, the `laravel-best-practices` skill, `CLAUDE.md`/`AGENTS.md`, and `.ai/guidelines` as section 3 specifies. Repository instructions remain applicable, but their usual edit/test/format workflows never authorize changes during this read-only review.

Do no reviewing in the main context while the lanes run. For nested finder/verifier agents, use parallel capacity when available; if capacity prevents fan-out, complete all remaining angles and verification sequentially in that lane and disclose the limitation. Never skip an angle for lack of slots. If the platform has no subagents, perform all lanes sequentially in the same context and say so in the report. A failed lane is “not run,” never “clean.”

## Step 3 — Aggregate

Apply section 6 of `references/lanes.md`: deduplicate across the three defect and convention lanes, prioritize Security → Spec → Correctness → Conventions, preserve each lane's ranking, and retain distinct dependent convention findings with “apply after fixing S1/C1” where needed. Spec findings are never merged with or dropped in favour of another lane's finding, nor the reverse: a missing requirement and a bug on the same line are two findings.

Before accepting each finding, glance at the cited line yourself at the correct revision. Fix an old-side or incorrect pointer only if a valid in-scope pointer exists; otherwise drop the item and explain a material verification gap. Do not redo the lane's review.

Keep clear corrections, judgment calls and false positives distinct. Judgment calls receive an explanation and no recommended fix; false positives appear briefly as skipped. Keep PLAUSIBLE correctness findings explicitly labelled. Unresolved suspicions remain under Could not verify with what evidence would settle them; never present them as confirmed defects. Number surviving findings S1… / R1… / C1… / V1… .

## Step 4 — Report in the conversation

Use this exact structure, with no “Test plan” section:

```text
## Review: <target, one line>

<one-paragraph verdict: is this safe to ship, does it do what the brief asked, and the single most important thing to fix>

### Security
- **S1** `path:line` — <defect>. <who sends what and what they get>. Fix: <described>.
- skipped: `path:line` — <what was flagged> — <judgment call / false positive, why>
(or: Clean. Checked: <dimensions>.)

### Spec
- **R1** `path:line` (or "nowhere in the change") — <missing / partial / not asked for / wrong / open question settled silently>. Spec: "<quoted line>". Fix: <described>.
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

Every group is present even when empty. Replace parenthetical alternatives with the actual clean line when appropriate. If a lane could not run or had no convention rule set, say so under its group instead of reporting clean. Include skipped entries under their corresponding group. For judgment calls replace “Fix:” with the judgment explanation. If nothing remains unverified, write “None.” Do not claim runtime verification from a static review.

## Step 5 — HTML page for a long report

When the report has more than six findings in total or more than about forty lines, fill [assets/report-template.html](assets/report-template.html) and write `<repository root>/review-code-report.html`. This is the only permitted output file; never modify the installed template.

Populate all `{{PLACEHOLDER}}` tokens. Escape all text from code, paths, targets, evidence and rules as HTML; insert only your own trusted structural markup into the section/list tokens. Remove the bottom example comment and confirm no unresolved tokens remain. Use `security` for `{{VERDICT_CLASS}}` when security findings survive, otherwise `spec` when spec findings survive, otherwise `correctness` when correctness findings survive, otherwise `clean`. `{{SPEC_SOURCE}}` is the spec file or Notion URL, or "none"; without a spec, `{{SPEC}}` holds the unrun token and `{{N_SPEC}}` is `–`. Counts exclude skipped items. Report unrun lanes explicitly and never substitute a clean line for missing checks. Severity pills convey impact (HIGH/MEDIUM/LOW), with PLAUSIBLE or judgment status retained in text; convention cards also cite the rule.

Open the HTML in the browser using the platform's available mechanism. If permission is required use the normal approval flow; if unavailable or declined, disclose that it was not opened and provide a clickable file path.

Keep only the verdict paragraph, one line per group with finding/skipped counts and checked/not-run status, the Could not verify list, and the file path in the conversation. Keep the Security → Spec → Correctness → Conventions order and no “Test plan” section.
