# Reserved lighting overlay candidate

Opt-in map policy `lighting_reserved = TRUE` suppresses overlays only in the
interior of an explicitly reserved region. A one-tile halo retains overlays.
All original corners, masters, light accumulations and source memberships remain.
No map opts in. Empty cells, void areas and z levels do not imply reservation.
Omission also requires `/area.lighting_reserved_clearance_enabled == TRUE`.
Its default FALSE and every other value keep overlays active. It is an author
switch, not a certificate: enabling it requires independent review of a frozen
map/source/asset inventory and declared inert clearance. No production map enables
it. The switch is excluded from ordinary area save export/import. Never enable it
for a region whose appearance inventory, reachable states or future immutability
are unknown. No new movement/state interception hooks are implemented.

The one-tile halo is only a graph halo. Actual normal/snow pine frames are 64x96;
constructor offsets x=-24..-8/y=0..16 give a conservative full-frame rectangle
x=-24..55/y=0..111, touching offsets dx=-1..1/dy=0..3. Empty neighboring anchors
do not establish that an omitted cell has no overlapping canopy. Preserve masks
on every overlapping cell or keep the gate off; no global three-tile fix is
claimed. The reported live canopy composition defect remains unconfirmed.

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

## Declared author-clearance schema

`clearance.py declaration.json --repository <frozen-checkout>` accepts exactly
`schema_version` (1), `bindings` (relative file paths to SHA256), `world` ([x,y,z]),
`region` ([xmin,ymin,zmin,xmax,ymax,zmax]), `omitted_cells` (unique [x,y,z] rows),
`appearances` and `unknowns` (must be empty). Bind the actual map, inventory/source
audit and every relevant resource. The validator verifies supplied bindings; it
does not discover missing map entries or establish inventory completeness.

Each appearance has exactly `resource`, `states`, `anchor` ([x,y,z]), `pixel_x`
and `pixel_y` (inclusive min/max pairs), `transform` (`identity`), `lifecycle`
(`frozen-static`), `overlays` and `underlays` (both empty). DMI frame dimensions
and declared states come from the bound resource. Complete frame rectangles at
offset extrema conservatively cover all placements; alpha, collision bounds and
TILE_BOUND are not clearance oracles. Every intersecting omission is rejected.
The existing graph halo, world bounds and duplicate coordinates are checked too.

`frozen-static` is a declaration requiring source evidence, not a mechanism that
freezes a game atom. Ordinary trees can change state; unaudited death/radiation,
seasonal resources, transforms, nested appearances or map/admin/save overrides
belong in `unknowns` and refuse approval. Runtime transitions remain unsupported
for enabled regions. A successful report proves only the supplied frozen static
geometry; it cannot authorize the area switch or replace independent review.

Offline tests use real normal/snow pine resources and all six live states with
1,734 offset placements. Full-rectangle controls reject two/three-tile overlap,
allow a nonintersecting declared scene and reject unknown/death/transform/nested
appearance, source drift and invalid cells. These are not native renderer tests.

## Current CI parity lane

`run-ci.py --byond-bin <516.1681-bin> --output <new-directory>` runs only
in a disposable CI workspace. It prepares the actual merged production sources,
compiles five closed-port 16x16 fixtures, and compares all six complete native
state snapshots with reserved omission off versus on. The virtual-master mutation
must reach a structural snapshot mismatch; halo and refused-owner mutations must
fail their named assertions. Compilation and execution have finite per-process
timeouts and preserve logs and source manifests. No live world, user session or
renderer is used. The default area clearance flag remains FALSE and no map opts in.

The workflow now selects this native lane for the introduced suite or extensive
regressions and retains evidence even on failure. The older Windows contained
runner remains a separate explicitly granted workflow. Earlier statements above
about an unregistered/unrun native fixture describe that original review stage.
A passing CI run establishes only these native state/parity checks, never client
pixels, complete map clearance, net memory savings or deployment readiness.

The Linux CI runner binds only `icons`, `sound`, `UI`, `interface` and `code/js`
from the checked-out revision beside each generated DME. BYOND resolves resource
literals relative to that DME even when source includes are absolute. No existing
save or runtime configuration directory is linked into the fixture. This staging
fix does not change the frozen Windows runner or claim parity before native tests.
