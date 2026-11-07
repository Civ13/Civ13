# Gaia first starts

New Gaia Nomads choose independent, uniform random coordinates across the
entire 500x350 authored surface (z=2). Other maps/jobs keep their existing paths.
There are no landmark weights, minimum landmark distance, biome quotas, or
per-map candidate lists. Larger eligible land areas therefore receive more
starts. The surface sea-area islands and swamp-area land are included too.

A candidate must be natural grass, dirt, sand, snow, gravel or rock, outdoors
in a known biome, dry, unoccupied and free of structures, roofs, dense objects,
fire, radiation, mines and bear traps. Underground rock, caves, water including
ice, lava, voids, indoor areas and built floors are excluded. A bounded cardinal
flood search must reach four tiles away over equally safe ground, rejecting
small trapped pockets. This checks local egress, not global connectivity to a
settlement, access to food/water, future weather, or future hazards.

Selection tries at most 512 coordinate pairs. Each egress search retains at
most 64 tiles and each tile admits at most 64 contents. On exhaustion, Join
stays in the lobby, releases the reserved role, and offers a retry. It never
falls back to a landmark or unsafe coordinate. This can reject a very sparse
world despite some eligible ground; it intentionally avoids a full-world scan.

Selection happens after saved-body reclaim admission and before constructing
the body or handing off the mind/client. Both subsequent relocate calls are
no-ops except for ambience. The constructor captures the birthplace area for
the delayed existing biome customization, so crossing a border immediately
does not change the language: tundra/taiga Old Norse, temperate/semiarid/sea
Latin, desert Egyptian, savanna/jungle Japanese. Existing names/appearance rules
are reused. Saved-body identity is unchanged. Established region-group home-bed
respawns retain their existing bed placement, distinct from random first starts.

Run:

    python3 -m unittest discover -s tests/gaia_spawn -p 'test_*.py' -v

The tests translate complete production helper bodies with fake spatial/engine
boundaries, exercise terrain, hazards, occupancy, egress, retry bounds, all
coordinate outcomes on a small world, and bed precedence, then check admission,
restore and birthplace wiring and the authored map. They are registered in the
offline CI baseline. They do not launch BYOND, load a save, or prove connected
client/gameplay behavior. Full-game compilation is reported separately.
