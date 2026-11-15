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
| `resources` | ore richness and kinds, a rare find, soil fertility and game; the land world places them ([expedition lands](expedition-lands.md#ore-rare-finds-and-game)) |
| `seed` | chart seed, tile and reroll count: the same template always gives the same land |

Only an admin reroll (or a later scripted event) gives a tile a new template,
and only while no world has been built from it.

### Sizes

| Size | Tiles a side | Ore | Fertility | Rolled now |
| --- | --- | --- | --- | --- |
| Tiny | 200 | rich | poor | yes |
| Small | 300 | good | thin | yes |
| Medium | 500 x 350 (Gaia) | fair | fair | yes |
| Large | 500 | thin | good | yes |
| Massive | 600 | poor | rich | yes |

Smaller lands have richer, more concentrated ore and more often a rare find;
larger lands feed a settlement better. Only the sizes in `SIZES_ENABLED` are
rolled, and all five are: the largest massive land was measured in a cloud
container ([expedition lands](expedition-lands.md#one-level-and-its-measurement)).

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
([slots](expedition-slots.md#lands-opened-for-ships)). A settled or claimed
land is on every owner's chart.

### Opening new lands

No admin decides who may sail. A course for a land with no world yet is
refused while:

- its owner, or the account at the tiller (`by`), still has a land it opened
  standing undecided (`LANDED`): "your crew still has the land at X,Y undecided";
- either opened a new land less than 3 hours ago (`OPEN_COOLDOWN_SECONDS`);
  the reason gives the minutes left;
- no slot is free. Then the land that has stood empty longest is parked (below)
  and the course is refused with "a harbour is being cleared"; the crew set
  out again once the host has freed the slot. With nothing to park: "every
  harbour master is busy".

`chart_opened` keeps who opened each land and when. A land the host could not
build is forgotten there, so it costs no wait.

### Parked lands

Slots are the lands awake at once, not the lands there are. `make_room` asks
the host to park (`<expeditions>/park/<slot>.json`) the land nobody has been on
longest: at least an hour (`PARK_IDLE_SECONDS`), started, and with no course
set for it in the last two hours. The host saves and stops it and moves its
save aside ([slots](expedition-slots.md#parked-lands)); `refresh_parks` then
takes the tile off its slot (`region` empty, `parked` true in the snapshot,
`chart_parked`). A parking the host called off (somebody was there) or never
did within an hour is forgotten.

A parked land keeps its state, its claim and its 7 days. Nothing of it is
lost: only an undecided one still runs out, 7 days after anyone was last
there (`<expeditions>/discard/<x>-<y>.json` tells the host).

It gets a slot again (`place`: the wanted file says `parked`, so the host
restores it, not generates it) when:

- a ship sets course for it. That is never a new land, so no wait applies;
- somebody whose character is there comes back (`/chart/request` op `summon`).
  While a land is parked the homes there are `land:X,Y`, which is no region:
  any world such an account joins asks for the land and tells the player to
  press Join again in a few minutes (`region_home.dm`). `Coordinator.chart_moves`
  moves the homes and the land stage to the parked land and back to
  whichever slot it is restored into.

| Course state | Meaning |
| --- | --- |
| `ASSIGNED` | the land has a slot; the host is opening it |
| `READY` | the host started the slot on that land |
| `REFUSED` | with a reason; the ship turns back |

Courses are kept for 6 hours. Each snapshot sent to the worlds carries them
(`courses`, by voyage id) and what each owner has seen (`seen`: a hex bitmap,
bit `y * width + x`), so a world shows a crew its own chart. A ship's `scout`
request charts the tiles round a tile for its owner, as an admin `reveal` does.

## Settling, claiming and abandoning

A land's own world asks for its crew (`/chart/request` ops `settle`, `claim`
and `unclaim` with the colony's parent faction as owner, `abandon`; x and y must name the
land it holds). Settle: tile `SETTLED`, land stage `FRONTIER`. Claim: tile
`CLAIMED`, stage `COLONY`, one claim per faction (`chart_claim`, sent to the
worlds as `claims`); giving it up puts the tile back to `SETTLED`, stage
`FRONTIER`. Abandon, or 7 days with no players on a land still
`LANDED` (`chart_landed`, refreshed by land samples): tile `LOST` for good, the
homes there go to the mainland and the host archives the slot. See
[voyages](ship-voyage.md#settle-claim-or-abandon).

## Where it lives

- Coordinator database: `chart_tile` (templates and states), `chart_seen`
  (each owner's tiles), `chart_pin`, `chart_meta` (seed and revision),
  `chart_course` (ships' courses), `chart_landed` (lands opened and last
  visited), `chart_opened` (who opened each land), `chart_parked` and `chart_parking`
  (parked lands, parkings asked of the host), `chart_claim` (faction claims).
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
