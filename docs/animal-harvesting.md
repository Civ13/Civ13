# Bounded animal harvesting

## Player interaction

Use a sharp held item on an adjacent dead animal. Harm intent butchers for 30
ticks (normally three seconds); grab intent skins and butchers for 100 ticks
(normally ten seconds). Moving, changing the active hand, incapacitation or losing
the corpse/tool cancels the action. The corpse, actor connection and tool are
checked again after waiting. One corpse accepts one claim; cancellation releases
the claim. Existing mouse sharp-tool behavior uses the same guard.

Skinning selects species pelts, while quick butchering selects leather for
explicitly supported mammals. Both yield the same meat and food byproducts.
The corpse is removed after completion. Humans controlled through simple-animal
NPC types are not given mammalian anatomy by this feature.

## Yields

The existing size categories give a bounded yield `Y`: minuscule 1, tiny 2,
small 3, medium 4, large 5, huge 8. Normal animals emit `Y` real meat portions,
rather than one portion with extra reagent volume. Species exceptions retain
one pig leg, one chicken carcass, poisonous frog meat, crab meat, rotten poisoned
zombie meat, and the mouse human-meat/plague route. Pig-leg/chicken-carcass
processing and poisoned-arrow processing remain on their existing item types.

Supported mammals are cattle, pigs/boars, goats, sheep, deer, bison, camels,
rabbits, monkeys, cats, bears, wolves, foxes, gorillas, panthers, sabertooths,
horses, dogs, mammoths and bats (including their subtypes).

| Mammal product | Count |
| --- | --- |
| Heart, liver, kidneys, lungs, brain, intestines | One of each if `Y >= 3`; otherwise one mixed giblets portion |
| Stomach | Existing cow/pig/goat/sheep processing stomach; other mammals with `Y >= 3` get one food stomach |
| Sinew | One stack containing `min(4, max(1, Y-2))`, only if `Y >= 3` |
| Bone | One stack containing `max(1, Y-2)` |
| Fat | At most two portions, respecting existing `has_fat`, bonus and penalty |
| Quick-butchering leather | One stack containing `max(1, Y-2)` |

Chicken/rooster also yields one giblets portion. Other nonmammals do not gain
mammalian organs, sinew, generic leather or bone. Existing reptile skinning pelts
remain. White-wolf and giant-gorilla special pelts are selected before their base
types. Species pelt counts remain in `harvest_hide()`; no new organ datums or
per-organ processes/timers are registered.

Offal is food, not a transplant organ. Each portion starts with two protein
units, is raw, decays through existing food handling and accepts existing meat
processing. Radiation uses the existing half-corpse-radiation rule. Pig/cow/goat/
sheep stomachs keep their sausage/rennet handling. Balance is bounded output,
not a biological mass-conservation model.

## Binding and crafting

Use sinew in hand to consume one portion and create one ordinary rope portion
named sinew binding cord. Existing rope recipes accept it (including nets,
leashes and bindings, with their existing era gates). Sinew stacks cap at 20.

The existing sharpened-stick plus sharpened-flint assembly now requires one
sinew or rope portion in inventory or on the user's turf. Assembly waits 100
ticks, checks all parts/connection again and consumes one binding, the stick and
the flint head for one flint axe. Competing assembly cannot reuse the parts.
Separate stone/bone stack recipes are unchanged.

## Provenance and verification

Design comparison used Pocket-Stronghold-13 at
[`2bfb1906a9a68f58c5e5da25383f83dd495bf138`](https://github.com/Valgorithms/Pocket-Stronghold-13/tree/2bfb1906a9a68f58c5e5da25383f83dd495bf138):
its [butchering component](https://github.com/Valgorithms/Pocket-Stronghold-13/blob/2bfb1906a9a68f58c5e5da25383f83dd495bf138/code/datums/components/butchering.dm)
separates hide harvesting and species butcher results. The maintainer authorized
adaptation. This Civ13 implementation is written for its existing corpse,
material and food types; no upstream code/assets were imported. The comparison
does not establish an upstream sinew or comprehensive organ system. Upstream's
README retains its /tg-derived licensing notice; existing Civ13 sprite credits
and licenses remain applicable.

See `tests/animal_harvest/README.md` for actual runtime coverage and limits.
The custom saver enumerates `tmp` fields, so `harvesting` and `assembling_axe`
explicitly opt out through `persistence_runtime_var`; completed claims persist.
New products reuse existing surgery/rope DMI states. Preview sheets show actual
sprites and are not gameplay captures. Gameplay capture is unnecessary when
source review, these production tests and required CI adequately establish the
change under the standing capture rule. No live server restart/deployment or
full-server memory test is part of this change.
