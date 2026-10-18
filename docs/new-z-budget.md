# Dynamic level allocation budget

Production currently refuses **all new native grid growth** with an explicit
`UNMEASURED` reason: there is no validated incremental/player/save/address-space
headroom profile. This happens before native allocation or paid roofbuilder
consumption. Existing planes remain usable. No host configuration can opt out.
The arithmetic limits below are additional bounds, not memory-admission evidence.

All production native z growth goes through `building_allocate_level` and the
runtime `world_z_budget` reservation controller. The budget counts the entire
native grid: `world.maxx * world.maxy * target_z`, including compiled levels,
existing additions and configured unused reservations. A small room on another
z still allocates a full world plane. BYOND does not provide a sparse grid here.

The provisional default and hard ceiling is **600,000 total cells**, with at most **one
roof-added plane** above the actual compiled maximum. Existing limits of 32
absolute levels and 8 added levels remain. A host may lower these settings in
`config.txt`; this patch provides no higher override:

```text
NEW_Z_CELL_BUDGET 600000
NEW_Z_ROOF_LEVELS 1
NEW_Z_INSTANCE_RESERVE 0
NEW_Z_SAFEHOUSE_RESERVE 0
```

The first two accept decimal integers in 0..600000 and 0..1 respectively. Zero
disables the corresponding arithmetic permission; no value enables the missing
production memory admission. The reservation counts accept
integers in 0..8 and reserve whole planes for future explicit consumers. Unknown
purposes and instance/safehouse requests without a configured reservation fail
closed. Invalid configuration retains the preceding policy. Policy changes are
refused while a reservation owns allocation; reservations cannot be lowered
below committed usage. The configuration datum mirrors the accepted settings;
the controller is the allocation authority. Raw admin edits of world maxx,
maxy or maxz are refused for every input type.

Europe's shipped 375x447x1 grid contains 167,625 cells; one addition totals 335,250.
The shipped Gaia map has two 500x350 coordinate blocks: 350,000 cells, then 525,000
after one addition. A generated one-z 500x350 Gaia profile instead starts at 175,000
and grows to 350,000. The controller records actual compiled dimensions before
startup yields; map names do not determine the initial z count. Compiled worlds
already exceeding the budget remain intact and playable, with new growth denied.

Roof previews explain refusal before the construction wait. Final allocation
rechecks admission before resizing, and the existing roofbuilder is consumed
only after successful slab construction. A request for an existing upper plane
does not create another plane or consume growth capacity.

When admitted by an independently validated profile (or an explicitly isolated
fixture adapter), an allocation reserves its complete target without yielding. Each sequential
claim rechecks ownership and prospective demand immediately before the native
resize; initialization retains the reservation through its tick yields. Other
growth and save/load admission are excluded until the whole interval finishes.
Native failures after a resize retain the failed ownership/recovery guard;
shrinking the world is not a rollback mechanism.

Saved-world restoration reserves the whole target before prospective validation
and before its first resize. If a target exceeds the budget or lacks memory admission, it enters a
non-destructive admission hold: no grid expansion or save-file truncation occurs,
the original refusal remains in `map_storage.last_error`, and further save/load
and roof growth remain blocked. This also prevents the legacy automatic restore
caller, which ignores a false return, from later saving a fresh world over the
held generation. Preserve `map_saves` and its backups. Restart from the original
map only after reviewing the profile/settings within the ceiling or a separately
reviewed recovery change. There is no automatic grandfathered overcap expansion.
Matching already-allocated dimensions do not request new memory through this
allocator and continue through existing import validation.

The current merged game has no Dagger/safehouse native allocator. Its future
owner must reserve the entire instance interval under purpose `instance` or
`safehouse`, pass the same reservation to every sequential allocation, and finish
it only after all levels initialize. Unused reserved instance/home planes count
against roof admission. A four-deck Dagger requires four full planes and can
therefore be refused on a full-size Gaia profile even when its placed rooms are
small. Even a compact extraction profile remains refused until a separately reviewed
calibrated memory policy exists; this patch does not silently take reserved capacity or invent that
integration. Runtime reservations/usage are unsaved; a future durable instance
owner must explicitly reconcile restored leases before enabling new requests.

This is an **uncalibrated allocation throttle**, not a heap/headroom test or an
OOM guarantee. It does not query current private bytes, reserve actual memory
for players or saving, measure fragmentation, or establish the process address
space. A busy world can still run out of memory within this grid limit. Before
any positive production admission or raising policy is reviewed, compare sequential fresh-process runs at the
same map dimensions, save generation, population, client state and lighting
settlement, including peak save/import allocation. Establish explicit current-use,
player, save and address-space headroom with documented measurement semantics.
Europe and Gaia observations from different states do not establish bytes/cell.

The empty-sky lighting optimization is separate. This patch does not change
world defaults, sky appearance, corners/overlays, daylight, weather, ordinary
falling, roof geometry, or generic turf lifecycle.

## Verification boundaries

`tests/new_z_budget/prepare.py --output <new-directory>` prepares a full production
fixture and checks source bindings without invoking BYOND. Its
`memory-admission`, `cell-limit` and `roof-ceiling` controls mutate generated
copies only. A tests-only subclass in `tests/new_z_budget/fixture_admission.dm` deliberately
permits tiny accepted paths; it returns no measurements, is never included by
`civ13.dme`, and must never be described as a calibrated profile. The production
controller is tested first for real paid-builder refusal, then again for
existing-plane reuse. The DM probe exercises real
configuration loading, controller admission, roofbuilder debit ordering and
sequential native allocation when later run by an authorized trusted launcher.
Large Europe/Gaia and exact-limit cases call the production arithmetic helper
without allocating those large grids. The actual admin guard has a source-binding
check; connected-client admin input is separate acceptance.

`tests/world_save/run-dimension-bootstrap.py --prepare-only` prepares real disk
writer/import cases, including valid one-level and multi-level saved targets
refused before any allocation and unchanged completion/round metadata. The
ordinary building support-tier fixture uses seven compiled planes, so it can
continue checking support semantics without raising the new growth limit.
First-roof growth is checked by the separate budget and lighting fixtures with
their explicit test adapter. The disk suite also checks single/multi-level
unmeasured refusal and preserved intent. The full durable dimension fixture
uses the actual `resume_startup()` state machine with a valid round-v2 intent,
asserting a pre-import hold and unchanged original generation bytes.

Prepared source, unique mutation targets and whitespace checks do not establish
compilation, native assertions, connected-client rendering, memory improvement,
or deployment acceptance. Native and full-game evidence must be recorded
separately against the exact reviewed commit.

`tests/new_z_budget/run.py` is the bounded native launcher for the authorized
executor: it verifies source hashes and exact commit, pinned compiler/runtime
516.1681, closed fixture port, zero exit status, strict diagnostics and complete
positive results. Each omission control must fail at its named assertion and
allocation boundary. Preparation and offline oracle checks do not execute it.
The new suite has its own existing-selector workflow guard; editing the workflow
does not dispatch CI or establish acceptance.
