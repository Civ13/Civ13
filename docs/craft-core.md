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
half and full ahead). Her drives still pay once per hop's worth of tiles. A craft's `pace` (1 everywhere
else) divides that interval: the Broadside TDM map sails its ships at pace 4. For
each step `under_way.dm` sets `body.glide_time`, and the body calls
`craft_glide()` on everything it carried: a thing square on its tile gets the
`glide_size` that makes the engine glide it for the whole step (given back when
it leaves her or she stops, and at once when anything but her own step moves
it, so a shove, pull, throw or current never draws a move at her pace;
`craft_glide_was` on the thing names the record holding it and is never saved), and a thing the engine will not glide (a step
offset or unusual bounds, such as a free-moving human) is drawn one tile back
and slid forward by `animate()`, with the view of its player. Appearance only:
the server still moves her a whole tile at once. Not checked in a game client.

A built hull with a player near does not use that glide: she sails by pixel
offsets instead (`vehicle_offset_hull.dm`, see [docs/vehicle-offset.md](vehicle-offset.md#built-hulls-under-way)),
creeping a pixel at a time at the same pace, and her crew walk her deck as she
goes. The glide above is what she does when nobody is near to see.

Modular vehicles and frame boats glide the same way: `axis.do_move()` calls
`glide_step()` with what it moved, which shows every frame, wheel, thing and
person carried through the shared `glide_show()` for `vehicle_m_delay + 1`
ticks, and `glide_rest()` gives the glides back when the vehicle stops.

Turns swing round instead of snapping. After a built hull's `move_to()` with
a turn, and after `axis.do_matrix()`, each thing carried goes through
`glide_swing()` for `glide_turn_time()` (5 ticks): a thing that moved one tile
glides there, and a thing that moved further, which the engine will not glide,
is slid there by `glide_slide()` with a sine ease. Sprites take their new
facing at once; only the travel is drawn. A spacecraft's thruster step
(`thrust_one()`) sets `glide_time` on her turf body, whose `shift()` glides
what she carries and slides her tiles with `glide_slide()`; her jumps between
levels and slots are not glided.

A built hull's slide into a berth is drawn too: `finish_dock()` sets
`body.slide_time` to `glide_dock_time(tiles)` (three ticks a tile, one to four
seconds) for its one `move_to()`, and everything aboard travels to its new
place over that time. Template vessels (`datum/vessel`) still jump.

`/obj/structure/hull_tiller` (`naval/built_hull.dm`) is the helm of a built
hull: it commissions, refits and strikes the hull, steers her, keeps the
papers and saves the hull as offsets from its own tile.

### Pushing her off by hand

A built hull only sails along her heading and swings round her pivot, so one
run up against a shore can be stuck. `naval/hull_push.dm` lets people standing
beside her, ashore or in shallow water (never on her deck or in deep water),
click a plank with an empty hand to heave for three seconds. Heaves the same
way within five seconds add up by strength; an average person moves about
`HULL_PUSH_TILES_PER_PERSON` (20) tiles of hull. Enough strength moves her one
tile away from them with `move_to()`, keeping her heading, drawn as a one-second
glide. She cannot be pushed under way, while turning, on a voyage or during a
save, and `plan()` still refuses land and anything solid.

### Upper decks

A roof built over a built hull's deck has its walkable upper face on the
building level above (`building_levels.dm`). That upper deck sails with her:
`upper_cells()` finds it again at every move by position, as the floor above
each hull tile whose roof stands on that tile, or the top of a ladder whose foot
does. Nothing about it is saved and no field links one deck to the other, so a
loaded world finds the upper deck the same way. `plan()` refuses a move when the
open air ahead of the upper deck holds a floor, a ladder or anything solid, and
when her hull and upper deck together pass `BUILT_HULL_MAX_DECK_TILES` (300). A mast
(`/obj/structure/vehicleparts/movement/sail`) on a tile with no upper deck
over it stands up through the level above too: `mast_tile_refusal()` stops her
when a floor, a bridge or anything solid is there.
`move_to()` carries the lower deck first, then the upper floors and ladder tops,
then whoever stands up there, so nobody reaches open air without a floor. A
roof makes the tile under it indoors, so the areas of her tiles sail with her
and the sea's areas close in behind. Measured in
`tests/naval_carrier/upper_deck_probe.dm`, a sailing step at the cap (asking
`can_move_to()` and then moving, as the sailing loop does) with ten sailors and
ten buckets aboard takes about 12 ms, and a bare 200-tile hull about 7.5 ms.

Three things keep a step cheap. Her own floors and roofs (`craft_quiet_carry()`:
a cover that is not a wall, not dense and not opaque, or a roof) are carried by
`craft_quiet_move()` in `glide.dm`, which sets their place and keeps the save
gate, the sight caches and the level views, but skips the Entered, Exited and
Crossed callbacks that nothing listens to for them; anything else aboard still
goes by `forceMove()`. `can_move_to()` keeps its plan for the `move_to()` that
follows in the same tick (`plan_memo`, keyed on her place, the target and
`world.time`), so a step is planned once. And a step without a turn keeps her
offsets list and its box (`offset_box`) instead of rebuilding them.
A hull with an upper deck crosses the sea and sets out on voyages with it
([ship-crossing.md](ship-crossing.md#holds-and-cargo)).

A roof built on her upper deck makes a second deck above, its floor one
building level higher again. `top_cells()` finds it the same way from her upper
deck tiles, `plan()` checks the air ahead of it like the upper deck's and counts
it toward the deck cap, and `move_to()` carries it after the upper deck. A roof
on the upper deck makes the tiles under it indoors, and those areas sail with
her too (`built_hull_areas_before()`). It crosses the sea with her as
`record["top"]` ([ship-crossing.md](ship-crossing.md#holds-and-cargo)).
Measured in `tests/naval_carrier/second_deck_probe.dm`.

### Holds

A built hull can also carry a hold on the level below her deck
(`naval/hull_hold.dm`): `/obj/covers/steelplating/hold` floors (any cover with
`hold_origin` set) on `/turf/floor/plating/ship_hold` tiles under her own hull
tiles. `lower_cells()` finds it again by position, like the upper deck. A hold
is hollowed out of rock or deep water only (`hull_hold_ground()`); the rock
left around it is her hull below the waterline. At each move
`before_hold_move()` turns the tiles the hold arrives on into `ship_hold`,
the hold's floors, ladders and cargo are carried, and `after_hold_move()` gives
the tiles it left their ground back. Each hold floor keeps the turf type it
hollowed (`hold_origin`, text, saved with it). `plan()` refuses a move when
the ground ahead of the hold is anything else or holds something solid, and
counts the hold in `BUILT_HULL_MAX_DECK_TILES`. `carries()` answers for all
her decks, so an engine in the hold drives her. An airship has no hold. A
hull with a hold crosses the sea with it ([ship-crossing.md](ship-crossing.md#holds-and-cargo)).

### Airships

Basic wooden dirigibles use the 1903 Lighter-than-Air Flight research, after
Wagons & Ships and Utilities. Craft wooden airship planks and the helm from
wood, a gas cell from cloth, and a gasbag from leather. The Utilities water-gas
retort makes hydrogen from water and coal or charcoal. Fill the gasbag at the
retort, then use it on the hung gas cell. A basic airship can make slow ahead
without an engine. Powered Flight still gates the aircraft, metal airship frames
and bomb hatch, and anyone who already knows Powered Flight keeps access to
the wooden kit.

`naval/air_hull.dm`: `/datum/craft_body/built/air` is a built hull laid as
`/obj/covers/airship_deck` planks on the ground or the open-air level, started
anywhere clear on the ground or beside a ladder top and grown edge to edge (`air_deck_lay_refusal()`), at most 60 tiles. Its
`tile_refusal()` takes only clear open air, it has no upper deck, and `plan()`
refuses any move while her gas cells (`/obj/structure/airship_gas_cell`, 12
each) hold up less than her tiles plus the people aboard. `move_to()` carries
floors before anything else on a tile, so nobody reaches open air without the
deck under them. `/datum/craft/air` never creeps by pixels, keeps only engine
drives, and redraws a ground view for the crew and a shadow for the ground on
every hop. `/obj/structure/airship_helm` commissions, steers and saves her;
a restored airship holds her position. Ground fire crossing a tile under her
deck goes through `air_hull_overhead_fire()` (from `airborne_overhead_hit()`):
`struck_by()` hits someone aboard, holes a cell (3 lift each, cloth patches) or
burns it out with fire arrows and incendiary shot, then `check_lift()` holds
her in place when short of lift and calls `crash()` below half of it, which
drops everyone and everything aboard to the ground. `/obj/structure/airship_bomb_hatch`
drops aircraft bombs onto the ground below. She can fly on any open-air level:
her views, wreck and bombs reach the first solid level under her
(`air_hull_solid_below()`), ground fire reaches her only through open air
(`air_hull_levels_between()`, half the chance per extra level), and a click on
open air from her deck aims at what is seen through it (`airborne_aim_turf()`).
A deck can also be laid on clear, level ground (`air_ground_open()`); while
`landed()` she creeps only over such ground. `lift_off()` raises her a level
when she has the lift and nothing overhead, and `land()` lowers her a level at
a time onto clear ground with no tree below (`land_refusal()`, rechecked each
level). Short of lift, `check_lift()` starts `sink()`: she comes to rest on
floors and roofs, flattens trees under at most a quarter of her tiles (holing
the cells over them) and snags in more (`tear_on_tree()`). A wreck over a tree
drops people beside its trunk (`air_hull_beside()`), and a pedal airship forced
down over a forest snags in the tree below until it comes down
(`snag_in_tree()`, `pedal_airship_tree_gone()`).
Deck tiles weigh by `air_weight` (wood 1, aluminium 0.5, steel 2) in `load()`;
only wood catches fire (`air_deck_catch_fire()`), and trees under `snag_proof`
steel tiles never snag her. Gas cells set `max_lift` and `hole_lift`: cloth
12/3, rubberised (5 plastic sheets on a cloth cell) 12/2, goldbeater's skin (6
sausage casings) 15/5.
Cells hang empty and lift in proportion to their `gas_amount` (60 fills one)
of hydrogen, or helium at nine tenths, and only hydrogen burns
(`flammable_gas()`). `naval/gas_works.dm` makes and keeps the gas as the
ordinary hydrogen, helium and oxygen reagents: `/obj/structure/gas_works`
(hydrogen generator, powered electrolysis tank giving hydrogen and oxygen,
water-gas retort, powered helium separator beside a working oil well) are pipe
sources stepped from `factory_fluids_step()`; the gas holder is a pipe buffer
and feeds cells through a gas hose; gasbags carry it by hand, and steel
cylinders are filled only by a powered gas compressor (a pipe sink). Oxygen
from a bag or cylinder eases someone short of breath.
Native probe:
`tests/pedal_bicycle/ride.py --probe air_hull_probe.dm`.

## Drives aboard

`naval/hull_drives.dm`: anything standing on a craft can be a drive by
answering `craft_drive()` with a `/datum/craft_drive/fitted`. `craft.fit_drives()`
collects them (on commission, when a speed is rung and before each hop), and
`craft.max_speed()` weighs their push against the tiles of hull: half ahead
needs `CRAFT_THRUST_HALF` per tile, full ahead `CRAFT_THRUST_FULL` per tile
from drives whose `top_step` reaches full ahead. A rigged ship mast is a sail
drive of `CRAFT_SAIL_THRUST` that tops out at half ahead. Its push is divided
by `sail_delay_factor()` (`naval/points_of_sail.dm`) for how the wind stands
to her bow: full on a beam or broad reach, 1.3 times less running before the
wind, 2.5 times less close-hauled and 3.5 times less beating upwind. Frame
ships (`ships/axis.dm`) and sailing boats (`transports.dm`) take their step
delay from the same file (`sail_step_time()`), and a frame ship under sail
keeps `currentspeed` at gear 1 instead of writing a delay into it.

A manned rowing bench (`naval/rowing_bench.dm`) is an oar drive of
`CRAFT_OAR_THRUST` that can make full ahead. Its fuel is the rower's stamina:
`OAR_STAMINA_PER_STEP` per telegraph step at each burn, and a rower under
`OAR_MIN_STAMINA` pushes nothing. Oars are not `sustained`, so
`craft.sustained_full_ahead()` (which paces a world chart voyage) counts only
engines. The steering oar is a cheaper `hull_tiller` subtype; benches and the
helm type cross between worlds in the ship record (`"o"` entries and `"helm"`).

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
`chart_spots`. `/obj/structure/chart_helm/orbit` steers a spacecraft on it
(below). A console subtype adds its own orders with `extra_orders()` and
`extra_order()`, and `ordered()` is called before any order is carried out.

## Chart hazards and sectors

`craft/chart_hazards.dm` builds on the `/datum/chart_hazard` base. Every
step of a steered chart calls `chart.hazard_step()`: each hazard drifts by
its `vx`/`vy` (turning back from the chart's edge and from a sector that
keeps hazards out), `entered()` tells a crew once when their craft comes
inside, `affect_token(token, seconds)` acts on every craft token inside that
is `exposed()` (a token whose craft lies at a place is not), lifetimes count
down, and every `CHART_HAZARD_ROLL` seconds of chart time one hazard from
`passing_table()` is brought on by `spawn_passing()` while fewer than
`hazard_cap` are passing. `standing_hazards()` are laid once at fixed spots
(`standing_spot()`), so nothing is saved and a restart moves nothing. A chart
only steps while something on it moves, so weather costs nothing on an empty
sea. `hazard_lines(token, unit)` is what a helm reads.

Kinds: `field` (asteroid field, `field/reef`) strikes a craft going faster
than `safe_share` of her top speed, halving her speed and calling
`craft.hazard_struck()`, which batters the body through
`body.hazard_damage()` (a built hull takes it on one plank, never below
`CHART_STRIKE_FLOOR` of its health; other bodies take none yet); `storm`
sets her along `blow` and carries `interference`, `storm/solar` only blinds;
`wormhole` throws her to its `twin`, leaves her alone for
`CHART_WORMHOLE_REST` seconds and closes with its twin.

`/datum/chart_sector` is a box of a chart with rules: `hazards` (FALSE keeps
them out, as `sector/harbour` does), `boarding` (FALSE makes
`craft.order_grapple()` refuse through `sector_boarding_refusal()`) and
`owner` for `sector/held`. The open sea has reefs, squalls and a harbour
sector over the home waters; the orbit chart has asteroid fields, solar
storms, wormhole pairs and a harbour sector round the arrival beacon. Both
leave boarding allowed. A test that must not meet weather sets
`chart_hazards_off`; one chart is quietened with `hazards_on = FALSE`.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/hazards_probe.dm 300

## Turf bodies and spacecraft

`craft/turf_body.dm`: `/datum/craft_body/turfs` is a hull made of turfs, kept
as offsets from a pivot. `shift(x, y, level)` takes the type and facing of
every tile and everything standing on it to the matching tiles of the new
place, on the same level or another, inside one rigid carry, and leaves
`open_turf` behind. `plan()` checks every tile the hull does not already
cover with `tile_refusal()`; `ready_refusal()` is where a subtype says the
hull cannot move as built. It does not turn, and it assumes the levels it
moves between share one area.

`space/spacecraft.dm`: a spacecraft is the habitat module an orbital helm
stands in and every module docked to it, up to `SPACECRAFT_MAX_MODULES` (5).
The helm reads the hull again (`survey()`) each time it is used, so modules
docked or folded later are picked up; a node module, a hull built into a
module that is not docked to her, a second helm or a region gate aboard keep
her from flying, and the console says why. The helm holds the propellant
(rocket propellant poured in, `SPACECRAFT_TANK` 120) and is her one drive.

- Lying off a place her token is pinned to that place's token. Which place
  is read from the plane her hull is on (`lies_at()`): the arrival beacon, a
  station, or nothing in the lanes.
- A burn or a course calls `depart()`: she is given a slot of the lanes
  (planes owned by `transit`, 32-tile slots, claimed past the pool's pause
  like a station's own planes) and shifted there. `spacecraft_lanes_sweep()`
  frees the slots of ships that are gone.
- `arrived()` calls `arrive()`: the station token under her names the level,
  `spacecraft_welcome()` asks whether her party (the party of whoever last
  gave an order) owns the station or one of its docking ports welcomes it,
  and `berth_on()` finds clear space nearest the middle of the plane with two
  tiles free all round. Refused, she holds off in the lanes.
- "Thrusters" at the helm moves her up to 8 tiles, one every half second, a
  unit of propellant a tile, only while she lies off a place.

The orbital helm has a recipe (electronics, with the other spaceflight
fittings). No orbit region runs yet, so the probes are what exercises this.

## Encounter sites in orbit

`space/orbit_sites.dm`: `/datum/chart_site/orbit` is a place on the orbit
chart that is built on a pool plane when a spacecraft reaches it. A fresh
chart seeds `ORBIT_SITE_DERELICTS` (5) derelicts and `ORBIT_SITE_FIELDS` (3)
asteroid fields, at least 10 squares from the beacon and 7 from each other
and from stations.

- `load()` claims a plane as `site:<id>` through the pool, so the site cap
  (4) and the admin pause apply, and calls `build(z)`. A ship that reaches a
  site that cannot load holds off in the lanes.
- A derelict is one to three dead habitat modules rolled from the site's
  seed: no air, the cold of space, one hole in the hull, salvage crates
  (steel, glass, electronics, copper, sometimes a hull patch kit or a module
  kit) and sometimes a life support machine. Patched and aired it is an
  ordinary module, and a helm makes a ship of it.
- A field is 6 to 11 small asteroids (`orbit_asteroids.dm`) that keep their
  place, with fresh rock each time it loads.
- A loaded site is looked at every `ORBIT_SITE_LOOK` (5 minutes). Two looks
  in a row with no ship there and nothing `clear_refusal()` protects (a
  character, a bunk kept as home) empty the plane and give it back. A
  derelict that was visited is then removed and another is seeded elsewhere;
  a field stays on the chart.
- `contacts_of()` on the orbit chart always lists the beacon and stations.
  A site is listed inside sensor range and from then on (`charted`).
- The registry saves the sites as one text (`site_state`): place, seed,
  charted, visited and the plane each loaded site holds.

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
  `sea_cell_box()`, `sea_home_cell()` (the middle one). The home waters are a
  block of `SEA_HOME_SPAN` cells on a side round it with no race inside
  (`sea_home_block()`); every tile of the block reads as the home cell, whose
  box is the whole block. A cell is a square of
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
- **Meeting at sea.** The chart lists other ships at sea in sight
  (`open_sea_sails()`; one running dark only within a third of that). **Close
  a sail** lays a course for where she is now; on arriving within
  `CHART_ARRIVE_RANGE` of her token `open_sea_meet()` moves the hull into her
  cell, where hails, sightings and grapples work as in any waters. Whichever
  then sails on parts company: `put_to_sea()` gives her a cell of her own.
- On an open-sea world the lookout, the sea chart and the berth menu only see
  the ship's own cell (`sea_same_waters()`).
- The home island is drawn into the region map by
  `tools/open_sea/make_map.py`. On a map whose home waters are empty (a
  fixture), `open_sea_prepare()` raises a small one instead.
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

## Cargo

`craft/craft_cargo.dm`: every carrier asks one question of each thing on its
tiles, `M.craft_cargo()`: built hulls and airships at every step (deck, upper
deck and hold), turf-built vessels at every hop and turn, spacecraft, frame
ships and modular vehicles as they gather what they move, a sinking or
wrecked hull, the carrier's elevators, and a ship packed for a crossing.
Anything that stands in the world is cargo by default: floors, structures,
crates and chests with what they hold, machines (`/obj/machinery`, which frame
ships and vehicles now carry too), items, carts and small boats, animals and
people. It answers FALSE for what only draws something or is not really there:
lighting, flick animations and speech bubbles (`/atom/movable/overlay`,
`/obj/chat_text`), aiming marks, stack badges, HUD objects, map metadata, a
vessel's wake, ghosts and admin observers, lobby players, `dview` and agent
proxies. A thing that must stay where it was laid answers through
`craft_left_behind()` (naval mines, boathouse piles), which the default calls.
A new type that should never ride overrides `craft_cargo()`; one that should
ride needs nothing. Probe: `tests/naval_carrier/cargo_probe.dm`.

## Ships between worlds

A built hull at the map edge can cross to another world of the group (a land
across the sea, or home to the mainland): she is packed as a record that rides
with her crew's travel payloads and built again off the far edge. See
[ship-crossing.md](ship-crossing.md). Off a mainland she can also set out on
a voyage across the world chart, to a land opened for her while she sails or
to scout: [ship-voyage.md](ship-voyage.md).

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

`naval/freight_depot.dm` puts the same board on land:
`/obj/structure/berth/quay/depot` (recipe "freight depot", Wagons & Ships).
It is a quay with `takes_ships = FALSE`, so sea charts and docking leave it
out, while freight can be posted from a mooring post to a depot and back. A
board names itself by `post_word` and `place_word`, and finds the taker's
craft with `freight_crew_craft(H)`: the depot looks through `vehicle_crafts`
and `crafts` for one whose papers list the taker within `FREIGHT_DEPOT_REACH`.

`naval/depot_jobs.dm` is the depot's own work, `/obj/craft_contract/land`,
kept apart from freight (`jobs()` against `contracts()`). `fill_jobs()` keeps
up to three offers when the board is read, at most once every
`DEPOT_JOB_REFILL`; `find_spot()` picks open ground 60 to 220 tiles off
(`depot_job_ground`). A survey hands out a stake (`/obj/item/depot_guide/stake`)
that is driven in at the spot and reported back; lost cargo sets a crate down
at the spot when it is taken and pays when the crate is brought within two
tiles of the depot. Pay is made on the spot by `offer_job()` from the
distance. A party holds two of a depot's jobs at most. A new kind of land job
is a subtype with its own `job_text()` and a line in `fill_jobs()`.

Jobs a board makes up and pays for itself are switched off:
`npc_jobs_enabled` (`craft/contract.dm`) is FALSE, so `fill_jobs()` and the
harbour office's `fill()` offer nothing and the depot's menu has no "Depot
work". Only contracts one player posts for another are on offer. Probes set
the switch to exercise the jobs.

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

## Boats carried on ships

`craft/deck_berth.dm`: `/obj/structure/berth/deck` is the boat davit (recipe
"boat davit", wagons and ships research), a berth that stands on a ship's
deck. Its `cradle()` is `berth_length` tiles ahead of it by `berth_beam` to
the right of that way, so it turns with the deck. `hoist_plan(axis)` and
`launch_plan(axis, way)` write nothing and answer with offsets or the reason
in plain words; `hoist()` and `launch()` move the whole boat with
`axis.shift_vehicle_level()`, crew and cargo included. A boat is hoisted from
within `DECK_BERTH_REACH` tiles on her waterline level (`sea_z()`) and
lowered to the first clear water within `DECK_BERTH_SWING` tiles of her side.
A boat in a cradle refuses to sail (`axis.in_cradle()`).

Whatever vehicle stands wholly in a cradle is berthed aboard: `refresh()`
sets the davit's `occupant`, the vehicle craft's `berth` and, through
`craft.take_aboard()` / `set_down()`, the `carrier` and `carried` links
(rings refused). Nothing of that is saved; it is found again from what
stands there. After each hop `craft.on_hop()` calls `tell_carried()`, which
calls `on_carried()` on every carried craft in nesting order: the hook for
anything a carried craft must do when its carrier moved it. The sea chart
lists carried boats as "In her davits" and leaves them out of the boats in
sight. A new kind of deck berth (an aircraft tie-down, a pod port) is a
subtype that changes `cradle()` or what `vehicle_in()` accepts.

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/deck_berth_probe.dm 300

## Tow lines

`craft/vehicle_tow.dm`: a `/datum/vehicle_tow` joins a tug axis and a towed
axis that stood in line behind it (`axis.tow_plan()`, `hitch_tow()`). It keeps
a queue of what the towed vehicle has still to do: one move for every tile it
stood behind, then every move and turn of the tug. After each tug move the
towed vehicle works through the queue with its own `do_move()` and
`do_matrix()`, so it turns where the tug turned. It parts when more than
`TOW_SLACK` moves are owed. The file hooks `do_move`, `do_matrix`,
`get_weight`, `Destroy` and the frame's `attackby` by redefining them and
calling on, so the vehicle files are untouched. Aircraft tow and are towed
only on the ground: `tow_plan()` refuses an airborne one, and a plane on a line
does not take off (`try_takeoff()`). Test: `tests/vehicle_tow`.

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


## Vehicle assembly

`code/modules/craft/vehicle_assembly.dm` is how a land vehicle is built by
hand. `/datum/vehicle_survey` starts from the frame an axis stands on and
takes every loose land frame joined to it (frames of another vehicle and ship
frames are not taken). It sets `refusal` in plain words when the frames are
not a filled rectangle between 2 by 2 and 5 by 5, and otherwise lists the
engine, fuel tank, driver's seat and corner wheels or tracks it found;
`missing()` is what the vehicle still needs before it drives and `report()`
is the text the builder reads.

`axis.assemble(facing)` binds the surveyed frames in any of the four
facings, moves the axis to the front left corner, lays the turning square
(`assembly_square()`: from the front left corner to the vehicle's right and
back) and calls `fit_parts()`, which also fits parts stood on the frames
later. `take_apart()` unbinds a `hand_built` vehicle so it can be changed and
assembled again; `take_apart_refusal(H)` keeps that to its owners while it
is registered. Clicking the axis opens the menu.

A boat of ship frames is assembled by the same code from its rudder axis
(`axis.ship`): the survey takes ship frames only, refuses any that do not lie
on water, and looks for a ship's wheel (`helm`), masts and an engine of any
kind in place of a seat and corner wheels.

Planes and submarines are assembled by the same code from their own controls,
which only take their own sections (`vehicle_assembly_kind_matches()`).
`axis.assembly_refusal(S)` adds a kind's shape rules and `assembly_max_size()`
its longest side. Airframe controls (`aircraft/aircraft_assembly.dm`) take a
3-wide airframe 3 to 5 long and reshape each section into the nose, wing,
cockpit, fuselage or tail its place calls for, or a 5-wide, 4-long airframe into the twin-engine plane (`aircraft/aircraft_twin.dm`), whose wing engines run with the pilot's. Submarine controls
(`ships/submarine_assembly.dm`) take a hull 3 wide and 5 (Scout) or 7
(Explorer) long on surface water, reshape each section from
`submarine_layouts` (hull art tile, walls, lock-out hatches), and want a
ballast and periscope station (`survey.station`); the crafted station, battery
bank and air bank are bolted down by `fit_parts()` and come loose again with
`take_apart()`.

`code/modules/craft/vehicle_turret.dm` adds `/obj/structure/turret/built`
(recipe "tank turret", Mechanized War): the works tanks' traversing turret
(`siege/turret.dm`), empty until fitted. `fit_parts()` calls its `fit()`,
which takes the tank cannon and the gunner's, loader's and commander's seats
standing on the turret's tile into it; `release()` sets them down again when
the vehicle is taken apart. `lacking()` is what it needs before it can fire
and the survey's `turret_lines()` reports it. `built_turret_styles()` lists
the existing turret pictures a builder may pick in the current age ("Turret
style" in the axis menu).

    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/assembly_probe.dm 300

The automobile workshop builds a truck, an armoured car, a tracked carrier
and two tanks piece by piece from `works_vehicle_specs`
(`code/modules/craft/vehicle_works.dm`); see
[piece-projects.md](piece-projects.md). A new works model is one more spec
naming an existing layout.

## Carriages

`code/game/objects/structures/carriage.dm` is the horse carriage, and
`craft/carriage_papers.dm` puts it on the core as a `/datum/craft/vehicle/carriage`
with a `/datum/craft_body/carriage` (its footprint). It keeps a vehicle's
papers in a carriage's words (master, coachman, wheelwright, groom), appears in
"Our vehicles", and its reins follow the vehicle rule: crew urge the team,
a stranger forces the reins while an owner is about and is refused otherwise.
The carriage saves the register in `register_state`.

- **Footprint.** Two tiles wide and three long along `facing`, with the team
  in a lane two tiles wide ahead of it (`carriage_cells()`, `lane_depth()`).
  A turn re-lays bounds and sprite offset and is refused when the new
  footprint or lane is blocked, or when turning round faster than a walk.
- **Team and seats.** Up to four horses or oxen (not mixed), and five seats for
  passengers or loose structures (crates, barrels). Everything aboard stands on
  the carriage's corner tile and is drawn there with pixel offsets
  (`seat_point()`, `team_point()`, `place_at()`); `let_off()` is the one way off.
- **Pace.** A horse pulls 2 and an ox 1 (half when starving). Oxen walk, one
  horse trots, two canter (`carriage_top_gear()`). Each gear has a delay that
  grows with `load_ratio()` (load over `pull * CARRIAGE_PULL_CAPACITY`), is
  slower off built ground, in snow and in shallow water, and takes the walking
  slope rule (`terrain_slope_delay()`). Past four times capacity it will not
  move. Every animal pays hunger per step, more uphill, halved by a harness.
- **Steps.** A timer keeps to `next_step`; each step leases one glide to the
  carriage and everything aboard for exactly the step's interval. The tiles the
  step newly covers must be clear: people and large animals stop it (and are
  run into), small animals are run over, deep water needs a bridge.

## Vehicle load

`code/modules/1713/machinery/modular_vehicles/vehicle_load.dm` makes what a
land vehicle carries set its pace. `get_speed()` multiplies the gear's listed
delay by `get_load_factor()`: the vehicle as loaded against the same body with
steel walls and a normal load (one seated person per seat plus 10 per frame).
A rider buckled into a seat counts half their weight and one standing on the
deck or roof counts in full (`vehicle_rider_weight()`). Wall
sides weigh 0.5 per point of armour (`frame.wall_weight()`), so a lighter hull
material only has to override that proc. Loose items other than the fuel
tank, crates and the contents of crates are cargo; everything else on the
frames is fitted.

- A normally loaded vehicle reads exactly 1.0 and drives as before; the factor
  runs from 0.7 to 1.5. At 0.8 or less `top_gear()` allows one gear above the
  list, a tick quicker than the last (`gear_delay()`).
- Turning time is `loaded_turntimer()`, the same factor held to 0.7 to 1.3.
- The factor is cached and rechecked at most every 2 seconds, and the movement
  loop refreshes the delay after each step, so boarding or unloading on the
  move changes the pace.
- Boats, ships and aircraft opt out (`uses_load_factor()`); the engine stall
  limit in `check_engine()` is unchanged.

## Gun turrets

`code/modules/naval/ship_turret.dm` adds the ship's gun turret
(`/obj/structure/cannon/modern/ship_turret`, 60 steel, Naval Mines research):
a one-tile breech-loader that fires the field shells (`/obj/item/cannon_ball/shell`)
and reuses the unused `modern_ship` state in `icons/obj/cannon.dmi`.

- Its barbette is found by position: `magazine()` looks for a shell rack on
  the tile right under it, one or two levels down (`multiz_level_below()`).
  On a ship every tile on the way down must be one of her own decks
  (`craft_holding()` and `body.carries()`), so a rack in the rock beside her
  hold does not count. Ashore any rack dug under it does.
- A loader beside it Alt-clicks it (or uses Hoist a Shell): after five
  seconds `take_from_magazine()` moves one shell from the rack into the
  breech. Nothing links turret and rack, so a hop or a turn needs no fix-up
  and nothing extra is saved.
- Bomb racks do not feed it.

## Hull weight

`code/modules/naval/hull_weight.dm` weighs a built hull's own floors with the
same material table the land vehicles use (`vehicle_hull_stats()` in
`modular_vehicles/vehicle_hulls.dm`), so there is one weight table, not two.
A plank tile is the measure of 1; every other floor weighs its material's
weight against plank (`hull_material_weight()`): steel, iron, stone or
concrete about 1.67, aluminium about 0.92.

- `fit_drives()` already walks `body.aboard()` before each hop; it hands the
  same list to `count_structure()`, which counts one floor per turf, deck,
  upper deck and hold alike, and stores `structure_weight` as the weight past
  one plank per tile of her hull. `craft.mass()` adds it before water, load
  and fouling, so speed is still push over mass (`max_speed()`).
- Airships keep their own lift table (`air_weight`, air_hull.dm) and opt out
  (`weighs_floors()`).
- The ship designer's estimate (`/datum/ship_draught/mass()`) counts the same
  weights from the draught: plank or steel deck cells, and every extra deck
  tile at its level's floor (the hold is plated with steel).
- Turning: `turn_time()` is the path warning (5 seconds) for a hull up to ten
  tiles long, half a second more for each tile past that, at most 30 seconds.
  Turf-built template vessels keep their fixed turn.

## Tests

    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/craft_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/turret_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/orbit_world/spacecraft_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/orbit_world/sites_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/papers_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_papers/probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/draft_carriage/probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/vehicle_load/probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/freight_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/depot_jobs_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/built_hull_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/hull_push_probe.dm 300
    python3 tests/ecology_spawning/run_linux.py . tests/naval_carrier/bilge_probe.dm 300
