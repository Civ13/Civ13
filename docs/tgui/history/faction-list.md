# Faction List reader migration

Source base: 5bf745fc202ca5cc3794b778b5a5acdb9971264f.

The existing Check Faction List verb now opens the default modern adapter with
a retained classic template. It remains public to its existing /mob recipients,
including observers/dead owners, on civilization maps. Only invoking the verb
rebuilds the snapshot. There are no reader actions or population polling.

The existing reset/tally of map.facl is preserved, in original faction order,
counting every matching non-dead world human, including NPCs and disconnected
humans. Only positive populations are shown. facl is an existing durable map
field; this change neither adds a durable field nor changes serialization.
Manager status refreshes do not recount, mutate the tally or resend symbols.

The cached custom symbol takes precedence over the existing fixed banner shape
tinted with custom_civs[relf][7]. The existing flist_[ckey(relf)].png naming
and browse_rsc-before-window order remain. Neither renderer generates symbols
or invokes the symbol editor, baking, moderation or save routines. Name, stored
encoded motto/flavour, population and optional symbol basename are the entire
view schema. Text stays inert; image sources are restricted to local symbol
basenames and URL-encoded, allowing non-ASCII names without accepting URLs,
paths, query strings or fragments. Existing filename collisions/cache behavior
are not changed or claimed repaired.

The owner-bound state is update-only, closes on stale owner/client or disabled
civilization mode, and introduces no using_object assignment or movement hook.
The reader disables inherited legacy close-side logic so closing it cannot
clear another machine's interaction. Shared generation/handshake/fallback,
unregistering and transfer cleanup stay in the existing adapter.

## Inventory disposition

The merged default adapter covers the original ten NanoUI screens. Four
independent readers are published but unmerged: Known Languages #3452,
Ship Stocks #3460, Religion List #3461 and Crew Log #3462. This Faction List
slice starts directly from master and uses already merged symbol accessors.
It does not depend on those readers. Their shared registry, build and test
additions must all be retained and assets rebuilt when branches are integrated.

Crafting Atlas is a remaining reference-reader candidate with existing bounded
query/pagination and catalog-loading contracts; inspect those before its next
slice. Character memory/discoveries and flavor readers need their existing
knowledge, visibility, stored-rich-text and save-owner contracts reconciled.
Paper/books/photos need per-source content and image policies; do not strip
their formatting mechanically. Containers, crafting, shops, groups and
instruments involve actions, distance checks or prompts and follow the typed
prompt/cancellation foundation. Preferences/random traits and Player Help have
separate owners. Movement/vehicle/HUD, privileged admin, chat/status and
engine-native controls remain later families in the existing all-screens plan.
The inventory is not exhausted and this change creates no new foundation.

## Verification boundary

Local component/source contracts, bootstrap fake-transport tests, production
bundle JSDOM and actual classic doT compilation cover this source proposal.
They do not execute DM or prove native icon generation/delivery/cache, observer
access, Topic transport, movement/focus, scroll, concurrent-window close or
transfer behavior. No native compilation/client, new browser screenshot, remote
CI or deployment was run for this unpublished proposal.

Future normal PR selection is compilation plus the existing offline baseline
and tests/tgui; no new native fixture is introduced. Frontend CI only gains the
factions producer and classic compiler dependency paths. Main reviews the local
packet before publication; the existing merge/publisher hold stays in force.
