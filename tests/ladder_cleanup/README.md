# Ladder destruction layers

Run `py -3 -m unittest discover -s tests/ladder_cleanup -p test_destroy.py`.
This stdlib-only suite projects complete production/frozen procedure bodies
through the existing offline source adapter. It launches no engine or collector.

BYOND chains repeated same-type procedure definitions: the later definition's
`..()` invokes the earlier one. The old effective chain was WW2 (when applicable),
partner cleanup, registry removal, then inherited structure destruction. The
registry layer ignored its parent's return, so the ladder returned null.
See the official [DM reference](https://www.byond.com/docs/ref/info.html),
".. proc" and ". var (proc)". Consolidation preserves that order and return.
The WW2 override and all inherited structure/object/atom/datum code stay intact.

The 48-case before/after matrix covers top/bottom, missing/present target,
plain/WW2, zero/one/two registry occurrences and null/non-null parent returns.
Focused cases check ordering, exactly one inherited call, unrelated entries,
unchanged WW2 requests, and callback changes observed by the next layer. Five
mutation controls exercise missing effects, wrong order and propagated return.

Registry removal and qdel are explicit fake boundaries. Retaining the target or
clearing target/top during delivery are mock policies, not proof of native
deletion, reference nulling, recursive partner destruction, GC timing or paired
ladder gameplay. Native compilation and runtime acceptance are separate.
