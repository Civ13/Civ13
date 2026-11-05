# Paper editor

The pen/crayon route in [the entrypoint](paperwork-entrypoint.md) constructs this
editor. It accepts only finite append, refresh and cancel messages, using the
existing current-client, pen, custody, document identity/revision/lease and
spoken-language checks. Signatures come from the actual held pen. A committed
append rotates the lease; an unconfirmed response is never replayed. The UI
keeps an invalid or oversized unsent draft for correction.

Every sent snapshot is re-projected for the current viewer. Unsupported or stale
sessions close rather than send cached data. Unknown-language section text is
never supplied by this UI; the server projection supplies placeholders. Existing
unclassified legacy text keeps its reading policy and stored bytes. No reading
or study XP is awarded.

## Rendering

The document uses the guarded Book page: opaque white paper, ink colours and
ordinary selection/accessibility.

- Existing legacy writing (pencode HTML in `info` plus `stamps`) is sent as the
  authored bytes, never the `info_links` write cache. The client parses it in an
  inert `DOMParser` document and keeps only text, line breaks, bold/italic, font
  colour and font face (Verdana, Times New Roman, Comic Sans MS). Block tags,
  list items and table cells become line breaks or separators, images show as
  `[stamp]`, and script/style/frame content is dropped. Nothing is inserted as
  HTML. Classic examine/readers still show the full original HTML.
- Pen sections use Verdana; crayon sections use bold Comic Sans MS; signatures
  use italic Times New Roman (bold too for crayon), matching the classic reader.
- New sections are plain text. Line breaks are kept, and `[b]`, `[/b]`, `[i]`,
  `[/i]` and `[br]` are applied when shown, both here and in the classic reader.
  `[sign]`, `[date]` and `[time]` are replaced once on the server when written.
  Other pencode (`[center]`, `[field]`, tables, lists) stays literal text.
- Legacy `[field]` blanks show as empty and cannot be filled from this editor.

A legacy body over 65536 characters, a parse/budget failure, forced-colors or
print rendering, or a rendering check failure falls back as a whole to an
authorized, freshly projected read-only classic preview. That preview adds no
writing controls or legacy href cache, and its owned UI rejects actions.

The shared NanoUI hook consumes only this owned editor's fixed action; other UIs
keep the original guarded `src_object.Topic` path. Session/UI/listener state is
runtime-only. Construction binds before opening, uses a unique window key and
retires authority on failed or early construction.

## Writing controls

The form shows the language and section choices, a formatting toolbar (bold,
italic, `[sign]`, `[date]`, `[time]`) that wraps or inserts at the textarea
selection without sending anything, a multi-line text box (Enter for a new
line, Ctrl+Enter to write), a live count of the characters left after the
draft, and a preview page that appears once there is a draft. The signature
section previews the name the held pen will actually sign; the server sends it
as `draft_signature` by running the pen getter before the snapshot rechecks
authority, and the client never sends signature text. Written titles render
bold in both the editor and the classic reader. Saved, refreshed, rejected,
pending and unconfirmed states use distinct notices; a full paper says so. The
Close button sends the existing cancel operation.

Study, forms/templates, field answers, stamp repair and filing remain separate
work.
