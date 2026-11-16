# Tamahagane and the tatara

Japanese iron-sand steel, built from the plan Val approved on 2026-11-16.
Code: `code/modules/1713/tatara.dm`; art: `icons/obj/tatara.dmi` from
`tests/sprites/create_tatara.py`; checks: `tests/tatara/`.

## Iron sand

`/obj/item/stack/ore/iron_sand` (satetsu) is gathered, never mined, from the
Classical age (map ordinal age 1):

| Route | Where | Yield |
| --- | --- | --- |
| Pan river sediment (wooden bowl) | Dirt or sand beside shallow fresh water | 3 per two-minute pan |
| Sift soil (hand or sieve) | Beach sand only | 2 per sift |

Lands with `iron_sand_rich` on their map metadata (Asia) give 2 more per
pan or sift. `deposit_small_resource()` caps one deposit at 5 units.

An ordinary bloomery smelts iron sand at 2 sand per sponge iron
(`IRON_SAND_PER_SPONGE`); an odd grain waits for the next smelt and Empty
returns it. The blast furnace refuses iron sand. Bloomery automation ports
still take only iron ore.
