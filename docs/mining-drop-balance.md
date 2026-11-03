# Independent mining drop balance - 2026-11-03

Baseline: master `edb0d3901529c9e1cbfad55fc6491c08e12baa4a`.
Only finite rock mining changes, including the shared dynamite caller. Renewable sifting, panning, drills,
fracking, recipes, tool speeds, waits, map placement and live servers are unchanged.

## Intended behavior and actual old probabilities

The old table returned after its first success. At ages 2-7 outside Antarctica,
its nominal 40% iron roll was actually `0.8 * 0.4 = 32%` per wall. The nominal
25% fuel branch was actually `0.8 * 0.6 * 0.25 = 12%`, divided equally between
coal, saltpeter, sulphur and lead: **3% each**, not 25% each. Silver, gold and
diamonds were likewise reduced by all preceding failures.

Every listed ore now has its own independent roll. These are the *unconditional*
per-wall rates, not rates conditioned on another ore failing. Coal alone is
intentionally raised from 3% to 6%. Other ore rates and batch sizes are retained.

| Ore | Old chance, ages 2-7 | New chance | Ordinary batch | Old expected units/wall | New expected units/wall |
| --- | ---: | ---: | ---: | ---: | ---: |
| Copper | 12% | 12% | 12-24 | 2.16 | 2.16 |
| Tin | 8% | 8% | 12-24 | 1.44 | 1.44 |
| Iron | 32% | 32% | 12-24 | 5.76 | 5.76 |
| Coal | 3% | **6%** | 24-32 | 0.84 | **1.68** |
| Saltpeter | 3% | 3% | 8 | 0.24 | 0.24 |
| Sulphur | 3% | 3% | 8 | 0.24 | 0.24 |
| Lead | 3% | 3% | 8 | 0.24 | 0.24 |
| Silver | 1.8% | 1.8% | 4 | 0.072 | 0.072 |
| Gold | 0.684% | 0.684% | 4 | 0.02736 | 0.02736 |
| Diamond | 0.33516% | 0.33516% | 4 | 0.0134064 | 0.0134064 |
| Uranium | 0% | 0% | 1 | 0 | 0 |

Iron stays unavailable before age 1. Coal/saltpeter/sulphur/lead stay unavailable
before age 2 and in Antarctica. Uranium stays unavailable before age 8 and on
legacy rocky floors without the mineable flag; their other drops stay supported.
Early/Antarctic precious-metal rates retain their historical values:

| Eligibility | Uranium | Silver | Gold | Diamond |
| --- | ---: | ---: | ---: | ---: |
| Age 0, any map | 0% | 4% | 1.52% | 0.7448% |
| Age 1, or ages 2-7 Antarctica | 0% | 2.4% | 0.912% | 0.44688% |
| Age 8+, outside Antarctica | 1.8% | 1.71% | 0.6498% | 0.318402% |
| Age 8+, Antarctica | 2.4% | 2.28% | 0.8664% | 0.424536% |

These are analytic nominal probabilities under independent RNG. DM passes
fractional percentages directly to its native `prob` built-in; rates are not
rounded to whole percentages. A local 516.1688 seeded million-draw check of
`prob(0.33516)` produced 3,317 hits (0.3317%), consistent with its 0.33516% target.
That finite sample checks engine precision support, not long-running gameplay.

## Co-occurrence, drought tails and material budget

For ages 2-7 outside Antarctica, the independent count distribution is obtained
by multiplying `((1-p) + p*x)` for all eligible ore rates:

- No listed ore: 45.9087% (old: 33.18084%); every such wall still gives geology
  or ordinary stone. Preserving marginal yields while allowing clusters means
  more ore-free walls as well as multiple-ore walls.
- Exactly one ore type: 40.3584%; two: 11.8874%; three: 1.70271%.
- Two or more: **13.7329%** (age 0: 2.1561%; age 1: 8.1877%; age 8: 14.4024%).
- Iron and coal together: **1.92%**; previously impossible.
- Maximum successful batch at ages 2-7: 140 ore units across ten types, plus at
  most 12 shared rubble. At age 8 add one uranium. Such all-success outcomes
  are extraordinarily rare; each resource still has only one bounded roll.

Coal drought probability after `n` independent eligible walls is `(1-p)^n`:

| Eligible walls | Old no-coal chance | New no-coal chance |
| --- | ---: | ---: |
| 25 | 46.6975% | 21.2910% |
| 50 | 21.8065% | 4.5331% |
| 100 | 4.7553% | 0.2055% |

A 95% chance of at least one coal batch moves from 99 walls to 49. The mean wait
moves from 33.33 walls to 16.67; coal is still random, with no pity timer. Expected
coal per iron unit moves from 0.14583 to 0.29167. Total expected listed ore at
ages 2-7 rises from 11.03277 to 11.87277 units/wall, a 7.61% increase consisting
entirely of coal. This does not equate ore units of different values.

The old precious-ore and geological budgets are calculated from historical
marginals, never from the actual outcome of another independent ore roll. After
all ore misses, geology is admitted with `old_geology_probability / new_no_ore_probability`.
At ages 2-7 that is 72.27569%; multiplying by the 45.90872% no-ore chance restores
exactly the old 33.18084% geology budget. Its original climate/map/era predicates,
including historical boolean precedence, stay intact. Fossils, sandstone, marble
and obsidian keep their unconditional availability and quantities. Geology
rejection gives ordinary stone, including in sandy/icy terrain.

Common ores share one 8-12 rubble batch, regardless of how many common ores
succeed. Rare-only drops have no added rubble. On ordinary temperate Pangea at
ages 2-7, expected stone rises from 11.70893 to 13.13146 units/wall (+12.15%);
marble remains 6.636168% with a 16-24 batch. This small stone increase comes from
the additional ore-free walls, partly offset by paying rubble once. Special
caves retain their existing doubled mineral/geology batches and undoubled common
rubble; uranium remains one unit and fossils two. Existing special-cave coal can
still be 48-64 units; this patch does not redesign stack caps.

## Downstream implications and evidence limits

Copper/tin/iron progression and expected metal supply are unchanged. Saltpeter,
sulphur and lead supply is unchanged, avoiding an unintended gunpowder/ammunition
increase. Gold, diamonds and uranium keep their expected availability. Joint
variance changes: materials can now arrive together rather than being exclusive.

Coal fuel availability intentionally doubles. Existing oven/factory/refining
handlers credit three fuel per coal; the heat-source helper credits 240 burn
seconds per unit, versus 80 for charcoal; the steam locomotive credits 15 fuel
per coal. Thus expected heat-source coal energy rises from 201.6 to 403.2 seconds
per eligible wall, and locomotive fuel from 12.6 to 25.2. Recipe costs, conversion
ratios, capacity and alternatives are unchanged. These source calculations are
not a claim that steel, transport or power is balanced in a populated round.

The native deterministic production fixture covers all ore types alone/together and both quantity endpoints,
ages 0-8, Antarctic exclusions, special quantities, geology admission, single
strength/rubble rewards and finite depletion. It also asserts the numeric chance
passed to each ore roll and the unconditional geology budget. The existing
Modern energy fixture's uranium mask is moved to its new eighth roll; its separate
native runner is not claimed as executed here. Connected-client mining, full-world
save/load, performance and live economy observations remain unverified.
