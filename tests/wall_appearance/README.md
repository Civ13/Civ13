# Wall material appearance investigation

Status: source preparation only. Native execution awaits the Windows restart
and an exclusive benchmark grant. No timing, memory or visual parity result is
claimed yet.

## Narrow first candidate

`set_material()` assigns the material, calls `update_material()`, then calls
`check_relatives(1,1)` again. The current `update_material()` ends in the same
call. For a dense ordinary wall, its `update_icon()` also calls that procedure:
three root neighbor passes, each updating every joinable cardinal neighbor.
With four joinable neighbors, the source call chain therefore reaches fifteen
`check_relatives()` invocations. Removing only the last `set_material()` pass
would reduce that to ten. These are source-derived counts, not measurements.

Do not remove the final pass inside `update_material()`: it clears the damage
overlay after `update_icon()`, so that would change existing final appearance.
Do not remove initial state assignment, subtype update calls, lighting effects,
or any immediate interaction update as part of this first candidate.

## Required acceptance

- Execute baseline and current production procedure bodies under pinned BYOND
  516.1681; count root/neighbor passes and image construction separately from
  uninstrumented paired timings.
- Compare the ordered complete appearance of the changed wall and neighbors,
  including icon resource/state, color, direction, alpha, blend/layer/plane,
  damage state, sub-bulkhead color lines, dense/open walls and null materials.
- Exercise material reassignment, repeated unchanged updates, all cardinal
  adjacency masks, subtype overrides, real native turf replacement and actual
  saver/loader restoration. Check animated resource/direction behavior instead
  of accepting a single flattened frame as complete parity.
- Independent generated-source controls must omit required smoothing and alter
  final overlay ordering; both must fail the parity checks.
- Record warm-up, alternating paired order, native timer units/resolution,
  maximum heartbeat gap, cache entry counts, and peak/settled process memory
  across repeated completed update/disposal cycles. Do not infer CPU time from
  wall time or whole-server stability from the fixture.
- Geometry: actual Gaia is 500x350x2 (350,000 tiles). Provisional fourfold area
  is 1000x700x2 (1,400,000 tiles), retaining the two existing levels. Stage memory
  allocation conservatively on the 32-bit engine; record a failed or omitted
  large allocation rather than silently substituting smaller geometry.

## Subsequent source candidates

1. `floor_icon.dm:update_icon()` clears and rebuilds overlays for floored
   turfs, optionally updates surrounding floors, and includes radiation logic.
   Coordinate that code with the memory owner's radiation work before edits.
   Its existing global flooring cache includes image resources, direction and
   layer indirectly through the first creation; audit key completeness and
   material/replacement invalidation before extending it.
2. `wall_cache` is already global and keyed by state and material color. Bound
   cardinality and measure retained entries before adding any new icon cache.
3. `getFlatIcon()` recursively renders ordered underlays/base/overlays and
   constructs native icons. Inventory the actual call sites and workloads before
   choosing a cache. A general cache needs explicit appearance, direction,
   recolor, animation and lifetime invalidation; it is outside this first patch.
4. Wall constructors/deletion also refresh lighting overlays in `view(21,src)`.
   Measure actual queue activity before changing this path; reuse the existing
   bounded lighting scheduler rather than deferring atomic wall interactions.
