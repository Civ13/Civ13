# Animal fat as light fuel

Code: `code/modules/1713/light_fuel.dm` (burning and refuelling),
`code/modules/1713/fat_lights.dm` (grease horn, stone fat lamp) and
`harvest_fat_pieces()` in `code/modules/1713/animal_harvest.dm`.

## One measure for fat

A piece of animal fat holds 10 units of lard. Pressed into an open container it
becomes those 10 units; boiled on a fire they render to 5 units of fat oil.
Every burning light lists both in `refuel_reagents` as seconds of light per
unit, with oil worth twice lard, so a piece gives the same light raw or
rendered:

| Light | One piece of fat | Holds |
| --- | --- | --- |
| Torch | 10 minutes | 20 minutes |
| Tiki torch | 10 minutes | 30 minutes |
| Lantern | 20 minutes | 60 minutes (bronze lamp 90) |
| Stone fat lamp | 30 minutes | 60 minutes |

A light takes only the lard it has room for. A piece of fat used in part keeps
the rest (`light_fuel_fat_used` deletes it once the lard is gone) and its
examine text says how much is left. Wrapping a tool handle takes the whole
piece, or 5 units of oil, or 10 of lard.

For scale: the dark half of a day is 40 real minutes, a lard candle (half a
piece and a rope) burns about 33 minutes.

## Grease horn

`/obj/item/weapon/reagent_containers/glass/grease_horn`: 2 bone, Basic Tools.
A 30-unit belt or pocket container, so three raw pieces as lard or six pieces'
worth of rendered oil. Reagents do not rot, which is the point of rendering.

## Stone fat lamp

`/obj/item/flashlight/lantern/fat_lamp`: 1 stone, Primitive Construction. As
bright as a candle (`CANDLE_LUM`), carried in the hand, an open flame when lit.

## Fat by species

`harvest_fat_pieces(size)` replaces the old cap of two pieces: wolf and fox 1,
sheep, goat and deer 2, cattle, pigs and elk 3, bison, buffalo, camel and bears
4, polar bears and ground sloths 5, mammoths 8. Young and small animals keep
the size formula (a calf gives none). Hunting skill scales the count as before.

## Tests

- `python3 tests/fat_lights/test_source.py` (offline suite `fat_lights`)
- `python3 tests/ecology_spawning/run_linux.py . tests/fat_lights/probe.dm`
- `python3 tests/sprites/create_fat_lights.py --check`
