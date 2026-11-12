# Craft core

The shared base for everything that moves as a whole: ships today, and later
airships, spacecraft, pods and trains. It lives in `code/modules/craft/` and
its constants in `code/__defines/craft.dm`. The ideas come from a review of
how Shiptest moves ships; all code and art here are Civ13's own.

Nothing in the game calls the core yet. Existing vessels, helms and saves
behave exactly as before.

## The pieces

| Type | File | What it is |
| --- | --- | --- |
| `/datum/craft` | `craft.dm` | Identity only: name, body, drives, register, chart token, berth, carrier and carried crafts. |
| `/datum/craft_body` | `craft.dm` | How the craft occupies and crosses the map. `template` wraps a `datum/vessel`. |
| `/datum/craft_drive` | `craft.dm` | One source of push: thrust, fuel, on or off. |
| `/datum/craft_register` | `craft_register.dm` | Owning party, crew roles, join mode, requests, barred list, memo. Saves as text. |
| `/obj/structure/berth` | `berth.dm` | A place a craft may arrive: size, owner, who is welcome. Hands out `/datum/berth_ticket`s. |
| `/datum/chart` | `chart.dm` | A map of tokens, sites and hazards, in mirror mode (tokens follow real positions) or steered mode. |
| `/datum/plane_pool` | `plane_pool.dm` | Claim and release of whole z-levels. `orbit` wraps the orbit registry. |

## Rules

- `datum/vessel` is not renamed or replaced. Helms save its type path, so a
  template body wraps it. `craft_of_vessel(V)` makes the craft on first use
  and `craft_at(turf)` finds the craft a tile belongs to.
- A vessel tells its craft about every hop and turn from `relocate()`, whoever
  asked for the move (the wheel, the hop timer or a body): `craft.on_hop(old_origin)`
  and `craft.on_turn(angle)`.
- When a craft turns, everything aboard gets `craft_turned(craft, angle)`.
  Objects and creatures turn their facing with the hull, and loose items also
  turn their pixel offset. A type whose facing must not follow the hull
  overrides `craft_turned()`. `craft_moved(craft, old_loc)` is for bodies that
  move things one at a time; a template body moves whole tiles and does not
  call it.
- Turn angles are the ones `turn()` takes (counter-clockwise positive). Use
  `craft_turn_angle(old_dir, new_dir)`.
- A craft nobody registered is open to anyone. Once a party owns it,
  `craft.may_steer(user)` asks the register.
- A berth is asked with `request(craft)` and answers with a ticket. A ticket
  that is not `granted()` carries the reason in `refusal`. `complete()` docks
  the craft and `cast_off()` frees the berth.
- Saved fields hold text and numbers only, never object references.

## Built bodies and sailing

`/datum/craft_body/built` (`built_body.dm`) is a hull the players laid as
`/obj/covers` floors over water. It keeps the hull as offsets from a pivot
tile, one level only, at most `BUILT_HULL_MAX_TILES`. A move snapshots what
stands on every tile, carries it to the matching tile of the new place and
hands the water level from the floors that leave a tile to the floors that
arrive; a turn rotates the offsets about the pivot. `built_hull_survey()`
finds the hull around a tile and refuses one still joined to the shore, to a
vessel or to another craft.

`under_way.dm` gives every craft the telegraph, anchor, hop timer, path
warning and delayed turn that vessels have, on top of `body.move_cells()`,
`can_move_to()`, `move_to()`, `turn_to()` and `turn_corner()`. A new kind of
body that implements those sails without more code. `craft.max_speed()` is
where drives will set the top telegraph step; a hull with none makes slow
ahead.

A body made of objects sets `glides` (`glide.dm`; the built body does). Such
a craft covers the same water in the same time one tile at a step:
`craft.sail_tiles()` is 1 and `craft.sail_interval()` is the hop interval
divided by the tiles a hop would cover (15, 7.5 and 5 seconds a tile at slow,
half and full ahead). Her drives still pay once per hop's worth of tiles. For
each step `under_way.dm` sets `body.glide_time`, and the body calls
`craft_glide()` on everything it carried: a thing square on its tile gets the
`glide_size` that makes the engine glide it for the whole step (given back when
it leaves her or she stops), and a thing the engine will not glide (a step
offset or unusual bounds, such as a free-moving human) is drawn one tile back
and slid forward by `animate()`, with the view of its player. Appearance only:
the server still moves her a whole tile at once. Turns, docking slides and
turf-built vessels are not glided. Not checked in a game client.

`/obj/structure/hull_tiller` (`naval/built_hull.dm`) is the helm of a built
hull: it commissions, refits and strikes the hull, steers her, keeps the
papers and saves the hull as offsets from its own tile.

## Drives aboard

`naval/hull_drives.dm`: anything standing on a craft can be a drive by
answering `craft_drive()` with a `/datum/craft_drive/fitted`. `craft.fit_drives()`
collects them (on commission, when a speed is rung and before each hop), and
`craft.max_speed()` weighs their push against the tiles of hull: half ahead
needs `CRAFT_THRUST_HALF` per tile, full ahead `CRAFT_THRUST_FULL` per tile
from drives whose `top_step` reaches full ahead. A rigged ship mast is a sail
drive of `CRAFT_SAIL_THRUST` that tops out at half ahead.

A running engine loose on a deck (`/obj/structure/engine`, not on a vehicle
frame) is an engine drive: it pushes its current `maxpower` and can make full
ahead. After each hop `craft.burn_drives()` asks every drive to pay for it at
`speed / VESSEL_SPEED_FULL` of full power; an internal engine pays from its
own fuel tank (`craft_burn()`, `engines/internal_combustion.dm`) and stalls
when it cannot, and an external engine's heat source is its fuel.

## Plane pools

`craft/plane_pool.dm`. `orbit_pool()` is the pool of an orbit world, over the
plane registry. Besides claiming and releasing planes it:

- empties a plane: `clear(z)` deletes everything on it and puts the base turf
  and area back, and `clear_refusal(z)` says why it will not (a character
  there, awake, asleep or logged out, or a bunk kept as home).
  `release(z, TRUE)` empties first and keeps the plane when it cannot;
- shares a plane in slots: with a `slot_size`, `claim_slot(owner, z)` hands
  out squares of a plane (`slot_box(n)`), one per owner, kept in the registry's
  `slot_owners`;
- caps loaded sites: owners named `site:...` hold one plane each and at most
  `site_cap` together;
- can be paused: `set_paused()` is kept in the registry's `pool_paused` and
  stops pool claims. Admins flip it with Server > Toggle Orbit Site Loading.
  Stations claim their own decks and sectors through `orbit_claim_plane()` and
  are not paused.

## Wiring aboard

`craft/rigid_move.dm`: cables, engines, generators, batteries and connectors
drop their links when they are moved. A body that carries cargo wraps the move
in `craft_rigid_begin(things)` and `craft_rigid_settle(carry)`: while it runs,
`craft_carrying()` is TRUE for the cargo and those types keep their links;
afterwards `craft_carried(aboard)` on each thing cuts only the links to what
stayed behind. Both the built body and `datum/vessel/relocate()` do this, and a
cable swaps its `tiledir` on a quarter turn. Piped barrels still disconnect.

## Steered charts

On a chart in `CHART_MODE_STEERED` a token has momentum (`craft/chart.dm`).
`set_burn(heading, throttle)` pushes it along a heading in degrees clockwise
from north, a throttle of 0 lets it coast, `order_stop()` burns against its
motion until it lies still, and `lay_course(x, y, name)` makes for a place and
stops there (`arrived()` is the hook). `eta()` estimates the seconds from rest.
A full burn is `craft.thrust_per_tile() * CHART_ACCEL_PER_THRUST` squares per
second per second, paid for through each drive's `burn()`; a token with no
craft uses its own `accel`. `chart.wake()` starts a timer that calls
`run_step()` every `CHART_STEP_SECONDS` and stops when nothing moves; a step
also counts hazards down and calls `affect_craft()`. `contacts_of()` cuts the
sensor range by the `interference` of hazards at the viewer and at the target.

`craft/chart_helm.dm` is the console: `/obj/structure/chart_helm` reads the
chart and steers the token of the craft it stands on (burn, cut, full stop,
lay a course), behind the same helm access as a ship's wheel, and saves the
token's place and speed as plain numbers. It is a base with no recipe; a
subtype answers `chart()`.

`space/orbit_chart.dm` is the first steered chart: `orbit_chart()` on an orbit
world, 100 squares across with the arrival beacon in the middle and a station
token for every party that owns a plane, at a spot the plane registry keeps in
`chart_spots`. `/obj/structure/chart_helm/orbit` steers on it; no craft
carries one until the plane pool phase.

## Sea chart and harbours

`naval/craft_chart.dm`: `sea_chart(z)` is the mirror chart of a sea level, in
squares of `SEA_CHART_SQUARE` tiles. `refresh()` rebuilds its tokens from the
crafts and mooring posts really on that level; nothing ticks, the chart is
refreshed when read. `craft.sea_chart_text()` is what a helm shows: her square,
ships within her token's `sensor_range` (a `dark` token is an unknown contact)
and every harbour with the answer its berth would give her.
`sea_boat_contacts()` and `sea_aircraft_contacts()` are the modular boats on a
level and the aircraft over it within a reach; the chart lists them as far as
the lookout sees and the carrier's radar lists them to its own range, so both
read one list. A boat or aircraft with vehicle papers goes by the name in
them (`sea_contact_name()`).

A mooring post (`/obj/structure/berth/quay`) is the first real berth. A craft
within `QUAY_DOCK_RANGE` calls `order_dock(post)`: the post's `request()` gives
a ticket, `berth_plans()` says where she would lie (along the shore, abreast of
the post, on the post's `water_side()`), the water is marked, `body.hold()`
stops her hops, and `finish_dock()` moves her `QUAY_DOCK_WARNING` later, makes
her fast and completes the ticket. `craft.on_hop()` and `on_turn()` cast off,
so a moored craft that moves is no longer moored. Moorings are not saved.

## The open sea

An open-sea region (shard kind `OCEANIC`, `maps/sea/open_sea.dmm`,
`/obj/map_metadata/nomads/open_sea`) is the Shiptest loop at sea: ships are
built in the home waters, make passage on a steered chart, and the islands and
wrecks they reach are built when they arrive. No live region runs it yet;
[open-sea-region.md](open-sea-region.md) has the setup steps.

- **Cells** (`naval/open_sea.dm`). The sea level is cut into squares of
  `SEA_CELL_PITCH` tiles by tide races (`/turf/.../saltwater/tide_race`, dense,
  nothing passes or is built on them) `SEA_CELL_MARGIN` wide on every side, so
  nobody in one cell sees or reaches the next. `sea_cell_of()`,
  `sea_cell_box()`, `sea_home_cell()` (the middle one). A cell is a square of
  the one level, not a level: saves, digging, weather and lighting are those of
  any surface map, and nothing grows the world.
- **Pool** (`/datum/plane_pool/sea`, `sea_pool()`). Its "planes" are cell
  numbers. A cell is free when no loaded site lies in it, no craft and no
  living or logged-in character, so only site-to-cell has to be saved.
  `clear()` deletes what is in the cell, closes the sea and restores the rock
  under it; it refuses while a character, a ship or a claimed bunk is there.
- **Sites** (`naval/open_sea_sites.dm`, `/datum/chart_site/sea`). `load()`
  claims a cell and calls `build(box)`; `unload()` clears it. An island is
  built from its seed (`/datum/sea_dice`), so it rises the same each time. A
  wreck is broken ship floors with crates; with a tiller she can be sailed.
  `watch()` starts a `SEA_SITE_LINGER` count once nobody is there, and the
  chart sweeps for that every few minutes. A site with a mooring post in its
  cell is a harbour and stays, for up to `SEA_KEPT_CAP` sites; at most
  `SEA_SITE_CAP` sites are loaded at once. New kinds are new subtypes with a
  `build()`.
- **Chart and passage** (`naval/open_sea_chart.dm`, `open_sea_chart()`). The
  home waters are a token in the middle; each site has one. The tiller's
  **Open sea chart** lays a course, steers by compass or heaves to. An order
  given at a place calls `put_to_sea()`, which moves the hull to the middle of
  a free cell; when the token arrives, `open_sea_arrive()` loads the site and
  `open_sea_shift()` moves the hull to lie near the edge of its cell
  (`open_sea_berth()` tries each side). Where a ship is on the chart is read
  from where her hull lies (`open_sea_place()`), her token's place and motion
  are saved by the tiller with the hull, and the sites by
  `/obj/structure/sea_registry` as one text. Her drives pay once per half
  minute under way.
- On an open-sea world the lookout, the sea chart and the berth menu only see
  the ship's own cell (`sea_same_waters()`).
- The home island is built by `open_sea_prepare()` the first time the world
  boots, while the middle of the home waters is still open sea.
- **The harbour office** (`naval/sea_office.dm`). `sea_office_place()` stands
  a board on the home island. It is a contract board whose poster is the
  world: `fill()` offers up to four `/obj/craft_contract/sea` jobs when
  somebody reads it, each with silver in its record. A **survey** is done when
  the taker's ship anchors off the island (`sea_office_arrived()`, called by
  `open_sea_arrive()`); reporting it pays and sets the site's `charted`, which
  is saved with the sea and puts the island in every ship's course list from
  any distance. **Salvage** is paid for a crate branded `salvage_of` the
  wreck, set down by the board: the board keeps the crate and leaves what was
  in it. A crew takes a contract with a registered ship lying in the home
  waters and can give it up.

## Contracts and freight

`craft/contract.dm`: a contract is a record object (`/obj/craft_contract`)
that lies inside the board that offered it, so the world save keeps it there
with its reward in its contents. It is `CONTRACT_OPEN` until a registered crew
takes it (`take(H, craft)`, with `craft_contract_crew_craft()` finding the
ship whose papers list the taker within reach of the board), `CONTRACT_TAKEN`
while it is carried out and `CONTRACT_RETURNED` when it ended unearned
(`give_back(why)`): the reward then waits for the poster to `collect()`. A
contract that is carried out calls `pay(H)` and deletes itself. A new kind of
job is a subtype; a new kind of board keeps the records in its contents.

`naval/freight.dm` is the first kind: `/obj/craft_contract/freight`. The
mooring post is the board ("Freight" in its menu). `offer_freight(H, crate,
destination post, reward item)` takes a closed crate and the reward into the
record; taking it sets the sealed crate down beside the taker;
`hand_in(H)` at the destination post pays whoever brought the crate, seal
whole. A crate knows its contract by `freight_id` (the global `freight_crates`
is rebuilt by the crate's `after_load()`); opening it sets `seal_broken`,
which turns a hand-in into a returned contract. The poster can `withdraw()`
an open offer and `write_off()` a taken one whose crate no longer exists. A
destroyed post spills what it held. The post and the sea chart say how many
contracts are on offer.

## Hails and running dark

`naval/craft_signals.dm`: `craft.hail(other, text, from)` calls across to a
craft within `lookout_range()` on the same level; both crews hear it and the
receiver keeps it in `last_hail`. `craft.set_dark(state)` sets `running_dark`
(not saved): her token is `dark`, `knows(other)` is false for crafts of other
owners, so charts, radar and hails call her "unknown contact" or "an unknown
ship". A dark craft makes slow ahead at most (`craft.max_speed()`,
`vessel.speed_cap()`), and a template ship's deck lights go out
(`body.dark_changed()`). New craft kinds get both from the base; a helm only
needs `hail_menu()` and `dark_menu()` entries.

## Vehicles aboard

`craft/vehicle_aboard.dm`: a modular vehicle whose every frame stands on a
craft's tiles rides with her as cargo. Its axis and wheels sit inside frames,
so `frame/craft_turned()` turns the axis heading and wheels when the craft
turns; the result equals `axis.do_matrix()`. `craft_overhang(turfs)` finds a
vehicle with frames both on and off the craft, and both move planners
(`built.plan()`, `vessel.plan_move()`) refuse while one stands half aboard.

## Tow lines

`craft/vehicle_tow.dm`: a `/datum/vehicle_tow` joins a tug axis and a towed
axis that stood in line behind it (`axis.tow_plan()`, `hitch_tow()`). It keeps
a queue of what the towed vehicle has still to do: one move for every tile it
stood behind, then every move and turn of the tug. After each tug move the
towed vehicle works through the queue with its own `do_move()` and
`do_matrix()`, so it turns where the tug turned. It parts when more than
`TOW_SLACK` moves are owed. The file hooks `do_move`, `do_matrix`,
`get_weight`, `Destroy` and the frame's `attackby` by redefining them and
calling on, so the vehicle files are untouched. Test: `tests/vehicle_tow`.

## Weather and murk at sea

`naval/sea_weather.dm`: `sea_murk_at(turf)` is what the area's weather takes
off a lookout there (wet 10, smog 20, extreme 25 tiles) plus the
`interference` of any `/datum/chart_hazard` the level's sea chart holds over
that square (in tiles on a sea chart). `craft.lookout_range()` is her range
where she lies; `craft.sights(other)` uses the worse murk of the two places,
and by night caps a ship running dark at `SEA_DARK_NIGHT_RANGE`. The sea
chart and hails go through `sights()`; radar does not. To add a fog bank or
a squall, put a hazard in `sea_chart(z).hazards`.

## Grappling and boarding

`naval/craft_grapple.dm`: `craft.order_grapple(other)` links two crafts with a
`/datum/craft_grapple` when `grapple_plan()` finds a straight run of at most
`GRAPPLE_REACH` tiles of open water between their hulls. Both bodies are held
(`body.hold()`), so neither hops, turns or docks, and boarding lines
(`/obj/covers/repairedfloor/rope/boarding`, never saved) lie across the gap.
`grapple.release(by, who)` frees both and starts the thrower's cooldown; a
destroyed line or a deleted craft releases too. `hull_floor_in()` keeps the
lines out of hull surveys. A helm needs `grapple_menu()` and
`grapple_refusal()`.

## Ship's papers

`code/modules/naval/ship_papers.dm` is the first user of the register. The
ship's wheel has a "Ship's papers" entry: a player registers the ship to
their party, and owners or the captain sign crew on, change roles, bar
people, set how she takes new crew and write a memo. `craft.helm_access(user)`
answers `CRAFT_HELM_FREE` for owners and steering crew, `CRAFT_HELM_FORCE`
for anyone else while an owner is in the world (the wheel can be forced,
slowly, with the crew warned) and `CRAFT_HELM_CHAINED` when no owner is
about. `craft.fitting_refusal(user)` guards levers and the radar the same
way without the delay. The wheel saves the register in `register_state`.

The menu is one for every kind of craft. A craft type that is not a ship
sets the words it is read in (`papers_title`, `kind_word`, `helm_word`,
`helm_stance`, `sail_word`, `pro_she`, `pro_her`, `pro_hers`), overrides
`role_title(role)` to rename the roles, and adds entries of its own with
`papers_extra()` and `papers_extra_action()`. Roles are always stored as the
`CRAFT_ROLE_*` values.

## Vehicle papers

`code/modules/craft/vehicle_papers.dm` puts modular vehicles on the core. A
vehicle is a `/datum/craft/vehicle` with a `/datum/craft_body/axis` (its
cells are the tiles its frames stand on; it has no `move_to`, the axis still
drives itself). `craft_of_axis(axis, make)` makes it the first time it is
asked for. Vehicle crafts live in `vehicle_crafts`, never in `crafts`, so
charts, hails, grapples and radar do not see them.

The driver's seat has a "Vehicle Papers" verb that opens the same papers in a
vehicle's words (commander, driver, mechanic, gunner, crewman). The steering
wheel item asks `axis.papers_allow()` before it starts the engine or changes
up and `axis.papers_steer()` before it turns: crew drive freely, a stranger
must force the controls while an owner is in the world (remembered in
`forced_by` until the crew take it back) and is locked out otherwise.
Slowing and stopping are never locked. This sits beside the vehicle key, it
does not replace it. The axis saves the register in `register_state`.
Turret controls ask `vehicle_fitting_refusal(turret, user)` before they fire:
`craft.fitting_refusal()`, the rule a ship's levers follow.
Owners can name the vehicle, and "Our vehicles" lists every registered
vehicle of the reader's party with its distance and bearing
(`party_vehicles(party)`, `craft.where_text(from)`).

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/craft_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/papers_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/freight_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/built_hull_probe.dm 300
