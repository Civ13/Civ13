# Pedal bicycle

The first pedal vehicle is a one-person ground bicycle. The pedal airship built
on it is described in [pedal-airship.md](pedal-airship.md).

## Obtain and ride

In the global crafting catalogue, **Factories** unlocks a pedal bicycle under
**vehicle parts**. It costs 12 steel and uses a 200-decisecond base crafting time.
It has its own sprites in `icons/obj/vehicles/bicycle.dmi`, drawn by
`tests/pedal_bicycle/sprites.py`; the handlebars, crank and nearest wheel are
drawn in front of the rider. A seated rider is drawn 6 pixels up (`rider_lift`),
which rests the hips on the saddle and the feet on the pedals. There is no engine, fuel tank, passenger seat or
cargo platform.

Drag yourself onto the bicycle with one free hand. Use the handlebars to start
pedaling, steer with the cardinal direction keys, and use the handlebars again
or their secondary action to stop. Click the bicycle to dismount. It stops at
obstacles rather than inflicting motorcycle crash damage. Water needs a bridge;
it cannot fly over open floors, water or sky.

## Load and stamina

Each step recalculates carried item weight, including worn items, pockets,
holsters and nested bags. Guns and magazines use their existing ammunition-aware
weight method without counting their contents twice. Item weight uses the same
`get_weight()` units as ordinary walking; this does not rebalance item weights.

Load is divided by the existing strength-scaled carrying capacity:
`max(1, (1 + (strength - 1) / 2) * 59)`.

- Empty load: 1.5 deciseconds per tile, 0.5 stamina per tile.
- Half capacity: 2.25 deciseconds, 0.75 stamina.
- Full capacity: 3 deciseconds, 1 stamina.
- Three times capacity or more: 6 deciseconds, 2 stamina.

## Ground and hills

The tile ahead changes each step:

- Built ground (roads, floors, decks, tamped earth, any floor or road cover)
  rides at the pace above.
- Natural ground (grass, dirt, sand, rock, gravel, snowfields) takes 1.25 times
  as long and 1.25 times the stamina. Lying snow adds 1 decisecond.
- Hills use the walking slope rule (`terrain_slope_delay`): climbing adds its
  delay and 0.5 stamina per level, and coasting downhill is a little quicker
  and costs no stamina, so a tired rider can still roll down.

The final interval is kept between 1 and 10 deciseconds. Steps are scheduled
against the previous deadline, so whole-tick timers do not stretch the average
pace; time spent stopped is never banked.

The load intervals and stamina costs are clamped. More weight
never makes the bicycle faster. No stamina is charged for a blocked step, and
insufficient stamina stops pedaling before movement. Braking/restarting cannot
skip an already paid movement interval. Timer scheduling is subject to server
tick resolution.

Pedaling requires a connected, conscious rider, intact feet and legs, no leg or
hand restraints, and the bicycle's own handlebars held in a hand. Losing the
controls, dismounting, death, deletion or a stale seat link ends movement.

## Verification

`python3 tests/pedal_bicycle/test_bicycle.py` executes selected production
procedures through the existing offline source adapter. It checks bounds,
monotonic load penalties, nested weight accounting, driver admission, stamina,
ground and hill effects, scheduling, blocked/duplicate steps, changing loads,
callback redirection, the sprite sheet and lifecycle wiring. The suite is
registered as `pedal_bicycle` in `scripts/ci_baseline.py`.

`python3 tests/pedal_bicycle/ride.py --byond-bin <pinned BYOND bin>` is the
native check (not run by CI). It boots the full game headless and rides in all
four directions, loaded, over grass, into an obstacle and exhausted, checking
seating, shared glide, pace, stamina, braking and a clean dismount.
`tests/pedal_bicycle/render.py` draws the parked and ridden sprites.

Still for in-game acceptance: how it looks in the real client, nested loaded
bags, doors/borders/mobs, bridges and water, hills on a height map,
disconnect/death, and save/load with an empty bicycle and a mounted rider.
