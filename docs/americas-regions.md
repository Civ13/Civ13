# The Americas regions

Two large Nomads regions, drawn after the Americas: a northern continent and a
southern continent, each its own world, joined at the isthmus: players walk over the shared map edge. They
are meant as the main starting lands. This page covers the design, how to
regenerate the maps, what was measured and how to add the regions to a host.
Nothing here starts or changes a live server.

## The maps

| | North | South |
| --- | --- | --- |
| Map | `maps/nomads/nomads_americas_north.dmm` | `maps/nomads/nomads_americas_south.dmm` |
| Metadata | `/obj/map_metadata/nomads/americas_north` | `/obj/map_metadata/nomads/americas_south` |
| Region id | `northamerica` | `southamerica` |
| Size | 1132 x 920, one level | 848 x 1224, one level |
| Walkable ground | about 302,000 tiles | about 397,000 tiles |
| Fresh water | about 31,000 tiles | about 44,000 tiles |

Gaia, for comparison, has about 100,000 tiles of land on a 500 x 350 surface.

Both maps are original and are written by a script from hand-placed outlines,
mountain chains, rivers, lakes and climate centres
(`tests/americas_maps/continents.py`). The outlines follow the real continents
loosely; nothing is copied from another map.

- **North**: tundra and sea ice in the far north, a wide belt of taiga, the
  western mountain chains with passes through them, dry plains and a desert in
  the south-west, temperate forest and the great lakes in the east, a long river
  system draining the middle, jungle down the narrowing land to the isthmus and
  islands in the warm sea.
- **South**: jungle along the great river basin, a mountain chain down the whole
  west coast with a coastal desert and a high cold plateau, savanna and dry
  scrub in the middle, temperate grassland in the south and a cold cape with
  ice at the bottom.

Dry savanna grass and desert sand cannot be ploughed, so the rivers and lakes of
both dry lands carry a strip of plain grass and dirt: farming there starts on
the banks, within a crop's reach of the water
([outdoor-map-inventory.md](outdoor-map-inventory.md)).

Each map is a single surface level. Mountains are rock to mine at ground level
(`/turf/floor/dirt/underground` and its icy and sandy kinds, with unbreakable
cores), so neither map has or needs an underground level. Mined-out mountain
floor keeps giving stone and regrowing ore seams ([mountain-seams.md](mountain-seams.md)). Trees, bushes and
other wild plants are seeded at round start from each area's climate, and
animals by the ecology spawner; the map files hold only ground, water, rock
and a few hundred markers (groves, puddles in dry country, oil seeps, wolf
dens, volcanoes).

## Relief, rivers and floods

The generator builds an elevation field (distance inland, rolling noise and
the hand-placed mountain chains), fills its hollows and lets every tile drain
to the sea. The hand-drawn rivers and lakes are kept; tributaries are added
where enough ground drains through one tile, and ponds where a hollow fills.
The same field gives three files beside each map in `maps/heights/`:

- `nomads_americas_{north,south}.txt` - terrain heights in half levels
  (water is level 0, banks climb away from it, summits reach level 15), made by
  `tools/procedural_maps/terrain_files.py` like every generated land.
- `.flow.txt` - river currents, flowing downhill (`scripts/river_flow.py`).
- `.flood.txt` - river reaches, their flood thresholds and the hollows that
  fill ([river-flood.md](river-flood.md)). North has 485 reaches and 126
  hollows, south 712 and 282.

The test suite rebuilds the current and flood files from the committed map and
heights and fails when they differ, so the three never drift apart.

## Walking between the two lands

The north map's land runs off its south edge at the isthmus and the south map's
land runs off its north edge at the same place, a neck 14 tiles wide on both.
Nothing stands there: no trail post and no gate. Each map names its neighbour
(`edge_crossings` on the map metadata), and
`code/modules/persistence/region_edge.dm` does the rest:

- A player who walks onto the border row of the neck (or wades just beside it)
  is asked once whether to travel on. Saying no leaves them alone for 30
  seconds.
- On "Travel" they leave as an ordinary region traveller, with what they wear
  and carry and the same rules about what can travel
  (`code/modules/persistence/region_travel.dm`). Wounds go with them; unlike a
  trail, the walk does not ask for full health.
- Worn and held tools and weapons keep their material, quality and wear, a bag
  keeps what it holds (one level: a bag inside a bag has to come out), and
  whole arrows, bolts and cartridges travel one by one
  (`code/modules/persistence/region_travel_gear.dm`). Anything that still
  cannot travel is named in the refusal, with the bag it sits in.
- They come out on the facing edge of the other land, as far along the neck as
  they were, three tiles in and facing inland.
- A rider takes the mount along. A rideable animal that carries nothing goes
  as a record of its kind, name and health, and stands beside its rider on the
  far side (the rider gets back on). If the rider is turned back, the animal
  comes back with them.
- One animal led by hand (pulled) crosses the same way, as long as it is not
  wild, carries nothing and nobody rides it. It arrives as a new animal of its kind with its
  name and health; anything else about it (milk, wool, age) starts fresh.
- A hand cart or a travois pulled by hand crosses with what is shut inside it
  (up to 60 things, by the same rules as what the traveller carries). The
  refusal names anything in it that cannot cross. A cart hitched to an animal
  or a carriage has to be unhitched and pulled by hand.
- A driver or anyone dragging anything else is told to go on foot.
- A pedal bicycle or running bike is wheeled over: its rider gets off at the
  edge when asked, and it arrives beside them with its frame material and
  condition. The pedal airship does not cross.
  **Carriages and motor vehicles do not cross yet.**

Both regions must run in the same group under the ids above. A neighbour that
is asleep is woken by the first walker; one that is stopped on the host is
closed and the admins are told someone is waiting.

Travellers from any other region arrive at a trail that leads back to where
they came from, or at the region's ordinary arrival spots.

## New players

Both types set `new_player_start_z = 1`, so a new nomad starts on a random safe
outdoor tile of the land (`code/game/objects/map_metadata/nomads/nomads_start.dm`).
The 18 `JoinLateCiv` marks on each map are the fallback arrival spots for
travellers. A random start can fall on one of the islands.

## Regenerating

The generator needs numpy and Pillow; the test suite needs neither.

```sh
python3 -I -B tests/americas_maps/build.py                    # rewrite both maps and their height, current and flood files
python3 -I -B tests/americas_maps/build.py --only north --preview north.png
python3 tests/americas_maps/test_americas_maps.py              # checks file digests in tests/americas_maps/sidecars.json (about 6 s)
AMERICAS_MAPS_REBUILD=1 python3 tests/americas_maps/test_americas_maps.py   # also rebuilds the current and flood files and compares (about 45 s)
```

The generator is deterministic. Regenerating a map under a world that already
has a save moves coasts, rivers and rock through whatever players built, so
treat a regenerated map as a new world.

## What was measured

Measured 2026-11-14 on BYOND 516.1688 (Linux DreamDaemon, cloud container) with
the whole game compiled in, Persistence mode, no players. Each run boots a
fresh world, waits seven minutes for seeding and wildlife, changes the time of
day twice, saves the world, then boots again from that save. The memory limit
is `PERSISTENCE_MEMORY_LIMIT_MB` (3072).

| Map | Cells | Fresh world | Peak after save | Peak after reload | Save | Time-of-day change |
| --- | --- | --- | --- | --- | --- | --- |
| Gaia 500 x 350 x 2 | 350,000 | 558 MB | 624 MB | 744 MB | 30 s | 31 s |
| North 800 x 650 | 520,000 | 611 MB | 663 MB | not run | 36 s | 46 s |
| South 600 x 866 | 519,600 | 635 MB | 722 MB | not run | 54 s | 46 s |
| North 960 x 780 | 748,800 | 803 MB | 865 MB | 1085 MB | 53 s | 66 s |
| North 1132 x 920 | 1,041,440 | 1037 MB | 1128 MB | 1432 MB | 75 s | 92 s |
| South 848 x 1224 | 1,037,952 | 1087 MB | 1257 MB | 1652 MB | 104 s | 92 s |
| North 1132 x 920, reworked relief and floods (2026-11-15) | 1,041,440 | 1037 MB | 1095 MB | 1401 MB | 72 s | 92 s |
| The same with the standing open-air level (2 x 1,041,440 cells) | 2,082,880 | 1043 MB | 1098 MB | 1526 MB | 85 s | 92 s |
| South 848 x 1224, reworked, with the standing open-air level | 2,075,904 | 1128 MB | 1235 MB | 1729 MB | 108 s | 92 s |

The standing open-air level costs about 5 MB while empty, 13 s more per save
and about 125 MB and 50 s more on a reload. The reworked south map, measured with it, reloads at 1729 MB.

Memory grows a little under 1 KB per map cell plus what stands on it (the
south's jungle seeds about 67,000 wild plants against the north's 29,000).
The shipped size keeps the reload peak of an empty world at about half the
limit. A map may not grow past 1,050,000 cells without a new measurement
(`MEASURED_CELLS` in the test suite). Idle CPU with no players was about 2% of
one core at every size.

The same runs showed that start-up time grew much faster than the map: the turf
registry was an associative list keyed by turf, and BYOND inserts sequential
references into such a list in quadratic time (one million inserts took 310 s
in isolation). `code/game/turfs/turf_registry.dm` keeps the same membership as
one bit per cell; the 1132 x 920 map then reached the end of map loading in 107
s of CPU instead of 408 s, with 56 MB less memory. Every map boots faster for
it.

## Limits

- **One open-air level, no more.** Both maps keep one standing open-air level
  above the surface (`building_levels = 1`, `building_level_standing`), so
  aircraft fly and a roof carries one upper floor. The admission for it is its
  own measured bound (`NEW_Z_STANDING_MEASURED_CELLS`, see
  [new-z-budget.md](new-z-budget.md)); a second level above it, and a dug cave
  level (`dig_down_underground`), are still refused on a plane this large.
- The time-of-day lighting pass takes about three times as long as Gaia's.
- The wildlife caps (`ecology_wildlife_cap` 1000 north, 1200 south) and wild
  plant caps (550 and 650) scale with the land, short of in proportion.

## Adding the regions to a host

These are host steps; merging the code starts nothing.

1. Update the server checkout to a build that contains these maps and compile.
2. Add the two entries from `scripts/shard-group/americas.example.json` to the
   `regions` list of the group config, with ports that are free on the host.
   Keep the ids `northamerica` and `southamerica`: each map's isthmus edge
   leads to the other id.
3. Run `setup --region northamerica` and `setup --region southamerica`, then
   `start` for each, as for any other region
   ([scripts/shard-group](../scripts/shard-group/README.md)). The first boot of
   each takes several minutes.
4. To make the north the land new characters start in, set the group's
   mainland to `northamerica` (see [land-stages.md](land-stages.md)). The south
   then opens through the land stages.
5. Start the regions one at a time and wait for each to reach its lobby.
6. Check: both regions show as running, a new character starts on open ground
   in the north, and walking onto the south edge of the north map at the
   isthmus (about x 863 to 876, y 1) asks to travel and arrives three tiles
   inside the north edge of the south map (about x 42 to 55).
