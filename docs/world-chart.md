# The world chart

The world chart is the map boat expeditions will sail
([plan](https://claude.ai/artifact/61LciJHKi6eKEUsYMfFgwE)). It is kept by
the group coordinator next to the land stages ([land stages](land-stages.md)).
Ships sail it ([voyages](ship-voyage.md)): a course for a land opens it in an
expedition slot, built from the tile's template by the land generator
([expedition lands](expedition-lands.md), [slots](expedition-slots.md)).

## Tiles

The chart is 48 x 32 tiles (`CHART_WIDTH`, `CHART_HEIGHT` in
`tools/transfer_storage/world_chart.py`), drawn from a random seed the
coordinator keeps. Each tile is ocean or land. A land tile's biome follows
latitude (warm in the middle rows, cold at the top and bottom) with some
climate noise, so neighbours agree: ice sheet, tundra, boreal forest,
temperate forest, grassland, desert, savanna, rainforest or swamp. The border
of the chart is ocean.

The mainland is **pinned** to a tile: on a new chart, the coordinator's
`--mainland` region sits in the middle. The tiles round a pinned land are
always ocean, so a ship can always set out from it. More mainland regions (the
America regions) are pinned with `--chart-pin REGION=X,Y`.

## Templates

A land tile stores nothing until a ship first sees it. Then the coordinator
rolls its **template** once and keeps it:

| Field | Meaning |
| --- | --- |
| `biome` | from the tile |
| `land_type` | coastal plain, river delta, highlands, archipelago, fjord coast, marsh, volcanic isle or plateau, weighted by biome |
| `size`, `width`, `height` | the size class and the real tiles a side, within about 15% of the class |
| `coast` | the sides that face open water (N, S, E, W); an inland tile has none and cannot be reached by sea |
| `features` | rivers, lakes, ridges and caves for the map generator |
| `resources` | ore richness and kinds, a rare find, soil fertility and game |
| `seed` | chart seed, tile and reroll count: the same template always gives the same land |

Only an admin reroll (or a later scripted event) gives a tile a new template,
and only while no world has been built from it.

### Sizes

| Size | Tiles a side | Ore | Fertility | Rolled now |
| --- | --- | --- | --- | --- |
| Tiny | 200 | rich | poor | yes |
| Small | 300 | good | thin | yes |
| Medium | 500 x 350 (Gaia) | fair | fair | no |
| Large | 500 | thin | good | no |
| Massive | 600 | poor | rich | no |

Smaller lands have richer, more concentrated ore and more often a rare find;
larger lands feed a settlement better. Only the sizes in `SIZES_ENABLED` are
rolled; the others wait for a memory measurement on the host.

### Tile states

`CHARTED` (template kept), then later steps add `LANDED` (a world was built),
`SETTLED`, `CLAIMED` and `LOST` (abandoned for good).

## Who sees what

Each owner has its own chart: the tiles its ships have seen. Owners are
`faction:NAME`, `crew:CKEY` (factionless crews) and `admin`. Admins see the
whole chart.

## Courses

A ship that sets course for a land asks the coordinator for a world there
(`WorldChart.set_course`). The land must be charted, on the ship's owner's
chart, have a coast and not be lost. A tile already `LANDED` sends her to its
slot; otherwise a free slot is chosen and the host asked to open it
([slots](expedition-slots.md#lands-opened-for-ships)). With no free slot the
course is refused ("every harbour master is busy").

| Course state | Meaning |
| --- | --- |
| `ASSIGNED` | the land has a slot; the host is opening it |
| `READY` | the host started the slot on that land |
| `REFUSED` | with a reason; the ship turns back |

Courses are kept for 6 hours. Each snapshot sent to the worlds carries them
(`courses`, by voyage id) and what each owner has seen (`seen`: a hex bitmap,
bit `y * width + x`), so a world shows a crew its own chart. A ship's `scout`
request charts the tiles round a tile for its owner, as an admin `reveal` does.

## Where it lives

- Coordinator database: `chart_tile` (templates and states), `chart_seen`
  (each owner's tiles), `chart_pin`, `chart_meta` (seed and revision),
  `chart_course` (ships' courses).
- Each home pass sends the whole chart to any agent whose copy is older
  (`/homes`, key `chart`); a world reads it from its agent (`/chart`).
- Requests from a world (`/chart/request`: admin ops `reroll` and `reveal`,
  ships' `scout` and `course`) wait in its agent and are decided on the
  coordinator's next pass.

## Admin tools

In game: **Admin > World Chart** shows the chart, every charted land's
template and lets an admin reroll a charted land, or chart the tiles round
the mainland for testing.

On the host:

```sh
python tools/transfer_storage/coordinator.py --db <coordinator.sqlite> --group <group> --mainland <id> --chart
python tools/transfer_storage/coordinator.py ... --chart faction:rome --chart-json   # one owner's chart as JSON
python tools/transfer_storage/coordinator.py ... --chart-reveal admin=24,16           # chart round a tile
python tools/transfer_storage/coordinator.py ... --chart-reroll 20,10                 # new template for a charted land
python tools/transfer_storage/coordinator.py ... --chart-pin americas_north=20,16     # pin a mainland region
```

Tests: `python3 -I -B tests/transfer_storage/run.py` (`test_world_chart.py`).
