# Driving trains

Code: `code/modules/1713/trains.dm` (cars, rails, locomotives),
`code/modules/1713/train_platforms.dm` (walkable cars and clearance) and
`code/modules/1713/train_warfare.dm` (armored locomotive) and
`code/modules/1713/train_locomotives.dm` (heavy 3x4 locomotives, cab stations
and the 3x6 main-line engine), `code/modules/1713/train_crashes.dm` (wrecks)
and `code/modules/1713/train_brakes.dm` (handbrakes, brake wheel, brake van),
`code/modules/1713/train_rolling.dm` (cars that roll free) and
`code/modules/1713/train_adhesion.dm` (wheel slip and sand).
Tests: `tests/train_platforms` (the `drive/`, `load/`, `brake/`,
`double_heading/`, `tender/`, `collision/`, `crash/`, `brakes/`,
`brake_van/`, `rolling/` and `adhesion/` checks) and `tests/train_collision`.
Step cost by train length: [train-step-cost.md](train-step-cost.md).
Whole trains drawn on a train sheet and built at a rail works: [train-sheets.md](train-sheets.md).

## Controls

Using a locomotive opens its controls: start or stop the engine, throttle up
or down (notches 0 to 3), brake, sand the rails, and the reverser (forward or
backward, only while the train stands). Examine shows the notch, reverser, speed and load.
The heavy steam engines split these between three
[cab stations](#cab-stations-and-the-main-line-engine).

Stopping the engine or closing the throttle lets the train coast; the brake
stops it faster. Neither stops it on the spot, and the driver's brake holds
the engine alone ([Brakes](#brakes)).

## Smooth movement

A train still moves a whole tile per step, but each step is drawn as one
glide lasting until the next step, the way boats and ships sail
(`code/modules/craft/glide.dm`). `code/modules/1713/train_glide.dm` holds the
`glide_size` of every car, deck part, load and rider at the train's pace
before it moves (`train_glide_begin()`/`train_glide_end()` around each step
of `drive()` and a free roll); free-moving riders and loads swung two tiles
round a curve are drawn back a tile and slid instead. Moves go through
`train_glide_before()`/`train_glide_after()` in the car `Move()` and
`train_shift()`; outside a step they do nothing. The train gives every glide
back when it stops (`train_glide_rest()`). Checks: `glide/` in
`tests/train_platforms`.

## Bends

A bend is one curved tile that each section of a car takes in turn, so a car
with sections on two bends at once (an S-bend or a tight U-turn) would fold onto
itself. `code/modules/1713/train_bends.dm`:

- Laying track, the hammer will not spike rails down when the bend on that tile
  or one beside it is fewer than `TRAIN_CAR_LENGTH` (4) tiles from the next
  bend along the line (`track_bend_problem()`); under `TRAIN_LONG_CAR_LENGTH`
  (8) the layer is warned that long bogie stock and main-line engines need more
  (`track_bend_warning()`). The gap counts tiles from one curved tile to the next.
- A train will not step onto a bend whose next bend is closer than its longest
  car (`train_bend_problem()`, `train_longest_car()` by shared `car_id`), so
  older or mapped track still stops it short. One-tile wagons take any bend.
- Driven at such bends faster than 1 tile/s, the leading cars leave the rails
  (`tight_bend_check()` from the drive loop, as with `overrun_check()`); a light
  one-tile engine stalls instead, as elsewhere.

Checks: `bends/` in `tests/train_platforms`.

## Wide curves

A platelayer with a hammer can ease a sharp corner into a wide curve of radius
4 or 8 (right-click the corner, "Ease the Curve"). It lifts the corner and that
many tiles of plain straight track on each side and relays them as one curve of
the same number of tiles, so no rail is gained or lost. A crowbar relays a curve
as the sharp corner again. `code/modules/1713/train_arcs.dm`:

- `/obj/structure/rails/arc` tiles run from S to E as a short straight run, a
  staircase and another run (`train_arc_path()`), each tile leading by
  `leg_a`/`leg_b`. `rail_target()` routes them like any two-legged tile; they are
  not bends for the spacing rule, since a car never folds across them.
- Trains take a curve at up to `train_arc_speed()` tiles a second (4 on
  radius 4, 6 on radius 8, against 3 on a sharp corner) before `curve_check()`
  derails them.
- On the staircase a deck lies diagonally (`rail_arc_lay()` in
  `train_platform_tiles()`), so a car's tiles overlap no more than on a sharp
  corner, and furniture aboard turns once over the curve (`train_turning()`).
- The master tile draws Fable's art (`train_arc4.dmi`, `train_arc8.dmi`) turned
  and mirrored onto the curve. Cars, deck parts and engine bodies on a curve are
  drawn turned to the track and moved onto its circle (`train_arc_pose()`),
  animated over the step's glide; they are drawn square again off it. Riders
  and loose loads stay on their tiles.

Checks: `arcs/` in `tests/train_platforms`.

## Rail plans

A ship's draught can carry a railway ("Draw a railway on the sheet"): track
drawn tile by tile on a 40 by 40 sheet, north up, in the rail designer
(`code/modules/1713/rail_designer.dm`). `code/modules/1713/rail_plan.dm`:

- A tile is track or not; its shape follows from its neighbours as laid track
  does. A sharp corner can be marked to be eased to radius 4 or 8.
- Design checks of kind `rail_plan`: corners closer than `TRAIN_CAR_LENGTH`
  are an error (laying refuses them), closer than `TRAIN_LONG_CAR_LENGTH` a
  warning; a curve needs its radius in plain straight tiles each side and room
  for its tiles; where track meets more than two ways a switch is laid by hand.
- The plan travels as `C13RAIL/1/<name>/<x,y,count;...>/<x,y,radius;...>`
  through the shared draught export and import (`draught_kinds.dm`); the window
  saves through the same reader, `rail_plan_from_code()`.
- "Peg it out on the ground" drives a builders' peg (`build_markers.dm`, kind
  `rail`) into every tile of the line as first laid, the tile the builder
  stands on taking the drawing's south-west corner; a corner to be eased
  carries a note with its radius. A peg goes when finished track stands on it.

Checks: `rail_plan/` in `tests/train_platforms`; `PlanCodesTest` in
`tests/design_codes`.

## Speed and load

Speeds are tiles per second. `max_train_speed` is a locomotive's step delay in
deciseconds at full throttle with a light train, from the targets in
[vehicle-speeds.md](vehicle-speeds.md): diesel 1.2 (about 8 tiles/s), steam 2
(5 tiles/s), armored 2.4. Each notch is a third of that top speed.

Every car has a `train_weight` (wagon 1, platform segment 0.5 so a car is 2,
steam locomotive 3, armored 5) plus its load: cargo strapped on, people on its
tiles, items in storage, furniture on a deck (`car_load_weight()`). A
locomotive's `haul` is the train weight it pulls at full speed (steam 14,
diesel 16, armored 20). Over that, top speed falls in proportion; under a
quarter of the needed pull the wheels spin and the train will not start.

The lead engine refreshes the train's weight and pull every six tiles
(`refresh_consist()`); nothing is stored per step, and all the driving state
is `tmp`, so a saved train comes back standing with the throttle closed.

Speed changes by the second, not by the tile, so a train creeps away, gathers
way over many tiles and loses it gradually. A train gains `TRAIN_ACCEL` (0.25
tiles/s) each second times its pull ratio, up to twice that with pull to spare:
`train_speed_gain()` solves v' = v + a / v' for the step being taken, so a light
steam train reaches 5 tiles/s in about ten seconds and 25 tiles, and a train at
its rated load takes twice as long. Coasting and engine braking take a fixed
amount of speed each second (0.2, or 0.6 against a lower notch), divided by the
train's weight over six, so a long heavy train rolls a long way; each step
counts the seconds it takes (`train_step_seconds()`). Free-rolling cars
(`train_rolling.dm`) still lose speed per tile.

## Brakes

A train stops by the weight its brakes hold. Each second the drive loop takes
`brake_decel()` off the speed on top of the rolling resistance above: 1.2
tiles per second times the braked share of the train's weight, where the
braked weight is

- the engine itself with all its sections (`consist_own`) while the driver's
  Brake is on, and
- every car whose `handbrake` is on (`consist_braked`).

With the driver's Brake on, the train always loses speed at least
`TRAIN_BRAKE_OVER_ACCEL` (2) times as fast as it can gather it
(`stopping_decel()`: twice `TRAIN_ACCEL` times its pull ratio), so even a long
train held only by its engine stops in well under the time it took to get up
to speed. Handbrakes and a brake van shorten the stop further.

So a lone engine stops as before, while an engine with a long train behind it
needs many more tiles unless cars are braked too. `refresh_consist()` adds
both up; `set_handbrake()` refreshes the driving engine at once.

Every car that is not an engine has a handbrake (`has_handbrake()`), shared by
all the sections of a platform car and saved with them.

- The **Handbrake** verb pins it down or lets it off from beside the car in
  two seconds, only while the train stands (`work_handbrake()`).
- A **brake wheel** (`/obj/structure/train_brake_wheel`, iron, rail steam)
  bolted to a platform car's deck winds that car's brake on or off at a click,
  once a second, standing or on the move. A wrench unbolts it once the brake
  is off.
- The **brake van** (`brake_van` layout, kit in iron) is a four-tile guard's
  van: an open veranda, then a cabin with a brake wheel and a seat. Its
  sections weigh 1 each (`"weight"` in the layout), twice an ordinary car, so
  its brake holds twice as much.

A handbrake left on drags: `pull_ratio()` counts a braked car at four times
its weight (`drag_weight()`), so the train is slower and may not start. Any
handbrake in a train also holds it against being pushed by hand.

## The boiler

Steam engines (`/obj/structure/trains/locomotive/coal` and its subtypes) make
their power in a boiler. `on` means the fire is lit; the menu says "Light the
fire" and "Drop the fire".

- `pressure` (0 to 100) is what the engine has to work with. `steam_factor()`
  is 1 from 60 up, falls in line below that and is 0 under 15. It scales the
  engine's top speed and what a helper engine adds to the train's pull. The
  throttle will not open with no steam.
- By the clock (`boiler_tick()`, caught up when the engine drives or someone
  uses or examines it, so nothing ticks for a parked engine): a lit fire
  raises pressure, from cold to full in `steam_time` seconds on a firebox at
  least half full (120 s, heavy engines 240 s), and burns 0.02 fuel a second
  standing. With the fire out the boiler cools in 20 minutes.
- By the tile (`steam_use()`): the fire makes 1.1 on a firebox at least half
  full, less on a thin fire, and the work takes notch / 3 times the load
  (weight over `haul`, up to 1.5). A train at the engine's rated load holds
  pressure at full throttle; a heavier one winds the engine and must be
  driven on a lower notch.
- Water: `boiler_water` (60, heavy 100) boils off at up to a unit a tile and
  `water` is the tank (240, heavy 600). With the `injector` on, which is how
  engines are built, each tile puts back what was used at a small cost in
  steam. A quarter glass warns everyone nearby.
- A lit fire over an empty boiler melts the fusible plug (`drop_plug()`):
  the fire goes out, pressure is lost and the engine is dead until a new
  `/obj/item/fusible_plug` (1 lead, Rail & Steam) is fitted with a ten second
  job. Nothing explodes.
- Water goes in from any open vessel of water, a water tower or a water
  crane. A cold boiler is filled first, then the tank.

Engines are built filled and in steam, and engines saved before the boiler
existed load the same way. Diesel engines are unchanged.

## Tenders and water stops

`train_water.dm`. A tender is coupled directly to a steam engine, at either
end (`engine_tenders()`). There are two:

- the one-tile tender wagon: its fuel is the coal and wood in its storage,
  and it carries 600 water;
- the walkable tender, a platform car of kind `tender` built from a kit. It
  is drawn and built in one piece like a locomotive body (layout key `body`,
  no `engine`): a shovelling plate anyone can stand on and three solid
  sections. Its front section holds `tender_fuel` (up to 1500) and
  `tender_water` (up to 2400); `tender_store()` finds it from any section.
  Click any section with coal, wood or a vessel of water to load it.

Nothing feeds the firebox by itself any more. A fireman clicks the engine
with a shovel (`shovel_coal()`): each stroke moves up to 30 fuel from the
tender, once a second, and works on a moving train. Fuel can still be put in
by hand. The tender's water runs to the engine's own tank whenever the
train's weight is recounted (`tender_top_up()`).

`/obj/structure/rail_water/tower` holds 6000 water. It is filled from
vessels, or by its hand pump when fresh water lies within two tiles. Used
with an empty hand it fills every steam engine and tender whose rail tile is
within three tiles (`takers()`, `fill_takers()`). `/obj/structure/rail_water`
is the water crane: the same, two tiles, drawing from the fullest tower
within twelve. Region travel does not carry a tender's fuel and water.

## Heavy locomotives

Code: `code/modules/1713/train_locomotives.dm`. Tests: the `heavy/`, `diesel/`
and `armored_heavy/` checks of `tests/train_platforms`.

A heavy locomotive is three tiles wide and four long, assembled from a kit on
straight track like a platform car. Its front section is the engine, a
`/obj/structure/trains/locomotive` subtype, so the controls, load, braking,
reversing and double heading above are the same code. The three sections
behind it are platform segments of the car kinds `loco_steam`, `loco_diesel`
and `loco_armored`, hitched to the engine and sharing its `car_id`; they follow
curves, are checked for clearance and can be wrecked and welded like any car.
The body art is `loco_<kind>_<1-4><l|c|r>` in `train_platforms.dmi`.

| Kit | Step delay | Haul | Weight | Fuel | Cab |
| --- | --- | --- | --- | --- | --- |
| Heavy steam locomotive | 2 | 30 | 6 | coal, wood, branches (250) | third section |
| Heavy diesel locomotive | 1.2 | 32 | 5 | diesel or biodiesel, 1 per unit (300) | front section |
| Heavy armored locomotive | 2.4 | 40 | 10 | coal, wood, branches (300) | third section, armor doors |
| Main-line steam locomotive | 1.4 | 60 | 10 | coal, wood, branches (400), from a tender | sixth section |
| Main-line diesel locomotive | 1.2 | 64 | 9 | diesel or biodiesel, 1 per unit (600) | first and sixth sections |

The step delays are the locomotive rows of [vehicle-speeds.md](vehicle-speeds.md);
a heavy engine is no faster than its one-tile counterpart, it pulls about twice
the train. The controls open from the cab section (`control_spot()`); the
diesel's also from a tile beside it. Water goes in through any section; the
fire is fed at the firebox door (below). Boilers, bunkers and the
diesel's hood are solid; the diesel has a walkway either side of the hood, and
whatever stands in its front cab rides along (`cab_cargo()`). The front of the
body hits people standing beside the rails (`sweep_sides()`).

Explosions wear the steam and diesel engines down to `broken_down`, and the
armored one to `disabled`, instead of deleting them; a welding tool repairs
them. A crowbar packs a heavy locomotive back into an unfurnished kit when it
stands still, shut down, uncoupled and clear of riders and cargo
(`pack_problem()`, `pack_into_kit()` in `train_dismantle.dm`); its fuel and
water are lost. A tender packs into its kit like a platform car. A one-tile
wagon or engine comes apart with a crowbar into half its cheapest recipe cost
(`wagon_dismantle_problem()`, `take_apart()`). A rail warehouse
takes it whole, engine and body sections as one unit (`rail_warehouse_unit()`),
and it comes out as it went in. The inter-region record
(`train_transfer_codec.dm`) carries it the same way: the engine as the first
section of its own body. That record is still not wired to player departure.

## Cab stations and the main-line engine

Tests: the `cab/` and `mainline/` checks of `tests/train_platforms`.

A steam cab is three tiles and each is a station (`cab_station()`), so a full
crew is a driver and a fireman and a lone driver has to leave the regulator to
fire. Layouts with `"stations" = TRUE` have them: the heavy steam, heavy
armored and main-line engines. The diesel and the one-tile engines are worked
from one place (`"all"`).

| Station | Cab tile | Works |
| --- | --- | --- |
| Driver's stand | right of the engine's front | throttle, brake, reverser |
| Firebox door | middle | lighting and dropping the fire, coal or wood by hand, the shovel, the fusible plug |
| Fireman's side | left | the injector |

`attack_hand()` offers `station_controls(station)` for the tile the user
stands on and `work_control()` checks the station again when the choice comes
back. `at_firebox()` gates fuel and the shovel in `coal/attackby()`. Water
from a bucket and welding work from anywhere beside the engine.

The main-line steam locomotive (`loco_mainline`, kit 90 steel) is six sections
long with the cab last, built and driven like the heavy engines. Step delay
1.4, haul 60, weight 10, firebox 400, boiler 160, 360 seconds from cold. It
has no bunker and only a 100-unit feed tank: couple a
[tender](#tenders-and-water-stops) behind the cab, so the fireman at the
firebox door shovels from the tender's plate and `tender_top_up()` keeps the
feed tank full. Body art is `loco_mainline_<1-6><l|c|r>` with the stations
drawn in the cab (`cab_stations()` in `tests/sprites/create_trains.py`).

## Several engines and the tender

One engine drives a train: the first to open its throttle, wherever it is
hitched in (`locomotive()`, `train_head()`). At the front it pulls; behind cars
it pushes the front car along (`process_rail_forward()`), burning its own fuel
and hitting what is ahead with its own weight. Any other running engine in the
train adds its `haul` and burns its own fuel (double heading, banking); its
controls only take over once the driving engine has stopped.

What leads the train limits its speed (`leading_factor()`): an engine running
forward allows full speed, an engine running backward three quarters, and
cars with no running engine at their head a half.

Cars couple at either end with the Hitch verb: the front to the car ahead
(`hitch_front()`), the rear to the car behind (`hitch_rear()`). The sections of
one platform car or heavy locomotive stay hitched to each other.

## Cars facing either way

Any two ends couple, whichever way the cars face (`couple_end()`). A car's
`dir` is the way it faces, and that never changes when it is coupled. A car
whose front points at the rear of its train is `reversed`: it runs tail first,
and `train_heading()` gives the way it travels. Movement passes headings
(`Move(newloc, fdir)`, `rail_target()`); art, deck sides, doors and fittings go
by `dir`. When two fronts or two rears meet, `reverse_train()` turns the order
of one train round without moving anything: its links flip and every car's
`reversed` toggles. `settle_train_order()` then keeps the order the way most
engines face, else most cars, and it runs again after uncoupling, so a train
alone is never all reversed.

An engine's reverser is its own: forward is the way the engine faces
(`train_way()`). An engine at the rear that faces out runs the train back at
full speed, so a train with an engine at each end needs no turning. An engine
that leads bunker first still keeps to three quarters.

A car goes into a rail warehouse front first and comes out facing the way its
train heads. An inter-region railway refuses a train with reversed cars.

A car that stops on a curve while its train backs heads out along one leg of
the curve already; `rail_target()` lets it run straight on from there.

A coal tender anywhere in the train feeds the lead engine's firebox when it
drops below half: coal, wood planks and branches, as many as fit.

Fuel per tile is 0.25 at idle up to 1 at full throttle with a rated load, and
up to 1.375 overloaded.

## Couplings

Every car end carries a coupling (`train_couplings.dm`): `front_coupling` at
the end the car faces and `rear_coupling` at the other, each 100 when sound,
0 when broken and -1 when taken off. They are saved with the car. A car of
several sections has one at each end of the car only (`has_coupling_end()`),
and a heavy locomotive has its rear one on its last body section.

The link between two cars is still `connected`. It can be made only when
both couplings that meet are whole, and it parts when either breaks
(`damage_coupling()`): the cars beyond the break are left where they stand
and the engine's part of the train runs on. Explosions strain the couplings
of the cars they catch (`blast_couplings()`). Crash damage arrives with the
crash work.

Each end shows as a `/obj/effect/train_coupler` in the car's `vis_contents`,
so it turns and moves with the car at no cost per step, is never saved, and
is what players click (`coupler_use()`):

- empty hand: couple, or uncouple after a short moment; refused while an
  engine in the train is pulling (`train_under_power()`)
- a weapon on harm intent: wears it by the weapon's force
- welding tool: mends it, broken or not
- wrench: takes it off a free end as a `/obj/item/train_coupling`, which
  keeps its condition
- a train coupling: fits it to an empty end

The right-click Hitch verb still works and follows the same rules without
the wait. Spares are crafted (4 iron, Rail & Steam). `update_couplers()`
rebuilds the visible parts and is safe to call at any time. Region travel
does not carry coupling wear: cars arrive with sound couplings.

## Shunting

`train_shunting.dm`. A train that comes up to standing cars at 1 tile a
second or less buffers up to them (`buffer_up()`, called by `rail_hit()` for
a contact that is not a crash): it stops against them and neither is marked.
Faster than that it is a bump as before, and from 1.5 tiles a second the
cars are knocked rolling ([Runaways](#runaways)).

An end may carry an automatic coupler in place of the hook and screw link:
`front_auto` / `rear_auto`, saved with the car, and
`/obj/item/train_coupling/automatic` as the part (6 steel, Assembly Line).
It wears, breaks, welds and comes off like any coupling, and used on an end
that has the other kind it changes places with it. It shows as `knuckle_*`
states.

- **Coupling by contact**: when two automatic couplers meet at up to 1.5
  tiles a second, whole and free (`auto_couplers_meet()`), they lock and the
  train stops there. This holds for a driven train and for cars that roll
  free: a car let go down a siding couples to the cars it rolls onto.
  `join_trains()` makes the link for this and for coupling by hand.
- **The uncoupling lever**: between two automatic couplers
  (`lever_uncouples()`) a click lets go at once, without the wait. It is
  still refused while an engine pulls. On a coasting train the cars that
  are let go roll on by themselves.

A hook and screw link and an automatic coupler couple to each other by hand
only. A stored car keeps its couplings; one rolled out of a warehouse hitches
on only where both drawbars carry a sound coupling.

## Servicing

`train_servicing.dm`. Wear is counted by distance where the train is already
added up, `refresh_consist()` for a driven train and `roll_refresh()` for
one that rolls free, so nothing ticks by itself.

**Axle boxes.** Every car and engine has `axle_oil`, the tiles its oil will
last: 600 when oiled, saved with the car. `wear_axles()` takes the tiles run
off it. `axle_state()`:

| State | When | Effect |
| --- | --- | --- |
| oiled | 100 or more left | none |
| dry | under 100 | a line on examine |
| hot | 0 or less | smoke every 30 tiles; the car counts twice in `drag_weight()` (`consist_hot`) |
| seized | 150 tiles run hot (`axle_seized`) | held like a handbrake: `consist_braked`, `roll_braked`, and `shoved()` will not move it |

`service_use()` is the work by hand, on a standing train: an open vessel
with 5 units of oil (`train_axle_oils`: fat oil, olive oil, corn oil, lard,
petroleum) oils the whole car (`service_sections()`, `oil_axles()`); a
wrench changes a seized bearing (`change_bearing()`, 15 seconds), after
which the car is dry and must be oiled. `/obj/structure/trains/attackby`
calls it; the storage and transport wagons call it first, because a reagent
vessel is a weapon to them.

**The fire.** A steam engine has `clinker`, 0 to 100, saved.
`make_clinker()` (from `steam_use()`) adds to it with the fuel each tile
takes: four fireboxes of fuel fill it. Up to 40 it does nothing; above that
`clinker_factor()` takes from `fire_factor()`, down to half at 100, and the
controls say the fire is dirty or choked. `clean_fire()` is a fire rake
(`/obj/item/train_fire_rake`, 2 iron) used at the firebox door of a
standing engine over an ash pit (`/obj/structure/rail_ash_pit`, 6 iron, laid
on a track tile): 8 seconds, the clinker goes to 0 and a fifth of the fire
goes with it. A pit takes ten fires (`ash`), then a shovel digs it out
(`dig_out()`), which leaves up to three heaps of ashes.

**Brake shoes.** Every car and engine has `brake_shoes`, the tiles its
shoes last with the brake on: 300 for a new set, saved. `wear_shoes()` takes
the tiles run with a handbrake on, or with the driver's brake on for the
engine. Under 50 the examine text says they are thin. At 0 `brake_hold()` is
0.3 in place of 1: the car counts for three tenths of its weight in
`consist_braked`, `consist_own` and `roll_braked`. A set of brake shoes
(`/obj/item/train_brake_shoes`, 3 iron) used on a standing car with its
handbrake off fits a new set (`fit_shoes()`, 10 seconds).

**Scale.** A steam engine has `scale`, 0 to 100, saved. `make_scale()` (from
`steam_use()`) adds to it with the water boiled: twelve tanks fill it. Up to
40 it does nothing; above that `scale_factor()` takes from `fire_factor()`,
down to six tenths at 100, so steam is slower to raise and harder to keep.
From 20 the fireman's controls offer "Wash out the boiler" (`wash_out_by()`):
the fire out, pressure at 25% or less, the train standing, and a water crane
or tower within reach whose tower holds 300 units (`washout_water()`). It
takes 30 seconds and leaves the boiler clean, cold and full (`wash_out()`).

**Overhaul.** An engine has `mileage`, the tiles it has worked since its last
overhaul, saved; `wear_engine()` counts it while the engine is running.
After 5000 `wear_factor()` takes from the pull the engine adds to
`consist_power`, down to seven tenths at 10000, and examine says it is due.
A wrench on an engine at half that distance or more starts the overhaul
(`overhaul_by()`): the engine stopped, standing in the bay of a rail
warehouse (`engine_shed()`), 10 iron or steel in the other hand, 60 seconds.

A car in a rail warehouse is the car itself, so it keeps all of this. The
inter-region record carries a fixed list of working state per section
(`train_transfer_state_fields()`): couplings and their kind, ploughs,
handbrake, axle oil and a seized axle, brake shoes, tender water and fuel,
locked doors, a bulk or liquid load, and an engine's sand, mileage, tank and
boiler water, pressure, injector, fusible plug, clinker and scale. Amounts
travel as whole numbers inside the limits of their own files; a derailed,
wrecked or broken-down train is refused.

## The depot

`train_depot.dm`. Two structures beside the track, loaded by hand, that serve
what stands within two tiles of them, like a water crane.

- `/obj/structure/rail_depot/coal_stage` (20 wood) holds 6000 units of fuel:
  coal counts 15 a piece and wood 3 (`load_fuel()`). Used with an empty hand
  (4 seconds) it fills the bunkers of the walkable tenders and the fireboxes
  of the steam engines within reach (`fill_takers()`).
- `/obj/structure/rail_depot/sand_bin` (8 wood) holds 200 charges of sand
  (`load_sand()`) and fills the sandboxes of the engines within reach
  (2 seconds).

## Bulk freight

`train_freight.dm`. Ore, coal and sand travel as a kind and a count on the
car, not as items on its deck, so a loaded train costs no more to move than
an empty one.

- A layout with `"bulk" = <units>` carries bulk: the open wagon 600, the
  hopper 800. `bulk_amount` lives on the car's first section
  (`bulk_store()`); `bulk_path` (the stack type as text) and `bulk_fill`
  (0, 1 part, 2 from half) are copied to every section by `update_bulk()`,
  so each draws its own heap (`bulk_overlay()`, `train_loads.dmi`) without
  looking for the others.
- `train_bulk_item()`: any `/obj/item/stack/ore` that is not radioactive. A
  car carries one kind at a time. `bulk_use()` from the car's `attackby`:
  a stack is tipped in (`bulk_load()`), a shovel takes up to 50 out in 2
  seconds (`bulk_take()`).
- 200 units weigh as much as one section (`bulk_weight()`, added in
  `car_load_weight()` on the first section). A loaded car cannot be packed
  into a kit.
- The hopper (`"hopper" = TRUE`) is built with a
  `/obj/structure/train_hopper_lever` on its first section. `drop_load()`
  empties the car while it stands: into the `/obj/structure/rail_drop_pit`
  under any of its sections (`take_in()`, 3000 units of one kind; what does
  not fit stays in the car), otherwise as stacks on the track under it.
  The pit is dug out with a shovel (`dig_out()`).

Region travel does not carry bulk loads yet.

## Tank car

`train_tank.dm`. A tank car carries one liquid as a kind and a count, the
way a tender carries its water: no reagent holder rides the train.

- A layout with `"tank" = <units>` has a tank: the tank car 3600.
  `tank_reagent` (a reagent id) and `tank_amount` live on the car's first
  section (`tank_store()`). 600 units weigh as much as one section
  (`tank_weight()`, added in `car_load_weight()`). A car with liquid in it
  cannot be packed into a kit.
- The four middle sections carry `"solid" = 1` and `"tank" = "f"`, `"d"`,
  `"m"` or `"b"`: `apply_layout()` makes their rail tile dense, as it does
  for a locomotive body, and `tank_overlay()` draws that part of the tank
  from the section's own layout. The running boards either side stay
  walkable behind handrails; the end sections are open platforms.
- `train_tank_liquid()`: an open reagent container holding exactly one
  liquid reagent. `tank_vessel()` pours it in, or fills an empty vessel
  from the tank; it runs from `tank_use()` (the car's `attackby`, tank
  sections only) and from the valve's `attackby`.
- `/obj/structure/train_tank_valve` (4 iron, wrench to bolt) is fitted on
  the first section. Used by hand it runs the tank out in 4 seconds
  (`tank_run_out()`): water into the water towers within 3 tiles, a fuel a
  locomotive lists in `tank_fuel_ids()` (the heavy diesel: diesel and
  biodiesel) into the engines within 3 tiles.
- A water tower or crane counts a tank car that is empty or holds water
  among its `takers()` and fills it with `tank_fill()`.

Region travel does not carry a tank's liquid yet.

## Special stock

`train_stock.dm` and the layouts in `train_car_layout()`.

- `stock_car`: an eight-tile van with `slat` sides, `slat_door` sliding
  doors and a `straw` floor. Animals ride as any living thing does; the
  dense sides and shut doors keep them aboard.
- `ice_car`: an eight-tile insulated van (`cold` sides, `cold_door`). It is
  built with one `/obj/structure/closet/ice_house/reefer` (the ice bunker)
  and eleven `/obj/structure/closet/ice_house/cold_locker`. Both are ice
  houses (`small_ancient.dm`), so food kept in them takes the ice house's
  decay step in `food.dm` with no new branch there.
  - The bunker is packed with snow or cut ice like any ice house. On an ice
    car (`train_ice_car()`) its `slow_melt()` is true: the ice lasts four
    times as long, as it does underground.
  - A locker holds no ice. `is_cold()` asks the bunker on its own car
    (`bunker()`, found once within 8 tiles and kept in `feed` while it stays
    in reach). Snow and ice offered to a locker go to that bunker.
- `mail_van`: the baggage and mail van, with a coach roof for passenger
  trains: sorting tables and cabinets, side doors, crates and cabinets.
- `bogie_sleeper` and `bogie_dining`: the eight-tile sleeper (twelve
  compartments) and dining car (galley, five tables, six booths).

## Crane car

`train_crane.dm`. The crane car is a four-tile ballasted flat (`"weight" = 1`
a section) built with an outrigger lever (`/obj/structure/railway_gun_brace`,
the railway gun car's) and a
`/obj/structure/workshop_machine/shear_legs/crane/steam/rail`.

- The rail crane is a steam crane (`power_cranes.dm`): solid fuel counted in
  hauls, one haul burnt a haul, raise and lower one level. Reach 5.
- `rail_problem()`: it lifts only on a rail car (`train_deck_at()`) whose
  `braced` flag is set. `MouseDrop_T`, `attack_hand` and `hauler_ready()`
  all ask it, so a haul stops if the outriggers come up, and a braced car
  cannot move.
- `sling_reach()` (new on the shear legs, 1 for every other hoist) is its
  `reach`: a load is slung from anywhere under the jib, not only beside it.
- `haul_choices()` adds two same-level moves to the steam crane's: the clear
  deck tile of another car nearest the load ("Swing it onto ..."), and the
  clear ground tile off the track nearest the load ("Set it down beside the
  track"). Its own car's deck and dense sections are never offered.

## Diesel working

Code: `code/modules/1713/train_diesel.dm`. Tests: the `dieselmain/`,
`multiple/` and `deadman/` checks of `tests/train_platforms`.

What a diesel gives over steam is a small crew: no fire, no water, one driver.

- **Two cabs.** The main-line diesel (`loco_dieselmain`, kit 100 steel,
  `combustion`) is six sections with a cab at each end: `"cab"` is section 1,
  the engine itself, and `"cab2"` section 6, closed by invisible `cab_end`
  edges. `control_spot(user)` is the cab the user stands at and `rear_cab()`
  the rear one. `leading_factor()` gives full speed only while the cab that
  leads is manned (`cab_manned(1 or 2)`), else three quarters, so the driver
  changes ends to run back. Body art is `loco_dieselmain_<1-6><l|c|r>`, the
  roofs `roof_loco_dieselmain_<l|c|r>` and, for the rear cab,
  `roof_loco_dieselmain_b<l|c|r>`.
- **Working in multiple.** Engines whose `works_in_multiple()` is true (the
  heavy and main-line diesels) and that are coupled next to each other, with
  no car between, are linked: `linked_units(cars)` is the unbroken row as
  car id -> engine. Starting or stopping one starts or stops the row
  (`switch_linked()`), a cab of any of them works the unit that drives the
  train (`linked_driver()`), and the driver's brake holds them all
  (`refresh_consist()` counts linked units as the engine's own weight). Each
  unit burns its own fuel, as helper engines do.
- **Dead-man's handle.** `has_deadman()` engines are watched from the drive
  loop each time the train is counted, every six tiles (`deadman_watch()`).
  With nobody conscious and fit in a cab of the driving unit or a unit linked
  to it (`deadman_held()`) for two looks running, the throttle closes and the
  brake goes on.

## The conductor

Code: `code/modules/1713/train_conductor.dm`. Tests: the `conductor/` checks
of `tests/train_platforms`.

Four items put somebody in charge of the train behind the engine. All are
`rail_steam`; none of them sells or buys anything.

- **Guard's journal** (`/obj/item/train_list`, 1 leather). Used aboard or
  beside a train (`train_beside()`), it prints `train_list_lines()`: a heading
  with the vehicles, length, weight and what the engines pull, then a line a
  vehicle from the front with its weight, engine state, handbrake, axle boxes,
  wreck and locked doors.
- **Carriage key** (`/obj/item/train_key`, 1 iron). On a closed car door it
  toggles the lock: a bit per edge in the segment's `locked_doors`, like
  `open_doors`. A locked door stays shut to a hand from outside
  (`locked_against()`), opens and unlocks from its own tile, and is forced
  with a crowbar (`open_by_force()`). Region travel does not carry the locks.
- **Ticket book** (`/obj/item/train_ticket_book`, 1 leather, 40 tickets) and
  **ticket punch** (`/obj/item/train_ticket_punch`, 1 iron). `issue()` writes
  a `/obj/item/train_ticket` with its destination, fare and issuer; `punch()`
  cancels it once.
- **Signal flags** (`/obj/item/train_flags`, 2 cloth). `show_signal()` shows
  one of `train_hand_signals()` to everyone in sight and tells the people in
  every cab of the train the signaller is aboard or beside.

## Signals

Code: `code/modules/1713/train_signals.dm`. Tests: the `signals/` checks of
`tests/train_platforms`.

Everything here is `rail_steam`. Nothing stops a train by itself: signals and
tokens tell the crew what to do, and mark who did not.

- **Lineside posts** (`/obj/structure/train_lineside`) stand up to two tiles
  to the side of the centre of the track and speak to trains running their
  `dir`; a wrench turns one. They are kept in `train_lineside`. The driving
  engine calls `lineside_watch()` when it starts and each time the train is
  counted (every six tiles): a post up to ten tiles ahead of the leading car
  is read out to `cab_crew()` once (`sighting()`), and one that was read and
  is no longer ahead is passed (`passed_by()`).
- **Semaphore signal** (`/obj/structure/train_lineside/signal`, 4 iron).
  Danger until put to clear (`set_clear()`), by hand at the post. A train that
  passes it at danger is seen to, `passed` counts it and its frame rings.
- **Lever frame** (`/obj/structure/train_lever_frame`, 10 iron) works up to
  eight signals and switch levers within forty tiles. A **coil of signal wire**
  (`/obj/item/train_signal_wire`, 2 iron) used on the frame and then on a
  signal or `/obj/structure/train_lever` writes the frame's `frame_id` to
  their `worked_by`; used again it takes them off. What is wired does not
  move by hand. `pull()` works one lever and `locked_by()` is the
  interlocking: a signal does not clear while a wired signal that faces it
  along the same line is clear (`train_signals_oppose()`), a switch does not
  move while a wired signal within ten tiles of it is clear, and a signal
  always goes back to danger.
- **Token instruments** (`/obj/structure/train_token_instrument`, 8 iron)
  are wired as a pair with the same wire, up to 150 tiles apart, and share a
  `section`. `draw_token()` gives the one `/obj/item/train_token` of the
  section, and no second while it exists; `restore_token()` takes it back at
  either end.
- **Section board** (`/obj/structure/train_lineside/board`, 3 wood), marked
  for a section with the wire from a paired instrument. The cab is told
  whether `carries_token()` holds: the token is in a pocket, in a hand or on
  the floor of an engine of the train. Passing without it is seen and counted.

## Stations and warnings

Code: `code/modules/1713/train_stations.dm`. Tests: the `stations/` checks of
`tests/train_platforms`.

- **Station name board** (`/obj/structure/train_lineside/station`, 4 wood),
  named with a pen (`set_station()`). It is a lineside post that
  `speaks_to()` both directions: `sighting()` tells `train_riders()`,
  everybody aboard, where the train is coming into.
- **Whistle and bell.** The driver's stand has "Sound the whistle" (the horn
  on a diesel, `whistle_name()`), "Ring the bell" and the headlamp.
  `sound_whistle()` needs the engine running with steam, and tells conscious
  players up to forty tiles away who cannot see the engine which way it is.
- **Headlamp and the dark.** `refresh_consist()` multiplies `lead_factor` by
  `night_factor()`: at Night with no lit `headlamp` on the engine that leads,
  and no hand lamp showing white on the leading car, the train runs blind at
  half speed. The leading car's `lamp_range` (5 with the headlamp, else 2) is
  the light it shows while it moves.
- **Hand lamp** (`/obj/item/train_lamp`, 2 iron) turns through white, red and
  green (`set_shade()`), kept in `train_lamps`. `train_lamp_on()` finds one on
  a car's tiles, held or set down. Red on the last car is the tail lamp the
  guard's journal reports (`train_tail_lamp_text()`).

Raised platforms were not built: decks are walked onto from the ground, so a
platform is any floor laid beside the track.

## Snow

`train_snow.dm`. Snow that falls and lies (`snowfall_ground.dm`:
`weather_snow`, one or two units on a dirt or grass tile) drifts over the
track. After each tile the driving engine looks at the tile its leading car
entered (`meet_snow()`, `leading_end()`): snow there sets `snow_factor` to
0.75 for one unit and 0.5 for two, a factor of `cruise_speed()`, until the
leading car is on clear track again. Authored snow terrain does not count.

A snowplough (`/obj/item/train_snowplough`, 10 iron) is a part of a car end:
`front_plough` and `rear_plough`, saved. It is fitted and taken off at the
coupling of a free end (`plough_use()` from `coupler_use()`: the plough to
fit, a wrench to take it off, 6 seconds, train standing) and shows as an
overlay on that coupling from `icons/obj/vehicles/train_plough.dmi` (96 x 96).
When the end that leads the train carries one, `meet_snow()` clears the tile
(`/turf/proc/plough_snow()`) and the train keeps its speed. A plough stays on a
stored car and is carried by the inter-region record.

## Reversing

With the reverser backward the rearmost car leads: it takes the next tile
behind it, following turns and switches the same way, and every other car takes
the place of the car behind it. `train_solo_move` stops each car's `Move()`
from dragging its follower meanwhile. Clearance and collisions are checked at
the rear (`train_consist_obstacle()` takes the cars in travel order).

## Collisions

`collision_impact()` is 1 for an unpowered car and, for a moving locomotive,
speed / 4 tiles per second, times up to 2 for a heavy train. Below 0.5 (a
crawl) a train shoves a person off the rails with 5 damage and stops in front
of furniture without breaking it. Faster, it deals up to 250 damage, knocks the
person down beside the track and keeps going from 1 up; damage to objects and
to both trains in a train-on-train bump scales the same way.

## Leaving the rails

Code: `code/modules/1713/train_derail.dm`. Tests: the `derail/` checks of
`tests/train_platforms`.

A derailment is not a crash: nothing is smashed, but the cars that come off
(`derailed`, on every `/obj/structure/trains`) stop their train like a wreck
does until they are put back.

- **Too fast round a curve or through the branch of a switch.** After each
  step the drive loop calls `curve_check()` with the leading car and where it
  stood and faced: when it turned, or stepped sideways, at more than
  `TRAIN_CURVE_SPEED` (3 tiles a second) the train leaves the rails. One
  car or engine comes off, two from 1.5 times the limit and three from twice.
  The first notch of every engine is under the limit.
- **Off the end of the rails.** When the train could not step, the loop calls
  `overrun_check()`: no rail ahead, no buffer stop under the leading car and
  more than `TRAIN_OVERRUN_SPEED` (2 tiles a second) puts the leading car on
  the ground. A lifted rail does the same.
- `leave_rails()` takes the cars in the order they run, derails the leading
  units (`train_unit_come_off()`: the leading half of a car, a whole heavy
  engine with `set_derailed()`), stops the train and throws its riders with
  `crash_jolt()`. Small one-tile engines only lose their fire, as in a crash.
- **Rerailing.** A **rerailing jack** (`/obj/item/train_jack`, 6 iron,
  `rail_steam`) on a derailed section lifts it back (`rerail()`), a section
  at a time; there has to be rail under it (`rerail_problem()`). A heavy
  engine also needs `train_breakdown_crane()`: the crane of a braced crane
  car with fuel within five tiles, which spends one haul.

Not built: damaged rails (rails have no wear) and trailing a switch set the
wrong way (the track model has no trailing switches).

## Track works

Code: `code/modules/1713/train_trackworks.dm`. Tests: the `trackworks/` checks
of `tests/train_platforms`. Bridges for track are the steel and concrete decks
of `bridges.dm`.

- **Buffer stop** (`/obj/structure/train_buffer_stop`, 4 iron, `rail_steam`):
  a solid stop set on the last tile of rails; a wrench turns it. `rail_hit()`
  asks `hold(impact)` before the ordinary crash on a solid object. Up to
  `TRAIN_BUFFER_HOLD` (1.25, about five tiles a second for a light engine) the
  train stops against it unharmed, and a blow of 0.5 or more is counted on the
  beam. Above that the train is wrecked as against any obstacle
  (`train_crash()`) and the stop is broken up (`smash()`): the rails stay.
- **Crossing boards** (`/obj/structure/train_crossing_boards`, 2 wood): laid
  on a rail tile where a road crosses. They change nothing for trains.
- **Crossing gate** (`/obj/structure/train_lineside/gate`, 4 wood): stands on
  the road two tiles from the rails, like a signal, so the side of a wide
  car passes inside it; its `dir` points at the rails and a wrench turns it.
  A shut gate on the tile next to the rails is a solid object in the path
  of a three-wide car. Gates within `TRAIN_GATE_REACH` (4) tiles are one crossing and
  swing together (`set_shut()`): shut across the road they are dense, open
  they are not. They do not shut on anyone or anything solid standing in
  them (`shut_problem()`). By hand they take 2 seconds.
- Track fixtures stay put under a passing deck (`train_track_fixture()`):
  ash pits, drop pits, crossing boards, lineside posts and gates, buffer
  stops, levers, frames, token instruments, coal stages, sand bins and
  water cranes are never carried along as cargo.
- A gate is a lineside post: one gate of each crossing tells a cab coming
  up to it how the gates stand, and counts a train that runs over the
  crossing with them open to the road.
- **From a lever frame**: signal wire from the frame to one gate joins the
  whole crossing to one lever (`wire_gate()`); the gates then no longer move
  by hand. A signal of the same frame that reads over the crossing
  (`train_signal_over_gate()`: the gates stand up to 20 tiles ahead of it)
  does not clear while the gates are open to the road, and the gates do not
  open while it is clear.


## Turntables

`train_turntable.dm`. A pivot (`/obj/structure/train_turntable`, 20 iron;
`/large`, 40 iron; both `rail_steam`) with a bridge of rails across a square
pit. The small table has `radius` 2: five tiles of bridge in a pit five tiles
square, enough for a heavy locomotive or a four-tile car. The large one has
`radius` 5: eleven tiles, for a main-line engine with its tender.

- **Setting out.** A wrench on the unlaid pivot sets which way the bridge
  will lie; an empty hand lays it (`lay()`, 10 seconds). `lay_problem()`
  wants the whole pit on firm, dry, open floor with no track, sleepers,
  trains or solid objects in it. Lines are then brought up to the edge of
  the pit in line with the pivot, on any of its four sides.
- **The bridge** is `/obj/structure/rails/turntable`: rails to a train
  (`rail_canmove()` and `rail_target()` treat it as straight track), but not
  plain track, so it is never bent, joined to or prised up. A car kit is not
  assembled on it. A crowbar on the pivot takes the bridge up when nothing
  stands in the pit (`take_up()`), and deleting the pivot takes its bridge.
- **Turning.** An empty hand on the pivot or any bridge rail offers a
  quarter left, a quarter right or right round. `work()` wants the user on
  or next to the bridge and takes `turn_time()` for each quarter: 2 seconds
  empty and 0.6 seconds more for each unit of weight on it, at most 15; two
  or more people at the ends of the bridge (`hands()`) halve it.
- `turn_problem()` refuses while a train on the bridge moves, is derailed,
  braced or wrecked, or is coupled to anything not on the bridge; while
  anyone stands in the pit off the bridge; and while anything solid is in
  the pit.
- `swing(angle)` moves the bridge rails, every train section on them and
  what the decks and the bridge carry (`moving_tiles()`, the same rule as a
  moving deck) round the pivot, turns their `dir`, and puts deck parts,
  engine bodies and couplings back in place. People on the bridge or in a
  cab go round with it.
- A line that meets the pit where the bridge is not lined up ends there: an
  engine driven on runs off the end of the rails.
- Art: `turntable_deck`, `turntable_girders` and `turntable_pivot` in
  `train_platforms.dmi`; the pit is one image under the pivot from
  `train_turntable.dmi` (160 x 160) or `train_turntable_large.dmi`
  (352 x 352), all from `tests/sprites/create_trains.py`.
- Not verified in a real client: the pit image at the edge of the screen,
  timed turning, and save and load of a laid table.


## Track wear

`train_trackwear.dm`. Every rail carries `wear`, 0 to 100. Nothing runs on a
timer: an idle line does not decay.

- **Traffic.** The drive loop calls `meet_track()` once a step, after the
  snow. The rail under the leading car takes `TRACK_WEAR_RATE` (0.01) for
  each unit of the train's weight (`take_traffic()`): doubled on a curve or
  a switch, and half as much again above 5 tiles a second and once the tile
  is already rough. A 40-weight train puts 0.4 on plain track, so a tile is
  rough after about 60 such trains and worn after a hundred or so. Cars
  rolling free do not count.
- **States** (`wear_state()`): getting rough at 25, worn at 50, bad at 80.
  Worn and bad track shows an overlay (`track_worn`, `track_bad`,
  `show_wear()`), and `examine` says how the tile stands.
- **Line speed** (`line_speed()`): worn track is good for 5 tiles a second
  and bad track for 2. Faster than that the rails spread and the leading
  car or engine leaves them (`leave_rails()`, as on a curve). One-tile
  engines stall as they do on a curve.
- **The cab** is told once as a stretch gets worse (`track_told`): rough,
  then worn, then bad. Sound track clears it.
- **Platelaying** (`track_maintain()`, asked first by the rails' own
  `attackby()`): a hammer packs and spikes a rough or worn tile in 3
  seconds and takes 30 off its wear. Bad track will not hold packing: a set
  of railway sleepers used on it (5 seconds, one set) makes the tile new.
  Sleepers also relay a worn tile. Neither is done under a train.
- Turntable bridge rails wear and are packed like any others.
- Not verified in a real client: the overlays on curves and switches, and
  save and load of worn track.

## Early rails

`train_early.dm`. Rails before the steam engine, and the small things that
still run on them after it.

- **Hand car** (`/obj/structure/trains/transport/handcar`, 6 iron, Rail &
  Steam). A one-tile car with a walking beam. A rider standing on its tile
  clicks it to pump (`pump()`): one stroke every 0.8 seconds adds 0.5 tiles
  a second to a light car, less to a heavy one, and sets the car rolling
  free (`start_rolling()`, train_rolling.dm). It goes the way the rider
  faces when that is along the track, else the way it was last pumped
  (`pump_way`). One rider keeps up 1.5 tiles a second and two riders who
  both pumped in the last 3 seconds 2.25 (`pump_crew()`). Pumping against
  the roll takes twice a stroke off the speed. It rolls and coasts like any
  free car, so it must be pumped to keep going. `pump_problem()` refuses a
  rider who is not aboard, a pinned handbrake or seized axle, a train with
  an engine or a draft animal on it, and a train over 4 in weight.
- **Draft animals.** A horse or an ox (`is_draft_animal()`) is harnessed
  to the car at either end of a train with no engine: drag the car onto
  the animal, or use the car's Harness Animal verb (`player_harness()`, 3
  seconds). It draws 4 in weight for each point of `draft_animal_pull()`:
  8 for a horse, 4 for an ox, half that when starving
  (`train_draft_load()`). The car listens for the animal's moves
  (`GLOB.moved_event`): when the animal gets two tiles away the train
  steps one tile after it (`draw()`), turning its order round first when
  the animal is at the tail. There is no momentum: the train stops when
  the animal does. The traces let go (`unharness()`) when the animal is
  more than two tiles off or not along the line, a handbrake is on or an
  axle seized, the load has grown too heavy, or an engine is coupled on.
  The train slows a ridden animal by up to 3 of move delay
  (`draft_drag()`, through `hitch_drag()`). Harnesses are not saved.
- **Chaldron wagon** (`/obj/structure/trains/storage/chaldron`, 12 wood,
  Wagons & Ships): a wooden storage wagon of 10 slots that weighs 0.6.
- **Wooden rails** (`/obj/item/stack/rail_lengths/wooden`, 2 wood, Wagons &
  Ships). Laid on sleepers and spiked like iron rails; the bed and the
  finished rail carry `wooden` (`set_wooden()`), shown by a tint
  (`WOODEN_RAIL_COLOR`, `code/__defines/trains.dm`) and the name
  "wagonway". Prying gives wooden rails back. Hand cars, rolling cars and
  animal-drawn trains wear no track at all (only `meet_track()` in an
  engine's drive loop does); an engine wears wooden rails 8 times as fast
  as iron (`TRACK_WOODEN_WEAR`). Railway sleepers moved to Wagons & Ships
  so that a wagonway can be built before Rail & Steam.
- Not verified in a real client: leading and riding a harnessed animal,
  the feel of pumping, the tint on curves and switches, and save and load
  of wooden track.

## Electric traction

Code: `code/modules/1713/train_electric.dm`. Tests: the `electric/` checks
of `tests/train_platforms`.

An electric engine carries no fuel. It takes its power from a wire over the
track, and the wire takes it from the cable grid (`machinery/cables.dm`,
`machinery/power_points.dm`), so a railway's trains are a load on a town's
generators like any machine.

- **Overhead line mast** (`/obj/structure/train_catenary`, 4 steel,
  Electricity). It stands two tiles from the rails, clear of the cars, and
  a wrench secures it (`put_up()`): it turns its arm to the track
  (`track_way()`) and hangs a wire over the tile under the arm's end
  (`wire_turf()`) and four tiles either way along the line (`covers()`), so
  a mast every nine tiles makes an unbroken wire. The arm and wire are
  overlays above the car roofs (`draw_wire()`). A wrench takes it down
  again (`take_down()`).
- **The line.** Masts whose wires meet (wire tiles within nine of each
  other) are one line, a `/datum/catenary_net` found by `network()` and
  rebuilt only when a mast goes up or comes down
  (`train_catenary_serial`). A secured mast needs 1 kW, so a distribution
  transformer, wall outlet or utility pole in reach adopts it like any
  machine and it becomes a feeder (`feeders()`). `energise()` puts the
  line's whole demand on the first feeder whose grid can carry it
  (`draw_cable_power()`); the line is live when one accepts. Nothing runs
  on a timer: the line is asked when an engine asks.
- **Drawing power.** An engine with its collector up asks the line for
  `line_idle + line_draw x throttle` kW (`line_demand()`), at most once a
  second while nothing changes (`line_check()`, from `steam_factor()`).
  `request()` refuses an engine the grid cannot carry and keeps what the
  others draw, so an overloaded line drops the newest load, not every
  train. A refused engine, one under a dead wire or one past the end of
  the wire has `steam_factor()` 0: the train coasts and can be braked, and
  picks the power up again under the next live wire. An engine lets go of
  its share when the collector comes down, when it is wrecked and when it
  stops (`drive_ended()`), and a share not asked for again in 30 seconds
  lapses.
- **Electric locomotive** (`loco_electric`, kit 55 steel, Electricity):
  four sections, a cab at each end and an equipment hood with walkways
  between. Pull 40, as fast as a diesel, up to 155 kW. It works in
  multiple and has a dead-man's handle like the diesels
  ([Diesel working](#diesel-working)). `max_fuel` is 0 and `fuel` 1, so
  the fuel checks of the drive loop never stall it, and `fuel_per_tile()`
  is 0.
- **Tram** (`loco_tram`, kit 30 steel, Electricity): four sections people
  ride in, a driving platform at each end (open at the sides, which is the
  way in) and a saloon with four seats between, under a roof on every
  section (`roofed()`, the `m` roof row). Pull 10, so itself and one
  trailer car; top speed that of a steam locomotive; up to 42 kW.
- **The live wire.** Somebody riding on a car roof that moves under a live
  wire is burned, knocked down and thrown off (`train_catenary_strike()`,
  from `train_deck_clearance()`).
- Art: `loco_electric_<1-4><l|c|r>`, `loco_tram_<1-4><l|c|r>`, roofs
  `roof_loco_<kind>_<l|c|r>`, `_b<l|c|r>` for the rear cab and
  `roof_loco_tram_m<l|c|r>` for the saloon; `catenary_mast`,
  `catenary_arm`, `catenary_hanger`, `catenary_wire`.
- Not verified in a real client: the wire and arm drawn over passing
  trains and at the edge of the screen, the feel of coasting through a
  gap, and save and load of a line (masts are saved; the line is found
  again from them).

## Freight handling

`train_goods.dm`. The goods yard: every load is put on and taken off by
players, and nothing here buys or sells.

- **Loading stage** (`/obj/structure/rail_depot/loading_stage`, 24 wood).
  It holds up to 3000 units of one kind of bulk (ore, coal or sand: what
  `train_bulk_item()` allows). Stacks are tipped onto it (`load_bulk()`), a
  shovel takes 50 back off (`take_off()`), and an empty hand runs the heap
  down the chute in 4 seconds (`fill_takers()`) into the open wagons and
  hoppers within 2 tiles (`takers()`, by `bulk_store()`). A car that holds
  another kind takes nothing; a full car takes only what it has room for.
  The other end of the trip is the drop pit (see Bulk freight).
- **Goods crane** (`/obj/structure/workshop_machine/shear_legs/crane/goods`,
  12 iron). A hand crane with a reach of 3. On top of what any hoist does,
  `train_crane_swings()` offers the nearest clear deck of a car and the
  nearest clear ground off the track. The crane car's rail crane uses the
  same proc and never swings a load onto its own car.
- **Livestock ramp** (`/obj/structure/train_livestock_ramp`, 6 wood). It
  faces the car: the tile at its head (`head_tile()`) must be a deck with
  no shut door or side in the way (`ramp_problem()`), so it stands two
  tiles from the rails at a stock car's open door. The pen is the ground
  within 3 tiles behind and beside it, off the track (`pen_tiles()`).
  `drive_aboard()` moves the penned animals onto the car's free deck
  tiles, nearest first; `drive_off()` moves the animals on the car into the
  pen. Each takes 4 seconds (`work()`). `train_livestock()` leaves out
  people, hostile animals, the dead and ridden mounts. A wrench turns it.
- **Destination card.** Every car and engine has a holder
  (`destination_card`, kept on the car's first section, `card_holder()`).
  A pen writes up to 40 characters (`card_use()`, asked first by the
  train's own `attackby()`); a blank card takes it out. `examine` reads
  it, and the guard's journal notes `carded "..."` beside the car.
- Loading stages, goods cranes and ramps are lineside fixtures
  (`train_track_fixture()`): a passing train does not carry them off.
- Not verified in a real client: the timed actions, the pen prompt and the
  ramp's choice window, and save and load of a heaped stage or a card.

## Wheel slip and sand

An engine pulls only as hard as its wheels grip. Below 1.5 tiles a second,
`wheels_slip()` is true when the notch's share of full throttle is more than
0.8 x grip x `pull_ratio()`: grip is 1 on dry rails and 0.6 where
`weather_at()` is wet or extreme. While they slip the train gains no speed
(from a stand it does not move at all) and each spin burns a tile's worth of
fuel and steam. So a train at its rated load starts on notch 2 and takes
notch 3 once it is rolling, a train at half its engine's pull, or any heavy
train in the rain, starts on notch 1, and a light engine never slips.

**Sand the rails** at the driver's station spends one of the sandbox's 20
charges (`sand`, saved) and stops all slipping for the next 8 tiles. Sand
(`/obj/item/stack/ore/glass`) used on the engine fills the sandbox.

## Runaways

Cars keep their momentum. The head car of a train that rolls free carries
`roll_speed`; `roll_step()` moves it a tile and `roll_loop()` repeats that on
a timer. Each tile takes 0.2 off the speed, divided by the train's weight
over six, plus `train_brake_decel()` for any handbrake on aboard (and a dead
engine's own brake); under 0.25 the train stands. A rolling train hits what
is in its way by `roll_impact()`, crashes included.

- **A moving train parts** (`part_at()` when a coupling breaks, `couple_end()`
  by hand as the train coasts): `train_motion()` is read before the link
  goes, and `parted_rolls()` sets the part no engine drives rolling the way
  it was going.
- **A train runs into standing cars** (`rail_hit()`): at 1.5 tiles a second
  or more, `shoved()` sends the train that was hit rolling away from the blow
  at the striking speed x 1.2 x its share of the two weights. A handbrake, an
  engine's brake, a braced or wrecked car, or a blow that is not on the end
  of the train holds it.
- By hand, a handbrake cannot be worked on a rolling train
  (`train_rolling()`); a brake wheel aboard can.

## Crashes

`rail_hit()` and the clearance check call `train_crash()` where a train is
stopped dead by another train, a deck or something solid. It is a crash when
the impact is 0.75 or more and an engine in the train is running
(`rail_speed > 0`): a light train from about 3 tiles a second, a heavy one
from half that. Stock moved by hand and a train that has only just started
still bump as above.

The blow falls off down the train: the car that hit takes the whole impact,
the next car half, the third a third. For each car, counted as whole cars and
engines (`train_crash_units()`):

- hull damage of 80 x impact to its leading section, and 60 x impact to the
  car that was hit;
- the leading cars leave the rails (`train_crash_derailed()`): one from
  impact 1.25, two from 2, three from 3. The half of a car nearest the blow
  is `wrecked` at 40% health, a heavy engine is `broken_down` at 40%, a
  one-tile engine only loses its fire. One welding pass on each wrecked
  section, or on the engine, puts it back. The car that was hit derails the
  same way from impact 2;
- the coupling behind it takes 45 x impact wear and parts the train when it
  breaks ([Couplings](#couplings)); both couplings of the car that was hit
  take half that;
- riders take 12 x impact brute (60 at most), fall and are thrown up to three
  tiles forward; walls, doors and furniture hold them
  (`train_crash_can_slide()`). A buckled rider takes half and stays seated.
  Unanchored cargo slides the same way, and cargo chained to a transport
  wagon breaks loose from impact 1.

Every engine in the train is left stopped with its throttle shut.
