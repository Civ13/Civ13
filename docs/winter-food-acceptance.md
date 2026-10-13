# Winter food audit and acceptance

Status: the narrow open-can regression passed isolated native storage and save/load checks at `9851c638742256ad46c657a6ede3d67a1d1aa416`. Broader winter-food and player acceptance remain pending.
Audit base: `1627730ecec53f385cbf1956b7a9e4385dffa675`.

## Actual clocks

The ordinary Nomads constructor and base season loop each schedule 18,000 ticks,
nominally 30 minutes at 10 ticks/second. Ice Age's custom loop schedules 9,000
summer ticks and 27,000 winter ticks. Mountain has a 18,000-tick custom wet/dry
loop. Fixed wet-season labels and disabled seasons require an elapsed-time
fallback for any transition-based food lifetime. No extended duration is confirmed.
Continental calls its Nomads parent constructor and also schedules seasons itself;
verify whether these inherited callbacks produce two recurring chains before
using nominal intervals as observed cadence.

Food currently uses a separate randomized 590-610 tick callback per decaying item.
Each callback adds 600 age on a floor, 300 in ordinary storage, 200 in an unpowered
fridge, 75 in a powered fridge, or 50 in a freezer. These are immediate-container
checks, not proof that nested bags benefit from refrigeration. Closed cans and
vending machines pause age. Open cans also avoid the final accumulation branch;
this is a candidate preservation exploit requiring production-path verification.
Food is not opted into the generic abandoned-item registry by its parent.

| Example | Current decay units | Nominal floor lifetime | Nominal ordinary-storage lifetime |
| --- | ---: | ---: | ---: |
| Tomato | 9,000 | 15 minutes | 30 minutes |
| Cabbage | 12,000 | 20 minutes | 40 minutes |
| Wheat | 3,000,000 | 5,000 minutes | 10,000 minutes |
| Potato | 420,000 | 700 minutes | 1,400 minutes |
| Rice stalk | 0 | No decay callback | No decay callback |

These are source arithmetic, not measured lifetimes or nutrition availability.
Floor potatoes also have a random green-potato conversion and early deletion.
Rot-capable foods become rotten at half their decay limit. Crop classes therefore
cannot share one undifferentiated fresh-food lifetime.

## Acquisition and preservation leads

Default global recipes offer a three-plank fishing pole and four-rope net through
Basic Tools. Fish schools accept poles or a sharpened branch; successful attempts
consume their counter. Empty schools schedule one replenishment after 3,000-3,600
ticks. Concurrent attempts and save/reload recovery require tests before claiming
bounded renewable supply. Continental additionally spawns fish schools at runtime;
placed-map counts alone cannot establish access from a player spawn.

Fishing cages cost twelve planks and have mode/research thresholds to validate.
Their catches wait 18,000-24,000 ticks and require water at completion. Ice/water
conversion, construction access, species products and saved pending work require
separate checks. Hunting must reuse existing species-bounded animal harvesting.

A dehydrator costs five raw wood in the global catalog but is mapped to
`resource_processing`; legacy thresholds and faction gates must be checked before
calling this an early-era preservation route. Its nominal drying work is 1,200
ticks, advanced by 150-tick callbacks. It constructs the dried product and deletes
the input. Food age, nutrition conservation, interruption and native reload must
be tested across that transformation; a new output must not provide repeatable
age-reset or yield amplification.

## Required implementation and acceptance

Choose explicit food categories and finite transition budgets that bridge the
intended lean season while retaining a benefit for preservation. Keep a documented
elapsed fallback for maps without real seasonal transitions. Avoid per-item
sleeping chains and runtime fields in durable saves. Preserve paid food quantities,
partial consumption, existing rot effects and irreversible accumulated age across
storage moves, season changes and reloads. Do not extend generic debris cleanup to
stored food.

Map/biome seed compatibility, actual resource paths, authorised research, winter
fish access, hunting depletion, preservation and edible consumption must be checked
on supported Nomads maps. Broader native tests and actual gameplay are pending a fresh shared native queue grant. Do not update public player guidance from these hypotheses.

Sources: `code/modules/reagents/reagent_containers/food.dm`,
`food/grown.dm`, `food/snacks/meat.dm`, `code/game/objects/map_metadata/nomads`,
`code/game/mob/living/simple_animal/friendly/static.dm`,
`code/game/objects/structures/sea.dm`, `code/modules/1713/production.dm`,
`config/crafting/material_recipes_global.txt`, and
`code/modules/research_tree/research_node.dm`.

## Prepared open-can regression

The draft changes only the final ordinary-storage aging branch so opened cans
accumulate age; sealed cans still return before that branch. Run the existing
`tests/food_progression/run.py --probe storage --byond-bin <516.1681-bin>`.
The prepared fixture checks sealed/opened cans, faster floor aging, and actual
native entry restoration followed by continued aging. `--can-negative-control`
restores the old opened-can exclusion only in generated source and must fail
`opened can accumulates food age`. Only the recurring wait is accelerated.
Both modes passed at `9851c638742256ad46c657a6ede3d67a1d1aa416` with BYOND 516.1681, zero compile errors/warnings and no runtime errors. The negative control detected the historical opened-can exclusion. This narrow correction does not replace per-food callbacks
or establish preserved-food conservation, lean-season lifetimes or player access.

## Isolated drying conservation evidence

At `a73c30e9f9058375977d2d224f4b8ef42751e6ca`, the production octopus drying probe passed with BYOND 516.1681, zero compiler errors/warnings and no runtime errors. The fixture removes nutrition to represent a partially consumed paid input, exercises production rack insertion and `before_save` cleanup, and restores its partial nutrition, accumulated age and encoded drying progress from a native disk entry before finishing production drying. Output nutrient caps and accumulated age assertions passed. Independent generated-source omissions of the nutrition cap and age carry each failed their corresponding assertion.

The recurring drying wait alone is accelerated. This is a synthetic 6x3 fixture with normal startup disabled and temporary storage; it does not prove player consumption, every drying recipe, a full-world rack save round trip, multi-season food availability, or winter map access. The Windows guarded batch used 41 seconds, remained below 218 MB owned private memory and above 13 GB free physical memory, and cleaned its owned processes and generated temporary files. Candidate production changes and their CI remain separate from the previously tested opened-can correction in #3110. No public player or wiki availability claim follows from this fixture.
