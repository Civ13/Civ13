# Production geometric visibility

`CIV13_GEOMETRIC_LOS_CORE` defaults to **1**, with a compile-time override to 0.
This replaces the former test-only 21x21/two-client admission policy. It is a
visual and hover/examine policy, **not** a new weapon, click, drag or Topic
authorization system. Existing action checks remain unchanged.

Contexts belong to one connected human/body/own-eye combination. Observer,
non-human and remote-camera modes retain their native behavior. An otherwise
eligible human with blindness, unconsciousness, world reconstruction or
outstanding mutation tickets cannot obtain a world snapshot. Owned inventory
examination and screen-slot hover remain independent of world geometry.

Capture covers the actual z level and viewport (up to 63x63), plus one edge tile,
accepts ordinary terrain and clutter, and derives blockers from raw opacity.
Partial movement contributes `step_x/32` and `step_y/32` to the eye and moving
opaque blockers. All geometric products use eye-relative coordinates rather
than whole-map coordinates. Opaque targets use a closed ray and nonopaque targets a closed quarter-tile
footprint. Blockers on the target's own native turf do not occlude that target,
including items, mobs, ground, offset objects and multiple opaque owners. Other
tile blockers still occlude normally. Snapshots retain native tile coordinates
separately from fractional geometric centers; cache keys include both tile and
geometry plus the opaque/nonopaque policy. This is a
tile opacity model, not a reconstruction of irregular collision bounds.

A renderer captures once and calls `decision_snapshot(target, snapshot)` for its
pass; repeated nonopaque footprints share a snapshot-local cache. Hover/examine
capture fresh raw geometry each time. A snapshot is never an action lease.
The visual presenter only subtracts from native visibility; native transport and
BYOND sight restrictions remain in effect. No guarantee of seeing geometry that
BYOND did not send is made. The legacy directional human FOV rule is preserved.

Contexts, snapshots and mutation tickets are unsaveable. Context retirement also
retires its visual/tree presenters. Initialization and process reconciliation are
owned by the production presenter integration. No data is serialized as a cache.

## Offline checks

```sh
LOS_EVENT_BASE=<full-event-base-sha> LOS_EVENT_HEAD=$(git rev-parse HEAD) \
  python3 -B -m unittest discover -s tests/los_context -p 'test_*.py' -v
```

`test_offline.py` retains the independent rational convex-hull/ray oracle and
1,764 footprint plus 1,764 ray cases, mutation ownership and historical omission
controls. It checks default-on with explicit override rather than obsolete
fixture caps/no-production-callers assertions. Event-base/head checks retain
immutable provenance and existing adapter placement/retirement assertions.
The historical introducing-change disabled projection is not default-on behavior
evidence. The explicit OFF read path still reads no arguments.

`test_production.py` adds 96 fractional-eye geometric cases and translation
checks at large map coordinates, plus source contracts for opacity-only capture,
per-z/view bounds, movement offsets, shared decisions and presentation cleanup.
These are source-derived Python projections, not DM compilation or native pixels.
The initial updated ownership projection failed because its Python adapter did
not map the newly read `owner` field; the adapter was corrected. That was not a
native runtime result.

## Native acceptance still required

Compile the exact candidate before native fixtures. Exercise more than two
clients and eight roots on actual Gaia grass/clutter; doors/opaque movers, smooth
movement, rectangular views, world edges and z transitions; inventory versus
world hover/examine; observer/camera transitions, reconnect/HUD replacement,
save/load and clean opt-out. Capture actual root-lit tree pixels with weather,
shadows, roofs and hidden roots. Measure dense-scene capture/image allocation and
network work before claiming production cost or player capacity. Offline tests
establish none of those rendering, lifecycle or performance outcomes.

Ordinary saves continue fresh read-only geometry capture because same-z movement
remains permitted. Load/reconstruction and explicit mutation tickets suspend
capture without withdrawing existing denied-world masks.
