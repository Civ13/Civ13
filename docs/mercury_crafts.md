# Mercury crafts

Source: `code/modules/1713/mercury_crafts.dm` (mirror hooks `item_type` and
`structure_type` in `code/game/objects/structures/mirror.dm`; barometer
readings in `weather_forecast.dm`). Tests: `tests/mercury_crafts/test_contract.py`,
native probe `tests/mercury_crafts/probe.dm`. Art: `tests/sprites/create_mercury_crafts.py`
-> `icons/obj/mercury_crafts.dmi` and `icons/mob/mercury_crafts.dmi`.

| Craft | How | Quicksilver | Burden |
| --- | --- | --- | --- |
| Fire gilding (Bronze Working) | gold amalgam on a lit fire, brazier or furnace, the copper, bronze, brass or silver piece in the other hand, 8 s | 1 lump of gold amalgam | 6 to everyone within 2 tiles, 3 outdoors |
| Wall mirror | craft an unsilvered mirror (3 glass), use 1 tin sheet on it, then pour 5u | 5u | 1 |
| Barometer | crafted empty (8 iron), pour 5u into it | 5u | none |
| Thermometer | crafted empty (1 glass, Optics), pour 2u; reads `get_temp()` | 2u | none |
| Carroted felt (Haberdashery) | pour from an open vessel onto a pelt, 5 s: 1 pelt -> 2 felt | 2u | 0.5 |
| Felt hats | felt in hand, pick tricorne, bicorne or top hat, 2 felt each; rain_resist 30 | - | - |
| Dimercaprol | glycerol + bromine + sodium sulphide 1:1:1 -> 2, only from the Modern Medicine age (ordinal 7) | - | -6 per unit metabolised (-30 a 5u dose) |

Gilding reuses the electroplating coat (`plating = "gold"`, gold tint, +30 value),
so a gilt piece cannot be plated again and vice versa. Already-placed mirrors
and barometers count as silvered and filled.
