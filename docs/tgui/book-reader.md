# Book reader compatibility contract

This is a local source candidate for the existing base book reader, based on
master `7c1937d49899d4190400ed36b88bdc51f00440f4`. It does not depend on the
unmerged Notes or Flavor readers. It uses the existing modern adapter with
complete classic fallback. Publication and native execution await Main review.

## Authorized snapshot

`show_content()` retains the original admission expression: humans receive the
complete body; ghosts do so only when `forceshow` is false; other readers receive
the existing `stars(dat)` result. That random filtering runs once before either
representation. The exact same authorized value supplies the original complete
HTML snapshot and the structured parser. Reading does not modify stored bytes,
resolve a new signature, date or time, or change authoring, renaming, uniqueness,
fingerprints, knowledge, subtype overrides, blank-book or examine behavior.

The detached snapshot does not recollect content on manager refresh or add a
distance restriction after opening. Explicit reopening captures a new snapshot.
The lease checks the exact reader, client, source and book; logout or transfer
fails the old lease. Close retains the adapter's transport/unregister behavior
while disabling the unrelated machine interaction reset. There are no book
domain actions or new search, copy or reveal controls.

## Bounded option B

The page is opaque `#FFFFFF`, with black default ink, 16px Times New Roman
defaults and ordinary HTML whitespace. Supported balanced markup consists of
`b`, `i`, `br` and `font`. Font attributes are parsed explicitly, with no browser
HTML repair: only `face` and `color`, each at most once. Faces map to fixed
Verdana and Times New Roman families. Approved color names are black, blue,
red and white; exact six-digit RGB also works. Nested contexts restore prior
ink, font and emphasis, so a font-only signature inherits white pen ink.

Rendering creates ordinary text spans from validated structured runs. It never
inserts HTML or generates flattened body labels, summaries or tooltips. White
text stays white on the white page, without contrast correction or text shadow.
Ordinary browser selection and accessibility remain available, including for
white text: this preserves visual concealment, not confidentiality.

Unsupported attributes, duplicate attributes, malformed tags/entities, CSS,
sizes, layout constructs or unsupported colors reject the entire view. The
server caps the full encoded snapshot and metadata at 65,536 native length
units, structure at 2,048 opening/text/break nodes and nesting at 32. Title/name
metadata is limited to 256 units each and rejects HTML/entity/control syntax.
No prefix or supported subtree is salvaged. Fallback returns the complete
original authorized HTML, retaining the existing classic HTML boundary.

The frontend independently validates node keys, values, Unicode/entity syntax
and aggregate size. It requires supported computed white/ink/font styling,
observers and media APIs; forced colors, print, altered ink/filter/opacity or
horizontal content overflow request full classic fallback. Normal vertical
document scrolling remains available. Initial checks run before paint; bounded
observers and media/resize/load notifications check subsequent relevant changes.
These guards are not a guarantee against every engine or external style failure.

## Evidence and limits

The offline tests execute fail-closed projections of the actual parser's source
statements under character-index and UTF-8 byte-index adapters. They verify
inheritance, unsupported subtree/metadata rejection, budgets and the original
human/ghost/force matrix. They are not a DM interpreter or proof of native
Unicode indexing. Causal omission controls check owner/client, cached HTML,
whole-view fallback, metadata admission and close behavior.

Component tests cover inert decoded text, white styling, ordinary selection
metadata, invalid nodes and budgets. The production bundle keeps the 17 earlier
routes and registers this eighteenth route. JSDOM deliberately exercises Book
fallback because it cannot establish the required computed styling. Real
Chromium tests use the production bundle and a fictional snapshot shared with
the source projection; they check white-on-white ink, nested signature fonts,
ordinary accessible/selectable text and eight whole-view fallback conditions.
The browser transport is a fixture, not native Topic delivery.

No local BYOND compile, DreamDaemon, DreamSeeker, live game or Gaia operation
was run. Native font/ink rendering, Unicode indexing, resource delivery/cache,
focus, close/logout/transfer and classic reopen remain unverified. Normal future
PR selection is production compilation plus existing offline/frontend checks;
this patch introduces no native fixture or runtime runner.
