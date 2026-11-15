# Horse breeding

Code: `code/modules/1713/horse_breeding.dm`. Art: the horse and foal states in
`icons/mob/animal_64.dmi` and `icons/obj/horseshoes.dmi` from
`tests/sprites/create_horses.py`. Probe: `tests/horse_breeding/probe.dm`.

- **Wild horses.** On persistence maps, horses spawned in the wild are wild
  (`domestication.dm`); battle maps keep their horses tame. A wild horse refuses
  a saddle, harness and leash. Climbing on (drag yourself onto it) is breaking
  it in: after 3 s it throws you (knocked down, 2-5 brute). Each throw and each
  hand feeding counts as one step of trust, at least 10 minutes apart; six
  steps tame it.
- **Breeding.** A tame grown mare beside a tame grown stallion conceives, a few
  times a minute at most, if no more than six horses stand within seven tiles.
  The foal is born an hour (real time) later, with the coat of the mare or the
  stallion. It grows up two hours after birth; a foal can't be ridden.
- **Speed and stamina** (20 to 80, new horses 35 to 65). A foal gets the mean of
  its parents' values plus or minus 5. A ridden step takes
  `0.5 * (1.2 - speed / 250)` deciseconds before a hitched cart (0.46 at 70,
  0.54 at 30). Stamina scales the hunger of hauling by `1.5 - stamina / 100`.
  Examining a tame horse gives a rough read of both.
- **Horseshoes** (2 iron, Iron Smithing). Use a set on a tame grown horse
  (5 s). An unshod horse ridden on gravel, rocky ground, cave floor, plating or
  a stone or asphalt road takes 25% longer per step. Shoes last 2,000 steps on
  such ground and are then cast as worn horseshoes.

Ridden pace goes through `ride_delay()` on the mount for players
(`mob_movement.dm`) and agents (`agent_movement.dm`) alike.
