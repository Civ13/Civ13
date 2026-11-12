# Pedal airship

A one-person gas bag over a basket with a pedal-driven propeller. It is a
subtype of the [pedal bicycle](pedal-bicycle.md)
(`code/game/objects/structures/pedal_airship.dm`) and shares its seat, load,
stamina and scheduling rules. It has no engine, fuel, passenger seat, cargo
platform or crash damage.

## Where it flies

Aloft it rides on the open-air level above the ground, the same level the
planes use (`multiz_level_above`). It therefore only flies on maps that have
one, which today is Gaia. Elsewhere it stays on the ground and says there is no
open sky above.

## Obtain and fly

In the global crafting catalogue, **Factories** unlocks a pedal airship under
**vehicle parts**. It costs 30 cloth and uses a 300-decisecond base crafting
time.

- Drag yourself onto it with one free hand, as with the bicycle.
- The tiller's **secondary action** rises from the ground (3 seconds, 5
  stamina) when you are stopped. It needs open sky straight above: no roof or
  upper floor.
- **Use the tiller** to start or stop pedaling; steer with the cardinal
  direction keys. On the ground the propeller does nothing.
- The secondary action while moving brakes. The airship then hangs where it is.
- The secondary action while stopped in the air sinks (2 seconds) onto dry,
  solid, clear ground directly below. Water, trenches, lava, walls, dense
  objects and other people refuse the descent.
- You cannot get off in the air. Click the airship to get off once it is down.

## Load and pace

Load is the bicycle's: carried weight over strength-scaled carrying capacity.

- It cannot lift more than the rider's carrying capacity (load ratio above 1).
- Empty: 3 deciseconds per tile. Half capacity: 4.5. Full capacity: 6.
  The limit is 12 if a load is picked up in the air.
- Stamina per tile is the bicycle's (0.5 to 2 by load). Ground type, snow and
  hills do not apply in the air.

It is half the speed of the bicycle and slower than walking with a load. Its
use is crossing water, walls and rough country in a straight line.

## What stops it

It floats only over open air. An upper storey (a floor on the sky level), a
dense object on the sky level or the map edge stops it without damage. A tired
rider stops pedaling and hovers until stamina recovers.

## Never left in the air

Only an airship that is aloft and the people seated in it are held by open air
(`pedal_airship_holds`, called from `aircraft_holds`). Anything else on its
tile falls as usual.

If it loses its rider in the air (pulled from the seat, death, the airship
destroyed, a stale seat link) or a save is restored with it over open air, it
drifts down by itself: straight down where that is clear, otherwise to the
nearest clear ground within 6 tiles, otherwise straight down anyway. Nobody is
hurt. An unconscious or disconnected rider stays seated and hovers.

## Shadow and ground view

Like the planes, it throws a shadow on the ground below and shows the ground
through the open air around it, in full to 7 tiles and fainter to 10. Both are
nullspace effects drawn through turf `vis_contents` and are never saved.

## Art

`icons/obj/vehicles/pedal_airship.dmi` is 64x64, drawn 16 pixels to the left
so the rider's tile is the bottom middle. `tests/pedal_bicycle/airship_sprites.py`
draws it; the basket side and propeller are the `airship_overlay` state drawn
in front of the rider. Landed, the basket rests on the tile's bottom edge.
`tests/pedal_bicycle/airship_render.py` draws the landed and ridden views.

## Verification

`python3 tests/pedal_bicycle/test_airship.py` (in the `pedal_bicycle` suite)
checks the lift limit, pace, the open-air hold, the re-checks after each wait,
the set-down paths, the sprite sheet and the recipe wiring.

`python3 tests/pedal_bicycle/ride.py --byond-bin <pinned BYOND bin> --probe airship_probe.dm`
is the native check (not run by CI). It boots the full game headless and
covers: no pedaling on the ground, no rise when exhausted, rising, pace in the air, the shadow
following, hovering after a brake, no dismount in the air, a dropped item
falling, no descent onto water, sinking and getting off, the lift limit, a
loaded pace, an upper storey ahead and overhead, and the forced set-down when
the rider is pulled off, dies over water or the airship is destroyed.

Still for in-game acceptance: how it looks in the real client (the 64-pixel
sprite, shadow and ground view), steering with real key presses, and a real
save and load with an airship in the air.
