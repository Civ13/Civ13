// Modular aircraft flight states (code/modules/1713/machinery/modular_vehicles/aircraft/).
// Shared with the vehicle HUD, which is compiled before the aircraft module.
#define AIRCRAFT_GROUND "ground"
#define AIRCRAFT_LOW "low"
#define AIRCRAFT_CRUISE "cruise"
// Altitude is counted on the terrain height scale of the ground below (0-15,
// code/modules/1713/terrain_height.dm). Low flight covers that scale; only
// above its top does the aircraft count as cruising over upper storeys.
#define AIRCRAFT_SURFACE_CEILING 15
#define AIRCRAFT_MAX_ALTITUDE 20
// How far one press of Climb or Descend moves the target altitude.
#define AIRCRAFT_CLIMB_STEP 5
// Within this many levels of the ground, Descend tries to land.
#define AIRCRAFT_LANDING_CLEARANCE 2
