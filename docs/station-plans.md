# Space station plans

Code: `code/modules/space/station_plan.dm` (the plan, its code, the sheet,
the survey and the founding), `station_plan_checks.dm` (design checks and
part book of kind `station_plan`) and `station_designer.dm` (the drawing
window).

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

## The drawing window

`code/modules/space/station_designer.dm`: "Draw a space station on the sheet"
on a blank ship's draught, or "Draw on the sheet" on a station plan, opens
the station designer, by the airship designer's rule (the sheet and a pen or
pencil in hand). It follows the airship designer
(`code/modules/naval/air_designer.dm`): the grid of slots with north to the
top, a palette of the eight modules and the eraser, a Module panel with the
part book's what, use and how, the Figures, the Checks with the slots they
name ringed, the ready-made plans, undo and redo, a name and "Save to the
sheet". Drawing the command module or the keel airlock again moves it, and
a thirteenth module is refused in the window.

Every change is sent as a design code
(`?src=<designer>;station=preview|save;code=<C13STATION code>;name=<name>`).
The server reads it with `station_plan_from_code()`, which refuses a slot
off the grid, an unknown key, a slot written twice and more than
`STATION_PLAN_MAX_MODULES` modules, cleans the name with
`station_plan_clean_name()`, and answers `stationPlan(json)` with
`station_designer_answer()`: the figures, the findings (`data()`) and the
keel. `station_designer_keel()` gives the keel as the plan's own
`keel_slots()` that lie on the grid: truss on the first and second slot out,
a solar wing each side of the second and the reboost thruster on the third.
Save calls `take_station()`.

A slot is drawn as a rim of hull, the floor inside it and the module's
furniture; docked modules show the hatch they share. The pictures are cut
from the game's DMIs by `scripts/build_station_designer_icons.py` into
`icons/station_designer/` (`--check` exits 1 when they are stale) and sent
with `browse_rsc` as `stad_<name>.png`:

| Picture | Sprite |
| --- | --- |
| `hull`, `floor` | `wall_masks.dmi` `sub0`, `machines/submarine.dmi` `steel_grid` |
| `hatch`, `mod_A` | `doors/material_doors.dmi` `blast` |
| `mod_C` | `computers.dmi` `solar_screen` |
| `mod_Q` | `bed_chair.dmi` `bunk_bed` |
| `mod_G` | `structures.dmi` `kevlar_trough_empty` under `farming/plants.dmi` `parsley-harvest` |
| `mod_W` | `structures.dmi` `table` |
| `mod_S` | `storage.dmi` `crate` |
| `mod_N` | `stairs.dmi` `ladderdown` |
| `mod_K` | `structures.dmi` `grille` under `doors/material_doors.dmi` `blastopen` |
| `keel_truss` | `structures.dmi` `grille` |
| `keel_wing` | `renewable_power.dmi` `solar_panel` |
| `keel_thruster` | `decals_wider.dmi` `rocket`, scaled to one tile |

## Drawing a station at her console

Use a blank sheet of paper on a station's orbit console: the station's
modules are drawn around the command module (the one holding the return
hatch), and the airlock with truss outside it becomes the keel airlock.

## Tests

    python3 tests/orbit_world/run.py --byond-bin <pinned bin> --output <empty directory>

`orbit_plan_checks()` covers the ready-made plans, codes, refusals, costs,
the designer's page, pictures, figures and keel, the office, the founding and
the drawing at the console.

    python3 -m unittest tests.ship_draught.test_design_checks
    python3 scripts/build_station_designer_icons.py --check

The first also checks the designer's pictures, its page and what its Topic
checks; the second that the pictures match the game's sprites.

A real flight between two worlds on one machine, with the transfer agents
the live group uses (developer evidence, needs rust-g; see its README):

    python3 tests/orbit_flight/native_flight.py --byond-bin <pinned bin> --rust-g librust_g.so --output <empty directory>
