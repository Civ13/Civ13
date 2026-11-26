# Canals and pound locks

Code: `code/modules/1713/canals.dm` (with hooks in `trench.dm`, `aqueducts.dm`
and the boat movement checks). Art: `icons/obj/canal_lock.dmi` from
`tests/sprites/create_canal_lock.py`. Probe: `tests/canals/probe.dm`.

## Digging a canal

1. With **Field Defenses** researched, use a shovel on **Harm** intent twice
   on bare dirt or sand to dig a trench. If it shares a side with water and the
   water surface reaches the bed, it floods. A corner alone does not connect.
2. Use the shovel on **Harm** intent again to deepen the trench one step and
   recover a dirt pile. Examine a dry trench to see how far its bed is above
   adjacent water. Each tile can be dug one extra step without lining.
3. Apply **two wood planks** on **Help** intent to line it with timber, or
   **four stone** for stone lining. Timber allows two additional cuts below the
   original bed, and stone allows four. Stone can replace timber.
4. Apply a dirt pile to undo one cut. After restoring the original bed, two
   more dirt piles fill the trench completely. Raising the bed above the water
   surface dries that tile.

The bed and water surface are separate. Digging does not change the surface
height of an already flooded tile or the height of the land around it. Newly
flooded trenches inherit the source's water level and salinity. Boats can
cross deeper and shallower beds at the same water level, where their normal
movement checks permit it. Existing wet trenches without a saved water level
keep their original level.

## Raising a boat between pounds

**Pound lock** (12 stone, Wagons & Ships): build it on a flooded canal tile at a
step between two different **water surfaces**. It faces the higher side. Its
chamber stands at the lower or the higher level, and boats move between it and
the side it matches. Working it by hand (10 s) fills or empties the chamber to
the other level. A flight of locks climbs several levels.

An aqueduct channel beside a dry trench floods it if its water reaches the
trench bed, so a summit pound can be fed from higher ground. Lock chambers do
not flood adjoining new cuts.
