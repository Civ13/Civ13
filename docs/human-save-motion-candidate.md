# Tile-only human save candidate

Status: experimental and default off. `CIV13_HUMAN_SPATIAL_EXPERIMENTAL` is
not enabled in ordinary builds. The synthetic results below apply to their
named historical commit, not to a later integration, a connected client or a
live Gaia session. Enabling or deploying the feature is a separate decision.

A save captures a supported, directly located moving human's actual turf at a
between-pulses acknowledgement. The owner, turf identity and coordinates are
read synchronously; the saver may wait for that boundary while the movement
transaction continues with its normal completion and cost semantics. The frozen
turf receives the human's unique saved parent edge. Fractional `step_x` and
`step_y`, movement transactions and active pulses are transient: the new path
omits movement offsets and restores a zero-offset tile position. Independent
artwork offsets such as `pixel_x` and `pixel_y` remain saved fields.

Contained, buckled or otherwise linked humans keep their captured immediate
parent; they are not flattened onto a turf. Their containing level is resolved
through a bounded, cycle-checked chain. Saved slots, containment edges, owner
identity and generation are checked before publishing a completion marker.
Unsupported or inconsistent relationships refuse the candidate and retain the
previous completed generation. A still-active linked movement transaction is
not yet supported. Inventory uses rolling serialization, not an atomic snapshot.

Historical position capsules remain readable under the existing format, but the
experimental path deliberately does not restore their fractional offsets. An
older binary may not understand a newly written schema: retain the pre-update
completed generation and verify binary/save compatibility before any rollback.
Existing save data formats and inventory encodings are not removed.

The former exact-offset experiment indexed world geometry, emitted transform
sidecars and object bounds, and validated a fractional footprint. The tile-only
candidate removes that machinery. It still validates the saved tile, relevant
saved object density, ownership, slots and physical links. After level callbacks,
a local engine bounds query checks unlinked human placements against dense turfs
and dense objects, including neighboring overhangs. It excludes mobs and retains
linked and contained parents. The 1,024-entry limit is checked after the engine
constructs the list, so it is not a hard allocation limit. This is not a
simultaneous world snapshot or a guarantee of a route out of a closed room.

The change also includes always-on production work outside the experimental
human flag: cooperative yielding between lighting-restoration callbacks and a
post-yield ownership/roster recheck in the existing animal drain. Those changes
must be reviewed and tested as production scope even while human motion is off.

## Historical verification and remaining limits

- At `f41b6008bd81341dc4668c056cf3d1b6157677d8`, the
  [bounded synthetic fixture](https://github.com/Civ13/Civ13/actions/runs/41350658305)
  passed one compile and twelve sequential daemon phases on BYOND 516.1688.
  Ordinary and restart-owned writer/fresh-reader cases, movement continuation,
  zero restored movement offsets, art offsets, nested inventory, seated and
  contained parents, drag, and six rejection controls were exercised. A saved
  object's `after_load` created a solid obstruction; the loader refused the
  placement, set the recovery hold and released the operation. This uses
  headless synthetic actors and isolated saves, not connected clients or Gaia.
- At that same head, the [automatic native matrix](https://github.com/Civ13/Civ13/actions/runs/41350645415)
  and [general CI](https://github.com/Civ13/Civ13/actions/runs/41350645394)
  passed. Earlier failed fixture and CI attempts remain in the run history.
- Earlier 350,000-turf comparisons exercised the prior exact-offset design,
  not this tile-only candidate. Their measured cost and limits are historical
  evidence, not a tile-only performance estimate or a live-world guarantee.
- A current-master integration needs its own exact-head checks. Connected-client
  movement, live-world behavior, rollout and rollback compatibility remain
  separate operational evidence. A successful small fixture does not establish
  full-world consistency or restart readiness.
