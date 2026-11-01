# Ship Stocks reader migration

Prepared from master `5bf745fc202ca5cc3794b778b5a5acdb9971264f` as the next
bounded reader in the all-screens migration inventory. This patch is independent
of the unmerged Known Languages PR #3452 and does not include its source or
shared read-only state. Player Help and preferences remain with their owners.

The Voyage ship inventory book now produces structured rows for its existing
ten resources and units, using the existing tally procs unchanged. This includes
their existing area, container and reagent selection behavior; correcting any
unrelated tally defect is outside this slice. The Crew Log's Boatswain/Captain/
Deputy role gate and markup are untouched. No new role restriction is added to
Ship Stocks, which was already readable by human users interacting with the book.

The existing default modern adapter renders a labelled table, with a real
retained NanoUI template for automatic/manual classic fallback. There are no
domain actions, arbitrary HTML, new UI manager or movement/save fields.

A new snapshot requires the existing default state to admit physical interaction
with the book. Once opened, it remains readable while walking, as the old browse
snapshot did. Reusing the book refreshes the counts; processing and manager
refreshes do not rescan storage. The per-window state binds the opening human
body and book and returns update-only status, so both renderer protocols refuse
domain action forwarding. A different body or disconnected reader loses access.
The inherited close callback is disabled before opening, preserving unrelated
machine interactions. Existing registration, generation, startup recovery,
logout, transfer and fallback handling stay with NanoUI/TGUI.

Verification is restricted to offline component/source/bootstrap checks,
TypeScript, an actual classic doT template and production-bundle JSDOM. These
checks do not execute DM or establish native Topic, focus, scroll, cache,
concurrent-window close or body-transfer behavior. BYOND compilation, native
client tests, publication, merge and deployment require Main's next review and
are not performed by this local preparation.

Normal proposed PR CI scope is unchanged: existing exact-pin full-game compile,
bounded offline baseline and the TGUI frontend/build/browser workflow. Adding
Voyage and its retained doT compiler to that workflow's path selector ensures
future edits to these sources exercise the frontend checks. This patch adds no
DreamDaemon/DreamSeeker job, opt-in native fixture or manual dispatch. Existing
master documentation publication is a separate merge-queue scope decision.
