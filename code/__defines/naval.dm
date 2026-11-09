// Vessels built from decks of turfs (code/modules/naval/): a ship that is too
// large for the modular vehicle system lives on the map as turfs on one level
// per deck and relocates as a block while it sails.

// Ticks between hops at sea.
#define VESSEL_HOP_INTERVAL 300
// Tiles moved per hop for each telegraph step (full ahead is 3 steps).
#define VESSEL_TILES_PER_STEP 2

#define VESSEL_SPEED_STOP 0
#define VESSEL_SPEED_SLOW 1
#define VESSEL_SPEED_HALF 2
#define VESSEL_SPEED_FULL 3

// Carrier compartments on the hangar deck, bow to stern.
#define CARRIER_COMP_FORWARD "carrier_forward"
#define CARRIER_COMP_MAGAZINE "carrier_magazine"
#define CARRIER_COMP_HANGAR "carrier_hangar"
#define CARRIER_COMP_QUARTERS "carrier_quarters"
#define CARRIER_COMP_BUNKER "carrier_bunker"
#define CARRIER_COMP_ENGINE_ROOM "carrier_engine_room"
