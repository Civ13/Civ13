# Driving trains

Code: `code/modules/1713/trains.dm` (cars, rails, locomotives),
`code/modules/1713/train_platforms.dm` (walkable cars and clearance) and
`code/modules/1713/train_warfare.dm` (armored locomotive) and
`code/modules/1713/train_locomotives.dm` (heavy 3x4 locomotives).
Tests: `tests/train_platforms` (the `drive/`, `load/`, `brake/`,
`double_heading/`, `tender/` and `collision/` checks) and `tests/train_collision`.
Step cost by train length: [train-step-cost.md](train-step-cost.md).

## Controls

Using a locomotive opens its controls: start or stop the engine, throttle up
or down (notches 0 to 3), brake, and the reverser (forward or backward, only
while the train stands). Examine shows the notch, reverser, speed and load.

Stopping the engine or closing the throttle lets the train coast; the brake
stops it faster. Neither stops it on the spot.

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

Acceleration rises with spare pull. Coasting, engine braking and the brake
each take a fixed amount of speed per tile, divided by the train's weight over
six, so a long heavy train needs several times the distance to stop.

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

The step delays are the locomotive rows of [vehicle-speeds.md](vehicle-speeds.md);
a heavy engine is no faster than its one-tile counterpart, it pulls about twice
the train. The controls open from the cab section (`control_spot()`), or from a
tile beside it. Fuel goes in through any section. Boilers, bunkers and the
diesel's hood are solid; the diesel has a walkway either side of the hood, and
whatever stands in its front cab rides along (`cab_cargo()`). The front of the
body hits people standing beside the rails (`sweep_sides()`).

Explosions wear the steam and diesel engines down to `broken_down`, and the
armored one to `disabled`, instead of deleting them; a welding tool repairs
them. Heavy locomotives cannot be packed back into a kit, put away in a rail
warehouse, or sent over an inter-region railway.

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
to both trains in a train-on-train crash scales the same way.
