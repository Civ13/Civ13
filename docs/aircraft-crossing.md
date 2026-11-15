# Flying between continents

Code: `code/modules/1713/machinery/modular_vehicles/aircraft/aircraft_crossing.dm`.
Routes come from the shared continent layout in `code/modules/naval/sea_lanes.dm`
([ship voyages](ship-voyage.md#sea-routes-between-the-continents)): every
continent marked with a flight level (the fourth field of `continent_layout`)
can be flown to from any other continent on the layout. Today that is every
continent. On Europe and Asia the open-air level is the level above the
surface and the dug cave comes after it; arriving planes look for the lowest
open-air level, not a fixed z.

## Setting off

The pilot uses **Fly to another land** on the control column (or is told to
at the edge of the land). She must be in the air, with a frame within 8 tiles
of the map edge, no tow line, the transfer agent reachable and no save running.
The menu lists each continent whose world is up or can wake, with its bearing
and its distance in layout tiles. The flight burns 20 seconds of cruise fuel
for each tile at once, from her tank; with too little she is refused before
anything moves. While the menu is open she holds steady instead of stalling at
the edge.

Everyone aboard must be a player character with a BYOND account, conscious
and free, carrying only what region travel takes. An animal aboard keeps her
home. The control column goes back into its seat. The crew wait in a hidden
gate while she is packed with the bounded vehicle codec that hangars use
(`extraction/vehicle_codec.dm`): engine, tank and fuel, frames, wheels, seats
and what is stowed in her hold. A plane the codec refuses (too big, something
loose aboard) flies on where she was and the pilot hears why. Once packed she
is taken out of the sky, and the pilot leaves first, carrying her record (about
20 KB for a light plane, under the 49152-byte ship payload limit); the others
follow on the same flight id.

## Arriving

The pilot's arrival builds her on the open-air level (the lowest level whose
sample points are `/turf/sky/building`), 8 tiles in from the edge behind her
heading, so she flies inward, along that edge as near as possible to where she
left the other map. She keeps her flight state (low or cruise) and holds steady
for up to 30 seconds. The pilot is buckled in, the engine starts and she flies
on in the gear she left in. Other crew come aboard her. If the pilot could not
come, whoever brought her takes the controls. A flight refused at the far side
comes back where she left, if that sky is still clear. With no clear sky at
all she is lost and admins are told; the crew arrive on the ground.

The crew make their home in the land they fly to, as with any trip between
regions. A world restarted mid-flight does not replay the flight; the plane
was not saved after she left.
