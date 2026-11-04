# Ocean fishing

Players can fish the open sea from a boat, with no fish hotspot needed (#3051).
Code: `code/game/objects/structures/ocean_fishing.dm`.

- **Where:** stand on a boat (a ship frame or small-boat axis on water, or drive
  one) and click open deep saltwater next to it with a fishing pole, rod or net.
  The water must not be covered, and it must not be part of the boat itself.
  Underwater turfs are excluded.
- **Time and odds:** a cast takes 15 seconds, or 12 with a modern rod. A bite
  comes 15% of the time (25% with a rod), or 30 points more with bait.
- **Catch:** cod 55% of the time, otherwise ordinary raw fish. Baited lines
  sometimes bring up a squid instead.
- **Bait:** use raw meat, offal or raw fish on the pole to bait it. One piece
  is good for 3 casts and is spent on each cast, whether or not anything bites.
- **Stock:** each 8x8 stretch of sea holds 3 fish. A fish comes back every 10
  minutes until the stretch is full again, so a boat has to keep moving. The
  stock is checked again when the cast ends, so two people fishing the same
  stretch cannot both take its last fish. Stock is not saved and resets on
  restart.

Fish hotspots on rivers and coasts keep working as before. Bait does not change
them.
