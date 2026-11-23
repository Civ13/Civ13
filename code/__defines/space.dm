// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Orbit upkeep (orbit_upkeep.dm)
#define ORBIT_ALTITUDE_START 400
#define ORBIT_REBOOST_COST 20

// Orbit stations (orbit_world.dm)
#define ORBIT_STATION_PLANE_QUOTA 6

// Orbital flight (orbital_flight.dm)
// The epoch (map.ordinal_age) orbit opens in: 1969, as the Moon.
#define ORBIT_MIN_AGE 7

// Space station plans (space/station_plan.dm): modules on a square grid of
// this many slots each way, one module pitch (HABITAT_MODULE_SPACING) apart,
// with the middle slot on the middle of the station's plane.
#define STATION_PLAN_SIDE 7
#define STATION_PLAN_MAX_MODULES 12
#define DESIGN_CODE_STATION_MAX 400

// Rocket plans (space/rocket_plan.dm): one stack of pieces from the pad up.
#define ROCKET_PLAN_MAX_PIECES 20
// Sections (pieces that take height in the stack) a rocket may have.
#define ROCKET_PLAN_MAX_SECTIONS 16
// Sections one storey of the launch stand holds; storeys above the first
// mount from the levels above it.
#define ROCKET_STOREY_SECTIONS 4
#define DESIGN_CODE_ROCKET_MAX 120
// Leg ids, in the order a mission flies them.
#define ROCKET_LEG_LIFTOFF "liftoff"
#define ROCKET_LEG_ORBIT "orbit"
#define ROCKET_LEG_RETURN "return"
#define ROCKET_LEG_TRANSFER "transfer"
#define ROCKET_LEG_LANDING "landing"
#define ROCKET_LEG_LUNAR_RETURN "lunar_return"
