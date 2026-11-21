# Mechanical power

`code/modules/1713/mechanical_power.dm`, sprites
`icons/obj/mechanical_power.dmi` (drawn by
`tests/sprites/create_mechanical_power.py`), suite `tests/mechanical_power`.

## The drive

A prime mover (`/obj/structure/workshop_machine/mover`) drives the fastened
workshop machines and hoists within one tile of it, and through transmission
parts (below) the machines beside those parts. There is no network object, no
process and no list of movers: a machine calls `driven_time(base)` when it
starts a step, which asks `mechanical_drive_factor(src)`. That walks
`mechanical_drive_load(src)` from what stands around the machine at that moment
(bounded at 64 movers and parts) and returns
`1 - (1 - best) * min(1, strength / draw)`: the best share among the turning
movers joined to it, closing on hand time when the machines on that drive draw
more than the movers' summed strength. Movers update their own icon when asked
or examined.

Strength (`current_capacity()`): treadwheel 1, horse gin 2, mill wheel 3 (4 on
a mill race), windmill 1/2/3 in light/moderate/strong wind. Draw
(`/obj/structure/var/drive_draw`, set in `transmission.dm`): 1 for the
potter's wheel, mason's saw, cement mixer, shear legs and cranes, wire bench,
drill press, hand pump and hydraulic monitor; 2 for the trip hammer, rolling
mill, stone crusher, water stamp mill and blast furnace. A caller that draws
nothing itself (a lift turf) counts as 1.

## Transmission

`code/modules/1713/transmission.dm`, sprites `icons/obj/transmission.dmi`
(drawn by `tests/sprites/create_transmission.py`). Parts join when they stand
within one tile of each other, diagonals included.

| Part | Cost | Research | What it does |
| --- | --- | --- | --- |
| Wooden line shaft | 4 wood, bearing | Watermills | carries drive; a run with any wooden length turns at most 8 lengths |
| Shaft clutch | 5 wood, gear, bearing | Watermills | a length that carries only while thrown in; by hand or as a cord actuator (`mechanisms.dm`) |
| Gear box | 8 wood, 2 gears, shaft | Watermills | also joins the gear box directly above or below |
| Iron line shaft | 3 iron, bearing | Machined Tools | an all-iron run turns up to 16 lengths |
| Rope drive wheel | 4 iron, bearing, 2 rope | Machined Tools | rope on it ties it to a free wheel within 7 tiles on the level; drive passes between them |

## Hopper machines

`code/modules/1713/hopper_machines.dm`, sprites `icons/obj/hopper_machines.dmi`
(drawn by `tests/sprites/create_hopper_machines.py`). A hopper machine
(`/obj/structure/workshop_machine/hopper`, draw 2) holds up to 20 feed as
saved counts (`hopper`, kind -> count) and joins `processing_objects` while it
has feed. It asks the drive only when a step is due (`next_step`): a step takes
`60 s * share * 2` (a minute at half hand time), and an undriven or blocked
machine looks again after a minute. It stops at 20 products on its tile.
Taking it apart gives the feed back.

| Machine | Cost | Research | Feed | Step |
| --- | --- | --- | --- | --- |
| Millstones | 12 stone, gear, shaft | Watermills | wheat, oats, barley, rice (single items or from a sack) | 2 grain to flour or rice |
| Sash saw | 10 wood, gear, shaft, 2 iron | Watermills | plain log stacks | 1 log to 2 planks and a bark |

## Counterweight drum, cam drum and steam engine

`code/modules/1713/contraptions.dm`, sprites `icons/obj/contraptions.dmi`
(drawn by `tests/sprites/create_contraptions.py`).

| Part | Cost | Research | Share / strength | Notes |
| --- | --- | --- | --- | --- |
| Counterweight drum (mover) | 10 wood, gear, shaft, 2 rope | Watermills | 0.6 / 1 | crank (help intent, 10 s) stores 5 minutes of fall, up to 15; other intents or a cord brake and release it (`set_released`); the fall is worked out from `released_at` when asked |
| Cam drum (`/obj/structure/mechanism`) | 6 wood, gear, shaft | Watermills | draw 1 | click to set running; on the object loop, pulls its next cord every `20 s * share` while driven, rechecks every 10 s otherwise |
| Stationary steam engine (mover) | 16 iron, gear, shaft, 2 bearings | Steam Power | 0.35 / 6 | fuel in minutes (`steam_hammer_fuel_rates`, up to 60), burned lazily by `burn()` when asked |

A run that is too long binds: only the movers right beside the machine still
drive it, and the parts' examine says why.

Driven today: potter's wheel, mason's saw, cement mixer, shear legs and the
treadwheel crane. A step never takes less than half a second.

| Mover | Cost | Research | Turns when | Step time |
| --- | --- | --- | --- | --- |
| Treadwheel | 12 wood, shaft, 2 bearings | Stone Masonry | a standing, unrestrained person is on its tile | 65% |
| Horse gin | 10 wood, gear, shaft, bearing | Resource Processing | a living horse or head of cattle is within one tile | 50% |
| Mill wheel | 14 wood, gear, shaft, 2 bearings | Watermills | a tile within one of it has a river current (not still water or ice) | 40% |
| Windmill | 16 wood, gear, shaft, 2 bearings | Watermills | it stands in an outside area and `map.windspeedvar` is at least 1 | 70% light, 50% moderate, 40% strong or gale |

The parts are the standard `/obj/item/machine_part` items in any material,
paid as whole items through `config/craft_needs.json`. They are consumed by
the recipe; movers keep no part slots or wear (the alternate-materials work
owns that design).

Movers are workshop machines: wrench to fasten, hammer on harm intent to
dismantle, and too heavy for a ladder. The treadwheel is not dense so that a
person can stand in it.

## Trip hammer

`/obj/structure/workshop_machine/trip_hammer`: 10 wood plus 6 iron and a
shaft, Watermills. It does nothing by hand. `/obj/structure/anvil` asks
`forge_time(base)` at both forging waits in `blacksmithing.dm`: when a
fastened trip hammer within one tile has a turning prime mover next to it
(`striking()`), the job takes half the time, never less than a second. The
hammer plays its striking loop once when a job starts. Costs, recipes and
research checks at the anvil are unchanged.

## Rolling mill

`code/modules/1713/rolling_mill.dm`: 16 iron plus 2 gear sets, 2 shafts and
2 bearings, Railways and Steam Locomotion. It works only while fastened next
to a turning prime mover (`rolling()`), and the wait goes through
`driven_time()`, so a faster mover rolls faster. Stock used on it is rolled
into products that already exist (`rolling_mill_products`), for someone who
may craft that product:

| Stock | Product | By hand |
| --- | --- | --- |
| 1 iron | 2 pairs of rails, 5 s | 1 pair, 5 s |
| 1 steel | 3 pairs of rails, 5 s | - |
| 10 steel | 1 hull armour plate, 20 s | 15 steel |

It keeps rolling until the stack runs out or the worker steps away; metal is
taken only after each wait succeeds. Suite `tests/rolling_mill`.

## Machine shop

`code/modules/1713/machine_shop.dm` adds three more machines that stand next
to an anvil. `forge_time(base, category)` asks every fastened
`/obj/structure/workshop_machine` within one tile for `forge_factor(category)`
and takes the best machine of each `forge_role`; the shares multiply, and no
job takes less than a second. Each machine used plays its working loop once
(`forge_used()`). Nothing ticks.

| Machine | Role | Built from | Research | Works when | Share left |
| --- | --- | --- | --- | --- | --- |
| Trip hammer | hammer | 10 wood, 6 iron, shaft | Watermills | a prime mover turns next to it | 0.5 |
| Steam hammer | hammer | 16 iron, shaft, spring | Steam Power | it has fuel; one job burns one | 0.35 |
| Drill press | fitting | 10 iron, gear set, shaft, drive belt | Machined Tools | a prime mover turns next to it | 0.6 for guns, gun parts and machine parts |
| Hydraulic press | fitting | 14 iron, shaft, 2 bearings | Factories | always (hand pumped) | 0.6 for helmets, armour and shields |

Steam hammer fuel is counted in jobs (`steam_hammer_fuel_rates`): coal 4,
charcoal 3, wood, planks or bamboo 1 a unit, up to 60. The drill press list is
`drill_press_categories`; the press matches `hydraulic_press_words` against
the anvil recipe category. A milling machine is not built: the engine lathe
already cuts every precise part.

## Wire drawing bench

`code/modules/1713/wire_bench.dm`: 8 wood plus 4 iron and a shaft,
Electricity. Copper, iron, aluminium, silver or gold used on the fastened
bench is drawn into the standard coil for that metal (`wire_bench_coils`,
coil types owned by `materials/wire_materials.dm`): one unit makes a 25 m
coil in 2.5 seconds, where the hand recipe makes 10 m in 3.5. The wait goes
through `driven_time()`, so a prime mover next to the bench speeds it. Each
unit is taken only after its own wait succeeds.
