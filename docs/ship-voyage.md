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
way (a rigged mast or a running engine) and have at least 2 crew aboard and
awake.

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
She drops anchor and lies off the coast under way: the tiller only tells how
long is left and offers **Turn back**. Whoever is aboard at landfall sails
with her; anyone who steps off is left behind.

## Rations and happenings

Code: `code/modules/naval/voyage_provisions.dm`.

- **Rations:** each crew member eats one ration a chart tile, and any food
  aboard counts (in the hold, in crates, carried). The tiller says when she
  carries too little and asks before she sails hungry. What the voyage needed
  is eaten as she arrives (or comes home from scouting); every ration she was
  short costs the crew 60 nutrition between them, never taking anyone below
  150. Nobody starves at sea.
- **Happenings,** at most one of each a voyage: a **storm** (8% a chart tile)
  costs one or two tiles' time or washes something loose on deck overboard;
  a **sighting** (10% a tile) charts the water a tile or two off her course
  for her owner; sailing short, the crew are warned past halfway that rations
  are low, so they can turn back.

## Landfall

A course is sent to the world directory as she sets out
(`/chart/request`, op `course`), so the coordinator can open the land in a free
expedition slot while she sails ([slots](expedition-slots.md#lands-opened-for-ships)).
When her time is up she looks at the course on the chart:

- `READY` and the land's world up or able to wake: she crosses to it exactly
  as **Leave these waters** does, on the same voyage id.
- Not answered, still `ASSIGNED`, or the world not answering: "The coast is not
  yet in sight." She waits, for up to 30 minutes past her time, then turns back.
- `REFUSED` (no free slot, the land could not be made, the chart does not show
  it): she turns back at once with the reason.

A voyage is not saved: a world restarted mid-voyage finds her lying off the
coast where she set out.

## Settle, claim or abandon

A land opened for a ship is undecided until its crew choose
(`code/modules/naval/land_choices.dm`; the world directory keeps the choice in
`world_chart.py` and the land stage, [land stages](land-stages.md)):

| Choice | Who and what it takes | Then |
| --- | --- | --- |
| **Settle this land** (tiller) | any crew member: a mooring post that takes ships and 3 beds slept in by different people within 40 tiles of it | tile `SETTLED`, land stage `FRONTIER`: kept for good, on everyone's chart |
| **Claim** | a faction leader plants the colony charter (`colony_charter.dm`); one claim per faction, one faction per land | tile `CLAIMED`, stage `COLONY`; the world directory keeps `chart_claim` |
| **Abandon** | the captain, asked as she leaves (Leave these waters or a voyage onward) | tile `LOST` for good; homes there go to the mainland; the host saves, stops and archives the slot (`<root>/expeditions/abandon/<slot>.json`) and frees it |
| **Give up the claim** | the colony's leader, at its charter | charter down, tile `SETTLED`, stage `FRONTIER`; the faction may claim another land |
| nobody chooses | the land waits | abandoned after 7 days with no players there (the coordinator's land samples) |

A settled land can still be claimed. The colony's leader can give the claim
up at its charter (op `unclaim`): the charter comes down, the tile goes back to
`SETTLED` and the land stage to `FRONTIER`, and the faction may claim another
land. Until a land is settled or claimed, a
death there always sends the character home to the mainland: a bed there
does not keep the home. A land world reads its chart about once a minute to
know.

Tests: `tests/naval_carrier/voyage_probe.dm` (see `tests/naval_carrier/README.md`),
`python3 -B tests/transfer_storage/test_world_chart.py` (courses, land choices),
`python3 -B tests/gaia_host/test_expedition_slots.py` (opening lands).
