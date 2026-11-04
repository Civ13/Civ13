# Independent destructive mining yields

Run from the checkout root with the current canonical BYOND pin (516.1688):

```powershell
pwsh -NoProfile -File tests/resource_extraction/run.ps1 -ByondBin '<BYOND-bin>' -Probe tests/mining_yields/probe.dm
```

The launcher substitutes only RNG calls inside the production mining procedure.
Its era/map/climate gates, constructors, output quantities, strength award and
terrain conversion remain production code. The 12 x 12 x 2 fixture disables
ordinary startup, refuses clients and ports, and uses disposable runtime storage.

The deterministic matrix covers each ore alone and every ore together, both
quantity endpoints, ages 0-8, Pangea and Antarctica, ordinary and special caves,
all geology branches, rejected geology, one shared rubble batch, one strength
award, and a second completion against depleted terrain. It checks exact output
types and totals, including uranium's one-unit exception and two special-cave
fossils. A separate oracle checks all eleven marginal ore probabilities and the
unconditional geology budget for every age and both maps. Forced successful
rolls for zero-chance ores still must fail their eligibility guards.

A seeded million-draw check calls the native built-in `prob(0.33516)` outside the
adapted body, with a six-standard-deviation bound. This checks fractional native
probability support; it is not a full-game distribution or balance benchmark.

See [the balance audit](../../docs/mining-drop-balance.md) for old conditional
versus marginal rates, deliberate coal changes, drought tails and downstream
limits. Renewable gathering stays at its existing one-unit manual/two-unit
powered batches. The fixture does not establish connected-client interaction,
real mining wait duration, full-world saves or long-running economy balance.

Editing this existing fixture does not automatically admit its native CI group.
The ordinary PR compiler/offline checks remain selected; the local exact-source
fixture result must be reported separately. No broader native admission is added.
