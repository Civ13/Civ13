# Modern hydroponics design contract (proposal)

Status: **proposal for review, not implemented.** This is the "reviewed contract"
that #3050 holds implementation on. Every number below is a proposed default
for a reviewer to accept or change. Nothing here is gameplay evidence.

Source facts are pinned to master `c79792d002b9a15b7cebd7735a43f6ac960ad4b2`.

## Source facts the design must respect

| Fact | Where | Consequence |
|---|---|---|
| Crop growth requires `/turf/floor/dirt/ploughed`; otherwise `growth()` only runs `water_proc()` and returns | `code/game/objects/farming.dm` `plant/growth()` | A tray cannot reuse `growth()` unchanged. Fabricating a dirt turf is rejected by #3050. |
| Ordinary crops schedule themselves with a recursive `spawn(600)` per plant | same | Trays must not add a second chain per crop. |
| Timber seedlings already use a bounded scheduler: saved `growth_time_left`, runtime-only `last_growth_tick` excluded by `persistence_runtime_var`, re-anchored in `after_load()`, driven by `process_interval()` from `processing_objects` | `plant/tree` in `farming.dm`, `docs/tree-planting.md` | This is the precedent for the tray owner. |
| `stageGrowth()` advances deterministically when `plant_nutrition > 80` | `farming.dm` | A fed tray behaves like well-fertilised soil. |
| Harvest: `spawn_seeds()` returns 2 seeds; `spawn_produce()` returns 1 item plus 0-2 extra when `plant_nutrition >= 80` (stacks: x1-3). Both spawn at `loc` | `farming.dm` | A plant held inside a tray would spawn its outputs into the tray. The adapter must put them on the tray's turf. |
| Soil nutrition: 0-150; plants eat 3 per tick; soil recovers 20-40 every 20 min only while unplanted; compost item `fertilizer_value = 60`, dry dung 20, manure 10 | `flooring_premade.dm`, `floor_attackby.dm`, `shit_piss.dm` | Outdoor nutrition is cheap and renewable, so outdoor farming stays the economical option. |
| Reagent `fertilizer` is registered, but no reaction produces it | `Chemistry-Reagents-Toxins.dm`, `Chemistry-Recipes.dm` | It cannot be the solution's paid input. |
| Reagents `eznutrient`, `left4zed`, `robustharvest` are registered (subtypes of `/datum/reagent/toxin/fertilizer`, so mildly toxic if ingested), but no reaction produces them | `Chemistry-Reagents-Toxins.dm` | `eznutrient` is a registered ID that a new recipe can produce, so it avoids the #3201 trap where a recipe without a registered reagent silently consumes its inputs. |
| Paid `potassium` and `nitrogen` come from the nitrary (10 leachate -> 1 potassium + 1 nitrogen, from 8 crop-equivalent units, 10 water, 1 ash, 30 active-server minutes) and from the saltpeter ore route it mirrors. `poo` x2 + `urine` makes `potassium` only | `wood_ash_compost.dm`, `docs/wood-ash-compost.md`, `Chemistry-Recipes.dm` | Nutrients are finite, paid and pre-Modern-reachable. |
| Power: `obj.powerneeded`/`powersource`; `cable.update_power(amount, 1, consumer)` reserves per consumer, idempotently, and returns whether it was accepted; `obj/Destroy()` releases it. `powerflow` is capacity, `currentflow` reserved demand, not stored energy | `objs.dm`, `cables.dm`, `fridge.dm` (`powerneeded = 5`) | Power loss means "reservation refused", so there's no battery-drain model to invent. |
| Research: `electricity` (Industrial, era tier 5, prototype); Agriculture tree has `basic_agriculture` -> `irrigation` (tier 2) -> `advanced_agriculture` (tier 4) | `research_node.dm` | The new node goes in the Agriculture tree after both. |
| There is no tray art: `icons/obj/hydroponics_machines.dmi` is not in the repo, and the plant-bag code that names it is commented out | `bags.dm` | Art must be made by transforming existing assets or with vector tools, never generated (AGENTS.md). |

## Proposed contract

### 1. Structure and ownership
- New `/obj/structure/hydroponics_tray`: anchored, dense, one seed slot, an internal reagent reservoir, and a lamp that draws power.
- The tray is the **single processing owner**. It registers in `processing_objects` only while it holds a growing crop, and leaves it on ready, empty, death and `Destroy`/`Del`. This copies the tree seedling's chain and its persistence exclusions.
- The planted crop is the existing plant type, held in the tray's contents with a tray-owned flag. `growth()` returns immediately for tray-owned plants, so their recursive outdoor chain never starts. No dirt turf is fabricated.
- **Shared rules come through a small adapter, not a copy:** pull an overridable "advance one stage" step out of `growth()` (the `stageGrowth()` call plus the death-past-`readyStageMax` check). The tray calls it each supplied cycle. Outdoor behaviour must stay byte-for-byte the same; the existing plant lifecycle tests are the regression check.

### 2. Crop whitelist (initial)
`potato, carrot, cabbage, tomato, beans, wheat`. These are food staples with ordinary produce/seed paths and the standard 7-10 ready window.

Excluded: trees and fruit trees, mushrooms (they keep their existing indoor exception), herbs (they return no seeds and medicine owns them), cash and drug crops. Each later addition needs its own review.

### 3. Cycle and units
- **One cycle = 60 seconds of active-server time** that is both powered and supplied. This matches the outdoor `spawn(600)` cadence. Progress is kept as a saved `growth_time_left`; the clock anchor is runtime-only.
- Each cycle debits **1u of `eznutrient` and 2u of `water`** from the reservoir, then advances one stage. Planting at stage 1 to ready at stage 7 is 6 cycles: 6u solution and 12u water per crop.
- The reservoir caps at **60u in total**. It accepts only `water` and `eznutrient`. Any other reagent is refused at transfer time: no dumping, no partial accept.
- **Ready (stage 7) stops processing and debits nothing.** The crop holds until harvest. Unlike outdoor crops, it never passes the ready window and dies. That is the main benefit the tray buys, besides ignoring biome, season and weather.

### 4. Nutrient solution (one registered recipe)
- New `/datum/chemical_reaction/hydroponic_nutrient`: `water` 8 + `potassium` 1 + `nitrogen` 1 -> 10 `eznutrient`.
- It reuses the registered `eznutrient` ID. Its display name should become something period-neutral, such as "hydroponic nutrient solution". This needs review: the debug dispenser lists it.
- One nitrary batch (1 potassium + 1 nitrogen) makes 10u, enough for 1.6 tray crops. Nothing is created from scraps, and there is no self-sustaining loop: a tray's harvest cannot refill its own solution without the nitrary's paid crop units, ash and time.
- `tests/chemical_registration` must cover the new reaction. Add a native test of real mixing in a beaker, with a negative control that removes the reaction.

### 5. Power and failure behaviour
- `powerneeded = 5` (same as the fridge), reserved through the cable `update_power` each cycle.
- **Refused or no power source:** the cycle does nothing. No debit, no growth, timer frozen, and examine says the tray is unpowered.
- **Empty or insufficient reservoir:** same as unpowered. The tray must never debit partially or go negative.
- **The crop does not die from power or supply loss.** Pausing is a real cost without being punitive; this needs review. On disconnect and reconnect, the reservation is released and re-requested through the consumer key, so it is never double-counted.

### 6. Yield and harvest
- Harvest uses the existing tools and `spawn_seeds()`/`spawn_produce()`, with `plant_nutrition` set to 100. That gives 2 seeds plus 1-3 produce, the same as fertilised outdoor soil.
- **Atomic:** set the tray's empty state and retire the plant exactly once, put the outputs on the tray's turf (not in its contents), then leave `processing_objects`. A second harvest of the same plant must do nothing.
- Uprooting a growing crop returns nothing, as it does outdoors.

### 7. Research, era, construction
- New `hydroponics` node in the Agriculture tree. Prerequisites `advanced_agriculture` and `electricity`; era tier 6; bench tier 5; analysis mode.
- The tray's craft cost uses the existing recipe system with reviewed amounts. The proposed starting point, to be checked against the Crafting Atlas once implemented: 4 steel sheets, 2 glass sheets, 1 cable coil.
- Dismantling returns the materials, minus whatever the existing deconstruction rules say. The reservoir's contents spill to the turf, and the crop is destroyed.

### 8. Persistence
- **Saved:** crop type and stage, `growth_time_left`, reservoir reagents (native reagent holder), tray-owned flag.
- **Excluded through `persistence_runtime_var`:** `last_growth_tick`, the processing state, the power reservation.
- `after_load()` re-anchors the clock, rejoins `processing_objects` only if the crop is still growing, and re-links power the way other powered objects do. Oil wells re-link their runtime links after load, but the fridge pattern still needs confirming on the selected source.
- Offline time earns no progress.

### 9. Mining and materials coordination
Steel, glass and saltpeter come from existing routes. This adds no new mineral sources, so it doesn't overlap mining #7.

## Acceptance (from #3050, mapped to tests)
- **Isolated native fixture** (temporary storage, network closed, pinned engine, generated-source negative controls):
  - empty, partial and wrong reservoir inputs;
  - exact 1u+2u debit per cycle and no negative values;
  - no growth while unpowered or supply-starved;
  - disconnect/reconnect reservation idempotence;
  - single processing chain across repeated plant/harvest/remove;
  - atomic one-time harvest with 2 seeds;
  - destructive removal releases registry and power;
  - finite registry count after many trays;
  - save/load at every stage, including ready and unpowered.
- **Regression:** existing plant lifecycle, crop diagnostics, outdoor crop, chemical registration and power suites unchanged.
- **Gameplay capture:** only where tests leave real uncertainty, such as tray rendering and the lamp overlay.

## Open decisions for the reviewer
1. Solution cost (section 3/4): 1.6 crops per nitrary batch. Is that too cheap or too dear next to outdoor farming? Changing the 1u debit is the lever.
2. Crops pause instead of dying when power or supply is lost.
3. Ready crops hold indefinitely in trays.
4. Reuse `eznutrient` with a rename, or add a new reagent ID.
5. Era tier 6 and the craft materials.
6. Whether a powered pump that fills from a water source belongs in stage 1 or comes later. This proposal fills the reservoir by hand only.
