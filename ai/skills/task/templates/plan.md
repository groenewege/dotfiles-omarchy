# The implementation plan

The review point. The reviewer checks three things: **is this the right work, does
it fit the codebase, what will it break.**

Same shape as native plan mode, sized to the task: a one-field change gets under
400 words, a multi-week feature gets what it needs. A section with nothing to say
is omitted, not filled with "None". Written in English, concrete about what the
user will see, terse about process.

```markdown
## <task title>
<task url> · Status: <current> · Project: <project> · Parent: <parent title or —>

### Context
Two or three sentences: the need (from GOAL), what already exists in the code, the
pattern being followed (one reference, named by file or commit).

### Approach
Acceptance criteria as a checklist, one line each, from REQUIREMENTS. Mark anything
that is your inference rather than the brief's text *(inferred)*. Product copy goes
inline, in French, in quotes: label "Spécialité", help "Visible pour les étudiants".

When the feature is modelled on X, follow with "Differs from X": adapt / drop / add
only. Keep is the default and is not listed; every drop names its reason.

Then anything surprising found in the code (a stale reference path and its
substitute, a mis-wired class, a convention the brief got wrong) and the inferred
choices the reviewer may want to overrule. Migration or data implications appear
here only when destructive, backfilling or deploy-order sensitive.

### Files
Compact list grouped by area, new vs edit. No per-file explanation.

### Verification
The tests to add or extend and the command that runs them, then two to four manual
checks with URL and role.

### Open questions
Only if any. Unresolved items from the brief, each with what it blocks; the rest of
the plan can proceed.

### Not doing
OUT OF SCOPE from the brief, plus anything you noticed and deliberately left alone.
```

## Then stop

Wait for explicit approval before touching application code.

Ask about missing product decisions. Decide naming, file placement, test suite and
idiom yourself from the neighbouring code. A plan that ends in six questions about
naming has misread which decisions are the human's.
