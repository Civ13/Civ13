# Flint mining and knapping

Flint no longer has to come only from surface rocks. The design follows
Neolithic flint mines such as Grimes Graves, Spiennes and Krzemionki: miners
sank a shaft through chalk, cut galleries along the flint seam, and did it with
red-deer antler picks and bone or wooden shovels.

Source: `code/modules/1713/flint_mining.dm`. Tests: `tests/flint_mining` (`run.py --byond-bin` adds the native probe).

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

## Fire striker

A steel fire striker (1 steel, Tools menu, Iron Tools) works like a lighter for
candles, pipes and cigarettes, and it needs no lighter fluid. Hold a flint in your other hand and use the
striker: 70% of strikes throw sparks, which stay usable for 5 seconds. Each
successful strike has a 3% chance to use up the flint. Campfires and torches
still light by hand.

## Gunflint wear

A flintlock's flint lasts 25-40 shots. After that, half of all trigger pulls
misfire: the hammer falls, the gun uncocks and the ball stays loaded. Use a
sharpened flint on the gun (3 s) to fit a fresh one. Examining a flintlock up
close shows whether its flint is worn. Guns from crates and newly assembled
guns start with a fresh flint.
