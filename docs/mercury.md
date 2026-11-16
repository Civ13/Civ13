# Mercury: cinnabar, quicksilver and poisoning

First step of the ore-processing plan Val approved on 2026-11-16 after Fable's
review. Code: `code/modules/1713/mercury.dm`; art: `icons/obj/mercury.dmi` from
`tests/sprites/create_mercury.py`; checks: `tests/mercury/`.

## Cinnabar

`/obj/item/stack/ore/mercury` (cinnabar) is an independent mining roll, like
flint, gems and obsidian, from the Classical age (map ordinal age 1): 1% of
mining actions give 4 lumps, 2% on maps with `cinnabar_rich` (Europe, Asia and
both Americas, the old mercury belts). Special caves double it. It is also a
mountain-seam ore (weight 2, taken from iron's 30). The extraction kit no
longer leaches mercury out of it.

## Getting quicksilver

| Route | Needs | Yield | Fumes |
| --- | --- | --- | --- |
| Open roasting: cinnabar used on a lit fire, furnace or brazier with an open vessel in the other hand | Bronze Working | 2 units a lump, 6 s | 1.5 burden to everyone within 2 tiles (half under open sky), ground pollution 1 |
| Mercury retort (10 iron): charge up to 10 cinnabar, fire with 1 charcoal, coal or wood | Amalgamation | 6 units a lump into its 60-unit receiver | none while the clay seal holds |

Each firing wears the seal by 10; below 30 the retort is cracked: it gives 30%
less, releases 3 burden of fumes and pollutes the ground. One clay restores it.
The mercury flask (2 iron, Ore Dressing) holds 60 units.

## Burden

`/mob/living/human/var/mercury_burden` is one saved number. `Life()` does nothing
else while it is zero. It drains 10% per hour of play.

| Burden | Stage | Effect |
| --- | --- | --- |
| 20 | mild | metallic taste, headaches; the first time, the cause is named |
| 40 | moderate | tremor: dexterity, crafting, medical and weapon skills x0.85 |
| 70 | heavy | x0.7, philosophy x0.8, slow kidney damage, gums and memory |
| 100 | deadly | brain damage 0.2 a second, collapses |

Vapour is an event when a step finishes, not a gas: a fading effect and one
`range(2)` pass. Any mask lets 75% through, a gas mask 10%. Swallowed liquid
mercury adds 0.2 burden a unit. The doctor's handbook names the stage; admin
Check Illnesses lists it when nothing else is wrong.

## Research

Two nodes are registered here: Ore Dressing (era 2, after Resource
Processing; the flask now, washing and stamping machines later) and
Amalgamation (era 3, after Ore Dressing and Apothecary; the retort). Industrial
Milling (era 4, after Amalgamation and Steam Power) arrives with its machines,
since a node that teaches nothing cannot be practised.

## Checks

- `python3 tests/mercury/test_contract.py` (offline suite `mercury`).
- `python3 tests/ecology_spawning/run_linux.py . tests/mercury/probe.dm 300`: native probe of vapour range, masks, open sky, stages, diagnosis, the retort, the flask and cinnabar rates (17 checks).
