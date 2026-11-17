# River and sea currents, swimming, and seasonal channels

Rivers on the Nomads regions with terrain heights (Gaia, Europe, Jungle and
Asia) carry a current, and so does a belt of the sea off their coasts and off
the Desert's north coast. Lakes, broad
water, swamps, floods, ice, the shallows by the beach, the open sea and
isolated ponds stay still. The Desert region has no rivers; its
sidecar holds the sea current only.

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
    python3 scripts/river_flow.py --map maps/nomads/nomads_desert.dmm --z 2 --heights maps/heights/nomads_desert.txt --out maps/heights/nomads_desert.flow.txt
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
rises 2 a life tick (one second) in calm deep water, 3 in rain or snow and 4
under a storm's gale, and at 100 the swimmer goes under and takes the drowning
damage deep water has always dealt: about 50 seconds afloat in a calm, 25 in
a storm. Warnings come at 50 and 80. Out of deep water, or on a deck or raft,
it falls 4 a tick. A lifejacket or a sealed diving suit
floats its wearer at no cost. A spent swimmer goes under holding their
breath (`swim_hold_breath`) and can still reach the shallows, a boat or a
lifejacket; only when the breath runs out does the drowning damage start.
Anyone unconscious drowns at once, as before.

A dropped connection does not drown a swimmer. A player's body with no
client (`swim_player_away()`: it has a `persistence_owner_ckey`) treads water
without tiring for two minutes from its first life tick in deep water, then
`swim_wash_ashore()` moves it to the nearest shallows or shore within 60 tiles,
spent. The grace comes at most once every ten minutes; unconscious bodies and
bodies nobody owns get none.

Swimming is a body skill (`stats["swimming"]`, 100 to 250, added through
`ensure_late_stats`). `swimming_skill()` reads it without mood, clamped, so
thresholds never flicker. Skill divides the tiredness a tick (50 s afloat at
100, 100 s at 200, 125 s at 250) and the 20 ds deep-water step, never below
8 ds after footwear (`water_step_delay`, shared by `/client/Move` and Check
Movement); rest recovers at skill / 100 times the base rate; the held breath
is 10 + (skill - 100) / 3 seconds (10 to 60) and refills 3 a second afloat or
at rest. A heavy suit adds half its slowdown to the effort. Floodwater keeps
its own lighter step cost.

It trains by distance, not time (`swim_train`): one lesson
(`adaptStat("swimming", 0.6)`, 1.5x in rain, snow or a storm) for every 10
tiles crossed that are not among the last 24, and only while the character is
being played (`client.inactivity` under 2 minutes, or an agent), so floating
or paddling over a small pond teaches nothing. About an hour of real swimming
takes 100 to 250. The first swim in each kind of water (river, sea,
floodwater, storm sea) teaches a lump once per half hour, through the
variety record. A better swimmer within reach doubles the gain
(`skill_master_stats`), and the 150/200/250 milestones pay Natural Science.
Battle maps use deep water as their edge and keep it closed, and people with
nobody playing them keep out of deep water as they always did.

    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/sea_probe.dm

Rip currents that pull a swimmer out from the beach are not built yet.

## Free diving

A swimmer in the open sea over the sea layer may **Dive** (IC verb) to the
seabed straight below on one held breath, the same pool the swimming skill
sets (10 s at 100, 60 s at 250; code/modules/1713/machinery/modular_vehicles/ships/free_diving.dm).
The dive takes 2 s and two seconds of breath; it needs a rested swimmer
(tiredness under 80, breath at least half full). `free_diving` makes
`can_walk_seabed()` true, and the sea layer's `CanPass` asks
`seabed_zone_allowed()`: the shelf for anyone, open water from skill 200, the
deep and the abyss only for sealed suits. On the seabed the diver swims at
the surface swimming speed (20 ds a step divided by skill, floor 8), not the
3 ds a suit walks, and `outside_exposure_step` leaves the breathing to
`free_dive_tick`. **Surface** takes 3 s from the shelf and 6 s from open
water, spending breath on the way. When the breath runs out the diver is
forced up with 20 oxygen damage, or drowns in place at 10 a second under a
hull; anyone unconscious down there drowns. Each dive trains swimming like
surface water (the seabed is its own kind for the first-swim lesson), open
water 1.5x. Suited divers may use Dive too, and Surface drops their weights.

    python3 tests/ecology_spawning/run_linux.py . tests/river_flow/dive_probe.dm

## Scuba

The Scuba Diving node (Industrial, era 7, after Submarines) unlocks a dive
mask (glass, mask slot), swim fins (plastic, shoes: wading and swimming steps
0.6x, `land_slowdown` 1.5 ds a step out of the water) and a scuba set (steel,
back slot, a `pressure_tank` that refills where the diving bottles do).
Art: `tests/sprites/create_diving_gear.py` (states `dive_mask`, `swim_fins`,
`scuba_set`; no in-hand states). Code: `ships/scuba.dm`.

Mask plus a set with air (`scuba_ready()`) lets a swimmer Dive like a free
diver, breathe from the set instead of holding their breath, and reach open
water at any skill; the deep still needs a hard suit. Air use is 3 seconds of
tank a second times sqrt(100 / skill): ten minutes from a full set at 100,
about fourteen at 200. An empty set falls back on the held breath.

Breathing from the set in open water adds 1.5 nitrogen a second (cap 300); the
shelf releases 1 a second, so a stop there is a safety stop. Surfacing with a
load over 60 gives the bends at the excess: each second it drains stamina by
severity / 30, deals severity / 100 brute, and from 60 may knock the diver
down; it falls 0.5 a second, 1.5 lying down or in a bed. **Ascend Slowly**
takes load / 5 x 100 / skill seconds (20 to 60) and clears the load.


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
