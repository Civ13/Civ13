# Broadside map

`run.py` checks the Broadside TDM map (`maps/1713/broadside.dmm`, written by
`tools/broadside/make_map.py`) and its rules in
`code/game/objects/map_metadata/broadside.dm`.

Static checks: the map matches its generator, each side has one tiller, the
rigged masts can drive each hull at half ahead, the map is in the 1713 vote
list, the Naval Battle jobs serve it and joining puts a crewman aboard.

The headless probe compiles the real map in and checks that both ships are
commissioned as built hulls with their guns loaded, crewmen join on their own
ship, a ship sails at the battle pace carrying her guns, the boatswain's call
lays the guns on the enemy hull and fires them, boarders hold a tiller only
while her crew are away, and a ship that loses too much planking is sunk.

    python3 tests/broadside/run.py --byond-bin /root/byond-516.1688/byond/bin
    python3 tests/broadside/run.py --byond-bin /root/byond-516.1688/byond/bin --negative-control no-pace

The negative control sails the ships at the ordinary sea pace and must fail.
