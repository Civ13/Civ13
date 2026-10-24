# Prepared zone persistence fixtures

`test_contract.py` runs independent format examples and source checks only.
The zone fixture has not been compiled or executed on BYOND. The existing world-save preparer accepts
`--zone-topology --prepare-only` and refuses zone native execution.

`probe.dm` has two successive-generation modes, prepared but unrun:

- `write-sequence` uses production Save_World three times. It archives complete
  synthetic generations under `zone-fixtures/baseline`, `changed` and `deleted`,
  copying the completion marker last. A manifest records distinct generations
  and both affected area IDs.
- `read-sequence` requires those synthetic archives and manifest in a fresh
  isolated fixture directory. It imports baseline, changed and deleted in that
  order, each twice, using production ticker.loadmap. No production save path
  or runtime installation is an acceptable fixture directory.

Baseline gives each of `latejoin_turfs["target"]`, `newplayer_start`, `latejoin`,
`paradrop_landmarks` and `supplydrop_turfs` one destination on z=1. Changed moves
all five destinations to z=2 and adds one destination to each list. It creates
another named group and a same-type area; the previously saved area's exact ID
moves from (2,3,1) to (2,3,2), with the old turf returned to the base area.
Deleted empties all five lists, removes the old and new named groups, clears
durable aliases and deletes both areas only after their earlier saves exist.
The reader asserts coordinates/counts, old membership removal, area aliases and
list keys, stable instance identity between baseline/changed/repeated loads,
then absence of the deleted area IDs in the final area registry.

Existing `write`, `read`, `legacy-write`, `legacy-read` and malformed-input modes
remain. `absent-zone` now reads the target spawn's exact zone ID, proves positive
membership references to it, removes exactly that ID's inventory row and leaves
both spawn and membership references unchanged. Its temporary
`zone-negative-setup.json` records this proof. The other negatives cover duplicate
spawns/zones, stale IDs, out-of-range z, fractional coordinates and missing or
out-of-range scalar capture indexes. Membership is stored in level savefile
zone_capture records, not a world JSON run list.
Each malformed reader tests sentinel and index preservation before any ClearMap.

These are fixture source intentions, not native results. The fixtures reject
clients/Topic, refuse port reopening, and require an external listener-closure
acknowledgement before setup. Preparation does not compile or execute the fixture.

`test_revision.py` adds bounded-counter/collision, older-generation divergence,
staging surprise, retirement-failure and unavailable-registry controls. It also
projects the production admission predicate and allocator control flow with
explicit scalar/engine adapters; this is offline evidence, not execution of DM.
