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

// Rocket plan physics (space/rocket_plan.dm): game units, see docs/rocket-plans.md.
#define ROCKET_G 9.81
#define ROCKET_LIFTOFF_TWR 1.2
#define ROCKET_UPPER_TWR 0.3
#define ROCKET_DV_ORBIT 7.0
#define ROCKET_DV_RETURN 0.1
#define ROCKET_DV_TRANSFER 2.5
#define ROCKET_DV_LANDING 1.8
#define ROCKET_DV_LUNAR_RETURN 2.2
#define ROCKET_CREW_MASS 0.1
// A full cargo bay, in tonnes, and the hold items it takes.
#define ROCKET_BAY_TONNES 5
#define ROCKET_BAY_ITEMS 20
#define ROCKET_BOOSTER_DRY 2.5
#define ROCKET_BOOSTER_PROPELLANT 10
#define ROCKET_BOOSTER_THRUST 800
#define ROCKET_BOOSTER_VE 2.4
// Propellant units (reagent) a tonne of propellant takes to load.
#define ROCKET_UNITS_PER_TONNE 5
// Reuse (space/rocket_reuse.dm): from 2013 a first stage with landing legs
// flies back, keeping this share of its propellant to land.
#define ROCKET_FLYBACK_AGE 8
// Below this condition a rocket section will not mount (rocket_works.dm, rocket_reuse.dm).
#define ROCKET_SECTION_MIN_CONDITION 25
#define ROCKET_FLYBACK_RESERVE 0.1
