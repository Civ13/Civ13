# Zombie city generator

The zombie city is made at round start, not drawn in a map editor. The compiled
map (`maps/zombie_city/zombie_city.dmm`, built by `tests/zombie_city/build_base.py`)
is a blank 200 x 200 plain of dirt inside an indestructible rim with the
`/obj/map_metadata/nomads/zombie_city` object on it. `zombie_city_generate(seed,
ground_z, upper_z)` in `code/modules/zombie_city/generator.dm` fills it with
streets, districts, lots, building shells, loot and the markers the city host
reads. The host world (`world.dm`, the horde in `horde.dm` and the loot tables in
`loot.dm`) decides what happens in the city; the generator only builds it.
`interiors.dm` holds the room, furniture, loot spot and mess pass.

The map is never in a vote list. The city host selects it by name and calls the
generator from its round-start hook when `map.zombie_city` is set.

## Determinism

Everything the generator decides comes from `/datum/zombie_city_rng` (`rng.dm`),
a 24-bit linear congruential generator kept exact inside BYOND's single-precision
numbers. The generator never calls `rand()`, `prob()` or `pick()`, so yields
between ticks and other processes cannot change the city a seed produces. The
probe below checks that a repeated seed gives an identical grid and manifest.
Loot contents are rolled by `loot.dm` with the world's own random numbers, so
the items differ between runs even when the layout does not.

## Pipeline

1. Centre and districts. The city centre sits near the middle of the map with
   some jitter. Distance from it (Chebyshev, as a share of the half-size) gives
   downtown (under 0.28), commercial (under 0.6) and residential; a band of
   about 36 tiles along one chosen edge is industrial.
2. Streets. A three-lane ring road runs one tile inside the rim. Cuts along
   each axis every 18 to 28 tiles make avenues (three lanes with a centre line,
   40 percent) and streets (two lanes). In residential districts 30 percent of
   street segments between two avenues are dropped, merging two blocks into one
   longer block. Every street starts and ends on another road, so the network
   is connected by construction.
3. Blocks. The land between roads is flood-filled into blocks; the cells
   touching a road become sidewalk. Each block gets a zombie density tag from
   its district: residential sparse or normal, industrial sparse or normal,
   commercial normal or dense, downtown dense or infested.
4. Special lots. The largest suitable blocks become the hospital (downtown,
   infested), the police station (commercial or downtown, dense), the big-box
   hardware store and the garage. Each fills its whole block interior.
5. Lots and buildings. Ordinary blocks are cut into two rows of lots facing
   opposite streets (one row when the block is shallow). Lot widths depend on
   the district; the building footprint is inset one tile on every side so a
   yard separates it from the sidewalk and from its neighbours. Leftover space
   becomes a park, a parking lot with wrecks or a vacant lot with junk. Kinds
   by district: houses in suburbs; groceries, pharmacies, hardware shops,
   apartments and big-box stores in commercial blocks; offices, apartments and
   shops downtown; warehouses and workshops on the industrial edge.
6. Shells. Walls are cement, or concrete blocks on industrial lots and
   workshops. Each building gets a door on its street side (a double steel
   store door for anything but houses, apartments and offices), windows every
   three tiles on that side and every four tiles on the sides of houses,
   apartments and offices, and a back door on tier 3 lots.
7. Interiors (`interiors.dm`). Houses, apartments, offices, the hospital and
   the police station get an entrance hall two rows deep, a two-cell corridor
   running back from the front door and rooms three to five rows deep stacked
   along both sides of it, each with a wooden privacy door onto the corridor
   (wooden interior walls in homes, the shell's material elsewhere). A shell
   too narrow for side rooms stacks its rooms straight back from the hall with
   a door through each dividing wall; one too shallow stays a single room.
   Room kinds cycle per building: living, kitchen, bedroom, bathroom for
   homes; offices, meeting rooms and storage; wards, surgery, a pharmacy and
   storage in the hospital; offices, the armory, cells and a locker room in
   the police station. Shops keep the row inside the door free, put a counter
   and register on the next row away from the door, run store-shelf aisles
   with free ends behind that, and wall off a stockroom across the back when
   there is depth for it. Warehouses get crate and pallet rows with free ends
   and a small office in a back corner; workshops and the garage are open
   floors with benches, tanks and barrels along the walls and a wreck or two
   in the garage. Furniture only sits on cells along a room's walls, never
   within two steps of a door, so a room's free cells always connect to its
   door. Beds, chairs, toilets, sinks, drips and junk do not block movement.
8. Mess. By block density (sparse, normal, dense, infested) 10, 25, 40 or 60
   percent of windows are broken (frame only, passable) and 1, 3, 6 or 12
   percent of interior floor cells get a blood decal, half as many junk.
9. Loot. Each building holds `1 + tier` loot spots (hospital six, police four)
   on free floor cells with at least two free neighbours, out of the doorways,
   taking the police armory first, then rooms worth searching (bedrooms,
   kitchens, storage, stockrooms, the pharmacy, wards, surgery, offices, sales
   floors) on cells beside something to search, then anywhere else in a room.
   Each spot gets a `/obj/effect/zombie_city/loot` marker with the building's
   loot table and tier and `zombie_city_roll_loot` fills it. Tables: house,
   apartment and office residential; grocery and big-box grocery; pharmacy;
   hardware shop, warehouse and big-box hardware; workshop and garage garage;
   hospital medical, with pharmacy in its pharmacy room and on every second
   spot; police police; the checkpoint cache military. Tiers: houses 1,
   ordinary shops 2, special lots 3; downtown buildings have a 40 percent chance
   of one extra tier.
10. Insertion and evacuation. Four to six insertion points sit on the ring
    road's centre lane at a third and two thirds along each edge (jittered by two
    tiles). Three or four evacuation points sit at the ring road's corners. The
    first evacuation point is the checkpoint: Jersey barriers close the outer
    lanes beside it and a military loot cache sits on the road. Insertion points
    are at least 60 tiles apart and no evacuation point is within 40 tiles of an
    insertion point, measured as BYOND's `get_dist` does.
11. Dressing. Four percent of avenue and ring-road outer-lane cells get a car,
    van or truck wreck or a dumpster, never within six tiles of an insertion or
    evacuation point and never on a centre line.
12. Check and commit. A breadth-first walk from the first insertion point over
    passable cells must reach every insertion point, evacuation point, door and
    loot spot, or the plan is discarded and the next seed tried (three attempts).
    Only a valid plan touches the world: turfs row by row with `TICK_CHECK`,
    then one lighting overlay refresh for the level, then doors, windows and
    props, then markers, loot rolls, `zombie_horde_add_block` for every block
    and `zombie_city_add_insertion` / `zombie_city_add_evacuation` for every
    insertion and evacuation point.

## Output

`zombie_city_generate` returns a `/datum/zombie_city_layout` and stores it in
the global `zombie_city_layout`; a second call in the same world returns that
layout. It holds the seed, size, blocks (bounds, district, density), buildings
(bounds, kind, tier, table, doors, rooms with their kind and bounds, loot
markers), the road list, the insertion
and evacuation turfs and markers, the special lots and generation counts and
timings. `manifest()` and `to_json()` give the same data as a list or JSON, and
`ascii_rows` is a text picture of the grid (`#` rim, `=` road, `-` centre line,
`.` sidewalk, `,` grass, `_` paving, `W` wall, `w` window, `o` broken window,
`D` door, `f` floor, `L` loot, `E` insertion, `V` evacuation, `x` passable
props and decals, `X` blocking props and furniture). A plan that fails the
reachability check logs the unreachable cells and a grid excerpt around the
first one.

Markers (`markers.dm`) are invisible, anchored, never saved:
`/obj/effect/zombie_city/loot` (table, tier, building id),
`/obj/effect/zombie_city/entry` (side, ordinal) and
`/obj/effect/zombie_city/exit` (side, ordinal, checkpoint).

## Cost

Placing a wall normally refreshes every lighting overlay within 21 tiles. With
several thousand walls that took over two minutes, so `/turf/wall/New` skips
that refresh while the global `wall_bulk_placement` is set and the generator
refreshes the level's overlays once afterwards. A 200 x 200 city then generates
in about 6 s on the cloud runner (about 4 s of turf replacement, 1 s of lighting,
under 2 s of objects, markers and loot).

## Evidence

`tests/zombie_city/native_probe.py` compiles the game with the base map selected
and `native_probe.dm` appended, runs DreamDaemon once per seed and writes each
run's manifest, grid and result; `tests/zombie_city/check.py` then verifies
determinism, reachability, counts, spacing and cost, and renders a PNG preview
per seed. `tests/zombie_city/test_zombie_city.py` is the offline CI suite. See
[tests/zombie_city/README.md](../tests/zombie_city/README.md).

Not verified by any of this: what a client sees, zombie behaviour inside the
shells, and save or load of a generated city (the city world is never saved).

## Later phases

- Upper floors on z2 for two-storey lots, with stairs and paired roofs through
  the building-levels system.
