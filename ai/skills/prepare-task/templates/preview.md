# The approval preview

Everything that will be written, shown before anything is written. The reviewer is
checking one thing: **did the conversion from client evidence to specification
preserve what was actually agreed?** Show the briefs in full; a summary is not
reviewable.

## Structure

```markdown
## Preparing: <task title>
<task url>
Project: <project title> · Status: <current status> · <n> existing children

### Current understanding
2–5 sentences: what this feature is, in its current agreed form.

### Sources and gaps
Read: <n> notes on this task, <n> on its parent, the project page.
- `Some_file.xlsx`: attached to the task, not readable with the connected tools.
  **Blocks:** "enseignant : importation".
Write "No gaps." if there are none.

### Conflicts and open questions
For the **client** to answer.
1. **<short title>**: what was asked, what was proposed, what is unresolved, with
   source links. **Blocks:** <which items>, or *does not block*.

### Departures from <reference feature>
Only when the feature is "like an existing X", built from files actually opened.
Exceptions only; keep is the default.
| Element (file) | New feature |
|---|---|
| theme filter, any of 4 columns (DispoAnswerResource) | adapt: themes are ranked |
| week ternary filters (DispoAnswerResource) | drop |
| filter by session | **add** |

### Proposed changes to the parent body
Exact before → after for each edit. Name what stays untouched: documents, the Notes
view, the deploy checklist.

### Existing children to update
| Title | Change | Why |
|---|---|---|

### New children to create
Each in full:

---
**<french title>**
Status: backlog · Parent: <parent title> · no Project, no Notes links

<the complete brief: Blocked by / GOAL / REQUIREMENTS / REFERENCES / OUT OF SCOPE>
---

### Order and dependencies
Built from the `Blocked by` lines; titles until the pages exist.
Can start now (the frontier):
- enseignant : model + admin
Blocked:
- enseignant : formulaire de vœux ← enseignant : model + admin
- enseignant : importation ← enseignant : model + admin

### Legacy checklist coverage
| Existing entry | Covered by | Action after verification |
|---|---|---|
| `- [ ] enseignant → model` | enseignant : model + admin | remove |
| `- [ ] importation ?` | still an open question | **keep** |

### Seen in the evidence, not part of this task
- contract renewal / quote request (email, 14/09/2026)

### Questions for the developer: round 1
Implementation choices that are yours. Only the frontier: questions whose
prerequisites are already answered. Grilling format:

❓ **Q1** - **<short title>**: options, and which brief the answer changes.

➡️ <recommended answer>

---

❓ **Qn** - **Anything else?**: anything you already have in mind for this feature
(UI, filters, data shape) that is not in Notion?
```

## Then grill, then stop

The questions come **after** the finished preview, never instead of it: the
reviewer never answers before seeing output. Ask only material ones. The
developer's design choices are material; trivia and what the evidence already
answers are not.

After each round, write the answers into the affected briefs, show only the briefs
that changed (in full), and ask the next frontier. A question that depended on an
answer from this round can now be asked. When the frontier is empty and the
developer confirms nothing is left, end with what you need and nothing else:

> Approve to write, or tell me what to change. I can also apply part of this and
> leave the blocked items out.

Then wait. Do not write, do not set a status, do not "just create the
uncontroversial ones".
