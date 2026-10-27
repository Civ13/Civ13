# Animal combat regression

Run `run.py --byond-bin <516.1681-bin>` with a verified Python interpreter.
The complete production sources compile without maps or normal startup. Native
constructors, Life, item dispatch, damage, material wear, healing, feeding,
leashing, zero-force taps, sharp hostage fallback, Kenobi overrides and death run in temporary
storage. The runner closes its port during startup; the CI log records an initial
network port before closure, without a zero-listener census. A test material makes
ordinary wear deterministic;
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

`test_retaliation.py` checks defensive-retaliation source contracts offline.
`run.py --prepare-only` runs those tests and stages sources without native
processes. The native runner also includes `retaliation.dm`. Its headless native
assertions and all four existing negative controls passed on
`88d013f63ff719d51f44f701ccd9251767000d0a` in
[CI run 39993427940](https://github.com/Civ13/Civ13/actions/runs/39993427940), with
BYOND 516.1681 compilation producing zero errors and zero warnings. The earlier
[run 39992944285](https://github.com/Civ13/Civ13/actions/runs/39992944285) on
`54a273d` failed because the feeding fixture used a full ram; that failed attempt
is preserved, and `88d013f` corrects the test setup. Connected-client timing and
appearance remain untested; local native execution stayed deferred. See
[`docs/animal-retaliation.md`](../../docs/animal-retaliation.md) for species scope,
triggers, cooldowns, timing limits and client reproduction steps.
