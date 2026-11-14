# Voyages on the world chart

A built hull ([craft core](craft-core.md)) lying off the edge of a mainland
region can set out across the world chart ([world chart](world-chart.md)) for
a land across the sea, or to scout unknown water. Code:
`code/modules/naval/ship_voyage.dm`.

## Setting out

At the tiller, **Set out on a voyage** is offered when she lies within 4 tiles
of the map edge of a region group world that is not itself an expedition land.
She must meet the crossing rules ([ship crossing](ship-crossing.md): all stop,
no grapple, the transfer agent reachable, no save running) and have at least
2 crew aboard and awake.

The chart shown is her owner's: the captain's faction (`faction:<name>` from
the character's civilization), or the captain alone (`crew:<ckey>`). The world
reads the chart from its agent; its own tile is its pin on the chart, or the
mainland's.

- **A land:** every land on the owner's chart that has a coast and is not
  lost, with its size, biome, land type and voyage time.
- **Scouting:** north, east, south or west, 4 tiles out and back (8 minutes).
  Coming home, she charts the tiles round the turning point and halfway there
  for her owner.

A voyage takes about a minute a chart tile (the larger of the two distances).
She drops anchor and lies off the coast under way: the tiller only tells how
long is left and offers **Turn back**. Whoever is aboard at landfall sails
with her; anyone who steps off is left behind.

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

## Not done yet

- Rations, voyage events (storm, sighting, short rations) and engines sailing
  faster.
- Onward voyages from a land to another tile, settling, claiming and
  abandoning lands (next step of the plan).

Tests: `tests/naval_carrier/voyage_probe.dm` (see `tests/naval_carrier/README.md`),
`python3 -B tests/transfer_storage/test_world_chart.py` (courses),
`python3 -B tests/gaia_host/test_expedition_slots.py` (opening lands).
