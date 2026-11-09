# River currents and seasonal channels

This is a prototype. No production map has a flow sidecar yet. A map author
must review its channels before enabling currents: existing water heights are
flat, and some Gaia rivers are arms of salt water. Distance to the sea alone
cannot tell a river from a lake, estuary or tidal inlet.

When a map uses `maps/heights/example.txt`, an optional
`maps/heights/example.flow.txt` describes one z-level. The first lines are
`civ13-river-flow 1`, `size WIDTH HEIGHT`, and `z Z`; exactly HEIGHT rows
follow, north first, each WIDTH characters wide. A dot means no current; n,
e, s and w mean a cardinal direction. Direction applies only to water turfs.
Missing or invalid files leave the water still. Map authors can start with
`py -3 scripts/river_flow.py --map MAP --z Z --out FILE`, but its fresh-water
outlet heuristic is only a draft: it does not identify salt-water rivers or
inland outlets, and may mark lake margins as flowing. Never commit its output
without reviewing and correcting the map.

Flowing water attempts to move unanchored items and unrestrained living mobs
one tile every five seconds, using normal movement and water collision rules.
Covered water is sheltered. A waterwheel generator on land next to a flowing
tile can feed an attached cable, subject to the electricity research and era
rules. Examine water to see the direction. Visual current indicators and
in-game behavior still need review.

Seasonal mountain streams are a separate authored feature, not an automatic
conversion of existing water. One possible appearance is a narrow rocky bed
visible throughout the year, with meltwater and ripples in the thaw and a dry
or icy bed outside the flow season. Such channels would need explicit source,
season and downstream information, plus rules for people, items, fishing,
building, saved maps and waterwheels when the water recedes. Existing rivers
and water supplies should remain permanent unless a map explicitly marks them
seasonal. No seasonal channel behavior is implemented here.
