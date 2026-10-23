# Farming water discovery: offline review evidence

Base: `9db2b2f42a5fbbb0bdd49d50a2672da6111a7709` (master fetched 2026-10-22).
No `.agents/skills` or nested AGENTS.md is tracked at that base.

Run with Python 3.10+ (use a verified absolute executable on Windows):

```
python -B -m unittest discover -s tests/local_discovery -p test_farming.py -v
```

The existing CI evidence-checker runs `tests/local_discovery` when this PR
introduces the suite or an extensive-regressions run is explicitly selected.
The guarded group discovers both farming and temperature tests when both exist.
Existing-test/source edits retain the repository's opt-in regression policy.

The test reads the immutable base with local `git show`, translates the complete
production `water_proc`, and compares synthetic water/stage/death results.
It covers 10,240 type/flag/radius/z/climate/heat/water combinations, 24 mixed-source
orders, early-return precedence and independent semantic expectations. Three
generated-source controls reject lost salt/flooded checks and lost rain capping.
A whole-file projection proves code outside water discovery is unchanged,
including growth, RNG, soil, death presentation and harvesting. Those paths are
not executed by this adapter; no native growth/harvest acceptance is claimed.

Synthetic `range()` calls per eligible watering invocation:

| Nearby source | Base | Candidate |
| --- | ---: | ---: |
| None / salt only | 3 | 1 |
| Freshwater | 1 | 1 |
| Fresh flooded trench | 2 | 1 |
| Fresh flooded irrigation floor | 3 | 1 |
| Weather/mushroom/missing-area early return | 0 | 0 |

The spatial adapter uses inclusive Chebyshev radius and same-z coordinates with
explicit type-path inheritance. It is not a native BYOND range/type oracle;
synthetic candidate and typed-visit counts do not measure engine work. There
are no wall-time, memory, server-latency or speedup claims. Native compilation
(BYOND 516.1681), existing outdoor-crop/plant-lifecycle fixture checks, and any
needed graphical acceptance remain pending separate capacity/authorization.
No native game process, OpenDream, client, port or external-effect adapter runs.
