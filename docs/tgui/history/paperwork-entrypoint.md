# Paper editor entrypoint

`PAPER_EDITOR_ENTRYPOINT_ENABLED` is `TRUE`. Using a pen or crayon on a sheet of
paper opens the language-aware editor. When the editor cannot open and the
paper still has no canonical record (a paper subtype, or a writer with no
admitted written language), the existing guarded legacy editor opens instead.
A paper that already has a canonical record never falls back to the legacy
field/EOF writer; the player is told they cannot write on it right now.

After a canonical append commits, the item's legacy link cache is rebuilt and
its icon refreshed. A classified section counts as writing for the base paper
icon; the icon does not carry section text. Rejected edits do not refresh. The
cache remains derived from legacy `info`, not classified sections. Existing
subtype icon overrides and the original crumpled-sheet check remain in place.

Not verified with a live BYOND client: native transport, close/logout/body
transfer, owner/custody changes and icon/link refresh in play. Offline Python,
vitest and real-Chromium bundle checks cover the editor logic and rendering;
the native world-save round trip covers nested associative lists of the same
shape as `document_record`, not a full game save containing a paper.
