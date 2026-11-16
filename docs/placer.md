# Placer mining: pay dirt, the sluice box and the rocker

Step 2 of the ore-processing plan (Fable-reviewed, approved 2026-11-16). Code:
`code/modules/1713/placer.dm`; art: `icons/obj/placer.dmi` from
`tests/sprites/create_placer.py`; checks: `tests/placer/`.

## Pay dirt

The **Dig pay dirt** verb (Crafting tab), with a shovel in hand on an uncovered
dirt or sand bank right beside shallow fresh water (`panning_water()`), takes
10 s (shortened by strength) and gives one load. Each bank tile gives 3 loads,
then one comes back every 400 s; the stock is runtime only, like mountain seams.

The grade comes from a 16-tile district hash (`pay_dirt_grade`), so it is the
same for everyone and nothing is saved: 25% of districts are gold-bearing
(`pay_dirt/rich`), 40% tin-bearing (`pay_dirt/tin`), 35% barren. All three look
and read the same; panning a load tells you which it is.

## Washing

| Method | Needs | Time a load | Gold-bearing load | Gold per person-hour with digging |
| --- | --- | --- | --- | --- |
| Wooden bowl beside shallow fresh water | nothing | 20 s | gold 15%, names the grade | about 18 |
| Sluice box (6 wood) | Bronze Working; running water beside it, or 5 water a load | 6 s | gold 27%, silver 5%, tin 20% | about 60 (20 on tin ground) |
| Rocker (5 wood, movable) | Ore Dressing; 5 water a load from its 40-unit tank | 4.5 s | gold 32%, silver 6% | about 80 |

Tin-bearing loads give tin 60% and gold 9% (sluice). Barren loads give sand
40%, iron sand 50% from the Classical age and gold 1%. Free hand panning
(about 30 gold ore an hour on any bank) is unchanged.

Up to 10 units of mercury poured into a sluice's riffles raise its gold and
silver chances by a quarter; every load washes 0.05 units away into the ground
(pollution 0.15). River-bed mercury arrives with amalgamation.
