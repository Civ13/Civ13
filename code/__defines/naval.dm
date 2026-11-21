// Vessels built from decks of turfs (code/modules/naval/): a ship that is too
// large for the modular vehicle system lives on the map as turfs on one level
// per deck and relocates as a block while it sails.

// Ticks between hops at sea.
#define VESSEL_HOP_INTERVAL 300
// Tiles moved per hop for each telegraph step (full ahead is 3 steps).
#define VESSEL_TILES_PER_STEP 2
// Ticks of warning on the water before a hop or a turn covers it.
#define VESSEL_PATH_WARNING 50

#define VESSEL_SPEED_STOP 0
#define VESSEL_SPEED_SLOW 1
#define VESSEL_SPEED_HALF 2
#define VESSEL_SPEED_FULL 3

// Fuel oil (units of diesel or petroleum) a hop burns per telegraph step, and
// how much a carrier's bunkers hold: about 170 hops at full ahead.
#define VESSEL_FUEL_PER_STEP 2
#define VESSEL_FUEL_CAPACITY 1000
// How far the chart looks ahead of the bow.
#define VESSEL_CHART_RANGE 12
// Flooded compartments (average water at or over the deck's flooded mark)
// that sink a vessel; each one before that takes a telegraph step off her.
#define VESSEL_SINK_COMPARTMENTS 3
// Tiles the island radar picks out ships and aircraft at.
#define VESSEL_RADAR_RANGE 40

// Carrier compartments on the hangar deck, bow to stern.
#define CARRIER_COMP_FORWARD "carrier_forward"
#define CARRIER_COMP_MAGAZINE "carrier_magazine"
#define CARRIER_COMP_HANGAR "carrier_hangar"
#define CARRIER_COMP_QUARTERS "carrier_quarters"
#define CARRIER_COMP_BUNKER "carrier_bunker"
#define CARRIER_COMP_ENGINE_ROOM "carrier_engine_room"

// Motor freighter compartments below the waterline (slipway.dm).
#define FREIGHTER_COMP_HOLD "freighter_hold"
#define FREIGHTER_COMP_ENGINE_ROOM "freighter_engine_room"

// The open sea (code/modules/naval/open_sea.dm): the side of a sea cell in
// tiles and the width of the tide race round each one, how many loaded sites
// the cells hold at once and how many of them a mooring post may keep, and
// the ticks a site nobody is at stays loaded.
#define SEA_CELL_PITCH 100
#define SEA_CELL_MARGIN 7
#define SEA_HOME_SPAN 3 // The home waters are this many cells on a side, with no tide race between them.
#define SEA_SITE_CAP 8
#define SEA_KEPT_CAP 4
#define SEA_SITE_LINGER 6000
// How near the water a trail marker must stand on the home island.
#define OPEN_SEA_LANDING_TILES 3

// Points of sail (naval/points_of_sail.dm): the angle between the bow and
// where the wind blows from, and how many times longer a step under sail
// takes there than on a beam reach. A square-rigged hull cannot point
// straight into the wind, so heading upwind she beats: tacks across it at
// close-hauled pace and makes good about a third of a beam reach.
#define SAIL_POINT_BEATING 0
#define SAIL_POINT_CLOSE 45
#define SAIL_POINT_BEAM 90
#define SAIL_POINT_BROAD 135
#define SAIL_POINT_RUNNING 180
#define SAIL_DELAY_BEATING 3.5
#define SAIL_DELAY_CLOSE 2.5
#define SAIL_DELAY_REACH 1
#define SAIL_DELAY_RUNNING 1.3

// Rowing benches (naval/rowing_bench.dm): one manned bench pushes this many
// tiles of built hull, and a rower spends this much stamina per telegraph
// step every half minute she is rowed (a rested rower holds about 100 and
// gets back about 30 in that time). Below the last figure nobody can row.
#define CRAFT_OAR_THRUST 4
#define OAR_STAMINA_PER_STEP 20
#define OAR_MIN_STAMINA 10

// Hull classes, seam wear, fouling and bilge depth (hull_ledger.dm)
#define HULL_CLASS_SMALL 1
#define HULL_CLASS_BOAT 2
#define HULL_CLASS_SHIP 3
#define HULL_SEAMS_FAIR (1 / 3)
#define HULL_SEAMS_WORKING 0.6
#define HULL_SEAMS_OPEN 0.9
// How foul her bottom is where its name changes (hull_fouling.dm).
#define HULL_FOUL_SLIMED 0.1
#define HULL_FOUL_WEEDY 0.4
#define HULL_FOUL_FOUL 0.75
// How deep the bilge is, for messages: the share of her capacity each begins at.
#define HULL_DEPTH_DRY 0
#define HULL_DEPTH_DAMP 1
#define HULL_DEPTH_ANKLE 2
#define HULL_DEPTH_KNEE 3
#define HULL_DEPTH_AWASH 4
#define HULL_DEPTH_LISTING 5
#define HULL_DEPTH_FULL 6
// Wood a patch over a hole takes (hull_ledger.dm, berth.dm).
#define HULL_PATCH_PLANKS 2

// Outrigger canoes (naval/outrigger_canoe.dm). The sheet is 96x96 with the
// hull on the middle tile (tests/sprites/create_small_boats.py).
#define OUTRIGGER_ICON 'icons/obj/vehicles/outrigger.dmi'
#define OUTRIGGER_BOOM_WOOD 4   // Wood for the two booms and the float.
#define OUTRIGGER_LASH_ROPE 3   // Rope that lashes them on.
#define OUTRIGGER_MIN_ENGINE 100
#define OUTRIGGER_MAX_ENGINE 400
#define OUTRIGGER_MAX_TANK 150

// Hauling small boats over land (naval/boat_hauling.dm): what a boat adds to
// each step of whoever drags her.
#define BOAT_HAUL_LIGHT 1
#define BOAT_HAUL_HEAVY 2
#define BOAT_DRAG_EASY 0.75   // Afloat, on rollers, or with hands enough.
#define BOAT_DRAG_LIGHT 2
#define BOAT_DRAG_HEAVY 6

// Small boat upkeep (naval/small_boat_upkeep.dm). Wear and soak run 0 to 100.
#define BOAT_WEAR_FRESH 0.05     // Per tile travelled on fresh water; salt doubles it.
#define BOAT_LASH_SLACK 50       // Lashings this worn slow her.
#define BOAT_LASH_LOOSE 75       // And this worn let water in.
#define BOAT_SOAK_HEAVY 50
#define BOAT_SOAK_LOGGED 80
#define BOAT_DRESSING_TILES 600  // Tiles a dressing of fat or tar lasts.
#define BOAT_DRY_PER_MINUTE 10   // Soak a hull loses for each minute ashore.
#define BOAT_RAFT_NEW_WEAR 40    // A new raft is bound with bark and vines, not rope.

// Ship's draughts (naval/ship_draught.dm): the sheet is this many tiles each
// way, and a draught keeps to the built hull's limits (craft/built_body.dm).
#define SHIP_DRAUGHT_SIDE 40
#define SHIP_DRAUGHT_MAX_TILES 200
#define SHIP_DRAUGHT_MAX_DECK 300
#define DESIGN_CODE_SHIP_MAX 4000
