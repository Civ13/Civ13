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

The original Windows review stage left this fixture unrun. Current Linux
parity acceptance is recorded below; allocation assertions are: 256 normal overlays versus 220 for an
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
excluded. Current Linux native parity acceptance is recorded below.

The carried-source case uses production top-atom ownership and checks removal
from the carrier after release. Pooled refusal uses actual cleanup and pool
callbacks with explicit offline queue retirement, not a running garbage process.
Ice daylight repair clears only a cached overlay pointer and requires the
production repair callback to rediscover its actual owner and retain corners.
`compare.py baseline.jsonl candidate.jsonl`
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
compiles six closed-port 16x16 fixtures, and compares all six complete native
state snapshots with reserved omission off versus on. The virtual-master mutation
must reach a structural snapshot mismatch; halo and refused-owner mutations must
fail their named assertions. Compilation and execution have finite per-process
timeouts and preserve logs and source manifests. No live world, user session or
renderer is used. The default area clearance flag remains FALSE and no map opts in.

The workflow now selects this native lane for the introduced suite or extensive
regressions and retains evidence even on failure. The older Windows contained
runner remains a separate explicitly granted workflow. Earlier statements above
describe that original Windows review stage.
A passing CI run establishes only these native state/parity checks, never client
pixels, complete map clearance, net memory savings or deployment readiness.

The Linux CI runner binds only `icons`, `sound`, `UI`, `interface` and `code/js`
from the checked-out revision beside each generated DME. BYOND resolves resource
literals relative to that DME even when source includes are absolute. No existing
save or runtime configuration directory is linked into the fixture. This staging
fix does not change the frozen Windows runner or claim parity before native tests.

The current native ownership probe follows synchronous `qdel` retirement and real
pool reuse. It must never call `Destroy` through a reference that may already have
been reconstructed as a live overlay. A separate, distinct superseded overlay is
retired with the real `qdel` path while a replacement owns the turf backlink;
backlink identity must preserve that owner and luminosity. The Linux CI lane adds
an `owner-identity` mutation removing this guard. The refusal control now removes
the constructor's admission guard, since synchronous `qdel` itself also detaches
refused overlays. No deferred-Destroy behavior is assumed.


## Comparable resource instrumentation

Exact head `2d4229c2ca3062e6c358aa21575f0c203282f995` passed
[CI 39347909747](https://github.com/Civ13/Civ13/actions/runs/39347909747): six
snapshots, 1,350 equal rows and four causal controls. This existing parity
result is reused. It contains no comparable CPU/private-memory measurements.

`measurement.py` is a separate, source-reviewed measurement candidate, not a
native-accepted adapter. Its injected process/clock/counter interface is exercised
by `test_measurement.py` without launching any processes. No production/probe
changes, gate enablement or automatic native CI step are added.

A playable-owner executor can seal an isolated input directory containing
`daemon`, `probe.dmb`, `probe.rsc`, the unchanged `probe.dm`, and `build.json`:

```text
<verified-python> tests/reserved_lighting/measurement.py --seal <input-directory> --head <exact-source-sha>
<verified-python> tests/reserved_lighting/measurement.py --packet <input-directory>/measurement-packet.json --grant <grant.json> --output <fresh-output-directory>
```

Sealing only hashes files. `build.json` must contain `head`, `byond_version`
(`516.1681`), `compiler_sha256` and `files` mapping the four input names to SHA256.
This provenance is a declaration requiring independent exact-build evidence, not
proof from a compiler run. The sealing step never builds or launches anything.
The packet binds all inputs and permits only the same executable/DMB/RSC with
`reserved=0/1` changing. Both production defaults remain FALSE.
It also binds the absolute paths and SHA-256 hashes of the running measurement
script, comparator and Python executable. Moving or modifying these requires
resealing and a fresh packet-bound grant. This is not a complete Python runtime
dependency attestation; executor review must establish the trusted runtime.

The Linux-only adapter needs `/proc`, externally accepted account/network/process
isolation, and accepted platform/resource containment. A grant binds packet hash,
head, `executor: "playable-owner"`, `isolated_environment_accepted: true`,
`platform_adapter_accepted: true`, and numeric `starts_unix`/`ends_unix`. This is an
executor precondition, not self-authorization. No grant or native run is supplied
by this change. The Windows stopped-run packet must not be reused.

One excluded warmup per variant precedes ten alternating AB/BA pairs (22 fresh
processes). Per-process limits are 30 seconds wall, 10 seconds CPU, 512 MiB sampled
private bytes and 16 MiB generated output; total measurement wall is at most 960
seconds. Samples occur every 0.1 seconds and retain PID/start ticks. Linux exit
CPU comes from `wait4` user+kernel seconds; private bytes are sampled
`Private_Clean + Private_Dirty + Private_Hugetlb`, not RSS, true peak or net RAM.
No private observation makes a run incomplete. Wall includes observer/sampling
latency. Compilation, sealing and comparisons are outside the process timer.

Every sample is persisted before validation. Counter drift, wrong attribution,
sockets/children, output/resource/lease limits, partial outcomes, diagnostics,
missing parity or cleanup failure abort the batch without retry. Cleanup uses
only the retained child/group, with a five-second deadline. Between-sample
activity cannot be excluded by polling: network and child containment must be
provided by the isolated executor. Sampled private limits are detection limits;
the executor must supply accepted hard resource containment. The adapter itself
has not been validated with native BYOND in this task.

Every measured pair must pass six-snapshot/1,350-row equality. Raw paired CPU,
wall and sampled-private differences and their medians are retained; no automatic
speedup verdict is emitted. The tiny 16x16 workload may be below useful timer or
memory resolution. Measurements establish only this end-to-end fixture workload,
not isolated lighting CPU, client rendering, production latency, OOM remediation
or whole-server RAM savings. Fresh native allocation and exact input/build
artifacts remain required before execution.

Lease and aggregate bounds are checked again immediately before every launch,
after input hashing. Cleanup retires surviving group members even after the
direct child has been reaped, without waiting for that child twice. Before each
signal it checks Linux group/session membership and leader birth identity;
changed or unavailable ownership fails closed and reports incomplete cleanup.
The group inspection is not atomic with signaling and does not replace accepted
external process containment. Persistent groups fail the bounded cleanup check.
Diagnostic rejection includes spaced `## ERROR`, Bad ref/loc and null execution.
Unhandled exceptions, out-of-memory messages, failed assertions and access
violations also invalidate PASS artifacts. Injected outcome-entry controls check
each fatal message in runtime, stdout and stderr, with clean-log controls.
If post-launch identity acquisition fails, cleanup terminates and reaps only the
retained, unreaped direct child. It does not signal an unverified process group;
the receipt remains incomplete and requires external containment cleanup.

Batch completion rechecks lease/aggregate bounds and all bound inputs after
the final parity comparison and summaries, then rechecks time after hashing.
Expiry or input drift during final acceptance leaves the receipt incomplete,
even when every process exited and each pair returned matching snapshots.
Injected controls cover lease expiry during final comparison or rehashing,
aggregate timeout and input drift without starting any native process.


### Public runtime inputs

The unchanged full-source fixture initializes name lists through literal reads
in `code/names.dm`. An empty working directory would emit missing-file errors;
fatal diagnostics remain rejected. Before compiling/sealing, the source-only
`--prepare-runtime <fresh-input-directory> --head <exact-source-sha>` operation
reads only tracked `code/names.dm` and `config/names` Git blobs, derives the
explicit literal allowlist, and writes only those public name files (currently
146 files, 153,247 bytes) plus `runtime-inputs.json`. No settings/config tree,
credentials, saves or live files are copied. The script also binds names.dm in
its execution identity. Other newly discovered runtime reads require review;
this staging is not a claim that a native run is clean.

Place the exact prepared compiler outputs and daemon in that input directory.
`build.json` additionally binds `runtime_inputs_sha256`, the SHA-256 of
`runtime-inputs.json`. The runtime manifest records exact source head, source
hash/Git blob and each public relative path, byte count, SHA-256 and Git blob.
Sealing includes that manifest and every name file. Existing packets need to be
resealed and independently accepted; this operation creates no execution grant.

Every fresh per-run directory receives separate verified name-file copies before
launch, outside the measured process interval. Traversal, absolute paths, links,
unknown/missing/changed inputs and unexpected configuration files are rejected.
Copies are checked again after the process outcome. The source directory never
becomes a writable runtime/config symlink. These checks do not replace external
filesystem/process/network containment or eliminate all concurrent-write races.

Exact-head linkage comes from trusted Git-archive preparation and independent
build review; a self-consistent hand-authored manifest alone does not prove it.


### Registered containment-only pilot (default OFF)

The three pilot files in this branch match exact master merge
`61329b29e7e4b5d898662a7adf1c05595b13b357` from #3256 and #3259. They retain
manual/default-false container execution, the exact repository/head/public-hosted
guards and read-only job permissions. PR events can select only injected offline
tests under the existing introduced-suite policy. There are no BYOND, compiler,
measurement batch, game inputs, secrets, public ports, caches or artifact uploads
in that workflow. These synchronized draft copies were not executed as this PR.

Corrected containment pilot
[39636638727](https://github.com/Civ13/Civ13/actions/runs/39636638727) executed at
that master merge, with nine injected tests and all five runtime controls complete.
It checked denied egress, a protected-input write denial plus positive scratch
write, actual scratch ENOSPC, PID rejection attributed to the cgroup, hard-memory
OOM and retirement of an owned surviving descendant. All five owned containers
were removed; two retained process birth identities and their cgroup retired.
The independent source owner and sole allocator reconciled the same receipt.

This is a Python-only 64 MiB memory/zero-swap envelope with 16 PIDs/threads,
0.25 CPU, 8 MiB noexec scratch and 1 MiB shared memory. EACCES alone is not causal
read-only mount proof; separate mount RW=false inspection is configuration
evidence. CPU quota readback is not timing calibration. Host CLI output uses a
1 MiB polling detection threshold that may overshoot, not a hard host disk quota.
The exact local logging configuration is max-size=1m, max-file=1, compress=false.
Nine injected tests cover the source contracts; the successful run supplies only
the stated small Python containment evidence, not BYOND/platform acceptance.

Prior pilot
[39633874487](https://github.com/Civ13/Civ13/actions/runs/39633874487) failed before
its first Python control started because Docker rejected compression with one
log file. Its incomplete receipt and cleanup-only evidence remain preserved.
Both explicitly approved allocations are consumed. No further execution follows
from staging, source tests, the successful pilot or these synchronized copies.

### Remaining native measurement prerequisites

1. Review a bounded, isolated Linux BYOND 516.1681 build/preflight plan and its
   executor. The accepted Python image does not contain BYOND or establish the
   larger compiler/runtime envelope. Use a free standard public hosted runner,
   verified image/tool identities and external hard process/network/memory/swap/
   scratch/output bounds, with readback and owned cleanup. No Desktop or
   production resource, save, credential or public test port is a test input.
2. After explicit scoped admission, regenerate source/runtime manifests with
   Linux paths at the exact current PR head and compile the unchanged 16x16
   fixture. Retain independently checked compiler/version/hash, invocation,
   source inputs and zero-error/zero-warning outputs. Seal daemon, probe.dm,
   probe.dmb, probe.rsc, build.json and the 146 allowlisted public name inputs.
   A self-consistent build declaration alone is not exact-build proof.
3. Validate the real Linux measurement adapter and cleanup with the accepted
   wrapper: CPU attribution, sampled private memory, lease/aggregate bounds,
   diagnostics, input mutation, parity and failure cleanup. Python containment
   controls do not test the BYOND executable, /proc observations or wait4 path.
4. Obtain a fresh packet/head/executor-bound grant and separate authorization
   before the 22-process measurement batch. Both variants must use the same
   exact binary/resources, and every pair must pass six snapshots/1,350 rows.
   Preserve raw measurements and limitations; no speedup or RAM claim exists.

No native build packet, BYOND preflight, adapter execution or CPU/private-memory
measurement is supplied by this PR. The accepted lighting base remains
`2d4229c2ca3062e6c358aa21575f0c203282f995`, and this PR still targets
`reserved-cell-lighting-overlays`. A branch-relative fixture build does not
require resolving #3220's master conflicts or merging/deploying experimental
lighting. Source acceptance and merge/deployment readiness remain separate.

### Separate native preflight source (default OFF)

The [native preflight source](native_preflight/README.md) now provides an inert
toolchain recipe, exact public Git staging, and a separate one-compile/two-smoke
driver with injected negative controls. It does not change the measurement
batch or the accepted pilot. Its toolchain identities remain unresolved; larger
causal controls, engine contract, zero-cost handoff and explicit scoped admission
are required before any acquisition, build or native execution. No workflow
activates this source and no native result is supplied by it.
