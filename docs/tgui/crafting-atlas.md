# Crafting Atlas reader migration

The in-game Crafting Atlas uses the existing default modern adapter. It remains
a public, read-only catalog for connected mobs, including observers and dead or
incapacitated readers. Opening a processor's reference still selects that
processor. This does not grant crafting permission or change recipes, jobs,
map/faction gates, research, skills, tools, payment or item construction.

The modern screen provides resource and recipe results, dependency columns,
variant/source selection, acquisition guidance, search, unlock-era and processor
filters, and the existing explicit paginated list. Filter drafts stay local
until submission; cancelling edits sends no action. The classic Search prompt
and its cancellation behavior remain in the original HTML renderer.

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
variants, pages, acquisition information, local cancellation, disabled controls
and stale-content clearing. Source contracts and existing offline catalog/DOM
tests check bounds, filters, fallback wiring and preserved data. The production
bundle is exercised through JSDOM and a local headless Chromium fixture, with
fictional catalog data. These browser tests substitute the native transport.

Compilation and hosted CI remain to be run after review/publication. No native
BYOND runtime or client was run for this proposal. Native Topic delivery,
classic reopening, icon delivery/cache, focus/movement, close concurrent with
another window, logout/body transfer and stale generations remain unverified
in a real client. Existing transport tests are projections, not native proof.
