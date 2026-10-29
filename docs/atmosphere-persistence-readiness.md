# Persistence prerequisites for future atmospheric zones

Review baseline: `58404f5bd16e3fed80f1d9844c5db3edd144942c`, 2026-10-24.
This is preparation for post-modern atmospheric systems, not an implementation
or readiness claim. No solver, live settings, saves or scheduler are changed.
See the [zone audit](zone-persistence-audit.md) for the recovered roof failure,
existing work owners and current offline-test limitations.

## Existing source and gaps

| Source at baseline | What exists | What it does not establish |
| --- | --- | --- |
| `code/modules/persistence/saving.dm:186-193`, `durable_graph.dm:54-58` | Area references use an anchor coordinate and type | Stable room/zone identity across split, merge, replacement or moved boundaries |
| `code/modules/persistence/loading.dm:45-165` | Validated roof topology is reconstructed before graph decoding | General room, pipe or atmosphere topology reconstruction |
| `code/modules/persistence/durable_world.dm:17-45,49-153` | Versioned world metadata, explicit schemas, graph and area coverage validation | Gas inventories, network endpoint schemas or conservation acceptance |
| `code/modules/persistence/durable_graph.dm:17-72,112-169` | Typed bounded graph, aliases and generation-bound `(z, ref)` world-atom links | Arbitrary zone/gas datum metadata; unsupported datum values reject |
| `code/modules/xgm/xgm_gas_mixture.dm:1-18,182-195` | Species-to-moles map, Kelvin temperature, volume, group multiplier; total_moles/graphics caches; pressure derived from cached totals | A versioned atmosphere persistence policy or proven room solver |
| `code/modules/submarine/submarine_turfs.dm:156-194,434-487` | Per-turf compartment/vent labels, O2/CO2, thermal/pressure fields and simplified ventilation | Stable dynamic-zone IDs or a general cross-z network contract |
| `code/modules/submarine/flooding_controller.dm:15-19,27-68` | Runtime turf, compartment and vent registries | Durable registry identity or complete post-import rebuild/activation barrier |
| `code/processes/submarine.dm:15-25` | A registered process calls flooding/atmos and machinery | An atmosphere save/load barrier in this local fire body; review the complete scheduler path before claiming one |
| `code/modules/persistence/durable_timers.dm:18-65` | Generation/revision-owned named callbacks, remaining delays and blocking during persistence | Atmosphere worker topology epochs or a gas-transfer transaction protocol |
| `code/game/atoms.dm:56-66` | Base air delegation/removal interfaces, with null defaults | A populated persistent atmosphere for ordinary Gaia turfs |

Submarine floor vars are not by themselves a save contract: the generic turf
partial-save path uses `map_storage_saved_vars`, and this baseline has no
sub_deck saved-field override for those atmospheric quantities. Generic object
serialization might retain changed gas-datum fields; that would still not define
which quantities are authoritative, rebuild caches, or prove conservation.
The current explicit durable area schema has no atmosphere inventory. Existing
gas/submarine code is useful input, not acceptance of future post-modern support.

## Model-independent identity and topology requirements

If references must distinguish persistent rooms/networks, they need a logical
identity separate from BYOND area type, runtime object/ref and a convenient first
turf. One area can cover multiple rooms or levels; boundary edits can split one
component or merge several without changing its area type. #3290 demonstrates
why deriving saved meaning solely from fresh startup membership is insufficient.

Before implementation, specify:

- A world/generation namespace and logical zone/store/network IDs, with strict
  bounds, duplicate rejection and an explicit topology revision. IDs must survive
  a load of the same generation; no assumption that an ID survives every split
  or merge unchanged. UUIDs versus deterministic IDs is an implementation choice.
- Exact persisted membership or a deterministic, versioned reconstruction rule
  from authoritative geometry. Coordinate runs/tiles must be in bounds, unique,
  complete for the enabled domain and tied to the same topology revision.
- Split/merge lineage and reference rebinding rules. Define how old IDs retire,
  which references follow a successor and how quantities are distributed. Neither
  runtime area allocation order nor `locate(type)` may choose the result.
- Explicit directed/undirected links, endpoint/port identity and valve/door state.
  Cross-z pipes connect logical endpoints, not coincident numeric per-plane refs.
  Validate endpoint existence, membership, direction, enabled domain and topology
  revision before activating a link. Nonadjacent ducts are not ordinary turf
  adjacency. Tanks, moving vehicles and exterior reservoirs need their own
  ownership/lifetime policy, not an invented area alias.
- A policy for a boundary edit or moved container during save: quiescent topology
  epoch, committed immutable snapshot, or another specified ownership protocol.
  Existing cross-z movement blocking is insufficient for same-z room splits or
  gas flowing between two records serialized at different times.

These requirements hold regardless of the future flow, combustion or pressure
solver. They do not require treating all BYOND areas as atmosphere rooms, changing
every historical area reference, or inventing a general-purpose zone service now.

## Authoritative quantities versus rebuildable state

Define one canonical owner for each gas store. Persist species IDs and amounts
with declared units, volume/geometry binding and thermal state. Decide whether
temperature plus a versioned heat-capacity model or thermal energy is the durable
thermal representation; do not independently restore inconsistent temperature,
energy and pressure as three competing authorities.

Current XGM uses a group multiplier and cached total_moles. A future codec must
state whether amounts are totals or per-group values and apply scaling exactly
once. Pressure, cached totals, graphics, connectivity caches, object pointers,
worker snapshots and current processing cursors should be rebuilt from validated
authoritative state rather than copied as durable truth. Geometry-derived volume
must agree with the restored topology or follow an explicit migration.

Validate finite, nonnegative quantities, supported species/model versions,
positive enabled volume and a documented valid thermal domain. Unknown species
or versions must not be silently dropped; negative/invalid quantities must not
be clamped merely to make a save load. Exact limits and numerical tolerances
belong to the eventual reviewed model, including the pinned engine's precision.

Conservation acceptance must compare total inventory and thermal accounting
before/after save-load and topology changes. Splits, merges, grouping and links
must not duplicate or lose a store. Reactions, vents to exterior, breathing,
machines and deliberate sinks/sources need explicit accounted deltas; tests must
not assert conservation across an intentionally open system without that ledger.

## Schema and recovery protocol

Current world metadata schema 1 and graph exact-field checks are a useful
fail-closed base, not an atmosphere schema. Introduce a separately versioned
component envelope and define its relation to the world generation, topology
revision, species catalog and solver/schema versions. Existing older readers
must reject required unsupported atmosphere state before ClearMap. An optional
feature flag cannot turn unknown required data into a default breathable world.

Legacy generations without atmosphere need an explicit map/profile migration
policy. Feature-disabled old worlds can remain compatible. Enabling atmosphere
on an old world requires a reviewed initialization/migration into a new derived
generation with retained originals, not silent gas replenishment on each load.
Migration must be deterministic, bounded and repeatable from copied inputs;
retain source/target versions, quantities, topology mapping and failure evidence.

All zone, gas, pipe and geometry payloads must share one committed generation.
Publish completion only after required components and integrity checks finish.
Interrupted component writes, mixed generations, missing networks or failed
conservation leave the previous verified generation recoverable. Do not let a
new empty/default atmosphere replace a valid older payload. A partial live
import remains held; it is not safe to resume a solver or retry in place simply
because its process is ticking.

## Restore and scheduler activation ordering

This is a required ordering contract to design and test, not a new live path:

1. Validate versions, generation, geometry/membership plans, IDs, links, inventory
   bounds and conservation envelopes without world mutation.
2. Quiesce the relevant live workers at an owned safe boundary. Invalidate old
   generation/topology epochs and stale callbacks; do not serialize live locks.
3. Restore authoritative terrain, walls, doors, hatches and roof topology, then
   create/rebind logical identities before decoding references to those zones.
4. Restore gas/thermal stores and endpoint relationships exactly once. Reject
   orphan, duplicate or conflicting ownership. Rebuild caches and pressure from
   the accepted model, without constructors adding a second default inventory.
5. Verify topology, quantities, aliases, conservation and completion. Only then
   admit a single generation-owned atmosphere scheduler and player exposure.

Define the first post-load timestep and whether offline time is ignored or
accounted by a reviewed policy. Never apply an accidental large catch-up step or
restore multiple worker chains. Existing durable timers provide cancellation and
remaining-time patterns, but do not prove this activation barrier. Full game
readiness must eventually include atmosphere readiness for opted-in maps.

## Acceptance matrix and staged work

All tests below are proposed and unrun. Use public tiny fixtures and copied data,
then representative scale separately. No native run is authorized by this note.

| Case | Required result |
| --- | --- |
| Same area type, two disconnected rooms | Distinct logical IDs and inventories, no accidental merge |
| Area object recreated / allocation order changed | Stable logical references and identical authoritative state |
| Wall/door roof changes split or merge a room | Defined lineage/rebinding, complete membership, accounted quantities |
| Link between levels or nonadjacent ports | Exact endpoint identities and valve state, no per-plane ref collision |
| Tank/vehicle moves during admitted save | Specified snapshot owner, no duplicate store or orphan pipe edge |
| Grouped XGM quantities restored | Multiplier applied once, totals and recomputed pressure consistent |
| Unknown species/model/schema, NaN/negative amount, zero volume | Reject before mutation; retain original generation |
| Missing/duplicate zone, overlapping turf or dangling endpoint | Reject topology before activation |
| Deliberately corrupted derived cache/pressure | Recompute from authority or reject inconsistency; never invent gas |
| Closed-system split/merge/save-load | Amounts and thermal accounting within specified tolerances |
| Open system or reaction | Explicit source/sink/reaction accounting matches delta |
| Save interrupted after each component/marker boundary | Old complete generation loads; incomplete new state never activated |
| Legacy without component / unsupported future component | Explicit migration or rejection, no implicit replenishment |
| Load twice / stale queued callback / failed import | One current worker epoch or none; no double flow, damage or timers |
| Fresh-process import and first normal scheduler tick | Exact generation, stores, topology, no errors, conservation retained |

Staged prerequisite PRs:

1. Repair the offline extractor (zone audit Z7), then add model-independent ID,
   topology-envelope, migration and conservation-oracle tests with no native run.
2. Add a default-off versioned component codec/registry and deterministic
   topology/reference reconstruction, with rejection and interrupted-publication
   tests. Reuse existing world-save/dimension/backup boundaries; coordinate #3105,
   #3082 and #3118 rather than fork their persistence ownership.
3. Review the authoritative gas/thermal representation and implement bounded
   native fixtures against actual chosen gas/zone constructors, caches, split/
   merge/link and scheduler cancellation paths. Preserve causal defect controls.
4. Validate fresh-process full-world round trips and representative resource/
   latency limits on an isolated opted-in map. Then separately review activation
   and legacy migration for an eligible era. Do not enable on Gaia from this plan.

Identity, versioning, topology-before-references, ownership, recovery publication
and scheduler barriers can be prepared independently of the final gas physics.
The solver, reaction policy, units/tolerances and gameplay balancing still need
their own design and evidence. The persistence system is not yet atmosphere-ready.
