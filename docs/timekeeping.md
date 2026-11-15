# Timekeeping and lighthouses

Code: `code/modules/1713/timekeeping.dm`. Art: `icons/obj/timekeeping.dmi` and
`icons/obj/lighthouse.dmi` from `tests/sprites/create_timekeeping.py`.
Probe: `tests/timekeeping/probe.dm`.

| Piece | Recipe | Research | Use |
| --- | --- | --- | --- |
| Sundial | 3 stone | Stone Masonry | Click or examine: the hour, outdoors in Morning, Midday or Afternoon with clear weather. |
| Water clock | 4 clay | Pottery & Cookware | Fill with water (up to 120 units, one drains a minute); reads to the half hour, day or night. |
| Hourglass | 1 glass | Glassworking | Use in hand: tells you when a minute has passed. |
| Tower clock | 15 iron | Optics & Instruments | Wind by hand (5 s) for two hours of running. Strikes each hour on a bell within two tiles. |
| Clock face | 3 wood | Optics & Instruments | Hung like a sign; shows the time to the half hour while a running tower clock is within 7 tiles. |
| Bell | 8 bronze | Bronze Working | Ring by hand as an alarm (10 s cooldown). Everyone within 60 tiles on the same tower column, more than 7 tiles off, is told the bearing. |
| Lighthouse beacon | 4 iron | Iron Smithing | Feed wood (10 min) or coal/charcoal (20 min), up to 120 min; light with any open flame. At night, people on water within 120 tiles are told its bearing, at most every 5 minutes each. |
| Reflector lamp | 6 bronze | Optics & Instruments | A beacon that reaches 200 tiles. |
| Lantern room glazing | 4 glass | Glassworking | See-through dense pane to wall in a beacon. |

Readings come from `rough_clock()`, built on `clock_time()`. Fuel, water and
winding are saved; tick counters and the beacon's told-list are runtime only.
