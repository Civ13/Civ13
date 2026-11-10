# Crafting Atlas reader migration

The in-game Crafting Atlas uses the existing default modern adapter. It remains
a public, read-only catalog for connected mobs, including observers and dead or
incapacitated readers. Opening a processor's reference still selects that
processor. This does not grant crafting permission or change recipes, jobs,
map/faction gates, research, skills, tools, payment or item construction.

The modern screen provides resource and recipe results with sprites, a recipe
card ("You need" and "You get"), variant selection, acquisition guidance,
search, unlock-era and "Made at" filters, and the existing explicit paginated
list. The search text stays local until submitted; the two filters apply when
changed. The classic Search prompt and its cancellation behavior remain in the
original HTML renderer.

## Reader view

- Names: resources show the in-game `name` where the generator found one
  (`title` in `UI/crafting-atlas.json`, built by `scripts/atlas/titles.py`).
  Catalog names and canonical IDs are unchanged, and both stay searchable.
- Search: up to six words, and every word must match the same recipe variant.
  Recipes whose own name matches are listed before ingredient or note matches.
- Map catalogs: material recipes exist once per map family. The reader sees the
  list their character crafts from (`crafting_catalog_key()`, shared with the
  crafting menu). "Include other maps" (`scope = "all"`) adds the rest, and the
  status line counts what is hidden.
- Resource pages list the recipes that make and use exactly that resource
  (60 rows each), in place of a text search for its type path.
- Item pages work as a small wiki entry: the item's kind, its examine text and
  declared basics (size, where it is worn, what it covers, armor, damage,
  caliber, nutrition, stack size), then how to obtain it, its first recipe
  shown without a second click, and a wiki search link. Facts come from
  `scripts/atlas/facts.py`, which reads literal declarations only and leaves
  out anything computed at runtime. Rows are capped at 16.
- Workstations: a recipe card links to where it is made, and a workstation's
  page lists the recipes made there (60 rows). The kind-to-station table in the
  adapter is presentation only; the catalog's `station` field is unchanged.
- Research: gated recipes name their research and show whether the reader still
  needs it, using the crafting admission helpers. This is display only;
  crafting keeps its own checks. Recipes past their last era show as retired.
- Sprites: each client remembers the preview files already sent to it, so
  browsing does not resend them.
- Clicks: the server accepts one atlas request per second per client. The
  window queues the latest click and sends it when the server will accept it.

## Server contract

- Existing matching and variant helpers select records. Resources remain
  independent of recipe-only era and processor filters. Direct resource links
  reset previous recipe filters. Each view remains private to its reader.
- The original per-client ten-tick throttle remains authoritative. Search is
  capped at 64 characters, pages at 1..10000 with 12 entries, graph indexes at
  150 resource and 150 recipe rows independently, and acquisition routes at 12.
- One UI subtype admits only `atlas_navigate`. Its JSON string is capped at
  1024 characters and six scalar fields, with a finite key set for each route.
  The shared adapter still verifies owner, window, generation, status and the
  ready/snapshot/ack handshake. The source additionally requires the current UI
  and its exact owner-bound state. It never forwards arbitrary hrefs or crafts.
- Refreshes send status only. Navigation reopens only this reader through the
  original `show()` entrypoint; it never broadcasts a query to other readers.
  Closing disables machine close logic and retains normal manager cleanup.
- Icon metadata and resource filenames are shared with the classic renderer:
  initial type appearance, paper fallback and `atlas_<md5(id)>.png`. No item is
  constructed for a preview. This does not repair or prove native cache delivery.

## Fallback and isolated fixture

The transport's existing capability selection and startup recovery apply. Once
classic fallback is selected for a UI datum, reopening it retains classic mode.
Its HTML comes directly from the original `render_html()` with the stored view
arguments. The placeholder template is registration metadata; it is not a
replacement implementation of the classic renderer.

The catalog core has a nullable generic presentation seam. Only the full-game
integration imports NanoUI. Existing isolated catalog fixtures which copy the
core file alone keep the original HTML path and need no new gameplay stubs.
The old catalog, matching, variant and HTML-renderer procedures are frozen by
source hashes pinned to `ff3acd14d57ffaad7bad0fae4d440c9173189664`; the resource
image helper extraction is separately checked. No native fixture is modified.

## Verification boundary

Frontend component tests exercise finite navigation, identity separation,
variants, pages, acquisition information, queued clicks, research and map
chips, disabled controls and stale-content clearing. Source contracts and existing offline catalog/DOM
tests check bounds, filters, fallback wiring and preserved data. The production
bundle is exercised through JSDOM and a local headless Chromium fixture, with
fictional catalog data. These browser tests substitute the native transport.

Compilation and hosted CI remain to be run after review/publication. No native
BYOND runtime or client was run for this proposal. Native Topic delivery,
classic reopening, icon delivery/cache, focus/movement, close concurrent with
another window, logout/body transfer and stale generations remain unverified
in a real client. Existing transport tests are projections, not native proof.
