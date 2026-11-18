# Hauling small boats over land

Code: `code/modules/naval/boat_hauling.dm`. Probe: `python3 tests/ecology_spawning/run_linux.py . tests/dugout_canoe/probe.dm`
(`canoe_hauling_checks`).

Small boats are built ashore and dragged to the water with the ordinary pull. What the boat adds
to each step of the puller comes from the structure `drag_delay()` hook; `haul_class()` says how
heavy she is (0 for vehicles that are not boats, which drag as before).

| Boat | On land, alone | With help | On log rollers | Afloat |
| --- | --- | --- | --- | --- |
| Raft, dugout canoe (`BOAT_HAUL_LIGHT`) | 2 | 2 | 0.75 | 0.75 |
| Outrigger canoe, legacy plank boats, RHIB (`BOAT_HAUL_HEAVY`) | 6 | 2 with one helper, 0.75 with two | 0.75 | 0.75 |

- A helper is any standing, conscious, unrestrained person within a tile of the boat who is not
  the puller and not aboard (`haul_helpers()`). A fitted engine counts as one helper fewer.
- On land a boat with anyone or anything aboard will not move: `Move()` refuses and drops the
  pull (`haul_refusal()`). Paddling uses `forceMove` and is not affected.
- **Log rollers** (`/obj/item/boat_rollers`, 3 wood, Basic Toolmaking) used on an empty beached boat
  set `on_rollers` (saved) and show under her. They drop out on the last land tile when she moves
  onto water, or come out with the Take Out Rollers verb.
- A look at a beached boat says how she drags (`haul_text()`, appended to `small_craft_text()`).

Not built: wear from use (lashings, soaking, torn sails), and anything for hulls built tile by tile.
