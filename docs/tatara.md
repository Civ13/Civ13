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

## The tatara

Research: **Tatara Smelting** (`tatara_smelting`, Industrial, era 2, needs
Iron Smithing; a trunk metal node, so military nodes may need it). It unlocks the furnace (20 clay),
kera sorting and tamahagane folding, and also opens the steel-faced anvil
(`anvil_steel_face_nodes`), so tatara steel can be forged before
Steelmaking.

`/obj/structure/tatara` is built for one firing:

1. Charge it by turns, up to 30 iron sand and 30 charcoal. Iron sand added
   on top of fresh charcoal counts one charge. Charging stays open for the
   first half of the firing.
2. Light it (at least 3 of each) by hand or with a flame. The firing lasts
   ten minutes (`TATARA_BURN_TIME`) on an `addtimer` loop; `burn_left` is
   saved and `after_load()` resumes it.
3. Bellows beside it blow into it (one pump = 90 s of blast). The share of
   firing ticks under blast sets the kera: sand matched by charcoal / 3,
   times 0.5 with no blast up to 1.0 with full blast, halved again if it
   was charged fewer than 3 times. Zuku is 1 pig iron per 10 matched sand.
4. When the fire dies the furnace is spent. A hammer or pickaxe breaks it
   open on the kera, the pig iron and 5 clay.

On any anvil that works iron (Crafting 1.2): kera sorts into 50%
tamahagane and 30% wrought iron (the rest is slag); every 3 tamahagane fold
into 2 steel sheets. Pig iron keeps its existing steel step.

## Washing for iron sand

The washing channel (`/obj/structure/kanna_channel`, 6 wood, Tatara
Smelting) stands on a tile beside shallow fresh water (`panning_water()`).

- Empty hand: 30 s of washing hillside soil leaves 2 iron sand (4 with
  `iron_sand_rich`). Each tile has 20 loads in `kanna_channel_stock`
  (keyed by coordinates, so rebuilding does not refill it); one load comes
  back every minute.
- Ordinary sand used on the channel, or on a wooden bowl while standing
  beside shallow fresh water (age 1+), washes down 5 to 1 iron sand (5 to 2
  with `iron_sand_rich`), 5 s per batch (`wash_sand()`).
- A hammer takes the channel apart for 3 wood.

## Japanese blades

Research: **Japanese Swordsmithing** (`japanese_swordsmithing`, Military,
era 2, needs Steel Blades and Tatara Smelting). It unlocks the tachi (anvil
row, ages 2-3, steel or iron) and clay hardening.

Clay hardening runs after the anvil forges a steel katana, wakizashi,
tachi, tanto or naginata (`is_japanese_blade()`), when the smith knows the
node, a watered quench tub is fastened beside the anvil and clay is to hand:
a clay lump stack or a plain unfired lump, in either hand or on the anvil's
tile (`is_hardening_clay()`). It takes 1 clay and the tub's water, sets
quality 1.35 (`CLAY_HARDENED_QUALITY`, above the tub's plain 1.2) and
`hamon = TRUE`, which examine shows. Iron blades and other weapons are only
quenched.

Nothing fails silently. A smith with clay to hand is told when the blade is
not steel, when the node is missing (the usual research warning), or when
the tub is missing, loose or dry (`clay_tub_problem()`); a smith who knows
the node and has a tub but no clay is told to hold some.

The anvil's `forge_stack_recipe()` hands each new piece to the
`finish_forged_piece()` hook, which quench_tub.dm extends: `clay_harden()`
first, then the plain quench, whatever the `.dme` include order. The native probe
`tests/tatara/clay_hardening_probe.dm` forges real katanas through it
(`python3 tests/ecology_spawning/run_linux.py . tests/tatara/clay_hardening_probe.dm 600`).
