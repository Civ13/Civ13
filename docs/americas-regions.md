# The Americas regions

Two large Nomads regions, drawn after the Americas: a northern continent and a
southern continent, each its own world, joined by a trail at the isthmus. They
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
| Land | about 386,000 tiles | about 485,000 tiles |
| Walkable ground | about 311,000 tiles | about 416,000 tiles |

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

Each map is a single surface level. Mountains are rock to mine at ground level
(`/turf/floor/dirt/underground` and its icy and sandy kinds, with unbreakable
cores), so neither map has or needs an underground level. Trees, bushes and
other wild plants are seeded at round start from each area's climate, and
animals by the ecology spawner; the map files hold only ground, water, rock
and a few hundred markers (groves, puddles in dry country, oil seeps, wolf
dens, volcanoes).

Hills come from `maps/heights/nomads_americas_{north,south}.txt` and river
currents from the matching `.flow.txt` files (see [terrain-height.md](terrain-height.md)).

## The isthmus trail

The north map's land runs off its south edge at the isthmus and the south map's
land runs off its north edge at the same place. Four trail posts stand across
each end (`/obj/structure/region_gate/trail_marker/authored/americas_south` on
the north map, `.../americas_north` on the south map). They are ordinary trail
markers that are approved by the map itself, so the trail works as soon as both
regions run under the ids above. A traveller who walks into a post arrives at
the posts on the other map.

These posts are not a general arrival point: travellers from any other region
still arrive at a trail or gate that leads back to where they came from, or
at the region's ordinary arrival spots (`accepts_strangers()` in
`code/modules/persistence/region_travel.dm`).

As with every trail, a region that is stopped on the host is closed; a region
that is asleep or cold is woken by a traveller.

## New players

Both types set `new_player_start_z = 1`, so a new nomad starts on a random safe
outdoor tile of the land (`code/game/objects/map_metadata/nomads/nomads_start.dm`).
The 18 `JoinLateCiv` marks on each map are the fallback arrival spots for
travellers. A random start can fall on one of the islands.

## Regenerating

The generator needs numpy and Pillow; the test suite needs neither.

```sh
python3 -I -B tests/americas_maps/build.py                    # rewrite both maps
python3 -I -B tests/americas_maps/build.py --only north --preview north.png
for n in north south; do
  python3 scripts/terrain_heights.py design --map maps/nomads/nomads_americas_$n.dmm --z 1 \
    --spec maps/heights/nomads_americas_$n.design.json --out maps/heights/nomads_americas_$n.txt
  python3 scripts/river_flow.py --map maps/nomads/nomads_americas_$n.dmm --z 1 \
    --heights maps/heights/nomads_americas_$n.txt --out maps/heights/nomads_americas_$n.flow.txt
done
python3 tests/americas_maps/test_americas_maps.py
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

- **No upper floors or dug caves yet.** A new level allocates the whole plane,
  and the admission limits (`NEW_Z_BUILDING_MEASURED_CELLS`, `NEW_Z_MEASURED_CELLS`,
  see [new-z-budget.md](new-z-budget.md)) are sized for Gaia. Neither map sets
  `building_levels` or `dig_down_underground`, so roofs give shelter but no
  second storey. Raising those limits for a plane this large needs its own
  measurement.
- The time-of-day lighting pass takes about three times as long as Gaia's.
- The wildlife caps (`ecology_wildlife_cap` 1000 north, 1200 south) and wild
  plant caps (550 and 650) scale with the land, short of in proportion.

## Adding the regions to a host

These are host steps; merging the code starts nothing.

1. Update the server checkout to a build that contains these maps and compile.
2. Add the two entries from `scripts/shard-group/americas.example.json` to the
   `regions` list of the group config, with ports that are free on the host.
   Keep the ids `northamerica` and `southamerica`: the isthmus trail on each
   map leads to the other id.
3. Run `setup --region northamerica` and `setup --region southamerica`, then
   `start` for each, as for any other region
   ([scripts/shard-group](../scripts/shard-group/README.md)). The first boot of
   each takes several minutes.
4. To make the north the land new characters start in, set the group's
   mainland to `northamerica` (see [land-stages.md](land-stages.md)). The south
   then opens through the land stages.
5. Check: both regions show as running, a new character starts on open ground
   in the north, and walking into the isthmus posts at the south edge of the
   north map arrives at the posts at the north edge of the south map.
