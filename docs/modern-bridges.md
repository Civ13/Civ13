# Modern bridges

Val (2026-11-07): modern bridges let trains and roads cross the ocean.

## What existed before

- A wooden floor (`/obj/covers/wood`, or the floor cover item) laid over
  shallow water or a deep lake works as a bridge: people walk on it and road
  vehicles drive over it (`axis.dm` lets a vehicle onto deep water under any
  non-dense cover). Floor cover items refuse deep saltwater, and repaired floors
  sink there, so the sea could not be bridged.
- Crafting is refused while standing on deep water, so nothing could be built on
  a floor over deep water from the crafting menu.

## Bridge spans

Two spans, crafted from the construction lists behind Reinforced Concrete
research (Industrial era):

- **steel bridge span**: 4 steel.
- **concrete bridge span**: 6 clay.

Use a span on the water tile in front of you (or in hand to build ahead). The
builder must stand on firm footing: the shore, the shallows or the bridge
built so far, never swimming or in a boat. The tile must be water with no
floor, vessel or dense object on it. Any water works, including the deep sea.

The deck (`/obj/covers/bridge`, `/obj/covers/bridge/concrete`) is an ordinary
floor cover: it does not burn or sink, people walk on it, and crafting works
while standing on it, so roads and railway track are laid on top in the usual
way. Rails on a deck are ordinary `/obj/structure/rails`, so the rail network
(`rail_network.dm`) and party train stations count them. Ships cannot pass
under a bridge.

A hammer takes a bare deck apart again (15 s) and gives the span back. Roads,
track, vehicles and people have to come off first. A deck destroyed by
shelling drops any track on it into the water.

## Track laying

`bridge_deck_at(T)` returns the deck on a tile. Piece-by-piece track laying
(`track_lay_problem()`) treats water with a bridge deck as firm ground, so
sleepers, rails and spikes go on a deck the same way as on land.
