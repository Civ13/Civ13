# Local vehicle level shifts

Run the offline suite:

```sh
python3 scripts/ci_baseline.py unit --suite vehicle_level_shift --output /tmp/vehicle-level-shift.json
```

`test_shift.py` executes complete source-projected bodies of the shared axis
helper, both public wrappers, tile-guard cleanup and passenger-vision refresh.
The fake boundaries model only the list operations, typed iteration, coordinates,
movement effects and deletion states needed by these procedures. They are not
native BYOND behavior. `legacy_shifts.dm` freezes the two original procedures
from master `6f8adb761` for differential checks without a Git-history dependency.

Coverage includes horizontal offsets, same-level movement, missing/out-of-map
destinations, initial and reentrant guards, duplicate movers, frame-first order,
passengers and cargo, contained controllers/wheels/items, stale and callback-deleted
movers, exception identity, guard cleanup, replacement tile owners and refresh
order. Negative controls remove offsets, deduplication, frame movement, exception
cleanup and vision refresh. The suite also records existing behavior for an empty
mover set and a false `forceMove` return, rather than changing those contracts.

The shared operation validates destinations before moving but is not a rollback
transaction. An exception can leave already-moved atoms at their destinations;
cleanup releases this operation's guards and propagates the original exception.
Flight/depth admission and state changes remain outside the shared helper.

Native probes use the existing aircraft fixture, including
`tests/aircraft/level_shift.dm`; see `tests/aircraft/README.md`. Full client gameplay,
rendering and persistence round trips are separate verification.
