# Space station plans

Code: `code/modules/space/station_plan.dm` (the plan, its code, the sheet,
the survey and the founding) and `station_plan_checks.dm` (design checks and
part book of kind `station_plan`).

A ship's draught can carry a space station plan: habitat modules on a grid
of `STATION_PLAN_SIDE` (7) slots each way, north to the top, one module
pitch (`HABITAT_MODULE_SPACING`, 4 tiles) apart. Side by side modules dock
with a hatch in the wall they share.

| Key | Module | Core | Kit (research) |
| --- | --- | --- | --- |
| C | command module: console, supply crate, bench, heater, scrubber, radiator, return hatch | `station` | orbital workshop kit |
| Q | quarters, two bunks | `quarters` | habitat module kit |
| G | greenhouse, two trays | `greenhouse` | greenhouse module kit |
| W | workshop, a bench | `workshop` | workshop module kit |
| S | storage, two crates | `storage` | storage module kit |
| N | node, a deck hatch | node core | node module kit |
| A | airlock | airlock core | airlock module kit |
| K | keel airlock: the keel runs out from it | airlock core | airlock module kit |

A module's research is its kit's recipe node; the office refuses a plan
whose modules the user's people have not researched.

## Checks

Errors: no command module or more than one; more than
`STATION_PLAN_MAX_MODULES` (12) modules; a module not docked to the rest;
no keel airlock or more than one; a keel airlock docked to more or fewer
than one module; a module on the keel (straight out three slots, and the
two slots beside the second slot out, where the solar boom crosses).
Warnings: a module more than two hatches from the command module's life
support; no quarters. Notes: extra modules' steel, no greenhouse, no node.

## Cost

Every plan costs the starter station's 180 steel, 40 glass, 40 copper and
60 electronics, plus 60 steel for each module past the starter's count for
the age (`station_plan_allowance()`: 3 in 1969, 5 from 2013, 8 from 2026).

## Code

    C13STATION/1/<name>/<col,row,piece>;...

## Launching

Use the sheet on a launch complex office whose project has started and has
not flown. The office's `requirements()` become the plan's costs, and the
plan (`plan_code`, saved) rides with every member in the `station_plan`
payload field (`travel_extra`, whitelisted and length-checked in
`region_travel.dm`). The first arrival founds the station from it
(`orbit_found_station_plan`): the middle slot on the middle of the plane,
modules unfolded nearest the command module first, the cable along the hatches
from the command module to the keel airlock and out along the keel, and the
keel as in the starter: the porch 7 tiles out, the solar boom at 9 (7 wide),
the isotope generator (from 2013) at 10, the fuel cell at 11 and the reboost
thruster at 12. A plan that does not fit the plane is logged and the starter
station is built instead.

## Drawing a station

Use a blank sheet of paper on a station's orbit console: the station's
modules are drawn around the command module (the one holding the return
hatch), and the airlock with truss outside it becomes the keel airlock.

## Tests

    python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>

`orbit_plan_checks()` covers the ready-made plans, codes, refusals, costs,
the office, the founding and the drawing at the console.
