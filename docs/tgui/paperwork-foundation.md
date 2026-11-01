# Paperwork foundation - local review slice

This document records the original foundation-only boundary. The subsequent
[read integration slice](paperwork-readers.md) adds shared classic reader routing
on master `fe45306a`. The subsequent capacity correction separates the legacy
snapshot's 1024-node budget from the complete record's 4096-node budget, so
all 128 short sections fit together with an admitted legacy snapshot. Both
copies retain the depth16 and 131072 text-unit limits; section count, total
authored text and physical free-space guards remain unchanged.
Authoring, TGUI and study are still separate work. Historical "not routed"
statements below describe the first foundation candidate, not that reader slice.

The source baseline is `157df2a34cb71758231b39a78308da6af5106953`.
The local candidate also incorporates merged Book master `4e26d579`.
This first slice adds a server-owned versioned document API and offline fixtures.
It introduces no Topic/TGUI endpoint and does not route an existing paper,
container, editor or renderer through the new service. No player-facing paper
behavior is activated. Review this foundation before connecting all read paths
and introducing the editor; it is separate from the Book reader migration.

## Durable data and compatibility

`paper.document_record` defaults to null, so existing saves/items retain their
current behavior. Explicit authorized initialization creates schema version1
with a revision, a server-minted document identity, an opaque `legacy_unclassified`
snapshot, sections and a section sequence. The snapshot preserves `name`,
`info`, `stamps`, `fields`, `free_space`, `stamped`, `ico`,
`offset_x` and `offset_y`, including malformed/incomplete HTML, old dates,
signatures and invisible ink. It does not parse HTML as Markdown, regenerate
signatures, assign an old language or manufacture author/history metadata.
The existing `info_links` field remains byte-unchanged on the original paper,
but is excluded from the new canonical record: it contains derived runtime src
hrefs. Regenerating that cache alone does not invalidate content or supply UI
authority. The new editor/fallback must rebuild transport links, never copy old
runtime hrefs from a saved or copied document.
Unsupported runtime objects/oversized/cyclic records are declined without
changing the original legacy fields. Unknown schemas remain stored and unreadable
through this API; they are not overwritten or repaired into a partial document.

Ordinary item persistence enumerates changed vars, including lists. The old
`map_storage_saved_vars` string alone does not determine durability. The new
record uses the existing typed scalar/list codec; paths in historical lists are
retained as paths. No serialization override removes existing paper fields.
The per-request service is `should_save = FALSE`; its paper reference is also
classified runtime-only. No service, UI, timer, client or study token is stored
on the paper. Native save/load is still untested; offline data round trips and
source checks do not establish native import behavior or Unicode indexing.

New sections are plain text v1 with stable section ID, server-minted text lineage,
immutable positive version, kind, explicit language ID, exact text, pen/crayon
kind and actual ink. Body, title, label, answer and written-signature kinds all
use the same language projection. The initial append API admits only body,
title and signature; form target identity/field creation belongs to the forms
slice. Signatures use the actual pen's existing getter, including chameleon
forgery. This is display text, not authenticated identity. The API is not a new
formatting dialect; the existing legacy parser and editing code are unchanged.
New titles stay in tagged sections; this API never flattens them into the
universally visible item name/description. Inventory/examine labels need the
same boundary when the new authoring UI is connected.

## Written languages and projection

Sixty explicit `civ13:<name>:v1` IDs map to ordinary language datum types from
`language/earth.dm`. IDs are not labels, speech prefixes, runtime references or
list positions. Retain old IDs when definitions are renamed; any future alias
or migration must be explicit. Animal/fantasy/Binary and innate, sign,
nonverbal or hivemind forms have no admitted written representation here.
All registered definitions and their flags are checked by source tests.

Knowledge requires an actual member of the reader/scribe's language list with
the registered type, plus the existing `can_speak()` on that actual member.
Rebinding by type avoids relying on singleton pointer identity across import.
Mute/silent physical speech state does not remove writing knowledge. Universal
understanding, universal speech without membership, dead/admin/ghost status,
species similarity and partial-language skill do not grant new text knowledge.
An eligible current default may preselect authoring language; committing always
requires an explicit eligible ID, and changing defaults never rewrites sections.

`project()` rechecks physical/control access on every call. It returns complete
known sections or the stable `[Unintelligible writing]` placeholder, independent
of the original secret's contents or length. All text kinds use this boundary.
There is no `hear_say`, partial scramble, reading XP or knowledge acquisition.
Ink is retained independently, including white ink; the later renderer must use
the equivalent opaque white page without contrast/reveal additions. Legacy
unclassified content retains its original human/ghost/forceshow comprehension
rule rather than an inferred language. No new ghost/admin bypass is added to
language-tagged sections.
Language knowledge is an additional gate after existing literacy/admission:
even a known-language nonhuman remains unreadable, and a known-language ghost
with `forceshow = TRUE` does too. A known-language ghost with `forceshow = FALSE`
retains the existing comprehension case after physical admission. This API
does not implicitly expand species literacy.

Canonical copying is a separate server-only API. It preserves originals and
language/lineage/version metadata, without a viewer's redaction or character
progress. The future copier must allocate a different physical document identity
while retaining faithful text identity. Never pass canonical data to a browser,
tooltip, accessibility label or classic fallback. Before exposing new authoring,
every paper/folder/clipboard/bundle/envelope path must consume the authorized
projection, and classic HTML must be built from that same projection.

## Mutation and integration boundary

Initialization and append recheck a linked actor/control session, physical access,
incapacitation/restraint, the actual active pen in that actor's possession and
current language membership. Append also checks document identity, revision,
legacy-source equality, kind and capacity, then validates and commits a bounded
copy without yielding. Lost access, language, pen, client or revision rejects
without changing the record or capacity. A legacy edit makes the modern append
stale; it never silently replaces or reparses old content. The next slice must
join legacy edits and record updates in the shared transaction gateway.
Projection and canonical copying also fail closed after a meaningful legacy
change, so newly typed legacy text is never silently exposed as unclassified
content by the new service. Cache-only link regeneration is exempt.
Each service context binds the actual controller and client at construction;
reconnects cannot reuse it. Reads and internal canonical-copy access recheck that
binding too. The future UI must additionally retain adapter generation checks
and create/cancel request contexts around its own pending interactions.
It must also cover renaming and printing: freshly authored text must not be
silently rebased as `legacy_unclassified` through an old editor or item label.

The first physical adapter admits a held page, an adjacent page on a turf, or
a page in a held clipboard/folder; deleted parents fail. Other containers,
including envelopes/bundles, are denied until their real page/seal access is
integrated. Existing legacy flows remain unchanged. These are explicit next-slice
dependencies, not claims that all new document routes already work.
The existing ghost examine path has broader range admission; its explicit
read-context adapter must be retained when connecting the new service, without
turning that physical permission into universal language comprehension.

## Dependency-ordered remaining work

1. Connect all server read/fallback paths and legacy editing transactions, then
   add TGUI authoring and preview with format help and cancellation. No canonical
   original may reach a reader who lacks section knowledge.
2. Add stable form targets and language-bearing labels/answers, subtype hooks,
   templates and stamps. Reproduce the commented-out stamp recording failure
   and fix its data/overlay delivery in a bounded stage; it is not fixed here.
3. Integrate faithful copying, filing and envelope/clipboard/bundle access,
   respecting era constraints and existing government/warrant programs.
4. Add deliberate study as a separately reviewed stage. Progress belongs to a
   durable character identity, not account/name/client/item, keyed by text lineage,
   immutable section version and language. Do not use content-hash-only phrase
   learning. Faithful copies preserve text identity; newly typed material has new
   lineage. Edits create a new version and cancel old study; never remap offsets.
   Appends add unknown sections. Completed increments may persist; unfinished
   work cancels. No open-window/offline time, copying, reopening or rerolls grants
   progress, and no language skill/default/Known Languages notes are changed.

Study should use bounded server phrase/sentence units and a token layered on
the existing `do_after`/`may_do_after` rules. Recheck character/control session,
page, all container ancestors/seals, immutable text and visual ink access
throughout and before a once-only non-yielding credit commit. Reject before
emitting an action start. Cancel on movement, changed hands, deletion, revisions,
closed/sealed containers, logout/body switch and explicit cancellation.
Proposed balance: configurable multi-minute increments (for example five minutes
per unit), deliberately long completion and no automatic reading XP. The user
has not selected an exact duration. No character-ID or study implementation is
claimed by this foundation.

## Evidence and attribution

Tests execute complete production procedure bodies through a bounded audited
Python projection with inert engine/list/clock seams. Character and UTF-8 byte
length adapters are labelled approximations. No native compiler, runtime,
savefile, gameplay or graphical test was run. There is no new dependency or
asset. Existing sparse-excluded DMI fixtures needed by the CI registry test were
materialized from exact tracked Git blobs, without editing them.

The architecture discussion references tgstation
`5ee81d694bd1f15bb4f39e3da49918ead35de4ca` and its PaperSheet/paperwork split.
This implementation is original Civ13-specific code; no tg code or asset was
copied. Before any later adaptation, inspect that individual file/asset's header
and the licenses at its immutable source pin. Do not assume one license covers
an entire upstream dependency or asset tree.
