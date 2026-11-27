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

## Over the map edges

Where the host has switched on edge travel (the group option
`edge_travel_oceans`), there is no destination menu: Fly to another land only
says to fly on over the edge. A plane that flies into the edge of the map
(`do_vehicle_check`) sets off by itself to whatever her heading meets beyond
it, by the world links table (`aircraft_edge.dm`, `air_edge_route()`).

- A land that shares the edge is one leg of flying.
- Oceans have no air level, so a plane flying into one is carried straight
  across it in the same heading: to Gaia or Greenland if her line crosses the
  island's box in the Atlantic, else to the far edge and on to what lies
  beyond. Each 100 tiles of ocean is a leg; a leg burns the same 20 seconds of
  cruise fuel a tile of the old layout did.
- With nothing to land on that way (north over the Arctic, round the Southern
  Ocean), or too little fuel, she is stopped at the edge as before and stalls
  if she does not turn.
- She is packed and flown as in "Setting off", and built in from the arrival
  edge at the place along it her line reaches (the payload's `along`).

## Crewed airship voyages

A built airship has **Set out on a voyage** on its helm. Fly within eight
tiles of the map edge and **Hold position** before using it. Where regions
use linked map edges, face the edge you intend to cross; your position on
that edge determines the route and the arrival coast. Elsewhere, choose a
land from the flight chart. The helm asks for confirmation and can wake a
sleeping destination. Crossing itself is abstracted; it does not burn
plane-style cruise fuel or create a separate travel map.

The same ledger entry carries the whole crew and the airship. Arrival waits
for the source region's next successful save, so there cannot be a second
copy of the equipment aboard after a crash. Crew can wait in the destination
lobby for the save to finish. Busy regions may defer that save under their
normal save policy. Every passenger
must be able to travel; a refusal leaves the entire party and ship where they
are. Supported cargo includes loose items, chests with their contents, and
deck engines with nearby attached fuel barrels. The deck materials, damage,
gas type and amount, and gas-cell holes carry over. Unload any unsupported
fixture (including a bomb hatch) or animal first. Pedal airships are not
crewed hulls and do not have this helm option.

The airship arrives holding position. Crew return to their original deck
positions and engines arrive switched off. A turned-back voyage first tries
to return where it started. If no clear sky fits the *entire* deck, the crew
instead arrive at the region entry point with an intact **packed airship**.
The pilot can use it to redeploy the ship once there is room. Older worlds
must update before they can receive a crewed airship.
