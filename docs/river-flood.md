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

The file is `civ13-river-flood 1`, `size W H`, `z Z`, `reaches N`, then one
line per reach (`r id down x y catchment upstream water`: the reach it drains
to or 0, its catchment centre, catchment tiles, tiles upstream including its
own, water tiles), then H rows of two-character reach ids per tile (`00` for
none), then H rows of thresholds in the height alphabet (`.` for none). The
Gaia file is 0.5 MB with 125 reaches.

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
- Placeholder drawing: shallow water over flooded land as images only the
  viewer holds, more opaque when deeper, redrawn when the viewer has moved 4
  tiles or the rivers changed. Nothing is drawn while every reach is at or
  below stage 0.

## Saving

The water held, the snowpack and the high-water mark of every reach are the
map field `river_flood_state`, saved with the durable world metadata (field version 4;
older saves load with rivers at their dry-spell level; saves from before flood
marks load with the marks at the water). A loaded save's water is
taken up on the next tick. The parsed sidecar is never saved.

## Admin tools

Debug verbs: **Flood Map** (reaches by stage, with flow, snow, catchment and a
jump link), **Set River Stage** (the reach you stand in or every reach),
**Start Spring Flood** (a winter's snowpack on every catchment, which melts
outside winter) and **Show Flood Thresholds** (threshold and reach id on the
tiles around you, blue where the water is now).

## Tests

    python3 tests/river_flow/test_flood.py
    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/flood_probe.dm
    python3 tests/durable_map_migration/run.py --byond-bin <dir>
