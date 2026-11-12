# River and sea currents, swimming, and seasonal channels

Rivers on the Nomads regions with terrain heights (Gaia, Europe, Jungle and
Asia) carry a current, and so does a belt of the sea off their coasts. Lakes, broad
water, swamps, floods, ice, the shallows by the beach, the open sea and
isolated ponds stay still. The Desert region has no rivers and no sidecar.

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

## Sea currents

The same generator gives salt water a coastal current. The belt of sea from
4 to 16 steps off the land (`SEA_SHORE`, `SEA_BELT`) flows along the lines of
equal distance from the shore, land on the left hand: round a basin the water
turns one way, round an island the other, as a boundary current does. Because
it follows those lines it never sets ashore; a thing adrift is carried along
the coast, not onto it. The shallows inside the belt and the open sea beyond
it are still, so a swimmer or a raft leaves the current by heading for the
beach or straight out. Sea ice counts as shore, belts under 150 tiles (bays
and inlets) stay still, and `build(rows, sea=False)` leaves the sea out.

Besides items and people, the current carries an empty raft: one with nobody
and nothing aboard, not being steered. Wide boats and ships keep their place.
Examining sea water in the belt says which way the current sets.

## Swimming

On the open-world maps (`map.nomads`) a played person may walk out of their
depth and swim (code/modules/1713/swimming.dm). Swimming tires: `swim_tiredness`
rises 4 a life tick in calm deep water, 5 in rain or snow and 8 under a
storm's gale, and at 100 the swimmer goes under and takes the drowning damage
deep water has always dealt. Warnings come at 50 and 80. Out of deep water,
or on a deck or raft, it falls 8 a tick. A lifejacket or a sealed diving suit
floats its wearer at no cost. Anyone unconscious drowns at once, as before.
Battle maps use deep water as their edge and keep it closed, and people with
nobody playing them keep out of deep water as they always did.

    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/sea_probe.dm

Rip currents that pull a swimmer out from the beach are not built yet.

## Flow lines

Flowing water, river or sea, shows which way it runs: a few pale streaks
slide along each flowing tile (`icons/turf/water_flow.dmi`, eight directions
in two variants so a wide current is not one tile repeated). They are shared
images in the turf's overlays, in the slot hill shading uses on land
(`terrain_shade_overlay`), so the same hooks restore them after a floor icon
rebuild or a turf change, they are never clickable and never saved. Still
water and ice have none. The streaks are placed pixel by pixel by a seeded
script:

    python3 tools/weather/make_flow.py            # rewrite the icon
    python3 tools/weather/make_flow.py --check    # exit 1 if stale
    python3 tools/weather/make_flow.py --preview flow.gif

## What the current moves

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
