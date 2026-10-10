# The Notion project-management model

How to read the data correctly. The structure is simple, but several things look
like an answer when they are not.

## Databases

| Database | One row is | Key properties |
|---|---|---|
| **Projects** | A website / repository / client engagement | Client, Status, relations to Notes and Tasks. The body carries contacts, a `URL` section with dev + staging addresses, and document links. |
| **Tasks** | A unit of work, at any size | Title, Status, a self-relation pair (parent / sub-item), relation to Project, relation to Notes, a `Completed` formula |
| **Notes** | One email thread, meeting, or piece of research | Title, Date, Type (Email, Other, …), relation back to Task |

Tasks are self-nesting: containers and their children live in the same database,
joined by a parent relation (limit 1) and its inverse sub-item relation. There is
no separate "epic" database.

**Developer notes.** A Note of type `Other` written by the developer
(conventionally titled "notes dev") holds design intent that no email contains:
the UI mechanism wanted, the admin filters needed, which existing feature to
mirror. Read it like any linked note and attribute it to the developer. If a
non-trivial task has none, suggest creating one after the run from the answers
given during the preview.

## Getting the live schema

Never work from remembered property names. Fetch the target page, read its
`parent-data-source` URL (`collection://<uuid>`) and fetch that. It returns the
property schema, the select options, which properties are read-only, and a SQLite
table definition for querying.

Identify properties by type and relation target, not by expected name (names may
be English or French):

- parent relation = relation to this same data source, `limit: 1`
- sub-item relation = relation to this same data source, no limit
- project relation = relation pointing at the Projects data source
- notes relation = relation pointing at the Notes data source

## Trap 1 — Inline database blocks always look empty

A task body renders its linked-Notes view as a bare tag:

```
<database url="…" inline="true" data-source-url="collection://…"/>
```

No rows, ever. A task with seven linked emails and a task with zero produce
identical body text. Concluding "this task has no notes" from the body silently
discards the entire client correspondence.

Always read the relation property instead; the task's properties carry the note
URLs:

```json
"Related to Notes (Task)": ["https://…", "https://…"]
```

If the property is absent or looks truncated, query the Notes data source for rows
whose task relation contains this task. The same applies to the sub-items view:
read the sub-item relation property, not the rendered board.

## Trap 2 — Children inherit nothing, and that is intended

A page created with the parent relation set gets nothing else: no `Project`, no
Notes, no Status, Tags or dates from its parent. In this workflow a sub-task is
deliberately bare:

- **No `Project` relation**, so it stays off the project page's kanban board,
  which shows top-level work only. The parent carries the Project.
- **No Notes links.** The correspondence is attached to the parent, where anyone
  looks for it.

A sub-task is a French title, its brief, its parent and a status. When reading a
child, walk up to its parent for the Project and the Notes. An empty `Project` on
a child means nothing is wrong.

## Trap 3 — Writes are asynchronous by default

Create and update tools return an async task handle. A read issued immediately
afterwards can return the old state, or a page whose template body has not
materialised. When a later step depends on the write, request synchronous
execution or poll the task to succeeded before reading back. For a template-based
create, "succeeded" still does not mean the body is present: fetch and retry until
it is.

## Trap 4 — Attachments are opaque

Files appear only as an encoded blob:

```
<file src="file://%7B%22source%22%3A%22attachment%3A…%3ASome_file.xlsx%22…"/>
```

The filename is recoverable; the contents are not, unless a tool that genuinely
downloads and parses attachments is connected. A spreadsheet, PDF or screenshot is
a gap. Report it as one. Never describe what a file "probably contains".

## Writing pages

- Content is Notion-flavored Markdown. Consult `notion://docs/enhanced-markdown-spec`
  for anything structurally unusual.
- `<br>` is a soft line break inside one block; a blank line starts a new block.
  The existing briefs use `<br>` heavily.
- Relation properties take arrays of page URLs or ids, even with `limit: 1`.
- Select properties take the option name as a plain string, matching the live
  schema exactly.
- Date properties are split into `date:<Name>:start`, `date:<Name>:end`,
  `date:<Name>:is_datetime`.
- Formula and rollup properties are read-only. `Completed` derives from Status;
  change Status.

**Edit bodies with targeted search-and-replace.** A whole-page replace destroys
attachments, inline database views and checklists that the fetch output only
represents as opaque tags. If a replace would delete a child page or database, the
tool refuses unless explicitly allowed: treat that refusal as a stop signal, not an
obstacle to override.

## Status

The Status select is workspace-defined; read the real options from the schema. The
usual flow is a backlog state, an in-progress state, done, then deployment states.
Map intent to what exists; do not assume a literal name is present.
