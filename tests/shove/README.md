# Deliberate shove offline regression checks

Run from the repository root:

```sh
python -B scripts/ci_baseline.py unit --suite shove --output .ci/shove-offline.json
```

This suite executes the current `try_deliberate_shove` admission prefix up to
its spatial-direction calculation, and the complete `shove_body_ready` predicate,
using the existing audited DM-subset source adapter. It checks rejected actor
states/range, exact stamina and deadline boundaries, grip-breaking as a separate
action, body exclusions, and leases. Fake boundaries supply adjacency, restraints,
messages, animations, grips, shape and linked-body state; their native behavior
is not established here. Every executable statement in those selected regions
is translated, rather than substituting an independently written gameplay model.

Source-contract checks additionally retain aimed disarm/martial dispatch, bound
the sweep to sixteen native 2px pulses, prohibit teleport/damage/knockdown in the
new path, keep stagger after displacement, suppress delayed Bump pushes, and
exclude transient deadlines from custom persistence.

These are **offline control-flow and source-contract checks**, not native BYOND
movement, collision, graphical, save/load, or multiplayer acceptance. Native
validation remains separately required for cardinal/sub-tile displacement,
walls/windows/doors/body collisions, active walk cancellation, map grace barriers,
persistence holds, and timing. Do not interpret a passing suite as those tests.
