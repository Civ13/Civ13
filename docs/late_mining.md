# Late mining

Source: `code/modules/1713/late_mining.dm` (washer hook `can_wash_load` in
`placer.dm`). Tests: `tests/late_mining/test_contract.py`, native probe
`tests/late_mining/probe.dm`. Art: `tests/sprites/create_late_mining.py` ->
`icons/obj/late_mining.dmi`. Both machines are on **Industrial Milling**.

## Hydraulic monitor (15 iron)

Fasten it with a wrench on a tile next to fresh river water and a turning mover
(mill wheel, treadwheel, horse gin, windmill), aim it with **Turn Nozzle** at an
uncovered dirt or sand tile and work it (6 s). The tile becomes
`/turf/floor/gravel/stripped` and drops 6 pay dirt of its district grade at once.
Gravel fails `can_sift_resources()`, so it never gives pay dirt or sifted
resources again. Each strip adds 2 foul load to the river reach beside the
monitor (`river_foul_dump`), or ground pollution off the river.

## Cyanide vat (8 wood)

A `placer_washer` subtype. Pour in water and cyanide, put a zinc sheet in the
box (10 loads), then wash tailings or amalgam tailings in it (5 s a load, 5
water, 1u cyanide, a tenth of the zinc). Each load has a 15% chance of a gold
ore (+0.15 metal per load) and leaves nothing behind. It works only from the
Early Modern age (ordinal 5). **Drain Vat**, or breaking the vat, dumps its
cyanide as river foul load.
