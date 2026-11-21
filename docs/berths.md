# Berths

A berth is any place that holds a boat for her upkeep
(`code/modules/naval/berth.dm`). The plan is in the project thread "Add
drydocks and shipyards for ship work": every berth repairs, refits and builds.
The boathouse slip and the slipway (after a haul-out) are berths now; the
drydock and shipyard office follow.

## Which berth holds her

`craft_berth(craft)` returns the structure that holds every tile of a built
hull, or null. A berth structure answers `berth_holds(craft, cells)`; it keeps
no record of the hulls in it, so nothing new is saved.

| Berth | Holds | Dry |
| --- | --- | --- |
| Boathouse | a built hull lying wholly in its 7x7 slip | no |
| Slipway | a built hull hauled out on its berth: every tile on dry ground, bow to the water, stern on the tile in front of the post | yes |

`craft_berth()` looks for a boathouse when her first tile is water, and for a
slipway next to one of her tiles when it is ground.

A hull at a dry berth (`berth_dry()`, `lies_dry()`) gathers no bilge water and
her ledger does not step: nothing seeps, wears, drifts or fouls.

## Hauling out on the slipway

`code/modules/naval/slipway_haul.dm`. Bring a built hull to a stop within 12
tiles off the foot of an empty slipway, her bow to the open water the way the
post faces, and use the post: "Haul the <name> out". It needs one pair of hands
within two tiles of the post (not aboard) for every 20 tiles of hull; a horse
or an ox counts as two. After three seconds for every tile she moves, she is
drawn up stern first until her stern lies on the tile in front of the post, in
line with it. Every tile she rests on must be dry open ground (not water or a
flooded trench), and the ways she slides over must be clear.

The body is moved with `move_to()`; for that one move `ways_tiles` on the
built body lets `tile_refusal()` accept the berth ground. She is stopped and
anchored and her bilge is emptied.

Hauled out, the post offers "Launch the <name> again", which slides her back
down to open water like a launch (`draught_landing()`), and "Survey her
condition". A keel or a draught cannot be laid while she is on the berth.
Nothing is saved: a hauled hull is found from where she lies.

## What a berth allows

`/datum/hull_ledger/proc/bottom_reachable()` is TRUE in the shallows or at a
berth. Where it is TRUE:

- caulking reaches tight (`caulk_floor()` is 0), not only back to sound;
- the bottom can be scraped and sheathed in copper over any depth.

Planking over a patch is berth work only. Use one piece of wood (or one steel
sheet) on a hull patch with a hammer in the other hand, standing on her deck
beside it, while she lies still. After four seconds the patch is replaced by
ordinary planking (`/obj/covers/repairedfloor/ship`) or steel plating
(`/obj/covers/steelplating`), and the ledger is surveyed again. The patch no
longer weeps, and a plated tile no longer seeps.

Work at a berth costs what the same work costs by hand.

## Survey her condition

The boathouse menu has "Survey her condition". It reports every built hull in
the slip (the ledger's status plus a "Work wanted" list with costs), every small
boat in the slip, and every stored small boat. `caulk_wanted()` and
`scrape_wanted()` count the twists of oakum and scraper goes still needed.

## Small boats indoors

A raft or dugout stored in a boathouse dries out three times as fast as one on
the shore (`dry_factor()`, used by `dry_out()` in `small_boat_upkeep.dm`).

## Tests

`tests/naval_carrier/berth_probe.dm` (51 checks):

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/berth_probe.dm 300
