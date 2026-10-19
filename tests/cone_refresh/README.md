# Forced relocation and vehicle cone refresh

This focused port adapts RuCiv13 commits
`3c1ee1fa0170330cc4aadf96273428c3f233ad58` (human forced relocation) and
`24434a668d0f37439db040ee56c01128ad99b34a` (vehicle passenger FOV refresh),
by SepuIka/RuCiv13 contributors, under the repository's AGPL-3.0 license.
The fork and Civ13 cone algorithms are identical at the reviewed revisions.
There is no separate fork lighting engine imported here.

Human forceMove keeps the parent result and only invalidates after a changed,
non-null turf. Active vehicle-owned passengers defer that callback until the
successful axis translation/rotation has released its flags and finalized hull
positions and passenger facing. Stationary gunner, MTLB gunner, loader and
commander seats refresh after their existing changed-facing assignments.
Driver/machine-gunner update_icon remains a no-op; their buckle callbacks
refresh the occupant after existing buckle direction handling. No new
production state is serialized.

Run offline checks without launching BYOND:

```
py -3 -m unittest discover -s tests/cone_refresh -p test_offline.py -v
py -3 tests/cone_refresh/run.py --prepare-only --output <new-evidence-directory>
```

The isolated native runner requires an explicit reviewed source commit and
BYOND 516.1681. It does not connect a client or open a network port:

```
py -3 tests/cone_refresh/run.py --byond-bin <bin> --expected-commit <sha> --output <new-directory>
```

Repeat with `--control forced-move`, `translation`, `rotation`, `early-refresh`
and `seat-facing`, each in a separate new output directory. Each generated
control must fail its exact named assertion; arbitrary diagnostics never count
as a caught regression. The runner requires one exact pinned compiler banner,
one clean artifact-specific summary, bounded output and no fatal diagnostics.

The full production includes remain in the fixture. Only ordinary world/global
startup and inert actor/vehicle constructors are suppressed. The production
cone body uses a fixture-only client-image transport datum instead of a network
client. Native view(), cone(), InCone(), images and rest/disabled/HUD gates are
unchanged. Human forceMove, axis transport/matrix/flag release, seat update_icon
and the disk BuildVarDirectory/Load_Entry procedures remain production bodies.
Preparation records exact source/generated hashes. The fixture checks parent
return/Entered callbacks, redundant/nullspace/diagonal/compiled-z moves,
rear/front membership, native opaque/open barrier visibility and view edges, no-client/disabled/rest/HUD gates,
actual two-frame translation and 2x2 rotation, final callback count/order,
busy/blocked refusal, unrelated actors on reserved tiles, all six seat facing
paths and a disk actor-codec round trip followed by cone rebuilding.

Limits: this is not client pixel/rendering acceptance, an oversized-sprite fix,
an opaque-door/tree/roof geometry overhaul, a full round restart/rejoin test or
a new movement/collision policy. The save test imports an identity-only dead
human to avoid unrelated physiology. Native outcomes must be recorded against
the exact head; preparation and Python tests alone are not gameplay proof.
