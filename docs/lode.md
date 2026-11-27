# Lode ore and ore dressing

Source: `code/modules/1713/lode.dm`, `code/modules/1713/stone_crushing.dm`.
Tests: `tests/lode/test_contract.py`, native probe `tests/lode/probe.dm`.
Art: `tests/sprites/create_lode.py` -> `icons/obj/lode.dmi`.

## Raw ore

From the Classical age, every mined rock rolls for lode ore on its own (like
cinnabar): 4% gives 4 lumps of **gold-bearing quartz**, otherwise 3% gives 4
lumps of **silver-bearing ore**. Regrowing mountain seams carry both (weight 3
each; iron dropped from 28 to 22).

## Crushing

One lump becomes one load of crushed ore (`crushed quartz` or `crushed silver
ore`) in:

- the hand stone crusher (Resource Processing),
- the **water stamp mill** (Ore Dressing, 12 wood): the stamp mill driven by a
  turning mover within reach instead of cable power, one lump every 6 s,
- the powered stamp mill (Electricity), one lump every 4 s.

Stamp mill hoppers hold up to 50 of stone blocks and lode ore mixed; each stack
is stamped in turn. Lode ore retains this washing route. By contrast, quarry rubble gives one unit of its named ore per chunk, accounted plain rock only yields sand, and unknown-origin blocks use Gaia trace recovery.

## Washing

One load of crushed ore holds `LODE_METAL` = 0.5 lumps of metal. Each load
washed is a chance of one metal ore equal to 0.5 x recovery, and always gives
one load of tailings.

| Method | Recovery | Research |
| --- | --- | --- |
| Pan (wooden bowl beside fresh water) | 20% | none |
| Buddle (6 wood, station water, 40 water) | 35% | Ore Dressing |

With the buddle, gold per mined rock about matches mining free gold ore.
Amalgamation (PR 4) and the industrial drum line (PR 5) raise recovery further.
Tailings are kept for the cyanide vat (PR 7).
