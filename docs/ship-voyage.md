# Voyages on the world chart

A built hull ([craft core](craft-core.md)) lying off the edge of a mainland
region can set out across the world chart ([world chart](world-chart.md)) for
a land across the sea, or to scout unknown water. Code:
`code/modules/naval/ship_voyage.dm`.

## Setting out

At the tiller, **Set out on a voyage** is offered when she lies within 4 tiles
of the map edge of a region group world: the mainland, or a land across the
sea (an onward voyage, from that land's own chart tile).
She must meet the crossing rules ([ship crossing](ship-crossing.md): all stop,
no grapple, the transfer agent reachable, no save running), be able to make
way (a rigged mast or a running engine) and have somebody aboard and awake
(one sailor is enough).
Everything the crossing would refuse at landfall refuses her at the tiller
instead (`sea_crossing_load`): something that cannot cross, too much loose
cargo, or a record over the crossing budget (`SEA_CROSSING_RECORD_MAX`,
192 KB, carried in the first crew member's payload); the voyage menu shows
how full she is. The tile caps bind long before the budget does: a 200-tile
steel battleship with a 96-tile hold, eight loaded turrets over full shell
racks, a belted side and 390 items in crates packs to about 25 KB
(`tests/naval_carrier/passage_probe.dm`), so records are never split. Her
turrets cross with the shells in their breeches, her shell racks with their
shells, and her belt armour as part of her hull (deck entry `"a"`), not as
cargo. Packing that hull costs about 140 ms each time the tiller measures her
and once as she crosses.

The chart shown is her owner's: the captain's faction (`faction:<name>` from
the character's civilization), or the captain alone (`crew:<ckey>`). The world
reads the chart from its agent; its own tile is its pin on the chart, or the
mainland's.

- **A land:** every land on the owner's chart, or settled or claimed by
  anyone, that has a coast and is not lost, with its size, biome, land type
  and voyage time.
- **Scouting:** north, east, south or west, 4 tiles out and back (8 minutes).
  Coming home, she charts the tiles round the turning point and halfway there
  for her owner.

A voyage takes about a minute a chart tile under sail (the larger of the two
distances), or 40 seconds when her engines drive her at full ahead.
She drops anchor and lies off the coast under way: the tiller tells how
long is left and offers **Turn back** and any pending storm choices. Her crew still see her sail: every
tile of open water within 24 tiles of her is drawn for them streaming past
from bow to stern, a tile every 1.2 seconds, until the voyage ends
(`code/modules/naval/voyage_sea.dm`, appearance only: override images of the
water, refreshed for whoever is aboard at every voyage tick). Whoever is aboard at landfall sails
with her; anyone who steps off is left behind.

## No admin decides: the limits instead

Any crew may sail for any land its chart shows, at any time. What keeps lands
from piling up and worlds from staying awake is in the rules themselves:

| Rule | Value | Where |
| --- | --- | --- |
| Undecided lands a chart owner (or the account at the tiller) may have open | 1 | `WorldChart.open_refusal` |
| Wait between opening new lands, for the owner and the account | 3 hours (`OPEN_COOLDOWN_SECONDS`) | `world_chart.py` |
| An undecided land with nobody on it is abandoned | after 7 days, parked or not | `WorldChart.expire` |
| With every slot taken, the land empty longest gives its slot up | after 1 hour with nobody there and no ship on her way (`PARK_IDLE_SECONDS`): it is parked, save and all, and loses nothing | `WorldChart.make_room`, [slots](expedition-slots.md#parked-lands) |
| A ship lies at anchor after a landfall before another voyage or crossing | 15 minutes (`VOYAGE_LANDFALL_REST`); scouting is free | `ship_voyage.dm` |
| An empty, saved land's world | shut down to disk after the idle wait (`freeze_cold`), not kept frozen in memory | [slots](expedition-slots.md#an-empty-land-sleeps-on-disk) |

Lands already open (her own undecided land, any settled or claimed land) can
always be sailed for, parked or not; only opening a new one waits. Slots are
the lands awake at once, not the lands there are: a settled or claimed land is
never lost for want of a slot. A land the host could
not build costs its crew no wait.

The landfall rest equals the host's idle wait before an empty world goes to
sleep (`freeze_idle_minutes`, 15). The world a crew left empties, saves at
once and is asleep by the time the same crew can leave the next one, so a crew
hopping from land to land keeps two worlds awake at most.

## Sea routes between the continents

Code: `code/modules/naval/sea_lanes.dm`. The continents of the region group need
no world chart: each has a place on one shared layout, `continent_layout`
(region id = x east, y north, in chart tiles, and the map edges with open deep
water along them, best first). The voyage between two coastal continents takes
the larger of the two distances in tiles. Today: North America (0,6), South
America (2,0), Gaia (6,7), Europe (11,9), Desert (12,4), Jungle (13,1), Asia
(18,8). The Desert's sea is off its north edge and the Jungle's off its west edge
(docs/map-coasts.md). The ids
are the host's region ids in earth.json.

**Set out on a voyage** lists every other coastal continent whose world is in
the group and up or able to wake, for example "Gaia, across the sea to the east: 6 tiles,
about 6 minutes". These come above any chart lands. A route needs no chart owner or pin and only one
crew member aboard. The other voyage rules above still apply: a mast or running engine, the
crossing rules and load, rations and storms. There are no sightings, since a route
crosses no chart. When her time is up she crosses to that world on the voyage
id, like **Leave these waters**, or waits off the coast while it wakes (up to 30
minutes, then turns back). She makes landfall off the arriving continent's
coasts facing where she came from, then its other coasts, then any side with
room. The crew make their home in the land they sail to, as with any trip
between regions.

## Rations and happenings

Code: `code/modules/naval/voyage_provisions.dm`.

- **Rations:** each crew member eats one ration a chart tile, and any food
  aboard counts (in the hold, in crates, carried). The tiller says when she
  carries too little and asks before she sails hungry. What the voyage needed
  is eaten as she arrives (or comes home from scouting); every ration she was
  short costs the crew 60 nutrition between them, never taking anyone below
  150. Nobody starves at sea.
- **Happenings,** at most one of each a voyage: a **storm** (8% a chart tile)
  gives the crew 30 seconds to stow cargo and choose at the tiller. **Detour**
  costs one chart tile's sailing time, but no extra rations or lost cargo, and
  is the default if nobody acts. **Press on** risks washing one loose item
  overboard from an exposed deck (50% chance if there is any), but avoids the
  detour. The hold, roofed decks, and cargo in pockets or containers are safe
  from this event. These are voyage encounters, not forecasts drawn from the
  weather at the hull's parked location. A **sighting** (10% a tile) charts
  water a tile or two off her course for her owner; sailing short, the crew
  are warned past halfway that rations are low, so they can turn back.

## Landfall

A course is sent to the world directory as she sets out
(`/chart/request`, op `course`), so the coordinator can open the land in a free
expedition slot while she sails ([slots](expedition-slots.md#lands-opened-for-ships)).
When her time is up she looks at the course on the chart:

- `READY` and the land's world up or able to wake: she crosses to it exactly
  as **Leave these waters** does, on the same voyage id.
- Not answered, still `ASSIGNED`, or the world not answering: "The coast is not
  yet in sight." She waits, for up to 30 minutes past her time, then turns back.
- `REFUSED` (no free slot yet while a land is parked to make room, a new land
  opened too lately or another still undecided, the land could not be made,
  the chart does not show it): she turns
  back with the reason. She asks after her course about once a minute under
  way, so a refusal reaches her within a minute or two of setting out, with no
  rations eaten.

A voyage is not saved: a world restarted mid-voyage finds her lying off the
coast where she set out.

### Holding her course once word is sent ahead (#6258)

Waking a land, or plotting a course that may open one, is a commitment
(`crossing_hold` on the tiller, `code/modules/naval/ship_crossing.dm`). Before
the request can yield she is held: `plotting` while the world chart is asked
for a course, `asking` while the host doorman is asked to wake the land
(`shard_group.ask_wake()`), `committed` once the doorman took the wake or gave
no reply (it may be waking), and `departing` while her crew leave. While held:

- Nothing else sends her anywhere: another **Leave these waters**, another
  voyage, a stale prompt from before and **Turn back** are refused in server
  code, and the tiller shows where she is bound and how long the hold lasts.
- A retry to the same land sends no second word: it waits on the first wake.
- A definite refusal before the doorman took the wake lets her go at once. The
  wake's own deadline (its eta plus a minute) ends a committed hold; a single
  failed poll does not. A voyage still holds its land after that and asks
  again on its next look; a land that answers late is crossed to then.
- Every step after a yield checks that the hold and voyage are still hers; a
  stale continuation neither moves her nor clears a newer hold. An admin's
  send overrides the hold.
- A course the chart never answered is sailed unconfirmed and asked again
  under way with the same voyage id, which the directory answers with the same
  course; she never plots a second.

Crew who set out on the voyage and logged out at sea still make the crossing
with her; anyone else aboard without a player is named, so her crew can put
them ashore (live report 2026-11-19).

Tests: `tests/naval_carrier/voyage_hold_probe.dm` (stubbed doorman, polls,
transfer agent and departures; nothing is woken).

## Settle, claim or abandon

A land opened for a ship is undecided until its crew choose
(`code/modules/naval/land_choices.dm`; the world directory keeps the choice in
`world_chart.py` and the land stage, [land stages](land-stages.md)):

| Choice | Who and what it takes | Then |
| --- | --- | --- |
| **Settle this land** (tiller) | any crew member: a mooring post that takes ships and 3 beds slept in by different people within 40 tiles of it | tile `SETTLED`, land stage `FRONTIER`: kept for good, on everyone's chart |
| **Claim** | a faction leader plants the colony charter (`colony_charter.dm`); one claim per faction, one faction per land | tile `CLAIMED`, stage `COLONY`; the world directory keeps `chart_claim` |
| **Claim this land** (tiller) | any player, for themself: a mooring post that takes ships and their own bed within 40 tiles of it; one land each, besides any land their faction claims; one claimant a land | tile `CLAIMED`, stage `FRONTIER`; claimant `crew:<ckey>` in `chart_claim`. **Give up your claim** at a tiller there puts it back to `SETTLED` |
| **Abandon** | the captain, asked as she leaves (Leave these waters or a voyage onward) | tile `LOST` for good; homes there go to the mainland; the host saves, stops and archives the slot (`<root>/expeditions/abandon/<slot>.json`) and frees it |
| **Give up the claim** | the colony's leader, at its charter | charter down, tile `SETTLED`, stage `FRONTIER`; the faction may claim another land |
| nobody chooses | the land waits, and its crew can open no other new land | abandoned after 7 days with no players there (the coordinator's land samples) |

A settled land can still be claimed. The colony's leader can give the claim
up at its charter (op `unclaim`): the charter comes down, the tile goes back to
`SETTLED` and the land stage to `FRONTIER`, and the faction may claim another
land. Until a land is settled or claimed, a
death there always sends the character home to the mainland: a bed there
does not keep the home. A land world reads its chart about once a minute to
know.

### Claimed lands

A faction's claim on a land across the sea can never be taken by another
faction while the faction lives there (`code/modules/naval/island_claim.dm`):

- The claim on the world chart is the colony's title. If the charter is
  destroyed the colony still stands: arrivals still join it, it still counts
  in the land samples, and its own leader (or a leader who travelled from the
  faction's land) can plant the charter again. Nobody else can claim the land
  meanwhile.
- A claim lapses when the land has had fewer than 3 residents for 14 days in
  a row: members on the colony's roster with a fastened bed of their own
  there. Members are told when the count drops, and when it recovers. On a
  lapse the charter comes down and the land goes back to `SETTLED`, open to
  any faction's claim (op `unclaim`).
- These lands have no provinces, so the colony's recruitment stations always
  work ([provinces](provinces.md)). Examining the charter shows the claim's
  standing.

The check runs with the land's chart refresh (`land_stages_refresh_due`).
State: `map.faction_recruitment["island_claim"] = list(parent, short since)`.

### Island borders

A faction decides who may land on its claimed island
(`code/modules/naval/island_access.dm`). Its leader, and officers holding the
papers power, set the border from any land with **Faction > Faction Island**:

| Border | Who may land |
| --- | --- |
| Open to visitors | anyone |
| Members and guests (the default) | members, the guests the faction names (each named while standing beside the officer, up to 50) and holders of a visitor pass |
| Members only | members alone, whatever passes say: the border is closed |

A member is anyone who travels as the faction (`colony_faction_id`): its own
members and its colonies' members. **Grant Island Visitor Pass** (a verb on the
faction's recruitment station) gives someone beside the station a pass for 1
hour to 7 days, or takes it back. The world directory keeps the border and the
passes (`chart_access` in `world_chart.py`; chart ops `access` and `pass`, sent
from any land for the tile the faction claims) and sends them with the chart
(`access`), so every land knows them.

- The voyage menu lists the island only to a captain it admits, and the tiller
  refuses a voyage, or a landfall, while anyone aboard may not land.
- Every trail, crossing and flight out of any land refuses them too
  (`region_gate/depart_party`). An admin's send is never stopped.
- On the island, whoever is ashore without leave (the border closed, a pass ran
  out, a member was expelled) is told to go and after 10 minutes is put ashore
  in the start land. Restrained captives stay where they are held.
- The faction's own members are protected while they sleep offline in a bed
  there ([offline sleep protection](../code/modules/persistence/offline_sleep_protection.dm)).
- Giving the claim up, or its lapse, drops the border with it: the land is
  open to every ship again.

Tests: `python3 -B tests/transfer_storage/test_world_chart.py` (borders, passes,
requests from another land).

Tests: `tests/naval_carrier/voyage_probe.dm` (see `tests/naval_carrier/README.md`),
`python3 -B tests/transfer_storage/test_world_chart.py` (courses, land choices),
`python3 -B tests/gaia_host/test_expedition_slots.py` (opening lands).
