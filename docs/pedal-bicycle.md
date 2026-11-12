# Pedal bicycle

The first pedal vehicle is a one-person ground bicycle. Pedal zeppelins are not
included: buoyancy, hovering and landing need a separate design and tests.

## Obtain and ride

In the global crafting catalogue, **Factories** unlocks a pedal bicycle under
**vehicle parts**. It costs 12 steel and uses a 200-decisecond base crafting time.
It reuses the existing wheeled, unpowered motorcycle frame artwork. There is no
engine, fuel tank, passenger seat or cargo platform.

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

The fastest and slowest intervals and stamina costs are clamped. More weight
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
blocked/duplicate steps, changing loads, callback redirection and lifecycle
wiring. The suite is registered as `pedal_bicycle` in `scripts/ci_baseline.py`.

These tests use fake collision, client and timer boundaries. A full-game compile
checks DM syntax and linkage; neither is native riding or graphical acceptance.
In-game acceptance should cover all four directions, holding and releasing the
controls, braking/restarting, exhaustion and recovery, nested loaded bags,
blocked doors/borders/mobs, bridges and water, disconnect/death/dismount, and
save/load with an empty bicycle and a mounted rider.
