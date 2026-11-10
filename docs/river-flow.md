# River currents and seasonal channels

Rivers on the Nomads regions with terrain heights (Gaia, Europe, Jungle and
Asia) carry a current. Lakes, broad water, swamps, floods, ice, salt water
and isolated ponds stay still. The Desert region has no rivers and no sidecar.

When a map uses `maps/heights/example.txt`, an optional
`maps/heights/example.flow.txt` describes one z-level. The first lines are
`civ13-river-flow 1`, `size WIDTH HEIGHT`, and `z Z`; exactly HEIGHT rows
follow, north first, each WIDTH characters wide. A dot means no current; n,
e, s and w are cardinal directions and a, b, c and d are north-east,
south-east, south-west and north-west (map rivers are often one tile wide
with diagonal joints). Direction applies only to water turfs. Missing or
invalid files leave the water still.

Sidecars are generated, then reviewed with an overview render:

    python3 scripts/river_flow.py --map maps/nomads/nomads_gaia.dmm --z 2 --heights maps/heights/nomads_gaia.txt --out maps/heights/nomads_gaia.flow.txt
    python3 scripts/river_flow.py --map maps/nomads/nomads_europe.dmm --z 1 --heights maps/heights/nomads_europe.txt --lake-depth 8 --out maps/heights/nomads_europe.flow.txt
    python3 scripts/river_flow.py --map maps/nomads/nomads_jungle.dmm --z 2 --heights maps/heights/nomads_jungle.txt --out maps/heights/nomads_jungle.flow.txt
    python3 scripts/river_flow.py --map maps/nomads/nomads_asia.dmm --z 1 --heights maps/heights/nomads_asia.txt --out maps/heights/nomads_asia.flow.txt

The generator treats water at least `--lake-depth` steps (default 5) from
every bank as a lake, along with its margins; Europe's broad rivers need 8.
Channel runs shorter than 12 tiles stay still. Each network drains to the
sea, else off the map edge, else into its lake, and with heights the water
runs downhill: a priority flood orders tiles by the highest bank on the way
to an outlet. Rerun and re-review a sidecar after editing a map's water or
heights.

Flowing water moves unanchored items and unrestrained living mobs one tile
every five seconds, using normal movement and water collision rules. Covered
water is sheltered. Examine water to see the direction.

A waterwheel generator is built from the bank: the builder stands on land and
the wheel is placed on the flowing water tile they face. It is anchored, so
the current does not move it, and it generates 12 power only while its own
tile flows. The sprite faces the current: face-on across east-west water and
edge-on, with the axle spanning the channel, in north-south water. A cable
coil used on the wheel lays the feed back toward the bank, subject to the
electricity research and era rules.

Seasonal mountain streams are a separate authored feature, not an automatic
conversion of existing water. One possible appearance is a narrow rocky bed
visible throughout the year, with meltwater and ripples in the thaw and a dry
or icy bed outside the flow season. Such channels would need explicit source,
season and downstream information, plus rules for people, items, fishing,
building, saved maps and waterwheels when the water recedes. Existing rivers
and water supplies should remain permanent unless a map explicitly marks them
seasonal. No seasonal channel behavior is implemented here.
