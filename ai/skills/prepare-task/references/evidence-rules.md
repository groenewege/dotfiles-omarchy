# Turning correspondence into a specification

The raw material is a French email thread between developer and client, sometimes
months long, interleaved with meeting notes and the developer's own
counter-proposals. The output is an English brief an agent can execute. Everything
here exists to stop one failure: **manufacturing a decision that was never made.**

## The four buckets

Every statement in the evidence goes into exactly one:

- **Confirmed requirement**: agreed, current, unrevised. Goes into GOAL or
  REQUIREMENTS.
- **Superseded**: explicitly revised later. Drop it, unless the change itself is
  material ("the deadline moved", "we abandoned the import approach"), in which
  case record the change and its source, because someone will ask why.
- **Proposal awaiting decision**: suggested, neither agreed nor refused.
  **Including the developer's own proposals.** A well-argued counter-proposal with
  no reply is still not a decision.
- **Open question**: asked and unanswered, or two positions with no resolution.

## Recency is not authority

A later message does not override an earlier agreement by being later. Promotion
requires an explicit revision by the person changing the decision. The recurring
shape in this workflow:

1. The client asks for X.
2. The developer explains why X is complex and proposes Y instead.
3. Silence.

That is an open question, not "we're doing Y" and not "we're doing X". Write it
as: *the client asked for X (note, date); a counter-proposal of Y was sent (note,
date); no answer has been recorded. Needs a decision before this item can be
executed.*

If a note appears to contradict something already settled in the task body,
surface the contradiction in the preview and let the human resolve it.

## Keep the concrete details

They are what summarising loses, and they are the value: exact numbers, dates,
times and counts ("3 dates per session", "16h to 18h"); field and column names;
conditions and exceptions ("a teacher may pick one or two sessions"); exact
wording for anything user-facing, quoted in French. A brief that says "add the
appropriate help text" has thrown away the one thing the client supplied.

**Verbatim only when supplied as copy.** A sentence the client wrote *to be
displayed* is literal copy: quote it and mark it literal. A sentence in which the
client *explains what a field is for* is source material: quote it and say it may
be adapted into a help text.

## Business rule vs inferred constraint

Three things look alike in an email:

| In the evidence | What it is | In the brief |
|---|---|---|
| "ils ne peuvent pas choisir une seule des dates" | the client's rule | a requirement |
| "14-Jan, 21-Jan, 04-Feb", three dates listed | an example of this year's data | seed data; "normally 3 dates", not enforced |
| "session 1 ou session 2", two sessions mentioned | a habit | "typically 2"; ask whether the count is fixed |

Write rules as rules and examples as *normally / typically*. If the difference
changes the data model or the validation, ask the developer. "Exactly 3 dates" is
a validation rule nobody asked for. Equally, do not add flexibility nobody asked
for ("do not hardcode the number of sessions") on your own reasoning.

## Developer intent

The client describes the need; the developer usually already knows how they want
it built (dropdowns rather than drag-and-drop, which admin filters, which existing
page to mirror), and it is rarely written down.

- A note authored by the developer is first-class evidence and, for decisions that
  are the developer's to make, authoritative.
- With no such note, ask (see "Who decides each open point" in the skill). An open
  design choice is not resolved by handing it to the implementing agent.
- The developer's messages *to the client* remain proposals until the client
  answers. Developer intent covers implementation choices, not what the client has
  agreed to.

## Excluded sources

If the user says to ignore a source, drop its requests **and** everything you
concluded from it. Re-check each brief for sentences whose only justification was
that source.

## Provenance and separation

For each material decision carry one line: note title, date, URL. Do not paste
emails into a brief; the Notes stay linked and readable, the brief is the current
state.

A single thread routinely covers the feature in hand, a bug, a contract renewal, a
staffing change and a future request. Only the first belongs in these briefs. Park
the rest once, at the end of the preview, under *"seen in the evidence, not part
of this task"*.

## References and out of scope

REFERENCES gives an agent repository-relative `@path` lines for what to reuse,
with a short note on what to take when the path alone does not say it. Only files
opened during the run; mark anything unverified. Finding the paths is this skill's
job, never the human's. A reference is not a mandate to copy: when the new thing
differs from its model, say so in REQUIREMENTS ("teachers are global, not attached
to a tenant, unlike students"), or an agent will faithfully copy the scoping.

OUT OF SCOPE is written whenever the evidence contains adjacent work an agent might
absorb; it is the cheapest guard against scope creep. Omit the section when there
is nothing to exclude.
