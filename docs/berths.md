# Berths

A berth is any place that holds a boat for her upkeep
(`code/modules/naval/berth.dm`). The plan is in the project thread "Add
drydocks and shipyards for ship work": every berth repairs, refits and builds.
The boathouse slip, the slipway (after a haul-out) and the drydock are berths,
and a yard office makes the berths around it a shipyard.

## Which berth holds her

`craft_berth(craft)` returns the structure that holds every tile of a built
hull, or null. A berth structure answers `berth_holds(craft, cells)`; it keeps
no record of the hulls in it, so nothing new is saved.

| Berth | Holds | Dry |
| --- | --- | --- |
| Boathouse | a built hull lying wholly in its 7x7 slip | no |
| Slipway | a built hull hauled out on its berth: every tile on dry ground, bow to the water, stern on the tile in front of the post | yes |
| Drydock | a built hull with every tile in a dock basin | when pumped out |

`craft_berth()` asks the dock gate of her first tile (`dock_basin_turfs`)
first, then looks for a boathouse when her first tile is water, and for a
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

## The drydock

`code/modules/naval/drydock.dm`. A dock gate (`/obj/structure/canal_lock/dock_gate`,
24 stone, construction, Wagons & Ships) stands on the flooded trench at the
mouth of a dug basin. The basin is every trench tile joined to the gate's tile
through its 8 neighbours, not counting tiles with a dock gate. It may touch
open water only at its gates, diagonals included, and holds at most 400
tiles. Several gates side by side across a wide mouth work as one.

- `dock_basin_turfs` maps each basin and gate tile to its gate. It is rebuilt
  from the gates (New, after_load, every use) and never saved.
  `tile_refusal()` lets a built hull float on a flooded basin tile and pass an
  open gate tile (`dock_floats()`); a shut gate is dense.
- A dock gate is a pound lock, so `canal_level()` reads its `chamber_level`.
  Shut, that is -1000, so no trench floods from the gate tile.
- "Pump out the dock" needs every gate shut and every hull in the basin wholly
  inside it. Each 2 s go pumps one tile, plus one for each hand bilge pump and
  four for each steam or sump pump within 3 tiles of a gate. When the basin's
  tile count is reached, `drain()` turns every tile dry at once (tile by tile
  it would flood again from its neighbours). Hulls there are stopped, anchored
  and emptied, and lie dry.
- "Open the sluices" (10 s) floods the basin with salt or fresh water as the
  gate tile is, and the gate can be opened to sail out.
- The gate saves `shut` and `drained`; the trench tiles save themselves.

## Building and refitting at a berth

`code/modules/naval/berth_build.dm`. `built_hull_survey()` takes floors over
open water, or, when the tiller does not stand on water, floors on the ground
of the berth it stands on (`berth_ground_at()`, `berth_ground()`):

| Berth | Ground |
| --- | --- |
| Drydock | every tile of the basin, flooded or dry |
| Slipway (no keel laid) | dry open ground in front of the post, 1 to 40 tiles along the ways and up to 20 to either side |

A floor joining hers off that ground still joins her to the shore. A hull can
be laid down from nothing there, or have floors added and lifted and be
surveyed again with "Refit the hull", as afloat. `berth_commission_refusal()`
lets a berth ask more: on a slipway her bow must point the way the post faces
and her stern lie on the tile in front of it, so she is a hauled hull and the
post launches her. A boathouse slip is open water, so it needs nothing new.

## Refitting to a draught

`code/modules/naval/berth_refit.dm`. Holding a ship's draught at the tiller of
a hull at a berth, "Mark out a refit" keeps the draught's code on the tiller
(`refit_code`, tmp) and lays it over her: its first tiller or steering oar on
her tiller, its bow her way (`refit_target()`). `refit_diff()` compares her
main deck tile by tile with `ship_draught_piece_on()`: add (green), lift
(red), change a floor or fitting (amber) and turn a fitting (faint amber).
Each is a `/obj/structure/berth_refit_mark` (not saved).

The work is done by hand at hand costs. A floor lifted at a berth is a hole in
the ledger, but `commission()` refits a hull at a berth despite holes, so
"Refit the hull" takes the lifted tiles out of her. It then marks her again;
"Check the refit" does the same, and when nothing differs the marks and the
draught go. Decks above and below are not compared.

## The yard office

`code/modules/naval/yard_office.dm`. A yard office (`/obj/structure/yard_office`,
30 wood, construction, Workshops) makes the berths within 15 tiles a shipyard.
It is not the carrier's shipyard office (`shipyard.dm`).

- `yard_time(atom, time)` divides work time by 1.5 within an office's reach.
  It is used for slipway pieces (template and draught), hauling up the ways,
  planking over patches, and pumping and flooding a dock.
- Stock: stacks that `piece_material()` knows (wood, steel, iron, planks,
  aluminium, glass, rope, cable, cloth) are stored in the office. "Fit from
  the yard stock" at a slipway post (`yard_options()`, `fit_from_stock()`)
  pays piece after piece from it, 4 s a piece before the yard's speed-up.
- Shelf: up to 20 ship's draughts are filed in the office and taken down from
  its menu.
- "Survey the yard" lists the slipways, boathouses and dock gates in reach and
  the hulls they hold.

The stock and shelf are the office's contents and save with it; offices are
listed in `yard_offices`, never saved.

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

## Breaking a ship up for parts

`code/modules/naval/berth_breakup.dm`. Every berth's menu (the slipway post
with a hull hauled out, the dock gate, the boathouse) offers "Break up the
<name> for parts" for each built hull it holds. A dialog says what comes back,
what happens to her cargo and how long it takes; nothing starts until the
player answers Yes (default No).

- Who: a registered hull only by a member of the owning party or her listed
  captain (`breakup_refusal()`); an unregistered one by any Discord-verified
  player (`verified_discord_id()`).
- Refused while she is under way, grappled, bound on a voyage, has anyone
  alive aboard, or carries a vehicle.
- Parts (`berth_breakup_part_cost()`): floors, walls, the draught's fittings
  (`ship_draught_pieces()` and their kin as a survey draws them), gunwales,
  roofs and ladder heads. Everything else aboard (cargo, a chest's contents,
  engines and machines the draught tables do not know, bodies) is moved whole
  to the berth's tile.
- Back: each part's hand cost times its condition (`breakup_part_condition()`:
  health over max health where the part keeps them, 0.5 for a patched plank
  or a broken vehicle frame, else 1), summed and rounded down per material
  (`berth_breakup_reclaim()`), stacked on the berth's tile. A sound ship
  gives back all she cost and never more.
- Time: half of the slipway's build time, 1.5 s a floor and 2.5 s a fitting,
  through `yard_time()`. Work goes in 5 s steps; several people can work at
  once and the work done is kept on her tiller (`breakup_done`, not saved).
- `break_up()` decommissions her, moves the loose things, deletes fittings
  then floors and roofs, and closes her hold back to the ground it was cut
  from, like `sea_crossing_strip()`.

## Tests

`tests/naval_carrier/berth_probe.dm` (142 checks):

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/berth_probe.dm 300

## Sprites

`icons/obj/berths.dmi` is drawn by `tests/naval_carrier/berth_sprites.py`
(original pixel art by Fable 5.2; `--check` fails when the DMI is stale,
`--preview out.png` renders a sheet): `dock_gate_shut`, `dock_gate_open`,
`refit_add`, `refit_remove`, `refit_change`, `refit_turn` (light greys, tinted
by the mark's `color`), `yard_office` and `keel_blocks`. Keel blocks
(`/obj/structure/keel_blocks`, 6 wood, construction, Wagons & Ships) are
dressing for a dock floor or slipway berth and hold nothing up.
