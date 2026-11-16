# Door bars

`python3 tests/door_bars/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 12x12 world with
real humans and doors, checks `code/game/objects/structures/door_bars.dm` and
the lock defeat rules in `key_doors/fitted_locks.dm`:

- bar brackets need a hammer and go on the fitter's side; a bar only drops in
  from that side and then keeps the door shut from both sides;
- pushing from the far side does nothing, and an empty hand on the bar's side
  lifts the bar out;
- blows land on the bar first, and a snapped bar passes the rest to the door
  while the brackets stay;
- a slide bolt shoots on grab intent and draws with a hand, only from its own
  side, and comes off with a hammer;
- bracing a shut door on grab intent stops everyone else opening it, until the
  holder lets go;
- a smashed door drops its bar;
- a spring latch can be shimmed with a knife unless the lock refuses it, and
  "all" refuses every method;
- a mapped lock is fitted with its code and refusals, keyed on the outside;
- no runtime errors.

It needs the pinned compiler (`bash scripts/cloud_byond_setup.sh`).
