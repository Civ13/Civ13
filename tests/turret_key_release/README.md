# Turret key release

Releasing the matching left/right movement key now stops the carried turret
controller's scheduled rotation loop. This ports the key-release behavior from
[SepuIka/RuCiv13 commit 93d641cd](https://github.com/SepuIka/RuCiv13/commit/93d641cd77a21717559894f7e4e04ad38cfc9953),
retained at `afb145be65c2f7a5ba2d466f6c278bb8e9f8b62e`. Attribution to RuCiv13
and its contributors is preserved; this adaptation remains under the repository's
AGPL license. Existing Civ13 direction signs, opposite-key guards and drone
release behavior remain intact.

Offline preparation:

```text
py -3 -B -m unittest discover -s tests/turret_key_release -v
py -3 -B tests/turret_key_release/run.py --prepare-only --output <fresh-directory>
```

Native CI with reviewed BYOND 516.1681:

```text
python3 -B tests/turret_key_release/run.py --byond-bin <516.1681-bin> --output <fresh-directory>
python3 -B tests/turret_key_release/run.py --byond-bin <516.1681-bin> --negative-control --output <another-fresh-directory>
```

The fixture extracts the actual two client release verb bodies and the actual
`stop_rotation`, `start_rotation` and scheduled `rotate` procedures from current
production files. Only client verb ownership changes to a declared datum with
a `mob` field, because native clients cannot be constructed headlessly. Item,
mob and turret declarations replace game constructors; the turret azimuth
callee records calls instead of running ballistics/vehicle simulation. Actual
BYOND scheduling, containment, object iteration and z-level positions execute.

Seven scenarios cover both turn directions, diagonal input, null/detached input
owners, stale opposite-key releases, other mobs, nested controllers and existing
drone stop semantics. They check flags, the absence of later scheduled azimuth
calls after release, mob position, inventory references and unchanged action
clocks. They establish callback behavior through the declared client adapter,
not real connected-client key dispatch or complete vehicle gameplay.

The negative control uses the actual release code from immutable Civ13
`cc03b199128f8afed58713912c551ad7556e6bc4`; it must compile/run successfully and
then fail the named scheduled-stop assertion. Compile/runtime failures cannot
count as a detected negative control. Preparation accepts only two exact
whole-file movement fingerprints: the original reviewed turret port, or pinned
`4b77eab58979ca718faf1aebe9a879a631dcdedf` sub-tile movement with only the same
two release additions. Every Move/SelfMove admission, context and dispatch byte
remains covered; unknown movement edits fail closed. Metadata identifies the
selected reference. The immutable `cc03b199` release control remains unchanged.
Six offline controls reject altered dispatch, identity gates, drone behavior and
missing, duplicated or relocated release stops. The
collision, Move/forceMove, doors, trees, vehicles, multi-z, pathfinding, input
cooldowns and save implementation are not replaced. No save/reload equivalence
or native client presentation is claimed by this focused fixture.

The fork's unrelated stealth rebalance and removal of Civ13 drone, football,
submarine-depth and vehicle-transform protections are deliberately not ported.
Human/vehicle vision-cone refresh is a separately owned dependency review.
No durable field or new reference is introduced by this change.

The runner closes the fixture's port, uses temporary storage, launches only
explicit native binaries with `-trusted`, and retains generated source, logs,
result and hashes. No game startup, configuration, external service or model
transport runs. Automatic CI executes the positive fixture and original control
and uploads evidence named for the exact PR head. Local native execution still
requires the repository's maintainer/lease authorization.
