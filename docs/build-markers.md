# Builders' pegs (build markers)

Val (2026-11-23): a house plan can be pegged out on the ground, "and the same
for rails after". The pegs are their own small system so that any plan can use
them: `code/game/objects/build_markers.dm`, defines in
`code/__defines/build_markers.dm`, art in `icons/obj/build_markers.dmi`.

## What a peg is

`/obj/effect/build_marker` stands on a tile with string round it and a tag
showing what to build there. It builds nothing and stops nothing:

- it is not solid and hides nothing, and lies on the floor under whatever is
  built on the tile;
- a plain click on it goes to its tile, so building, digging and fighting on a
  pegged tile work as if it were not there; shift-click examines it and
  alt-click pulls it (one peg, or every peg of its plan);
- it goes by itself when everything it asks for stands on its tile
  (`look()`, run for every peg each `BUILD_MARKER_SWEEP`, and whenever one is
  examined), unless a note is pinned to it;
- it goes when the floor under it does.

A peg holds only text, so it saves and loads as it is (`map_storage_saved_vars`):

| field | meaning |
| --- | --- |
| `wants` | `kind=label;kind=label`: what is still to build, the first shown on the tag |
| `set_id` | shared by the pegs of one marking-out |
| `set_name` | the plan's name, shown on examine |
| `note` | a note pinned to the tile |

At most `BUILD_MARKER_WORLD_MAX` pegs stand in a world.

## Using it from a plan

```
build_marker_place(turf, list("wall=timber wall", "roof=thatch roof"), set_id, set_name, note)
build_markers_of(set_id)        // the pegs still standing
build_markers_left(set_id)      // label = how many are still asked for
build_markers_pull(set_id, z)   // pull them, on one level when z is given
```

`build_marker_place()` leaves out whatever already stands on the tile and
replaces a peg of the same set, so marking the same ground twice is safe. It
returns null when nothing is left to ask for.

## Adding a kind of work (rails next)

1. A row in `build_marker_kinds()`: `"rail" = list("name" = "track", "state" = "rail")`.
   The `rail` tag is already drawn in the icon file.
2. A line in `build_marker_built()` saying when the work stands on a tile, for
   track `locate(/obj/structure/rails) in T` (finished track only: unfinished
   sleepers are `/obj/structure/rail_bed`).
3. The planner calls `build_marker_place()` for each tile of its plan, as
   `house_plan_peg_out()` does for a house.

## Tests

`tests/house_plans/probe.dm` pegs a two-storey house out in the real game,
builds it as its pegs ask and checks each peg's tag and that every peg goes;
`tests/house_plans/test_sources.py` checks the tables, the art and the
includes.

## Not done

- No peg has been seen in a BYOND client, and the click passing through to the
  tile is untested there.
- Pegs cost nothing but the time to lay them.
