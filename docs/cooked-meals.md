# Prepared meals

Fill an existing cooking pot with 100 units of water. Put in a potato or corn
and at least one carrot, cabbage or tomato. Each ingredient must retain at
least one unit of nutriment/protein, with at least four food units in the batch.
The full reagent contents must fit the pot's 100-unit capacity. Light a campfire
or oven within one tile, then use **Prepare meal** on the pot. Stay beside it
for six seconds; movement, interruption, lost ingredients or an extinguished
fire cancels preparation without spending the ingredients. Other pot actions
are blocked during preparation.

| Meal | Ingredients in addition to potato/corn | Mood floor |
|---|---|---|
| Vegetable potage | Carrot, cabbage or tomato | 55 |
| Hearty stew | One vegetable plus meat or beans | 60 |
| Seasoned hearty stew | Meat or beans, two different vegetables, at least 0.5 units of salt | 65 |

Use whole produce, not prepared dishes. Duplicate carrots do not count as two
vegetable varieties. Rotten ingredients and trace scraps do not qualify. Beans
provide a vegetarian route; meat preserves the normal dietary restrictions.
Existing crop gathering/farming, animal butchery, campfire, metal pot and bowl
crafting routes supply the ingredients and equipment. Existing research/map
restrictions still apply. Salt can be collected using the existing saltwater
boiling route; it is optional for the first two tiers.

Hold an empty wooden or snack bowl and use it on the finished pot. Three bowls
share the actual reagent pool, including its remaining fractional quantities;
serving spends the bowl and leaves the corresponding empty bowl after eating.
No nutrition or protein is generated. The 100 units of cooking water are spent,
not awarded as hydration. Cooking removes food poisoning and cholera; it does
not purify arbitrary chemicals or revive rotten food. The older automatic
boiling/stew route remains available and retains its existing balance.

Eating four actual units of nutriment/protein from the same quality tier can
raise mood to the listed floor. Tiny bites accumulate only their real food
content, switching tiers resets partial credit, and repeated portions cannot
stack above that floor. Higher mood is preserved. Normal mood decay still
applies. This changes no hunger, idle-metabolism, stamina or healing rates.
The existing mood system may affect performance through its normal modifiers.
Each bowl has a finite quality-credit budget from its original paid food;
refilling it cannot renew that budget. Prepared bowls retain this budget, their
quality and dietary flag in native saves; batches
retain their remaining portions and pool. In-progress cooking locks are excluded
from export and import. A restored interrupted batch must be prepared again.

## Source inspiration and assets

Pocket Stronghold13 was inspected in the clean local checkout at pinned commit
`a354dae33450a698deeb48238896615f072a5369` (origin recorded as
`https://github.com/Valgorithms/Pocket-Stronghold-13.git`). Its
`code/game/objects/items/food/dishes.dm` defines simple/decent/luxurious dishes;
`code/datums/mood_events/needs_events.dm` gives those tiers 10/15/20 mood with
10/20/30 minute durations. `_food.dm` adds them under the shared `food` mood
event key. `recipes.dm` associates actual ingredients, cooking stations and
skill requirements with dishes. These are design references, not Civ13 balance
values. Civ13 uses original recipes and its own bounded mood floor instead of
copying that event system. No PS13 code or assets are copied. Existing Civ13
`kitchen.dmi` stew states supply the graphics; no license inheritance is assumed.

## Verification

`tests/cooked_meals/run.py --byond-bin <516.1681-bin> --output <empty-directory>`
compiles production sources with maps/global startup disabled, closes the port,
and runs bounded ingredient, heat, interruption, portion, ingestion, reward and
native disk-save checks in temporary storage. Actor startup, inventory UI and
cooking waits are adapters; the production recipe, transfer, quality and save
paths execute. Controls `human`, `payment`, `portions`, `reward`, `persistence`, and `heat`
mutate generated source only and must fail their named assertion. CI selects
this new suite for this PR; existing suites remain opt-in. This is isolated
production-path evidence, not full-map, client, live server or deployment proof.
