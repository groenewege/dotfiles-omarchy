# Reading a prepared brief

A prepared task body has a `Blocked by` line (children only), then four sections,
each an `h3` followed by a divider:

```
**Blocked by:** <mentions of sibling sub-tasks>, or —
### GOAL
---
### REQUIREMENTS
---
### REFERENCES
---
### OUT OF SCOPE
---
```

`OUT OF SCOPE` is omitted when empty. A task missing GOAL **and** REQUIREMENTS has
not been prepared: recommend `/prepare-task` instead of guessing.

## Blocked by

The siblings whose work must exist before this one can start: the model before
its import, the form before the consultation of its answers. `—` means nothing
blocks it. Check each blocker's Status: if one is not done, say which and why it
matters (code, tables or seed data this brief depends on may not exist yet) and
ask before planning. A plan-only run may continue on request; building waits for
the blocker. Briefs written before this line existed do not have it: read the
dependencies from the brief text instead.

## GOAL

One or two sentences in product terms: who benefits and what becomes possible. If
an implementation choice does not serve the GOAL, it is probably the wrong choice,
however elegant.

## REQUIREMENTS

The acceptance criteria in prose, written by a developer who has read the client
correspondence. It mixes firm requirements ("the teacher selects one or two
sessions"), exact copy to use verbatim (quoted French, never translated or
paraphrased), concrete values (counts, dates, times, column names) and open
questions, usually at the end and sometimes phrased conversationally ("What do
you think?").

Read to the end. **An open question is a stop, not a hint.** If it affects what
you are about to build, raise it in the plan and let the human answer; do not pick
the option that looks more reasonable. It was written down because it was not
decided.

A line "Before implementing, give your opinion on …" is a genuine request for a
second opinion: answer it in the plan.

## REFERENCES

`@repo/relative/path` entries, sometimes with a note on what each one is for. They
are a map, not a fence: read them and their neighbours. A brief that names its
files does not need a fan-out to find them. How to treat them (stale paths,
conceptual references, pattern versus template, keep by default) is in the skill's
Phase D.

## OUT OF SCOPE

A hard boundary, placed deliberately because the evidence contained adjacent work
a reasonable implementer might absorb. Do not build it, and do not build "just the
groundwork for it". If it turns out to be genuinely required, that is a scope
change to raise, not to absorb.

## When to go back to the Notes

The brief is the current specification; the Notes are the archive behind it.

| Trigger | What you are looking for |
|---|---|
| The brief is incomplete or self-contradictory | The original statement |
| You are about to depend on a decision | Who decided it, when, and whether it was revised |
| A note post-dates the brief | Whether it changes anything |
| User-facing copy is referenced but not quoted | The verbatim wording |

Note dates matter: a note newer than the task's last edit may carry a decision the
brief has not absorbed. Surface it rather than acting on it. Never re-read the
whole correspondence by default: it is long, in French, full of abandoned
proposals, and treating it as authoritative undoes the preparation step.
