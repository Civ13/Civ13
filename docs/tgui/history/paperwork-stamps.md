# Paper stamps

`code/modules/paperwork/stamps.dm` records ink stamps and wax seals on paper.
Using any stamp on a sheet (or on the top sheet of a clipboard, or the open
page of a bundle) adds one impression:

- `stamped` gets the stamp's look (its `icon_state` text). Old saves may hold
  stamp type paths there (forensics reports); those stay as they are.
- `stamps` gets an `<img>` marker naming `paperstamp_<look>.png`, with the
  stamp's name as alt text. The first impression starts on a new line.

Both are ordinary saved paper fields, so a reload, a printing-press copy and a
faction mailbox copy all keep the stamps. A written (canonical) document takes
the stamp through `paper_document_prepare_edit`/`commit_edit`, so its record
and legacy mirror stay equal and an open editor sees a new revision.

Readers: `document_classic_html` sends each impression's image with
`browse_rsc` just before the page opens. Large images come from
`icons/stamps/dmi/stamps.dmi`, then `seals.dmi`, then the small sheet overlay.
The TGUI editor page shows an impression as `[stamp: <name>]` text.

Sheet sprite: overlays are rebuilt from `stamped` on `update_icon` and
`after_load`, with offsets fixed by position, so they look the same after a
reload. Overlay images are runtime-only. A sheet holds at most 12 impressions,
and crumpled sheets cannot be stamped.

The old commented-out code failed because it saved `<img src='\ref[image]'>`:
a browse window cannot load an image by reference, and the reference means
nothing after a save.

Checks: `python3 -m unittest tests/paper_documents/test_stamps.py` (offline
projection) and `python3 tests/ecology_spawning/run_linux.py .
tests/paper_documents/stamp_probe.dm` (native: every stamp type has a reader
image and a sheet impression, overlays rebuild without duplicates).
