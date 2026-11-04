# Carriage visual glide ownership

The ordinary carriage still advances one turf per existing movement-loop pass.
Collision checks, hunger, health, forceMove callbacks, gears, directions, offsets,
bounds and movement mode are unchanged. The loop captures the carriage's next
wait once and passes that same interval to the visual helper and native spawn.
Other vehicles retain their original scheduling expression.

One runtime-only lease per leg owns the carriage and its current physically
co-located passengers, animals and cargo. Explicit fractional glide is
`32 * world.tick_lag / interval`, with Euclidean diagonal scaling only when the
atom does not already have LONG_GLIDE. The next existing loop wake retires the
lease before starting another leg. Stop therefore lets the last committed visual
leg finish, instead of restoring default fast glide immediately. Repeated starts
while a wake is pending do not retire it. No extra timer or physical pulse exists.

The existing moved/destroyed observers detect removal and deletion. One-use
old-location/destination pairs distinguish the expected transport arrival from
other movement. Nested arrivals consume no reusable permission. Retired lease
identity rejects stale callbacks after a new lease or reboarding. Explicit
unload/dismount/untie paths release without requiring an arrival. Existing safety
checks reconcile membership and raw-location drift; raw loc assignment does not
raise the normal moved event and is not claimed to be detected immediately.

Callbacks reject null actors before dereferencing ownership: the dispatcher can
resume after another listener deletes an actor. Release explicitly unregisters
both callbacks for every live recorded member, including one whose owner pointer
has changed. The registry removes empty callback/listener/source entries. No
global subscription is created. The existing observation cleanup wrapper also
decrements event_listen_count/event_sources_count and removes zero-count keys;
the prepared fixture checks both listener tables and lease counter-key absence.
Clearing reciprocal owner pointers and the member
list then removes the remaining durable references; a currently executing callback
may retain the lease until it returns. Ordinary datum reference disposal is
sufficient after these edges are removed; no qdel scheduling is required merely
to retire this appearance lease. This is a source lifecycle argument, not a native
heap measurement. The prepared native fixture checks registry absence explicitly.

Restoration compares current glide with the lease's applied value; a changed
foreign value survives. Claiming a human first retires existing human-subtile
body/client visual ownership. Walking's next visual claim releases any carriage
lease on that body. Physical subtile state is not reset. This does not introduce
carriage camera/FPS ownership: connected-driver camera behavior still needs its
own acceptance. A foreign writer using the identical numeric value is not
identifiable without a cooperating ownership handoff.

All lease pointers, saved/applied values and expected arrivals are excluded from
the custom saver, as is owned glide_size. Lease datums are not saveable. No world
save format changes. The next movement reconstructs appearance ownership.

## Evidence boundaries

Fixture-only paired probe at controller
`e91d1fb4f9ff4baf36a64dc2546fc277f9365753`, run
https://github.com/Civ13/Civ13/actions/runs/40631681096, used gameplay source
`58404f5bd16e3fed80f1d9844c5db3edd144942c` and BYOND 516.1688. Its first
32-pixel carriage glide took approximately 0.4 seconds; assigning 16/21 to the
same four atoms made the second take approximately 2.1 seconds at unchanged
21-ds logical cadence. All four entities' sampled integer displacement agreed.
Artifact 12791652188 SHA256:
`b68d45d6cb55983293708b047c9a4c3b57c4b36a5832cf8cfde8bf61afa8ed84`.
This supports the formula in that straight fixed-camera fixture, NOT this new
production lease implementation, general smoothness, or marketing acceptance.

`tests/carriage_glide/test_sources.py` checks source contracts and omission
controls offline. It does not execute DM. `probe.dm` prepares actual production
handoff/removal/reboard/foreign-change/save-exclusion checks for an authorized
isolated full-game fixture; it is not included or run automatically.

Before acceptance, compile this exact production candidate and run the prepared
contracts, then exercise consecutive fractional legs, natural stop completion,
restart while pending, cardinal turns, collisions/ejection, speed changes during
a wait, death/deletion, forced cargo removal and reboarding. Compare callbacks,
positions, hunger/health, and saved fields against baseline. Fast fractional gear
waits (for example 2.6 ds at a 0.5-ds tick), scheduler lag and yielding movement
callbacks need native timing coverage; no scheduler quantization or no-jitter
claim is made from source tests. Connected clients must cover prior subtile
visual ownership, camera motion, logout/body handoff and restoration. Native
save/load and arbitrary raw-location writers remain separate acceptance gates.

## Rider synchronization regression (#3627)

The rider jitter in the village trailer raw take (about 0:57-0:59) came from a
build of game revision `58404f5`, which predates this lease. Frame tracking of
that take shows the carriage and horses gliding at gallop speed while the rider
glided at the fixed 4 px/tick its scripted walk left on it, so the rider fell
about 11 pixels behind on each tile and then snapped forward. Players hit the
same mismatch whenever their walking glide differed from the carriage's.

`tests/carriage_glide/ride.py` is a headless full-game regression for that
cause (native, not run by CI). It appends `ride_probe.dm` to a temporary copy of
`civ13.dme`, boards a driver whose glide is a fixed 4 through the real
`MouseDrop_T` path, hitches two horses, drives east through all three reins
gears, stops and dismounts. Every leg must give the driver, both horses and the
carriage the same glide_size, equal to `32 * world.tick_lag / interval`, and
dismounting must restore the driver's 4.

```sh
source ~/byond-516.1688/byond/bin/byondsetup
python3 tests/carriage_glide/ride.py --byond-bin ~/byond-516.1688/byond/bin
```

On master `6fb1998` with BYOND 516.1688 on Linux it passed with 6, 12 and 16
sampled legs at gears 1-3. The same probe on `58404f5` fails at the first leg
(carriage and horses 0, rider 4). This is server-side glide evidence; connected
DreamSeeker camera acceptance remains as described above.
