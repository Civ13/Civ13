# Pollution carried downstream

`code/modules/1713/river_foul.dm`. Water quality by kind is in
[water-quality.md](water-quality.md); river reaches are in
[river-flood.md](river-flood.md).

## Two scales

Close by, sewer outfalls, ditches and cesspits foul wells and aqueduct intakes
within a few tiles (`sewer_fouls_near` in `sewers.dm`). On a river with a
current an outfall fouls only what lies downstream of it
(`fouls_toward`: the offset from the outfall's water tile has a non-negative
dot product with the current), so a town can draw water above its own outfall.

Further away, each river reach carries a foul load. Every minute, after the
water step:

- sources lying in the reach add to it: an outfall that has carried waste
  lately adds 1, a dead body (human or animal) in the water 0.25, and a piece
  of waste (not compost) 0.05;
- a tenth of the load breaks down;
- the rest leaves with the water in the same share as the water itself
  (`RIVER_FLOOD_RELEASE`, 0.35) into the reach downstream, upstream reaches
  first, so a load reaches the next reach in the same minute.

A one-off load clears within about a quarter of an hour.

Loose things are tracked when they enter non-salt water (at most 600 at a
time) and dropped once they leave or are deleted. Nothing loops over tiles.

## Germs

A reach adds `load / max(storage, 5) * 28` germs to its water, capped at 2, so
a big river dilutes what fouls a stream. `water_germ_level()` adds this to the
water's own germs for non-salt water. At 0.5 the water counts as foul: the
examine text warns of scum, an aqueduct intake there is fouled, and fishing
grounds regrow more slowly (down to a quarter at the cap).

## Scum

Each reach shows scum 0 to 3, rising at germ levels 0.5, 1 and 1.5 and falling
0.2 below each step so it does not flicker. A change bumps
`river_scum_revision`. Each client draws `icons/effects/water_scum.dmi` as its
own images over river water within 12 tiles, and redraws when it has moved 4
tiles or the revision changed (called from `flood_life_tick`). Salt water and
ice show none.

## Saving

The loads are the last block of `river_flood_state`, one per reach after the
hollows. A state without them loads with clean rivers.

## Tests

`tests/river_flow/foul_probe.dm` (native) checks the hand-off downstream,
dilution, the germ cap, scum hysteresis, clearing, and the save block.
