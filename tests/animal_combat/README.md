# Animal combat regression

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.
The complete production sources compile without maps or normal startup. Native
constructors, Life, item dispatch, damage, material wear, healing, feeding,
leashing, zero-force taps, sharp hostage fallback, Kenobi overrides and death run in temporary
storage with ports closed. A test material makes ordinary wear deterministic;
actor animation and normal world startup are isolated adapters.

The compiled all-type health audit checks inherited defaults, allowing only the
explicit blindman NPC conflict (health 500, maxHealth 200). Its intended balance
needs a separate decision. Missing declarations are fixed explicitly, preserving
existing runtime construction and damage policies. The zombie constructor sets
health/maxHealth together dynamically.

`--negative-control health`, `chick`, `duplicate`, and `kenobi` mutate generated copies
only and must detect the old camel cap, chick cap, and repeated base/custom parent attacks.
Compilation warnings, runtime errors or missing completion invalidate a run.
Evidence is retained under ignored `data/animal-combat-tests/`.

This is offline native interaction evidence, not graphical or live-server proof.
No capture is needed for these deterministic contracts. No production restart,
save read or deployment occurs.
