# River stages and flood depth

Rivers on maps with terrain heights rise and fall with rain, snowmelt and the
season. This page covers the water model in `code/modules/1713/river_flood.dm`
and its sidecar tool `scripts/river_flood.py`. The effects players feel are
in `code/modules/1713/flood_effects.dm`; defences and Fable's water art come
later (the flooding plan).

## The sidecar

A map whose height file is `maps/heights/example.txt` may have
`maps/heights/example.flood.txt`, made from the map and its heights:

    python3 scripts/river_flood.py --map maps/nomads/nomads_gaia.dmm --z 2 --heights maps/heights/nomads_gaia.txt --out maps/heights/nomads_gaia.flood.txt
    python3 scripts/river_flood.py --map maps/nomads/nomads_europe.dmm --z 1 --heights maps/heights/nomads_europe.txt --out maps/heights/nomads_europe.flood.txt
    python3 scripts/river_flood.py --map maps/nomads/nomads_jungle.dmm --z 2 --heights maps/heights/nomads_jungle.txt --out maps/heights/nomads_jungle.flood.txt
    python3 scripts/river_flood.py --map maps/nomads/nomads_desert.dmm --z 2 --heights maps/heights/nomads_desert.txt --out maps/heights/nomads_desert.flood.txt
    python3 scripts/river_flood.py --map maps/nomads/nomads_asia.dmm --z 1 --heights maps/heights/nomads_asia.txt --out maps/heights/nomads_asia.flood.txt

Rerun it after editing a map's water or heights; `tests/river_flow/test_flood.py`
fails when a committed sidecar no longer matches. Each run takes under a second.

- **Reaches.** Fresh water (rivers, lakes, swamps; not the sea) is cut into
  reaches: one connected body of water inside one 32 x 32 cell. Bodies under 6
  tiles are left to the land around them. Each reach drains to the next reach
  toward the sea or the map edge; a closed lake drains into its largest reach.
  Reaches are numbered upstream first, so a reach always comes before the one it
  drains to. At most 4,095 per map.
- **Thresholds.** A priority flood from all water gives every land tile the reach
  it floods from and its threshold: the lowest stage, in levels above the water,
  that reaches it over the ground. A tile behind a ridge needs the ridge's
  height. Land the sea reaches first belongs to no reach and never floods from
  a river.
- **Hollows.** Closed basins on land: connected tiles below the same spill
  level, at least 3 tiles and half a level deep (at most 4,095, the largest by
  the water they hold). Each lists its spill and bottom levels, its tiles per
  half level and its catchment, the land whose water runs into it along the
  priority flood's drainage tree.

The file is `civ13-river-flood 2` (version 1 files, without hollows, still load), `size W H`, `z Z`, `reaches N`, then one
line per reach (`r id down x y catchment upstream water`: the reach it drains
to or 0, its catchment centre, catchment tiles, tiles upstream including its
own, water tiles), then H rows of two-character reach ids per tile (`00` for
none), then H rows of thresholds in the height alphabet (`.` for none), then
`hollows K`, one line per hollow (`h id spill bottom x y area catchment
counts`, levels in the height alphabet, tile counts per half level from the
bottom joined with commas) and `hollow_rows R` with only the rows that hold a
hollow (`row-from-north ids`). The Gaia file is 0.8 MB with 125 reaches and
217 hollows.

## Stages

Once a minute (`river_flood_step()`, from the weather process) each reach, in
order:

1. gains springwater from its catchment (`RIVER_FLOOD_BASEFLOW` per tile,
   scaled by season: spring 1.2, summer 0.6, winter 0.8, wet season 1.3, dry
   season 0.6, halved under a heat system);
2. gains rain where a storm is raining on its catchment centre
   (`RIVER_FLOOD_RAIN_YIELD` per tile per point of intensity), or stores snow
   where it is snowing;
3. melts part of its snowpack outside winter (6% a minute in spring, 12% later);
4. takes what the reaches upstream released, and releases 35% of what it holds
   to the reach it drains to.

A reach's stage compares what it releases with the flow of an ordinary year
(`RIVER_FLOOD_MEAN_FLOW` per tile upstream): 1.2 levels per doubling for the
largest rivers, less for small catchments (a quarter of that for a few
hundred tiles), from -1.5 (low water) to 3. The cap keeps a river off the
plains: on Gaia a stage of 2 to 3 reaches about 15% of the land.

`flood_depth_at(turf)` is the stage of the tile's reach above its threshold,
0 when dry. `river_stage_at(turf)` is the stage of the tile's reach. Both are a
table lookup; nothing loops over tiles.

## Hollows

`code/modules/1713/flood_hollows.dm`. Each hollow holds water in tile-levels
(saved after the reaches in `river_flood_state`). Each minute, after the
reaches, rain at its centre adds 0.003 per catchment tile per point of
intensity, counting at most 8 catchment tiles per hollow tile; 0.5% of the
water soaks away (1% in a dry season or under a heat system). The water stands
level, worked out from the tile counts per half level, and never rises past
the spill. Depth on a hollow tile is that level less its graded height. A river
that rises over a tile's threshold now stands on the tile's own ground, so a
basin behind a ridge or a wall fills to the river's level once the water tops
it. The view scan also draws hollow tiles.

## Effects

Every effect asks `flood_depth_at()` from code that already runs for that tile
or person; nothing loops over the map.

| Depth (levels) | Band | What happens |
| --- | --- | --- |
| under 0.25 | ankle | +2 step delay (the sub-deck wading rule, footwear helps), wet feet |
| 0.25 to 0.5 | knee | +4 step delay, the body drawn wading |
| 0.5 to 1 | waist | +6 step delay |
| over 1 | deep | swimming: the swimmer tires and drowns as in deep water; a boat, lifejacket or diving suit keeps them up |

- Check Movement names river floodwater and its depth.
- Fires on flooded ground go out, and campfires there can't be lit.
- Rivers at stage 1 or more carry things two tiles a pulse; at stage -1 or
  less, half the pulses move nothing. Waterwheels make 12 power scaled by
  `1 + stage / 3` (0.5 to 2).
- Ground a player has raised (shovel and rammer grading) stays dry until the
  stage tops its new height.
- Crops under knee-deep water drown after 6 growth minutes (3 at waist depth
  or deeper); rice doesn't. Floodwater waters a crop fully, and a crop that
  comes through a flood alive leaves 40 soil nutrition of silt.
- A well under floodwater is fouled (its `dirty` flag, cleaned with soap).
- Waist-deep floodwater soaks clothes like wading in a river.
- Flood marks: each reach keeps a high-water mark (`peak`, saved with the
  water) that fades 0.005 levels a minute. Examining a tree, a built wall or
  the ground within 2 tiles tells how high the last floods stood there, or how
  deep the water is now.
- Things on the floor, on tiles a player can see (once per river tick per
  tile): flour sacks are ruined and gunpowder pouches emptied; at knee depth
  or more, small items float one tile toward deeper water, and into the river's
  current. A table keeps things dry below waist depth.
- Drawing: `icons/effects/floodwater.dmi` (Fable, `tests/sprites/create_floodwater.py`)
  as images only the viewer holds: `flood1`-`flood4` by band on each flooded
  tile, `flood_edge<band>` on each dry neighbour (dir from the water to the dry
  tile) and `flood_step<band>` on a shallower flooded neighbour. The ripple
  shares the river water's 12-frame loop. Redrawn when the viewer has moved 4
  tiles or the rivers changed; nothing is drawn while every reach is at or
  below stage 0.

## Ground changes

`code/modules/1713/flood_ground.dm`. Grading a tile (shovel and rammer) or
building or breaking a finished dirt, sandbag or stone half-wall marks the
16 x 16 cell it is in. On the next river tick (up to 6 per tick) a priority
flood over that cell and 16 tiles around it, seeded from the river and from the
window's edge at the edge tiles' current thresholds, works out each tile's
threshold from today's ground: its graded height plus the crest of any
half-wall on it (1 level, concrete 1.5, palisades and unfinished walls 0).
Tiles that differ from the flood file go into the sparse `overrides` table
(turf to threshold), which `flood_depth_at()` and the flood marks read first.
A wall along a bank keeps the land behind it dry until the stage tops its
crest; a gap lets the water in. Overrides are derived and never saved: graded
tiles and walls mark their cells again as they load.

## Sewers (S1)

`code/modules/1713/sewers.dm`, art `icons/obj/sewers.dmi` (Fable,
`tests/sprites/create_sewers.py`). Only on persistence maps; elsewhere plumbing
still carries waste away by itself. Drain pieces on adjacent tiles form a
network: an open drain ditch (shovel, no research) or a covered stone drain
(2 stone, Sanitation). A drain beside open water is an outfall and shows the
`outfall` overlay; a cesspit (shovel) holds 40 flushes and is dug out with a
shovel into compost (one per 10). A plumbed toilet with a piece on or next to
its tile sends waste down the network: the walk (at most 600 pieces, only on a
flush) stops at the first outfall or settles in the first cesspit with room. A
toilet with nowhere to send waste backs up onto the floor. Wells and puddles
count sewage near them as fecal waste: an outfall within 4 tiles or an open
ditch within 2 that carried waste in the last 30 minutes, or a cesspit within 2
holding any. Covered drains foul nothing. Cesspit fill is saved; the
recently-carried time is not.

## Sewers (S2)

Also in `sewers.dm`. A drain on a hollow tile is an inlet: each river tick,
after the hollows fill, it takes up to its rate of hollow water (ditch 1,
stone drain 2, brick sewer 5 tile-levels a minute) while it stands in water,
and sends it to the outfall it reaches (cached per drain until any drain,
clog or gate changes). An outfall takes twice its own rate from all its
inlets together; past that the sewer runs full for two minutes and toilets on
it back up. When river floodwater stands over an outfall, an ungated outfall
backflows: each inlet raises its hollow by its rate while the hollow is lower
than the river there, and toilets on it surge back. A flap gate (3 wood,
Sanitation) on the outfall tile shuts against the river: nothing flows either
way and flushed waste is held. Each load of waste may silt up one random drain
it passed (ditch 2%, stone 0.5%, brick 0.1%); inlets silt at a fifth of that
per minute of draining. A clogged drain cuts the network until it is dug
clear with a shovel. Brick sewers are 3 stone bricks (Imperial Architecture).
Nothing new is saved but `clogged`.

## Sewers (S3)

Also in `sewers.dm`. A pumping station stands on an outfall tile. It always
carries a non-return valve, so like a flap gate it shuts the outfall against
the river even when stopped. Running, it lifts water and waste out over a
river in flood: over a flood the outfall takes only the pump's rate from its
inlets, and with the river low the pump's rate adds to the outfall's own.
Flushed waste goes out over the flood too and fouls the water as usual. The
steam sewer pump (formerly steam pumping engine; 12 iron, Steam Power) lifts
6 tile-levels a minute and burns one minute of fuel per river tick while it is on (coal 30 minutes,
charcoal 20, a log, plank or bamboo 10, up to 240), and stops when the fire
burns out. The electric sewage pump (8 steel, Utilities) lifts 10 and draws
20 power from a cable laid under it or an outlet. Pumps tick at the end of
`drain_hollows()`, after the water they move, even on a map with no hollows.

A settling tank (6 stone bricks, Germ Theory) on an outfall tile catches each
load of waste that goes out of it as sludge, so the outfall does not foul
wells, until it holds 60; a shovel digs it out into compost (one per 10).
Rainwater does not fill it. Open ditches upstream still foul.

A septic tank (6 concrete, Public Health) is a sealed cesspit: it holds 120,
fouls nothing, and digests one load per 30 minutes of real time, counted from
`world.realtime` whenever it is used or examined, so nothing ticks and the
server being down counts too. Saved: pump `on` and `fuel`, `sludge`, septic
`waste` and `digested_at`.

## Defences (Stone and Classical)

`flood_defences.dm`. Nothing here ticks.

- **Stilt platform** (4 wood, Primitive Construction) and **stone plinth**
  (4 stone, Stone Masonry) set the unsaved turf var `flood_raise` (2 and 1),
  rebuilt as platforms are built, loaded or destroyed. `flood_depth_at()`
  takes it off the depth on that tile, so everything that reads depth
  (wading, soaking, items, fires, drawing) sees the raised floor.
- **Sluice gate** (6 wood, Irrigation): a dense timber gate that, shut, adds a
  crest of 1.5 in `flood_tile_ground()` like a half-wall. Drawn up by hand
  (3 seconds), it is passable and adds nothing, letting floodwater through a
  levee onto fields for their silt. Opening, shutting, building and breaking
  mark the flood window like a half-wall.
- **Shaduf** (4 wood, Basic Agriculture) and **Archimedes screw** (8 wood,
  Irrigation) on a hollow tile beside ground outside that hollow lift 0.5
  and 1.5 tile-levels of its water per 3-second working, repeated until the
  worker stops or the hollow is dry.
- **River gauge** (2 wood, Basic Agriculture) within 2 tiles of river water
  reads the reach's stage against the bank (the tile's effective threshold)
  and the reach's high-water mark on examine.

- **Cistern** (10 stone, Paved Infrastructure): a 2000-unit water tank
  drawn from with a bucket. On the object scheduler like a rain barrel, each
  minute of rain at its tile puts in 10 from the open sky (none when roofed)
  plus 3 per roofed tile within 2 tiles, counted at most every 5 minutes.
  No catch-up after lag or downtime.

Saved: the gate's `open` and the cistern's water.

## Cellars and seepage

`flood_cellars.dm`. The level under the flood level (`multiz_level_below()`,
so Gaia's level 1 or a dug cave) is the cellar level, cached as
`cellar_z()`. `flood_depth_at()` on a cellar tile asks `seep_depth_at()`:

- Seepage: when the reach's stage comes within 2 levels of the bank (the
  effective threshold of the surface tile above), groundwater stands
  0.25 x the gap deep, at most 0.45 (knee). Nothing under water tiles or in
  solid rock.
- Pouring: when the river is over the bank above and that tile is a way down
  (open air, a ladder, stairs or a tunnel mouth: `/obj/structure/multiz`),
  the tile below takes the surface depth, at most 1.
- Bailing: an open container used on a wet cellar tile (not on harm intent)
  takes up water and keeps that tile and the 8 around it dry for 10 minutes
  (`cellar_dry`, unsaved).
- Pumps: any structure in `cellar_pumps` keeps tiles within its
  `cellar_reach` dry while its `cellar_pumping()` is TRUE.
- Tunnels: floodwater pouring down a tunnel mouth
  (`/obj/structure/multiz/ladder/ww2/tunneltop`, registered in `tunnel_mouths`)
  runs along the open tunnel below. From the tile under each pouring mouth,
  the water reaches 3 more tiles a minute, up to 30 and at most 400 tiles,
  roof-high (1.5) except for a waist-deep edge (0.8). Dense tiles, packed earth
  included, stop it (`tunnel_spread`). When the mouth stops pouring, because
  the river fell or the hole was filled, the reach shrinks a tile a minute.
  This is worked out at most once a minute, on demand, and is unsaved
  (`tunnel_flood_update`). Pumps keep it back, but bailing does not.
- Drowning below ground: roof-high tunnel water has no air (`flood_airless`).
  Instead of swimming, `handle_drowning()` spends a held breath
  (`tunnel_hold_breath`: the swimmer's `swim_breath` plus 10, so about 20 s untrained and 70 s at full swimming skill) and then takes 10 oxygen
  damage a life tick, until the person reaches shallower water or a ladder.
- Filling in: four dirt piles close a tunnel mouth, which stops pouring, and a
  shovel with a dirt pile packs an open tunnel tile into dense packed earth,
  which stops seepage there for good (docs/underground-excavation.md).

Cellar water is drawn like floodwater when a player is on the cellar level.
Nothing ticks.

## Pumps

`flood_pumps.dm`. Cellar pumps are `cellar_pumps` entries on the cellar level;
`running` is cached once a minute at the end of `drain_hollows()` (and when
switched) so depth lookups stay cheap.

- **Hand bilge and cellar pump** (formerly lever pump; 6 iron, Workshops),
  reach 3: each 3-second stroke keeps its reach dry 30 seconds more, banking
  at most 5 minutes. Unsaved.
- **Steam bilge and mine pump** (formerly steam mine pump; 12 iron, Steam
  Power), reach 7: started by hand, burns a minute of fuel per river tick
  (same fuel table as the steam sewer pump).
- **Sump pump** (4 steel, Utilities), reach 3, 15 power from a cable or an
  outlet. Its float switch runs it only while `seep_depth_at(T, TRUE)` (the
  depth as if nothing pumped) is above 0. On mains it charges its battery
  5 minutes a minute up to 60; without power it runs a minute of battery a
  minute.
- **Windmill pump** (12 wood, Watermills): a water lift on a hollow's edge
  that each river tick lifts 0.4 x `weather_wind_at()` (0 to 4) tile-levels
  unless its brake is set.

Saved: steam `on`/`fuel`, sump `on`/`battery`, windmill `braked`.

## Saving

The water held, the snowpack and the high-water mark of every reach are the
map field `river_flood_state`, saved with the durable world metadata (field version 4;
older saves load with rivers at their dry-spell level; saves from before flood
marks load with the marks at the water). A loaded save's water is
taken up on the next tick. The parsed sidecar is never saved. After the
hollows comes one foul load per reach (docs/river-foul.md); a state without it
loads with clean rivers.

## Admin tools

Debug verbs: **Flood Map** (reaches by stage, with flow, snow, catchment and a
jump link), **Set River Stage** (the reach you stand in or every reach),
**Start Spring Flood** (a winter's snowpack on every catchment, which melts
outside winter) and **Show Flood Thresholds** (threshold and reach id on the
tiles around you, blue where the water is now).

## Tests

    python3 tests/river_flow/test_flood.py
    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_probe.dm
    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_hollow_probe.dm
    python3 tests/sewers/test_sewers.py
    python3 tests/ecology_spawning/run_linux.py . tests/sewers/probe.dm
    python3 tests/ecology_spawning/run_linux.py . tests/sewers/s2_probe.dm
    python3 tests/ecology_spawning/run_linux.py . tests/sewers/s3_probe.dm
    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/defences_probe.dm
    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/cellar_probe.dm
    python3 tests/durable_map_migration/run.py --byond-bin <dir>
