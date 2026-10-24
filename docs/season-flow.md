# Configurable base season flow (review candidate)

`map.season_cycle` is an optional ordinary ordered list. Null retains
`SPRING -> SUMMER -> FALL -> WINTER -> SPRING`. A reviewed configuration such as
`list("SPRING", "SUMMER", "FALL")` skips Winter. Each actual transition selects
one destination, uses its existing payload, and retains exactly one counted-decay
hook with the admin's explicit keep/advance-age choice. Omitted seasons are not
synthetically executed and never charge extra age. The merged 60-minute duration
configuration and existing pending timer remainders remain unchanged.

## Supported edges

| Previous season | Spring | Summer | Fall | Winter |
| --- | --- | --- | --- | --- |
| Spring | reject duplicate | legacy | reconcile | reject |
| Summer | reconcile | reject duplicate | legacy | reject |
| Fall | reconcile | reconcile | reject duplicate | legacy |
| Winter | legacy | reconcile | reconcile | reject duplicate |

The four legacy edges keep their exact existing main payloads, probabilities,
delayed cleanup and phase timing. The reconciliation helper is a no-op on those
edges. `SPRING -> WINTER` and `SUMMER -> WINTER` are rejected: Winter's existing
probabilistic freeze assumes Fall's earlier cold work. A new explicit cold-entry
profile is required before accepting those edges. Even the legacy Fall-to-Winter
edge retains its historical partial/probabilistic behavior; it is not a guarantee
that every ground tile freezes before a forced admin transition.

Validation examines **every edge in the whole configured cycle before admitting
any transition**. It requires 2-4 unique implemented identifiers, plain
non-associative entries, the current season's presence and only supported edges.
Empty/singleton cycles, unknown names, wrong types, duplicate/associated entries,
missing current seasons and cycles containing either unsupported Winter-entry
edge consume the request without changing season, epoch, weather, decay age,
phase ownership or completion state. Repair the policy before another request.
Use the seasons toggle to stop cycling. Future event identifiers remain rejected
until an implemented, reviewed source profile supports them; configuration cannot
name executable callbacks.

## Reconciliation of the six nondefault supported edges

The existing queue first applies the actual destination once, then reconciles
missing target state under the same busy lock and epoch, and finally invokes the
existing map completion hook once. There are no additional delayed phases,
synthetic season requests, weather changes or random draws in reconciliation.

All six nondefault edges reconcile:

- **Warm ground:** temperate forest winter dirt becomes ordinary dirt; temperate
  winter grass becomes ordinary grass. Roofed winter ground becomes dirt, using
  the same ground classes as Summer's existing cleanup. Taiga/tundra forest and
  permanent cold-biome ground are not globally melted. This does not claim a new
  water-ice model; only the worker's existing winter-ground classes are reconciled.
- **Snow structures:** the three existing snow-wall/barrier/item classes retire
  through normal qdel outside tundra/taiga. Skipping Spring therefore cannot omit
  this worker's completed warm-season snow-wall cleanup.
- **Wet Spring:** wells/puddles become wet; desert dry-channel classes become
  their swamp classes; flooded dirt and flooded ploughed dirt become flooded water.
- **Dry Summer/Fall:** desert wells/puddles become dry; upper-level desert swamp
  and flooded-water classes become their existing dry/dirt counterparts. The
  existing z>1 restriction is retained. Lower-level flooding stays for the owning
  map's completion hook rather than being silently widened globally.

The new dry profile enumerates actual sinks and checks their area. The unchanged
legacy Summer body attempts to iterate a turf snapshot as sinks; this candidate
does not repair or relabel that legacy path. Nondefault edges have the explicit
dry-state contract above, while default-cycle behavior remains unchanged.

Asia's existing completion hook then dries flooded water in Summer/Fall and wets
flooded dirt in Spring/Winter, including z1. Its production body is unchanged and
tested after reconciliation for every supported edge. Other map completion hooks
retain their current dispatch. Mountain, Ice Age, Colonia and Pepelsibirsk have
explicit custom calendars and do not consume this base-worker policy.

Every terrain pass uses the existing fresh filtered area snapshots. Snow/sink
passes reuse the existing bounded candidate discovery. Each mutation rechecks
the candidate after `season_work_pause`; every pass retains worker/epoch checks.
An invalidated owner stops without running later completion work. One constructor
or deletion hook remains indivisible, so this is not a hard latency/memory bound.
State is idempotent on repeated cleanup: no further terrain replacements, snow
retirements or age charges; an existing sink icon may refresh again.

There is no saved cycle cursor. Reload uses the restored current season plus
installed author policy. Runtime exclusions retain both `season_duration_minutes`
and `season_cycle`; policy is absent from the durable map schema. Configuration
that omits a restored current season intentionally holds the next transition.

## Verification scope

Offline checks execute restricted projections of production validation, queue,
reconciliation and Asia completion bodies. They cover all twelve directed pairs,
both rejected edges before mutation, each of the six newly supported paths, thaw,
snow retirement, wet/dry state, z/climate exclusions, stale candidates, epoch
cancellation, idempotence, queue reentry, stale phases, single age charging and
admin keep-age. The destination-prefix boundary adapts legacy terrain/RNG work;
the remaining default payloads are separately compared byte-for-byte with an
immutable baseline. Duration tests retain cadence/configuration coverage; flow
tests own destination and queue parity so independent flow work is not blocked
by a historical whole-procedure byte freeze.

Terrain replacement, lists, locations, budgets and qdel are Python adapters. The
tests do not establish native callback timing, constructor side effects, complete
ecology, connected-client appearance, runtime memory/performance or restart
acceptance. Existing native source extraction is checked for helper retention
only; no claim is made that a native fixture was compiled or run. Native testing
remains held for the uncertain movement execution and denied process inventory.
The current testing window is owned by the parent coordinator. No existing sealed
packet, server, save, active configuration or live Gaia cycle is changed here.
