# Wildlife registry retirement source contract

Separate companion to the farm-only #3051 correction. Eight existing death and
Destroy hooks intersect the bear/bison/wolf registries with their retiring owner,
discarding other members. Replace only those operators with owner subtraction.
Parent calls, constructors, AI, reproduction, population limits, save fields and
revival are unchanged. No complete population-cap or revival repair is claimed.

Scope: bear death/Destroy, bison and bisonbull death/Destroy, wolf death/Destroy.
One-time review against master 5bf351248de6050876fe5b53f91209a970cc5668 verifies
only eight production operators change. The separate farm patch is not included.
All-state PR searches for bear_count, bison_count and wolf_count found no prior
repair; current file history still contains the original intersections.

Run offline with the Python standard library:

    python -m unittest discover -s tests/wildlife_registry -v

Five source-contract tests check all eight bounded hook bodies, parent calls,
wrong-registry/clear-all/missing-parent mutations, individual reversions and an
all-intersection control. Unrelated source additions are allowed. No Git history
is required. These are textual checks, not execution or emulation of DM semantics.
No native compiler/runtime, save/load or connected gameplay acceptance is claimed.
No CI workflow change, deployment or external publication is included.

Native acceptance should exercise production hooks with several peer identities,
repeated death, Destroy without death, death then Destroy and unregistered owner
removal, verifying parent execution and preservation of all other members. Broader
lifecycle and reproduction issues remain outside this operator correction.
