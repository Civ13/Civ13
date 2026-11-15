# Mounted charges, braced spears and shield walls

Code: `code/modules/1713/mounted_combat.dm`. Probe: `tests/mounted_combat/probe.dm`.
No new items or art: it works with the spears, pikes, halberds and shields
already in the game.

- **Charge.** Every ridden step in the same direction within 0.8 s builds the
  charge (`ride_charge_step`, called from the riding hook in
  `mob_movement.dm`). On the fourth straight step, a rider holding a spear,
  pike or halberd in the active hand strikes the first standing mob in the
  next tile: weapon force x1.5 + 10 brute to the chest, knocked down and
  pushed back a tile. A shield that faces the rider can turn the blow
  (`check_shields`). The blow spends the charge; turning starts it over.
- **Brace.** The Brace verb (IC tab) with a spear, pike or halberd in hand
  braces for 10 seconds, until the man moves. A deployed sarissa or pike is
  always braced. A braced man facing a rider who is three or more steps into
  a charge stops it on the tile in front of him: the horse takes 25-40 brute
  and the rider is thrown behind it (`horse_throw_rider`) and knocked down.
- **Shield wall.** A shield gains +15 block chance for each man beside its
  holder (left or right, not in front or behind) who holds a shield, stands
  and faces the same way, up to +30. It counts in melee blocks and against
  arrows and bolts.

Charge and brace state is runtime only (`persistence_runtime_var`).
