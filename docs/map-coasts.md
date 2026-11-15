# Map coasts

Ships cross between lands by arriving on free deep salt water within 60 tiles
of a map edge (`code/modules/naval/ship_crossing.dm`). Two hand-drawn lands had
no sea at all, so no ship could land there. `scripts/map_coast.py` cut one
coast into each:

| Land | Level | Edge | Deep | Shallows | Beach |
| --- | --- | --- | --- | --- | --- |
| Desert (225 x 225) | z 2 | north | 6,087 | 900 | 667 |
| Jungle (300 x 300) | z 2 | west | 7,774 | 1,200 | 757 |

    python3 scripts/map_coast.py --map maps/nomads/nomads_desert.dmm --z 2 --side N --land-area /area/caribbean/nomads/desert --seed desert
    python3 scripts/map_coast.py --map maps/nomads/nomads_jungle.dmm --z 2 --side W --land-area /area/caribbean/nomads/forest/Jungle --seed jungle --beach /turf/floor/beach/sand/dark

The tool replaces a band along one edge of one level: deep salt water from the
edge, four tiles of shallows, three of beach, along a wavy shoreline about 30
tiles in (`--mean`, `--swing`). The sea takes `/area/caribbean/sea/sea`.
Objects standing in the new water are removed; fresh water that reaches the
beach strip is kept so rivers run out to sea; spawn landmarks and the map
metadata object are moved straight inland to the first dry open tile. The edit
is deterministic for a map, side and seed, and `--dry-run` prints the counts
only. It is a one-off cutter: running it again on an edge that already has a
coast cuts a second band.

After a cut, rebuild the land's height, current and flood files
([terrain-height.md](terrain-height.md), [river-flow.md](river-flow.md),
[river-flood.md](river-flood.md)) and render the level to review it.
`tests/river_flow/test_generation.py` checks that both edges stay open sea
that shelves to a beach.

A saved world keeps its own copy of the terrain, so a running land shows its
new coast only when that land starts from a fresh world. Which lands a sea
lane joins is set in `code/modules/naval/sea_lanes.dm`, not here.
