# Reserved lighting overlay candidate

Opt-in map policy `lighting_reserved = TRUE` suppresses overlays only in the
interior of an explicitly reserved region. A one-tile halo retains overlays.
All original corners, masters, light accumulations and source memberships remain.
No map opts in. Empty cells, void areas and z levels do not imply reservation.

Only set the marker in map definitions before lighting startup. Never enable a
reservation on a running tile. `activate_reserved_lighting()` clears it one way,
builds newly exposed halo overlays from the existing graph, and applies current
daylight/TOD/visibility. Construction through `ChangeTurf`, including same-type
requests, activates. Imports activate before decoding payload and ignore any
saved reservation value. Saved/restored cells deliberately lose this optional
allocation optimization; legacy saves fail open to ordinary lighting.

`prepare.py --output <fresh-directory>` writes selected production copies and a
full-source DME referencing this checkout, with normal startup/maps disabled.
It does not launch or discover a compiler. `--control` makes an explicit mutation
in generated copies only. `test_prepare.py` checks extraction and mutation scope,
not behavior. Existing lighting-startup extraction includes the default-false
helper; its historical fixture still checks its own unchanged contracts.
Before eventual compilation, the coordinator's isolated launcher must place the
prepared DME in the checkout root so existing resource paths resolve; this
preparer does not compile the DME from the output directory.

The new native fixture is **uncompiled and unrun**. Expected allocation counts
are assertions to verify, not results: 256 normal overlays versus 220 for an
8x8 reserved region on a 16x16 world, with 289 shared corners in both modes.
It records normal/halo color, luminosity, ownership and source membership rows,
torch movement, daylight, opacity, activation, replacement and native entry
roundtrip. Refusal followed by activation and actual cleanup-body invocation
must retain the new owner. A wrapper around the real production sweep injects
activation and an intentional exception during startup. Activation must return
without waiting; only successful startup may refresh afterward. Reserved subtype imports must activate
the new turf, including when the old turf has a different type.
Paired runs must compare complete states.jsonl rows.
The final activated snapshot has a fixed 30-cell interior whitelist shared by
both variants, plus the original 220 normal/halo rows. Each of those 250 rows
requires an overlay and four corners before recording the actual production
color matrix, luminosity, TOD, visibility, RGB channels, ordered master
coordinates/directions and source-owner memberships. Membership never depends
on observed overlay presence; only six still-unactivated interior cells are
excluded. These are proposed assertions pending native execution.

The carried-source case uses production top-atom ownership and checks removal
from the carrier after release. Pooled refusal uses actual cleanup and pool
callbacks with explicit offline queue retirement, not a running garbage process.
Ice daylight repair clears only a cached overlay pointer and requires the
production repair callback to rediscover its actual owner and retain corners.
Every proposed behavior is still unrun. `compare.py baseline.jsonl candidate.jsonl`
requires all six ordered snapshots and exact equality of their complete rows;
its result cannot establish provenance or replace successful native receipts.
Controls cover virtual masters, halo boundaries and refused ownership. Redundant
individual import/runtime/compatibility guard mutations are omitted: another
production guard can preserve their behavior, making them unsuitable oracles.

Do not launch the fixture until the coordinator releases the native hold and
reviews the exact candidate and launch plan. Use pinned BYOND 516.1681, temporary
storage, closed ports and diagnostic scanning. No CI suite has been registered;
root coordinates shared CI selection after review. Compiler success alone will
not establish allocation counts or lighting parity. No memory/speed gain measured.
The marker adds a scalar field to every turf, including ordinary cells. That cost
is unmeasured. Overlay counts alone cannot establish a net reduction in RAM.
Serializer-only world-save, dimension, operations and wall fixtures share the
minimal `tests/world_save/stubs.dm` adapter. It permits only default-false cells
and raises an error for reserved ones; full production lighting tests must not
include that adapter.
