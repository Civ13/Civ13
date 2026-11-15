# Handfuls of rounds and the tightened grip

`python3 tests/held_grip/run.py --byond-bin <BYOND bin>` compiles the committed
game sources with normal startup disabled and, on a 12x12 world with real
humans, checks `code/modules/projectiles/ammo_handful.dm` and
`code/game/objects/items/grip.dm`:

- per-hand capacities (10 cartridges, 6 arrows, 3 darts, no rockets), kinds
  don't mix and spent brass is not held;
- clicking a round with another starts a handful; clicking floor rounds gathers
  up to the cap; a full handful refuses more;
- a tight grip blocks taking rounds out and loading, survives falls, and a blow
  to the hand breaks the grip before it can knock the handful away;
- an empty hand takes one round out, and the last round turns back into a plain
  round in that hand; dropping loosens the grip;
- a loose handful scatters on a fall without losing a round;
- a clip loads from a handful and the rest stay in hand;
- a blow to a hand can knock a plain held item away, with a bounded chance;
- no runtime errors.

Random outcomes are retried until they happen, so the probe is deterministic in
what it asserts. It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
