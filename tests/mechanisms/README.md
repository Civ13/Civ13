# Mechanisms

`python3 tests/mechanisms/run.py --byond-bin <BYOND bin>` compiles the
committed game sources with normal startup disabled and, on a 16x16 world
with real humans, checks `code/modules/1713/mechanisms.dm` and its tripwire
hook in `cmss13_gear.dm`:

- a cord works doors, castle trapdoors, bells and rock drops, not triggers;
- rope on a trigger ties a cord (one rope each) or cuts one (rope back), at
  most four cords;
- a lever opens the door and drops the trapdoor when thrown, shuts both when
  thrown back; a locked door holds;
- a pull cord toggles the door, rings the bell and lets the rock drop go,
  and waits between pulls; a rock drop hurts once and is hung up by hand;
- a pressure plate set from the hand ignores its setter's people and items,
  and pulls for a stranger; a tripwire alarm pulls its cords;
- every new icon state is in `icons/obj/mechanisms.dmi`.
