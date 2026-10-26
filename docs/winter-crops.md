# Winter crops: turnips and plump helmets

Originally prepared against Civ13 master `6b075397bd6efab6ad2e6ffcbd7240b865fcc72e`;
merged through PR #3314 as `a1f08b3d3ac366cd85a08eaf2fd4f9e734faa9a6`.
Exact-source native crop/food and focused writer/reload evidence is recorded below.
Connected gameplay and rendered world appearance remain untested; asset previews
are not gameplay captures.

## Two different food routes

| Crop | Site | Water | Yield / harvest | Tradeoff |
| --- | --- | --- | --- | --- |
| Turnip | Outdoor, open-sky ploughed soil; temperate, sea, tundra or taiga | 90-unit capacity; normal watering and fresh-water irrigation | Existing 1-3 produce based on sampled soil fertility, 2 seeds; each root has 2 nutriment | Winter and snowstorm eligible, not a cave crop; drought/sandstorms still kill it |
| Plump helmet | Ploughed soil, including indoors/underground | No watering, inherited mushroom behavior | Existing 1-3 produce based on fertility, 2 spores; each fungus has 2 nutriment | Only half of normal stage-advance attempts succeed before soil probability; still consumes soil every growth callback |

At high fertility, turnips need at least six nominal one-minute stage advances.
Plump helmets need at least six successful advances, averaging twelve attempts
before additional poor-soil delays. This is source arithmetic, not measured timing.
The fungus offers broader starter access, a distinct food and longer storage than
ordinary mushrooms, not a promised higher long-run calories-per-minute rate.
Probabilistic growth has no fixed wall-clock deadline; ripe stages still use the
same advancement path toward death rather than stopping at harvest readiness.
Ripe crops still advance toward death; harvest with a knife, hatchet, bayonet or
scythe rather than leaving the mature crop indefinitely. Both use the existing
three soil-nutrition debit per growth callback. No new scheduler is added.

Turnips have a 90-minute nominal floor decay limit (180 in ordinary storage).
Plump helmets have a 60-minute floor limit (120 in ordinary storage). Both use
ordinary edible-food metabolism, not satisfaction as a substitute for nutrition.
Neither adds a drying, soup, milling or brewing recipe. They are directly edible.
Existing food-age, refrigerator, can and rot rules are unchanged.

## Getting started

Use a kitchen knife in Help intent on a small bush with seed stock. The existing
random seed pool now includes turnips in their listed biomes, and plump-helmet
spores in every default biome. This is an ordinary forage route, not a guarantee
of a particular seed or a bush near every player spawn. Bush seed stock has the
existing ten-minute cooldown. Seeds can also be traded and each successful
harvest returns two, while planting consumes one.

Plump spores remain forageable in every biome for cave farming. Sowing now rejects
outdoor plots where inherited mushroom growth cannot advance, before consuming a
spore or starting soil payments. On the six Nomads maps, outdoor planting needs a
mushroom-compatible biome and season; jungle and savanna bypass season restrictions.
Desert and semiarid outdoor plots are rejected. Indoor/underground areas (location 0)
remain eligible in every climate, and non-Nomads maps retain their climate/season
bypass. A suitable ploughed soil turf is still required in every case.

A plough costs four wood planks under Basic Agriculture. Existing research-tree
and map rules apply; neither the recipe nor its legacy zero thresholds bypass
research admission. The node is era tier 1. Underground rock debris must first
be cleared with a pickaxe; ordinary resulting dirt can then be ploughed.
Jungle/savanna underground debris instead becomes jungle dirt, and the Desert
map uses dust: those remain unsuitable without a separately supported soil route.
This change does not introduce fungus beds, cave forage or new terrain conversion.

Turnips require open sky at sowing and again at every immature stage-advance attempt.
A later roof blocks development, not ripe-crop aging; the plant continues paying existing soil/water
costs. This is a location proxy for ordinary outdoor light, not a new real-time
photosynthesis or artificial-grow-light simulation. Darkness-compatible plump
helmets inherit the explicit mushroom family behavior. Other crops are unchanged.

Clear ground snow before ploughing, prepare soil before winter where possible,
and keep turnips watered. The inherited fresh-water irrigation check includes
existing water subtypes, including ice; this change does not rebalance irrigation.

## Seasonal hardiness, not a physical temperature simulation

Only turnips opt into `winter_hardy`, which skips the existing snowstorm instant
kill in `water_proc()`. It does not skip water use, drought, sandstorms, soil costs,
biome/season selection or overmaturity. Existing mushrooms retain their own
water/weather exemption. Ordinary crops keep `winter_hardy = FALSE`.

Civ13 crop growth is season/biome based and does not use `get_temp()`. Its human
weather model includes -29 C temperate winter and -82 C storms. This port does
**not** claim real turnips survive those temperatures; it adds a cold-hardy root
to the existing seasonal gameplay abstraction without rewriting global climate.

## Art and verification

See [asset attribution](../icons/farming/ATTRIBUTION.md). Actual Pocket Stronghold
turnip and plump-helmet art was visually reviewed before selection. The unrelated
cave-wheat sprites were reviewed but not ported: that would require a separate
grain/processing balance and was unnecessary for these two complementary routes.

Run source-only checks:

```sh
python -m unittest discover -s tests/winter_crops -p 'test_*.py' -v
python tests/winter_crops/assets.py --preview /tmp/turnip-preview.png
python tests/winter_crops/assets.py --crop plump_helmet --preview /tmp/plump-preview.png
```

The tests execute narrowly translated production water/site predicates and inspect
source/asset contracts; they do not substitute for DreamMaker or native gameplay.
The older extracted outdoor/lifecycle fixtures remain native unrun. A separate
Linux BYOND 516.1688 one-shot tested exact crop commit
`8070d5cbe26c39c42d6bf5ce132d16f7cc3768e0`: five clean compilations and seven
native phases passed, including direct crop/food paths, frozen scalar and partial
food persistence, and four causal controls. See the
[exact-source evidence and limits](../tests/winter_crops/README.md#exact-source-native-acceptance).

A later [natural writer/reload test](../tests/winter_crops/README.md#natural-writerreload-at-ae99e2b)
passed on exact head `ae99e2b07c3ba9a2dd191ba07b6dba27a4bfda3e` using ordinary
constructors, growth waits, real Save_World/Load_World and after-load callbacks.
Both writer and fresh reader observed two ordinary crop intervals, 80 soil payments
and four food-aging events, with tracked seed/crop/partial-food state conserved.
Reload starts a full new growth wait; the partial pre-save wait is not restored.

The later seed-admission-only commit `379875cabaec0be86ac86f8e9de36a9cb0d7815f`
compiled with zero errors/warnings and passed 17 winter source tests. It changes no
growth/save code, but the native result remains bound to ae99e2b rather than being
relabeled for the final commit or squash merge. Post-merge ordinary CI also passed.

These results do not establish a complete player forage-to-harvest-to-meal journey,
full harvest timing or winter food balance, connected-client interaction, full-round
restoration through ticker.loadmap, or full-world save/load acceptance.
