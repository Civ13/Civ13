# Laying railway track

Val (2026-11-07): track is built on the ground one piece at a time, like real
track, instead of crafting finished rails and picking their orientation from
the crafting menu. Track also has to come apart again.

## Building

Both parts are in the trains section of the crafting menu, behind the same
research as before (`rail_steam`):

- **railway sleepers**: 1 wood, enough for one tile.
- **rails**: 1 iron, a pair of rails for one tile.

1. Use the sleepers on an adjacent tile (or in hand to lay them on the tile in
   front of you). The ground must be firm, dry and clear.
2. Use the rails on the sleepers.
3. Hit the rails with a hammer to spike them down. Only now is the tile track:
   trains, railway stations and anything else that looks for rail ignore
   unfinished tiles (`/obj/structure/rail_bed` is not `/obj/structure/rails`).

## Shape

Nobody picks an orientation. A new tile lines up with the track around it
(`track_shape_for()`):

- Track already leading into the tile wins. One line leading in carries
  straight on; two lines from perpendicular sides make a curve; a crossing of
  two whole lines follows the way the layer faces.
- With nothing leading in, the tile joins a loose end straight ahead of or
  behind the layer (and may curve to one more). A loose end only off to the
  side is ignored, so a new line can start beside the tip of another.
- A lone tile runs the way the layer faces.

After a tile is laid, loose ends it leads to turn to meet it. A loose end is
unfinished sleepers or finished plain track at the end of a line (at most one
neighbour joined to it) with no wagon on it. So a corner is laid by running the
line on past the turn's tile and then laying the next tile to the side; the
turn's tile bends into a curve, even if it was already spiked. Tiles in the
middle of a line, switches, rotators and buffer ends never change.

## Taking track apart

A crowbar works in reverse, one step per use: it pulls the spikes from finished
plain track (the rails sit loose on their sleepers again), lifts the loose
rails off (giving back the rails), then pries up the sleepers (giving them back).
Switches, rotators and buffer ends come apart in one step for their iron
(2, 3 and 1). Nothing comes apart while a wagon stands on the tile. A hammer on
finished track no longer dismantles it into wood.

Switches, rotator platforms and train levers are still crafted whole.
