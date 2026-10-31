# Lighting: scoped agent notes

Read only the entries relevant to the paths or behavior being changed.
Code paths and commands below are relative to the repository root unless
shown as Markdown links. These dated notes preserve subsystem contracts
and historical evidence; they are not a task-wide completion checklist.
Use the root [PR completion policy](../../../CODEX.md) for the finish line.

Explicit restrictions on live actions, held runners, credentials and feature
activation still apply to those actions. Missing native, graphical or
save/load evidence belongs in the report and never blocks a source fix.
Do not turn an evidence limitation into a new approval requirement.

<!-- 2026-10-28: public lighting/exclusion reconciliation -->
The exclusion runner requires immutable event base/head SHAs and verifies the
checked-out head, event metadata in Actions and committed fixture inputs. Never
fall back to a fixed master checkpoint, moving ref or base/head self-comparison.
Preserve the complete event-base source, adding only missing exact fullbright
exclusions and area_change_owner; already integrated lighting policy stays intact.
Keep immutable historical bounded-save tests and lighting omission/parent controls,
plus actual CLI preparation tests for evolved pre/post-lighting event bases and
one-sided regressions. Source-only checks do not authorize native work.
The selected exclusion Linux entry point is explicitly 516.1688 and verifies the
existing pinned archive/members at admission and execution boundaries. Preserve
the historical 516.1681 gate, shared resource/cleanup limits and causal controls.

<!-- 2026-10-30: Gaia production visibility candidate -->
The owner requested default-on LOS and root-lit oversized trees. Production
contexts now use actual view/z and smooth offsets; one process owns per-client
refresh. The candidate compositor leases raw game/mask/roof/weather planes,
combines separately lit game and whole-root trees under one scene shadow, then
replays roofs and weather. See docs/gaia-visibility.md for native acceptance.
Default-on source is not a rendering receipt or deployment decision. Historical
21x21/eight-tree fixtures and failed pixel receipts remain historical; do not
relabel them as production proof. This request supersedes the old default-off
source instruction below, not its missing native evidence.

<!-- 2026-10-19: disabled lighting composition V2 -->
Keep LIGHTING_COMPOSITION_V2 at 0 until new native pixel and lifecycle acceptance.
V2 separates weather from tile RGB and explicitly represents visible fullbright
coverage. Historical render receipts bind only tests/light_plane_composition/rejected;
never relabel their failed weather/fullbright counterexamples as V2 evidence.
Headless mode/coverage checks and synthetic pixel-oracle tests cannot prove rendering.

<!-- 2026-10-22: area change lighting dispatch -->
`ChangeArea` owns turf membership, existing area notifications and the final
`T.change_area` hook. A temporary per-request identity rejects stale dispatch
after yielding callbacks, reentry (including away/back), or turf replacement;
the final destination is checked too. Exclude that identity from custom saves.
Same-area calls return before ownership changes; a missing old area still
initializes lighting. Valid hooks reconcile actual overlay state to destination
policy, since the old area's lighting may never have been applied; read current
area after the build startup wait and invalidate coefficients on real changes.
`tests/light_plane_composition` extracts both real
procedures and checks helper dispatch with counted overlay adapters, separate
from native corner graphs and client rendering. Keep V2 disabled.

<!-- 2026-10-18: inactive reserved lighting -->
Reserved lighting omission requires the default-FALSE area clearance gate as well
as reserved turf markers. No map opts in. `tests/reserved_lighting/clearance.py`
checks declared frozen full-frame geometry only, not map inventory completeness
or runtime immutability. The separate Linux CI lane compares native state and
causal controls; it does not prove client appearance or net RAM savings. Preserve
frozen Windows helper bytes and require a fresh grant for that held runner.

<!-- 2026-10-23: footwear water composition -->
Mud stains use brown blood_color/blood_DNA and the worn shoeblood overlay;
clothing dirtyness only supplies examine text. Water filters must group the
footwear image with its nested stain (KEEP_TOGETHER only while masked), and
new update_inv_shoes images need the current mask before publication. Keep
durable stain data intact. tests/footwear_water_mask checks source contracts
and prepares a tiny production-proc fixture; compilation/source checks do not
establish native client clipping, stance, movement or lighting acceptance.
The pinned native image getter returned lowercase #RRGGBB text for the tested
blood/mud inputs. The fixture comparator first requires text of exactly seven
characters matching #RRGGBB, then ignores hexadecimal case. Never coerce nulls,
named colors or matrices. Keep wrong-channel/missing-stain controls and preserve
the earlier failed raw-text comparison receipts; diagnostics are not pixels.

<!-- 2026-10-15: lighting persistence ownership -->
Custom saves enumerate tmp lighting fields too. Exclude light/light_sources and
derived light_source/lighting_corner/lighting_overlay graphs on export and import;
their constructors require live owners/turfs. Rebuild sources after durable atom
fields and after_load. tests/world_save/run-durable-world.py --lighting checks
actual constructors and legacy graph recovery; full-map acceptance is separate.

<!-- 2026-10-12: lighting batch ownership -->
Lighting overlays detach bounded 1000/2000-entry batches, null consumed slots
and retain unfinished batches across budget
returns. Scheduler replacement must transfer current_list/batch_index;
cancellation returns unfinished entries to the live queue. Tests in
tests/lighting_queues compare production color/luminosity and immutable baseline
queue workloads; trivial callback timings do not establish server latency.

<!-- 2026-10-12: wall material appearance parity -->
set_material relies on update_material's final neighbor refresh. Do not remove
that inner refresh: it establishes existing open/damaged-wall overlay ordering.
tests/wall_appearance runs actual wall constructors and ordered appearance/count
comparisons, production save/load and smoothing/duplicate/overlay controls.
Measured native callback reductions are not whole-server latency evidence.
<!-- 2026-10-12: bounded lighting startup -->
Initial turf New delegates overlay construction to bounded startup sweeps.
Dynamic excluded-z/void sites still need the compatibility overlay pass.
Shared corners activate after both overlay passes; runtime build/clear/activity
requests wait through startup and return after a failed barrier. Preserve
ordinary prestartup direct calls. tests/lighting_startup checks production
bodies, shared identity, late replacement and failed waiters against a baseline;
its adapted rendering does not establish client lighting acceptance.

<!-- 2026-10-18: building renderer gravity -->
Building-sky entry must exempt /atom/movable/lighting_overlay explicitly; it is
not an /obj/effect. Runtime level allocation and turf replacement can otherwise
drop a black renderer onto lit ground. The building lighting probes separate
replacement callbacks, explicit entry, and an adapted allocation interleave.
They verify native lighting state, not connected-client rendering.

<!-- 2026-10-12: lighting reinitialization -->
<!-- 2026-10-17: restored-round lighting -->
Turf luminosity is always 0; native tile visibility comes from lighting overlay
`luminosity` (an overlay at 0 leaves its tile black). Invisible overlays still
light their tile: `invisibility` 100 only stops shading being drawn. Pregame
overlays are hidden (100) until daylight is applied, and corner activation does
not queue overlay updates; only light sources and daylight do. Fresh rounds
apply daylight through the roundstart hook, but restored rounds skip
`ticker.setup()`, so `restore_round_state()` calls `apply_restored_lighting()`
for every restored round, including legacy saves without durable metadata.
`tests/core_boot/run.py --legacy-fixture-5161681 --lighting-restart --map maps/nomads/nomads_europe.dmm`
checks a real save, fresh-process import and sampled overlay luminosity; its
`restored-lighting` control removes that application. Default Nomads cannot be
saved (cross-level ladders), so use a single-level persistence map.

Lighting startup must reconcile existing inactive shared corners after adding overlays, as well as activating fresh corners. Native largest-startup fixtures exercise a later overlay pass after standalone corner creation; use bounded overlay-master visits without retaining a corner registry.

<!-- 2026-10-18: lazy floor decal tracking -->
Native nullable tracking lists do not auto-materialize on `|=`: omitting the
initializer raises a type-mismatch exception. `tests/floor_decal_tracking` covers
the writer, seasonal reader and native entry compatibility. Ordinary turf saves
exclude this derived field through their existing saved-variable allowlist.
