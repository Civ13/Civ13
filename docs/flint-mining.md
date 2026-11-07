# Flint mining and knapping

Flint no longer has to come only from surface rocks. The design follows
Neolithic flint mines such as Grimes Graves, Spiennes and Krzemionki: miners
sank a shaft through chalk, cut galleries along the flint seam, and did it with
red-deer antler picks and bone or wooden shovels.

Source: `code/modules/1713/flint_mining.dm`. Tests: `tests/flint_mining`.

## Getting flint

- Surface rocks are unchanged: grab intent, 5 flints per rock, one returns every
  30 minutes.
- Every mined underground rock wall (and rocky mining floor) rolls for flint
  nodules separately from the ore table, so the rates in
  [mining-drop-balance.md](mining-drop-balance.md) are unchanged.

| Rock | Chance per wall | Nodules | Expected flint per wall |
| --- | ---: | ---: | ---: |
| Ordinary underground rock | 20% | 1-3 | 0.4 |
| Sandy rock, or under a desert | 5% | 1-3 | 0.1 |

Special caves double the nodule count like other drops. The roll runs at every
age. Unsupported galleries still cave in, so flint mines need mine supports.

## Tools with no metal or flint prerequisite

| Tool | Source | Pick/dig speed | Notes |
| --- | --- | ---: | --- |
| Antler pick (new) | 2 per butchered stag, elk stag or reindeer (either sex); none from does, fawns or dik-diks | 0.8 | A pickaxe; durability 10 |
| Wooden spade (recipe added) | 3 wood, Tools menu, Basic Toolmaking (age 0) | 0.4 | Existing item, new sprite |
| Bone shovel, bone and stone pickaxes | Unchanged | 0.6 / 1.0 / 1.5 | Already available at age 0 |

Shaft digging time does not depend on the shovel's speed; mining a wall takes
24 s divided by strength and pick speed.

## Knapping

Hold a hammerstone (an unsharpened flint or a stone block) in your active hand
and use it on a flint that is in your other hand or on an adjacent tile.
Dexterity shortens the work and crafting skill lowers the failure chance. A
failure leaves a flint shard, which still cuts and butchers.

| Product | Time | Base failure |
| --- | ---: | ---: |
| Sharp flake (sharpens the flint) | 4 s | 10% |
| Three flint arrowheads | 6 s | 25% |
| Flint knife | 8 s | 35% |
| Flint spearhead (use on a branch for a flint spear) | 8 s | 30% |

Flint arrowheads make flint arrows and flint bolts, three from one nodule
instead of one from a sharpened flint. Using a flint as a whetstone on a blade
or tool still works as before.

An unsharpened flint used on a bolt no longer deletes the bolt.
