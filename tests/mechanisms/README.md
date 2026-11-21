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
- a pulley block carries cords one level up, and they go slack without it;
  a water clock and a tower clock pull their cords at their alarm;
- transmission (`transmission.dm`): a line shaft carries a treadwheel's
  drive, machines on it share its strength, a ninth wooden length binds the
  run, a clutch thrown out stops what lies past it and a cord throws it in, a
  gear box carries drive down a level, a rope drive carries it once roped,
  and a still treadwheel drives nothing;
- hopper machines (`hopper_machines.dm`): millstones take grain and refuse
  planks, wait for a drive, grind two a step at the drive's pace, stop when
  empty or at 20 products and give feed back when taken apart; a sash saw
  turns a log into two planks and bark;
- contraptions (`contraptions.dm`): a counterweight drum drives only while
  its weight falls and a cord brakes and releases it; a cam drum pulls its
  cords in turn at the drive's pace; a stationary steam engine drives once
  stoked and burns a minute of fuel a minute;
- fulling stocks felt wool and bark stamps crush bark into tanbark; a cord
  shuts and opens a hopper gate; a belt fills the hopper, an arm finds its
  products and an outgoing belt carries them off; a cord raises and lowers a
  sluice gate;
- bridges: a relay opened or closed by a cord cuts or restores the device on
  its tile; a mechanism port pulls its cords on a circuit signal, waits 2 s
  between pulls, pulls nothing while carried, and sends a cord's pull into its
  circuit only when one is inserted;
- every new icon state is in `icons/obj/mechanisms.dmi`,
  `icons/obj/transmission.dmi`, `icons/obj/hopper_machines.dmi` and
  `icons/obj/contraptions.dmi`.
