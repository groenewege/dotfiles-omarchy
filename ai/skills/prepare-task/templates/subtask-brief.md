# The sub-task brief

The body of every executable task: a `Blocked by` line, then four `h3` sections,
each followed by a divider. **English** body, **French** title.

## Skeleton

```
**Blocked by:** <mention of each sibling that must be done first>, or —
### GOAL
---
One or two sentences. The outcome, in product terms.
### REQUIREMENTS
---
What has to be true when this is done. Prose, <br> for soft line breaks, bullets
where a list genuinely helps. Open questions last, phrased as questions.
### REFERENCES
---
@path/to/file.php
@path/to/directory
### OUT OF SCOPE
---
What an agent might reasonably absorb, but must not.
```

Rules:

- `Blocked by` is the first line of every child of a container: the siblings
  whose work this one needs to exist before it can start (the model before its
  import), not a preferred order. Write `—` when nothing blocks it. Each blocker
  is a Notion page mention (`<mention-page url="…">title</mention-page>`), so the link survives a
  rename; in the preview, before the pages exist, write the French title. A
  standalone leaf with no siblings has no `Blocked by` line.
- `---` directly under each heading, no blank line. Omit `OUT OF SCOPE` entirely
  when there is nothing to exclude.
- `<br>` joins closely related sentences in one block; a blank line starts a new
  block. This matches the existing briefs and keeps pages compact.
- Open questions go at the end of REQUIREMENTS, as questions. Do not resolve them
  yourself.
- When the feature is "like an existing X", GOAL may open with two or three
  sentences walking through X (who does what, in which order) before the outcome.
  Then write REQUIREMENTS as **"same as X, except …"** followed by the adapt /
  drop / add items, each in X's own terms. Do not re-describe X in your own words:
  every paraphrase is a chance to lose something.
- A REFERENCES line carries a short note on what to take when the path alone does
  not say it. Only files opened during the run. Do not say where a behaviour lives
  unless you read it there.
- Client copy meant to be displayed is quoted in French and marked verbatim. A
  client's explanation of a field is quoted as source material that may be adapted
  into a help text.
- An unresolved client decision is written out where it blocks: what was asked
  (note, date), what was proposed (note, date), that no answer is recorded, and
  that neither variant is to be built until decided.
- A genuine design question the developer wants a second opinion on goes as the
  last line of REQUIREMENTS: *"Before implementing, give your opinion on …"*. Only
  when the developer asked for it.
- Repository conventions carry their scope: "tests run on the seeded database, not
  factories; the seeder itself uses the factory", not "no factories".

## Titles

French, lowercase, `context : what`, matching the board so the children of one
container group together:

```
enseignant : model + admin
enseignant : formulaire de vœux
enseignant : importation
```

## Length

Match the work. A one-line change gets three lines of brief; a multi-week feature
gets what it takes. Padding an easy task with ceremony makes it look harder than
it is and wastes the reader's attention.

## Example: a small item

The first child of its container, so nothing blocks it.

```
**Blocked by:** —
### GOAL
---
Create the teacher model and allow super administrators to manage teachers.
### REQUIREMENTS
---
Create a teacher model similar to the student model, but teachers are general, not
attached to a single tenant.<br>A teacher is attached to a user and has only a few
columns: nom, prenom, rattachement (string). Create the migration and the seeder.
Then a Filament admin section to manage teachers, modelled on the student resource,
but in the superadmin panel since teachers are not tenant-scoped.<br>Same index,
create and edit forms, delete, bulk mail, export and import.<br>The menu item goes at
the end of the sidebar under a new group called "Enseignement".
### REFERENCES
---
@app/Models/Student.php
@app/Filament/Admin/Resources/StudentResource.php
@app/Filament/Superadmin
### OUT OF SCOPE
---
client demands regarding the classes (how teachers access the student information,
how teachers add a video conference link, etc.)
```

It names the pattern, says twice where it differs (the likely failure), names the
panel, lists the columns and fences off adjacent demands.

## Example: the same item over-paraphrased, and the fix

A later run rewrote the requirements as:

```
Take the student resource as the model: index with search, create/edit forms,
delete, bulk mail, Excel export, and the 3-step Excel import.
[…] no factories are used in tests.
@app/Models/Student.php (user sync in booted(), email accessor)
```

The implementing agent planned a generic `->searchable()` instead of the student
filter bar, left out the impersonate action on the edit page, planned no factory,
and had to correct the `booted()` claim (user creation lives in
`CreateStudent.php`, the import job and the seeder). Three tidy phrases, three
losses. What it should have said:

```
Same index as the student resource, except: keep the name filter in the filter bar;
replace the numéro filter with a rattachement filter; drop the school year, week,
redoublant, exempté, convention, statut, tag and has_action filters and columns; add
an email column.<br>Same pages as students, including the impersonate header action
on the edit page; drop the tag handling.
Create the migration, the factory and the seeder (the seeder uses the factory, like
StudentSeeder; tests run on the seeded database).
@app/Models/Student.php (name sync and user delete in booted(), email accessor)
@app/Filament/Admin/Resources/StudentResource/Pages/CreateStudent.php (user
creation, role, NewStudentCreated event)
```

## Example: "similar to X" with a design question

The answers have to exist before they can be consulted, so the form blocks it.

```
**Blocked by:** <mention-page url="…">enseignant : formulaire de vœux</mention-page>
### GOAL
---
Today a structure fills out a yearly form: the super admin sets up the form and its
themes, the structure answers the active form, and the super admin consults, filters
and exports the answers.<br>Create the same consultation side for the teachers' form.
### REQUIREMENTS
---
Same as the structures' answers resource: search by teacher name, filter by form,
view page, export of the filtered list.<br>Drop the week and "asked by student"
filters, which have no teacher equivalent.<br>Add a filter by selected session.
The existing theme filter matches any of 4 theme columns. Teachers rank ALL themes,
so it would match everyone: replace it with "theme is within the first N vœux"
(default 3).
Before implementing, give your opinion on this theme filter.
### REFERENCES
---
@app/Filament/Superadmin/Resources/DispoAnswerResource.php (filters layout, name
search, form filter, theme filter to adapt, ViewAction infolist, ExportAction)
```

## The container body

A parent with children carries only the shared framing: a short goal, plus
whatever checklists and documents already live there. The detail is in the
children. A container has no `Blocked by` line; its children carry the edges.

```
### GOAL + REQUIREMENTS
---
I would like to manage teachers and class locations on this website.
```

Below it, the sub-items view, then the existing TODO / DOCUMENTS / DEPLOY columns
and the Notes view, all left where they are.
