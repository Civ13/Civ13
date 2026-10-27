# Initial throw clearance

The ordinary item throw starts at the human's anchor turf. A smooth human's
physical footprint can already cover the first destination turf, whose contents
therefore include the source. Launch clearance suppresses only that source's
initial continuous overlap during successful outbound cardinal hops.

First separation permanently disarms clearance for that flight. The state also
ends on a failed/no-op hop, changed attribution/direction, reverse or non-adjacent
hop, catch/container transfer, pickup, Bump, completion and destruction. Another
standing mob remains hittable during launch clearance. Thrown mobs, non-human
sources and remote/unattributed scripted launches never arm it. The existing
lying/barrier rules, stationary first-hop behavior, blocked-launch collision,
flight range, cadence, target and damage-speed values remain intact.

This is not physical-origin synchronization or movement-vector inheritance.
Those require a separate flight/collision/range contract. The legacy velocity
counter and impact speed are not physical velocity vectors.

Run the offline production-flow checks:

```powershell
py -3 -B -m unittest discover -s tests/throw_launch_clearance -p test_launch.py -v
py -3 -B -m unittest discover -s tests/save_movement -p test_throw_target.py -v
```

The first command executes selected complete production procedures using the
existing closed-subset DM projector and explicit native geometry/type/effect
adapters. It covers all directions, partial/odd offsets, aligned release followed
by a moving source, stationary launch, two-hop diagonal egress, empty-turf
separation, later recontact, reversal/reflection, unrelated actors, lifecycle,
different entrypoints and custom-save exclusion. Four defect controls exercise
missing source clearance, permanent immunity, first-hop-only immunity and missing
empty-turf separation. These are offline source-flow tests, not BYOND execution.
The bounded CI baseline registry includes this named offline test file only.

Prepare the full-source native fixture from an exact local commit:

```powershell
py -3 tests/throw_launch_clearance/prepare.py --prepare-only --output <fresh-output>
py -3 tests/throw_launch_clearance/prepare.py --compile-only --output <fresh-output> --byond-bin <516.1688-bin>
```

Preparation reuses the existing human fixture's map/startup isolation, strips
production maps, and selects `throw_launch_fixture_run` in an 18x14x1 world. It
uses native physical membership and the actual throwing processor. Living impact
dispatch enters a harmless human hitby adapter, with no damage, messages or
external attack logging. Aligned/moving cases use actual human pulse admission;
partial-offset cases use the existing explicit fixture placement adapter.

The compile mode uses the unchanged current-engine compiler Session and frozen
containment helpers. It has no daemon execution option and never runs a game.
Native execution is separate and must retain the existing closed port/rejected
clients/external-effect/owned-process requirements. Inspect its complete receipt
and `launch_checks` before claiming gameplay acceptance; compilation alone is
not acceptance. Expected native coverage includes the diagonal second-hop,
empty-turf separation, actual later source hitby, reflection before separation,
other target, blocked throw and lifecycle assertions. Run the historical
throw-target disk fixture separately if validating serializer behavior.
