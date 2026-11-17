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

## Controls

Using a locomotive opens its controls: start or stop the engine, throttle up
or down (notches 0 to 3), brake, sand the rails, and the reverser (forward or
backward, only while the train stands). Examine shows the notch, reverser, speed and load.
The heavy steam engines split these between three
[cab stations](#cab-stations-and-the-main-line-engine).

Stopping the engine or closing the throttle lets the train coast; the brake
stops it faster. Neither stops it on the spot, and the driver's brake holds
the engine alone ([Brakes](#brakes)).

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

Acceleration rises with spare pull. Coasting and engine braking each take a
fixed amount of speed per tile (0.2, or 0.6 against a lower notch), divided by
the train's weight over six, so a long heavy train rolls a long way.

## Brakes

A train stops by the weight its brakes hold. Each step the drive loop takes
`brake_decel()` off the speed on top of the rolling resistance above: 1.2
tiles per second times the braked share of the train's weight, where the
braked weight is

- the engine itself with all its sections (`consist_own`) while the driver's
  Brake is on, and
- every car whose `handbrake` is on (`consist_braked`).

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
them. Heavy locomotives cannot be packed back into a kit, put away in a rail
warehouse, or sent over an inter-region railway.

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
only. Region travel and the warehouse do not carry the kind of coupling yet.

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

Region travel and the warehouse do not carry axle oil, clinker, brake shoes,
scale or mileage yet.

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
(`/turf/proc/plough_snow()`) and the train keeps its speed. Region travel and
the warehouse do not carry ploughs yet.

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
