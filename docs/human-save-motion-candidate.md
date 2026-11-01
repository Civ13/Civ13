# Tile-only human save candidate

Status: unpublished source candidate, default off. No native validation or live
rollout has been performed for this revision. Historical exact-offset fixture and
benchmark evidence is retained separately; it does not establish this contract.

A save captures a supported, directly located moving human's actual turf at a
between-pulses acknowledgement. The owner, turf identity and coordinates are
read synchronously; the saver may wait for that boundary, while the movement
transaction continues and keeps its normal completion and cost semantics. The
frozen turf receives the human's unique saved parent edge. Fractional `step_x`
and `step_y`, movement transactions and active pulses are transient; new saved
human entries omit them and restore their movement offsets to zero. Independent
artwork offsets such as `pixel_x` and `pixel_y` remain ordinary saved fields.

Contained, buckled or otherwise linked humans retain the immediate parent that
was captured for their record; the implementation must not flatten them onto
the containing turf. Their containing level is resolved through a bounded,
cycle-checked chain. All captured human inventory slots are checked against the
saved containment graph, and the captured parent, reference closure, generation
and owner identity must remain valid before the completion marker is written.
The ordinary unlinked candidate additionally checks the saved turf and saved
physical links. Unknown or inconsistent ownership is refused, retaining the
previous completed generation. A still-active linked movement transaction is
not yet supported and refuses the candidate.

Historical position capsules are still parsed and checked as the old format,
but in the experimental build their fractional offsets are deliberately not
restored. This does not claim that older binaries understand any newer schema.
The disabled build retains its existing historical behavior. Existing save data
formats and inventory encodings are not removed.

The prior exact-offset machinery indexed geometry across the world, emitted
per-turf transform sidecars and object bounds, and validated a 1–4-turf
fractional footprint. The tile-only candidate removes those paths. It still
encodes a saved density for turfs and objects so a saved tile and objects
anchored directly on it can be checked; this has not been benchmarked. The
remaining validation scans saved ownership/slot references, so this is not a
claim that all world-wide work has disappeared.

## Review and validation gates

- After all level callbacks, a local engine bounds query checks unlinked human
  placements against dense turfs and dense objects, including neighbouring
  overhangs. It excludes mobs and preserves linked and contained parents. The
  query is rejected if it returns over 1,024 entries, but that limit is checked
  after the engine creates the list; it is not a hard allocation bound. Native
  tests must establish the engine's overlap and edge-contact semantics and
  exercise callback-created obstructions before this check can be relied on.
- Restore retains the saved turf or parent rather than searching for another
  location. It does not guarantee escape from a closed room or simultaneous
  global snapshot semantics.
- The updated synthetic source aims to check ordinary and restart-owned saves,
  movement continuing after handoff, zero restored offsets, retained art
  offsets, nested inventory, contained and seated parents, negative controls and
  retained previous generation. It has not yet run and has no connected-client
  or Gaia-world evidence.
- Source/model checks are not a DM compiler, BYOND execution, full-map benchmark
  or proof of production safety. Current master reconciliation, independent
  review and an exact-head native writer/fresh-reader run remain required.
