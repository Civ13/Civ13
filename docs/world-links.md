# World links

Every land and ocean of the earth group, and the stretches of map edge that
lead from one to another, are listed in one table:
`tools/world_links/world_links.json`. It is the single source for

- the game: `code/modules/persistence/world_links.dm`, written from the JSON by
  `python3 tools/world_links/build.py` (`--check` exits 1 when it is stale).
  It holds `world_links` (read by `region_edge_links()` in `region_edge.dm`
  through this world's region id) and `continent_layout` (the chart place,
  open-sea coasts and flight level used by `sea_lanes.dm` and
  `aircraft_crossing.dm`);
- the host tools and the launcher, through `tools/world_links` (`load()`
  checks the table and `crossings()` lists each region's edges both ways round).

Region ids are the host's (`earth.json`). A map no longer names its own links or
coasts; a world outside the earth group (a test fixture) can still set
`edge_crossings` and `sea_coasts` on its map metadata, and those win.

## The table

```json
"lands": {"europe": {"chart": [11, 9], "coasts": ["W", "N"], "flight": true}},
"links": [{"kind": "walk", "a": ["europe", "east", 0, 1], "b": ["asia", "west", 0.45, 1]}]
```

- `chart`: the land's place on the world chart, x east and y north, in chart tiles.
- `coasts`: the map edges with open sea along them, best first (ships make landfall there).
- `flight`: the map has a standing open-air level aircraft fly on.
- A link joins a stretch of one region's edge (`[region, side, from, to]`, as
  fractions of the edge counted west to east or south to north) to the facing
  edge of another. Each link is written once; both directions are made from it.
  `kind` is `walk` (dry ground on both ends) or `sail` (open water, ocean regions).

`load()` refuses a link whose ends do not face each other, a stretch outside 0 to
1, overlapping stretches on one edge, and a region not listed under `lands`.
`tests/edge_crossings` checks the DM table is current, that the walked links are
the expected land links with dry ground at both ends, and that every listed
coast faces open sea on its map.

## Changing a link

1. Edit `tools/world_links/world_links.json`.
2. `python3 tools/world_links/build.py`.
3. `python3 -m unittest discover -s tests/edge_crossings`.

Running worlds read the table at compile time, so a change needs a deploy.
