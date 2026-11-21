# Berths

A berth is any place that holds a boat for her upkeep
(`code/modules/naval/berth.dm`). The plan is in the project thread "Add
drydocks and shipyards for ship work": every berth repairs, refits and builds.
This first part makes the boathouse slip a berth for built hulls and adds the
shared repair rules. The slipway, drydock and shipyard office follow.

## Which berth holds her

`craft_berth(craft)` returns the structure that holds every tile of a built
hull, or null. A berth structure answers `berth_holds(craft, cells)`; it keeps
no record of the hulls in it, so nothing new is saved.

| Berth | Holds | Dry |
| --- | --- | --- |
| Boathouse | a built hull lying wholly in its 7x7 slip | no |

`berth_dry(craft)` is for berths that hold a hull out of the water (the
slipway after a haul-out, a drained drydock). None does yet.

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

`tests/naval_carrier/berth_probe.dm` (30 checks):

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/berth_probe.dm 300
