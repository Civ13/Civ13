# Character return and sleep-zone migration

Base: master `c79792d002b9a15b7cebd7735a43f6ac960ad4b2`. PR #3278 merged
as `9618d92d1d612887441ed502a31aadddf5b5ca66`; retain its runtime-reference
exclusion and the owned save/load admission introduced by #3276.

## Existing authority and limits

`player_reclaim.dm` already saves canonical account ownership on the actual human
and restores its physical inventory through the world graph. Lobby Login claims
that same body after successful complete-world restoration. PreferencesSQLite
character slots are appearance/preferences, not medical/inventory snapshots.
There is no independent durable character store or assigned-bed record. Buckling
is a spatial relationship, not ownership. Do not serialize a new cross-z bed link.

Protected Sleep currently moves a body to (1,1,1), retains lastx/y/z, and suppresses
some needs using inducedSSD. Its Wake Up delay returns the same body. Removing
that body from the world after a save would require an atomic independent custody
store; the current world saver cannot safely support that. This migration keeps
one physical body and inventory in the world. Bed sleeping is not an immediate
disk save or invulnerability; only a completed world generation is durable.

## Small local migration

- Apply new behavior only to existing durable Nomads profiles (Gaia and Europe).
  TDM and other maps retain their existing respawn and sleep rules. Dead bodies
  are never revived; normal new-character admission after death still uses the
  existing respawn restrictions. No rejuvenation, equipment or job assignment
  runs on reclaim.
- Sleep on an available stationary bed records a scalar canonical account claim
  on the bed and keeps the body there. One account may assign one bed; another
  account cannot silently take it. Chairs, carried/rolling beds, protected cells,
  blocked locations and another occupant are not return destinations.
- A saved body's first lobby reclaim prefers its unique valid assigned bed.
  The existing restored-body registry claim is consumed after successful key
  handoff; later lobby reconnects do not repeat bed placement. Keep the separate
  persistence_restored marker set to suppress delayed fresh-body customization.
  Ordinary induced bed sleep is not a pending imported return. Physical legacy
  zone residents still take the safe exit path even without an import claim.
  Missing/ambiguous/unsafe bed falls back to the body's safe saved location.
  A legacy protected sleeper may instead use its validated saved return point.
  If neither is safe, retain body/claim and hold in the lobby, with an explanation.
  Never invent coordinates or send a returning body to an initial-arrival spawn.
  Contained saved bodies and saved riders/drivers hold for ordinary dismount/unload
  reconciliation instead of being extracted with dangling vehicle relationships.
- Native reconnect to a still-existing body preserves its current position;
  reconnect is not a free bed teleport. Retain the legacy wake path for old
  sleepers and do not remove physical sleep-zone safety checks.
- Reclaim preserves the existing registered-body Login admission: guest/account
  bans and persistence readiness apply, while fresh-character entry locks,
  round state, players_can_join, trait and role/respawn checks do not govern
  reconnecting to that owned body. This is not identical to new-character joining.
  The new local-owned-body retry uses that reconnect policy too; a genuinely new
  character still follows ordinary creation checks. Recheck Playing/Server bans
  after return movement callbacks, before key transfer. A refusal retains the
  lobby and pending body claim for retry; movement may already have placed the
  still-sleeping body safely at its bed.
  Defensively rescan local ownership after callbacks: the selected body must
  remain the sole locally owned body before handoff. Normal owner recording
  clears an earlier owner; this protects the invariant against direct callback
  changes, rather than documenting a confirmed ordinary gameplay failure.
- Lobby join and final character creation retry reclaim before new-body creation
  and hold when an owned live/ambiguous/occupied body or incomplete recovery exists.
  Reserve the existing body before movement callbacks or key handoff. Failed
  movement releases only this claim reservation and never starts fresh creation.
- Missing/incomplete/corrupt generations hold when save artifacts or a recovery
  hold exist but import has not completed. A healthy generation with no account
  claim, or a genuinely fresh world with no save artifacts, may use ordinary new
  character admission. Without a historical account manifest, an externally lost
  whole save directory is indistinguishable from a fresh installation; this patch
  cannot recover deleted data or infer ownership from lastKnownCkey/name.

## Relationship to #3311

The topology/lifecycle design distinguishes initial safe edge arrivals from owned
character returns. This patch uses the existing local world/body claim only; it
does not add shard IDs, custody providers, transfers, initial arrival placement,
or a competing persistence format. Future configured shared custody must fence
this local admission before activation. Local ckey ownership is not shard custody.

## Acceptance and deployment

Offline source-flow tests cover bed validity, ownership, fallback, legacy return,
same body/inventory, two competing clients/reentrant callbacks, failed movement,
save/load/recovery holds, dead-body policy and final new-body admission. Retain
existing ownership, sleep, movement and topology regressions. Offline projections
are not native Login/Entered/HUD acceptance. No live save, configuration, native
world, deployment or restart is part of this task. Runtime paths/configurations
remain unchanged on D:; this C: checkout contains temporary source work only.

Implementation lives in `code/modules/persistence/bed_return.dm`, extending the
existing `reclaim_saved_player` handoff. `tests/save_movement/test_character_return.py`
executes complete selected production bodies with explicit native-list, location,
callback and key-transfer adapters. Generated source omission controls expose
reservation theft and unsafe fallthrough to fresh creation. Medical objects,
health, nutrition and water remain unchanged during the projected return. Another
check executes the actual changed-var selector against nondefault nutrition/water
using defaults read from carbon_defines.dm. Neither is a native disk round trip.

The existing minimal serializer fixtures explicitly leave the bed profile disabled
through adapters in stubs.dm. Their native results cannot establish bed return.
Before activation, exact-source native compilation, bed-claim disk export/import,
real Login/HUD/reconnect, refused/redirected movement, destroyed/occupied beds and
representative character medical/nutrition/water state need native acceptance.
No body deletion, independent character-file import, offline immunity, automatic
logout save or shared-custody activation is implemented by this local migration.
