# Review lanes

Each lane is a separate reviewer with one job. A lane reads only the files in
scope, reports only, and never fixes anything. The main session aggregates the
punch lists (three, or four with a spec) using the rules at the end of this file.

Contents:
1. Shared rules (every lane)
2. Lane 1 — Correctness
3. Lane 2 — Best practices and project conventions
4. Lane 3 — Security
5. Lane 4 — Spec (only when a spec is given)
6. Aggregation rules (main session only)

---

## 1. Shared rules (every lane)

**Scope.** The scope block you were given (mode, target, diff command, changed
file list) is the whole universe of this review. Read those files, and the diff
that command produces, in full. You may open other files to understand how
in-scope code is called or what it calls, but findings are only ever about lines
in scope. Unrelated work in progress that happens to be in the working tree is
none of your business: do not read it for findings, do not mention it.

**Report only.** Do not edit, create, stage, or format anything. Not even an
obvious one-character fix. The user decides what to change; your job is to make
that decision easy.

**Evidence bar.** A finding must describe the concrete input or state and the
wrong outcome it produces. "This could be null" is not a finding; "when the
student has no `phase`, line 42 calls `->name` on null and the request 500s" is.
If you cannot write that sentence, you do not have a finding, you have a
suspicion. Suspicions go in a short "Worth a look" list at the end, clearly
separated, so they never get confused with confirmed defects.

**Format.** Return a punch list, most severe first, one entry per finding:

```
- path/to/file.php:42 — <one-sentence defect>
  evidence: <who does what / which input, and what goes wrong>
  fix: <concrete change, described, not applied>
```

Then a `Worth a look` list (suspicions, same format but no evidence line is
required), then `Clean:` with the dimensions you checked and found fine.
An explicit "nothing found, checked X, Y, Z" is a valid and useful result.
Silence reads as "not checked".

Line numbers refer to the **new** side of the diff (the file as it is now).

---

## 2. Lane 1 — Correctness

Find bugs in the target. This is the **only** lane that looks for correctness.
Lanes 2 and 3 check conventions and security; they will happily pass code that
is flawlessly conventional, perfectly authorised, and functionally wrong.
If you do not find the bug, nobody will.

**Preferred method.** If the Skill tool lists a `code-review` skill, invoke it
on the resolved target and let it do the heavy lifting:

| Scope mode | `code-review` argument |
|---|---|
| `worktree` | no target (it reviews the current diff) |
| `commit` | the commit hash |
| `range` | the range, e.g. `HEAD~3..HEAD` |
| `branch` | the branch name |
| `path` | the path |

Never pass `--fix` or `--comment`. When it returns, keep only the findings that
land on in-scope files and lines, and re-express them in the punch-list format
above (it may report at a different granularity). Then do a short pass of your
own on anything it obviously did not cover.

**Inline method** (no `code-review` skill available, or it refused the target).
Read the diff with the surrounding code and hunt for:

- Logic errors: inverted or incomplete conditions, wrong comparison operators,
  off-by-one in ranges and pagination, wrong date arithmetic and timezone
  assumptions, boolean precedence.
- Null and empty paths: method calls on possibly-null relations, `first()` used
  where a record is required, empty collections, missing array keys, optional
  request input treated as present.
- Data integrity: writes that skip validation, missing transactions around
  multi-row updates, race windows between check and write, cascades that delete
  more than intended, mass updates with a missing `where`.
- Contract breaks: a changed signature, return type, route parameter, event
  payload, or Blade variable whose other callers (outside the diff) still assume
  the old shape. Grep for callers; this is the most common class of bug that a
  diff-only reading misses.
- Error handling: swallowed exceptions, errors reported as success, failure
  branches that leave partial state.
- Tests: a test that cannot fail (asserts nothing meaningful, mocks the thing
  under test, tautological expectations), or a test whose setup contradicts the
  scenario it claims to cover.

Rank by user impact: data loss and wrong results first, crashes second, wrong
messages and cosmetic breakage last.

---

## 3. Lane 2 — Best practices and project conventions

Check the changed code against the project's own rules. This lane does not
look for bugs; report a convention breach even when the code works.

**Find the rule set, in this order, and use the first that exists:**

1. If `composer.json` in the repo root requires `laravel/framework`, the
   project is Laravel. Look for a `laravel-best-practices` skill:
   `<repo>/.claude/skills/laravel-best-practices/SKILL.md`, then
   `~/.claude/skills/laravel-best-practices/SKILL.md`. If found, read it and
   apply it as the checklist (follow any references it points to). Laravel
   Boost installs this skill in recent versions.
2. Otherwise, for a Laravel project, use the `<laravel-boost-guidelines>` block
   in `<repo>/CLAUDE.md` (or `AGENTS.md`) plus any `<repo>/.ai/guidelines/*.md`.
   These are the Boost-generated conventions and cover the same ground.
3. For any project, also read `<repo>/CLAUDE.md` for house rules (naming,
   structure, testing policy, language of the UI, forbidden patterns).
4. If none of these exist, say so and stop: there is no rule set to review
   against, and inventing one would just produce noise.

**What to check** (only against rules that actually exist in the rule set):

- Structure: code placed where the project puts that kind of code
  (controllers, form requests, policies, services, admin vs public views).
- Framework idioms the rules call out: Eloquent relations over raw queries,
  form requests over inline validation, named routes, config over `env()`,
  eager loading where an N+1 is introduced, typed signatures and return types.
- Style rules stated in the rule set (braces, PHPDoc, constructor promotion,
  enum casing, translations through the lang files, etc.). Skip anything a
  formatter or linter would fix on its own unless the rules say otherwise.
- Testing policy: the rule set may require a test per change or a particular
  way to build test data. Report a missing or non-conforming test.

For each finding, cite the rule it breaks (file and section, or quote it).
A convention finding without a citable rule is an opinion; leave it out.

---

## 4. Lane 3 — Security

Review the changed code for vulnerabilities. Like Lane 1 this is a defect lane,
not a conventions lane: report exploitable weaknesses, not missing best
practices.

**Preferred method.** If the Skill tool lists a `security-review` skill **and**
the scope mode is `worktree` or `branch`, invoke it: it reviews the pending
changes on the current branch, which is what those modes are. Keep only the
findings on in-scope files, re-express them in the punch-list format, then do
your own pass on the checklist below for anything it did not cover.

For `commit`, `range`, and `path` modes, `security-review` cannot be pointed at
the target, so review inline against the checklist.

**Checklist.** Look for:

- Missing or wrong authorization checks on routes, controllers, and policies
  (a route without middleware, a controller action that never calls
  `authorize`, a policy method that returns true too broadly).
- Mass assignment exposure: `$fillable` or `$guarded` letting a request set
  fields the user should not control (roles, owner ids, prices, flags).
- SQL injection through raw queries, `whereRaw`, `orderByRaw`, `DB::select`, or
  string-built bindings.
- XSS through `{!! !!}` in Blade or `dangerouslySetInnerHTML` in React on
  user-controlled content.
- Secrets, tokens, or keys committed in code or config.
- Unsafe deserialization (`unserialize`, `json_decode` into classes, signed
  payloads not verified).
- SSRF in outbound HTTP calls built from user input.
- Path traversal in file handling (uploads, downloads, `Storage` paths built
  from request data).
- Missing rate limiting on public or authentication endpoints.
- PII in logs, in exception context, and in anything reported to error
  tracking.
- CSRF exemptions.
- Insecure direct object references: a record loaded by id from the request
  without an ownership or scope check.

**Evidence bar.** Same as Lane 1: describe the concrete attack, meaning who
sends what and what they get that they should not. "An authenticated student
POSTs `/absences/17/justify` with another student's absence id; the controller
loads it by id with no ownership check and marks it justified." If you cannot
write that, it is not a finding.

Rank by exploitability (unauthenticated remote first, then any authenticated
user, then privileged users, then requires unusual preconditions), not by
category.

---

## 5. Lane 4 — Spec

Check the change against the brief it implements: does it do what was asked, no
less and no more? This lane does not look for bugs, conventions or
vulnerabilities; the other lanes do. Code that is correct, idiomatic and secure
can still build the wrong thing, and only this lane will notice.

You received the spec text in your prompt. It is usually a brief with GOAL,
REQUIREMENTS and OUT OF SCOPE, sometimes followed by decisions taken at the plan
gate; a later decision overrides the brief line it answers. French strings in
the spec are product copy and must appear verbatim.

Go through REQUIREMENTS line by line, then OUT OF SCOPE, and report:

- **Missing or partial**: a requirement with no implementation in scope, or only
  part of it (two of three filters, the form without the validation message).
- **Not asked for**: behaviour in the change that no requirement calls for,
  above all anything OUT OF SCOPE names, or "groundwork" for it.
- **Wrong**: a requirement that looks implemented but does something else: a
  different value, count, condition, role, panel, or copy that differs from the
  quoted French.
- **Settled silently**: an open question in the spec that the code answers by
  picking one option without the spec recording a decision.

**Evidence bar.** Every finding quotes the spec line it concerns and gives the
`file:line` where the change does (or should do) it; "nowhere in the change" is a
valid location for a missing requirement. A requirement you cannot check from
code (a layout, copy only visible in the browser, behaviour that needs seeded
data) goes under "Could not verify", not as a finding.

Report in the section 1 format, with `spec: "<quoted line>"` in place of the
evidence line. Rank: missing and wrong first, then settled silently, then not
asked for. End with `Clean:` listing the requirements you checked and found met,
so "met" and "not checked" read differently.

---

## 6. Aggregation rules (main session only)

Once all punch lists are in:

1. **Deduplicate across the defect and convention lanes** (1 to 3). Spec
   findings are never deduplicated against them: a missing requirement and a
   bug on the same line are two findings, because the axes are separate on
   purpose. Two findings are the same when they point at
   the same `file:line` or describe the same root cause at neighbouring lines.
   When a correctness finding and a convention finding hit the same line, keep
   the correctness finding and drop the convention one. When a security finding
   and a correctness finding overlap, keep the security finding and fold the
   correctness detail into its evidence.
2. **Priority.** Security findings outrank spec findings, which outrank
   correctness findings, which outrank convention findings. Within a group,
   keep each lane's own ranking.
3. **Never let conventions mask defects.** If a convention item would, if
   applied, change behaviour on code that a security or correctness finding
   also touches, note that dependency on the convention item ("apply after
   fixing S1") rather than dropping either.
4. **Classify each surviving finding** as one of:
   - a clear correction with a concrete proposed fix (report the fix in words),
   - a judgment call (report it, say why it is a judgment call, no fix
     recommended),
   - a false positive (list it briefly under its group as skipped, with the
     reason, so the user knows it was considered).
5. **Group the summary** as Security, Spec, Correctness, Conventions, in that
   order. No "Test plan" section. A group with nothing in it says so
   explicitly; without a spec, the Spec group says "Not run" and why.
6. **Number findings** S1, S2 … / R1, R2 … / C1, C2 … / V1, V2 … so the user
   can refer to them.
