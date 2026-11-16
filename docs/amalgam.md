# Amalgamation and river bed mercury

Source: `code/modules/1713/amalgam.dm` (hooks in `mercury.dm`, `river_flood.dm`,
`placer.dm`, `lode.dm`, `resource_sifting.dm`, `floor_attackby.dm`,
`watercloset.dm`, `fishing_grounds.dm`).
Tests: `tests/amalgam/test_contract.py`, native probe `tests/amalgam/probe.dm`.
Art: `tests/sprites/create_amalgam.py` -> `icons/obj/amalgam.dmi`.

All steps need **Amalgamation** (Imperial).

## Making amalgam

- **Arrastra**: pour quicksilver (up to 20u) and water (20) into a stone crusher.
  Crushed ore worked in it gives wet amalgam at 55% recovery
  (`LODE_METAL` 0.5 x 0.55 chance per load). Each lump binds 2u; every load
  loses 0.15u (river bed beside water, else ground) and leaves amalgam tailings.
  A mover within reach speeds it like any driven machine.
- **Patio** (6 stone, open sky): 20 crushed silver ore, 20u quicksilver, 10u
  salt (sodiumchloride), 1 copper ore, turned six times (10 s, 5 s with a
  horse, ox, cow or mule beside it). Gives 7 silver amalgam (70%) and 20
  amalgam tailings; the other 6u of quicksilver are lost.

## Recovering the quicksilver

- **Amalgam press** (4 iron): wet amalgam (2u) becomes pressed amalgam (0.8u),
  1.2u runs into the tray.
- **Mercury retort**: takes amalgam beside cinnabar (10 lumps in all). Each
  lump leaves sponge gold or silver (subtypes of the ore, smelt the same) and
  returns 90% of its quicksilver.

## River bed mercury

`/datum/river_flood/var/bed_mercury`, one number per reach. A spill splits 60%
into its reach, 25% and 15% into the next two downstream (the last reach keeps
what has nowhere to go). It decays x0.99 an hour (one multiply a minute in the
existing flood step) and is saved after the foul block in
`river_flood_state`. Only maps with a flow file have reaches; elsewhere spills
are ground pollution (3 per unit).

At 1u or more in a reach's bed:

- drinking from the river adds 0.5 burden,
- containers filled from a well within 3 tiles take 1u quicksilver,
- fish caught there add 0.3 burden a bite,
- panning there shows beads of quicksilver.

Sources: sluice riffle losses, arrastra losses, the patio, and amalgam tailings
tipped into fresh water (0.05u a load).
