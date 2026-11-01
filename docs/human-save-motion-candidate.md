# Human movement during world saves: candidate boundaries

The human spatial capture candidate remains disabled in ordinary builds. The
test adapter explicitly defines `CIV13_HUMAN_SPATIAL_EXPERIMENTAL`; its
headless authority seam is not a connected player. When enabled, an admitted
unlinked human's origin and owned subtile offsets are captured at an idle or
between-pulses boundary without holding that human for the world save.
Ordinary and restart-owned saves share the path: a busy restart must own the
save operation. Load, startup and dimension recovery holds remain in force.

Each discovered saveable human is recorded for the operation. At its first
serialization, a supported unlinked human on a turf uses a spatial request;
an aligned idle linked or contained human can use the existing legacy frame
with its immediate saved parent frozen. A serialized legacy frame is not
upgraded later. Pending roster entries are reconsidered before completion;
unresolved required entries, missing parents, duplicate ownership or invalid
references reject the candidate. This is a rolling save, not an atomic snapshot
of inventory, actors or the whole world.

The spatial candidate checks encoded ownership, slots and physical links as
well as the frozen footprint. It accepts floor descendants with reviewed
nondense, nontransforming state and generic audited nondense objects where the
saved collision bounds do not establish an obstruction. It rejects dense or
unaudited intersecting objects, dense or transforming/non-floor turfs, invalid
shape or bounds, out-of-world footprints and unsupported saved physical links.
Mobs are treated as dynamic occupants rather than blanket static obstacles;
the proof does not claim a globally simultaneous world. Special object roots
and collision overrides require review rather than an implicit generic pass.
Unsupported partial linked/contained states, unsettled movement, broken
ownership, exhausted budgets and other unproved inputs can reject the entire
candidate before a new completion marker; they are not silently repaired.

For the new direct human restore schema, the loader verifies the generation,
saved parent, identity, links and hard geometry, then performs a local
nonyielding exact-offset assignment and preserves the existing living and human
movement-completion callbacks once, in order. Historical capsules retain the
legacy path. Existing world-load interleaving is not a new global pause. A
generation containing the new schema is rejected by a build without the
experimental reader: binary rollback alone is not a safe recovery plan.

At reviewed head `ed55db411e5cd75b0e1ee558e3766d385b764524`, the isolated
synthetic writer/fresh-reader fixture passed ordinary and restart-owned saves,
headless drag, and nine named refusal/preservation controls on a small map.
It is evidence for those cases only, not connected-client movement, a
populated world, full-map resource cost or live recovery. The earlier count of
26,312 original and 66,285 proposed exact-whitelist floor cells in a 350,000
cell Gaia template described a superseded design; it is historical, not the
coverage or runtime cost of the current candidate.

Before production enablement, review the enabled final tree, realistic refusal
availability, representative synthetic scale and a tested recovery plan that
retains a verified pre-enable generation and matching build. Connected-player
input and actual operational behavior remain separate evidence. No live save,
rollout, recovery or server action follows from this document or its fixture.
