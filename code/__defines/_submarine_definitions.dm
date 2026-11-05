// Submarine Constants
#define SUB_SONAR_PASSIVE 1
#define SUB_SONAR_ACTIVE  2

#define SUB_CONTACT_SURFACE   "Surface"
#define SUB_CONTACT_SUBMERGED "Submerged"
#define SUB_CONTACT_AIR       "Air"
#define SUB_CONTACT_TORPEDO   "Torpedo"

#define SUB_NATION_FRIENDLY "Friendly"
#define SUB_NATION_NEUTRAL  "Neutral"
#define SUB_NATION_HOSTILE  "Hostile"

// Thermodynamic / Physics Constants
#define SUB_AMBIENT_TEMP 20
#define SUB_MELTDOWN_TEMP 1000
#define SUB_ACCEL_RATE 0.1
#define SUB_MAX_SPEED_NUCLEAR 30
#define SUB_MAX_SPEED_DIESEL  18
#define SUB_MAX_SPEED_ELECTRIC 8
#define SUB_BATTERY_DRAIN_ELECTRIC 10 // kW per tick
#define SUB_DIESEL_PROPULSION_POWER 500 // kW per diesel engine for direct propulsion

#define SUB_RADAR_RANGE_SHORT 25000 // meters - surface + submerged + air contacts
#define SUB_RADAR_RANGE_LONG  70000 // meters - surface + submerged + air contacts
#define SUB_RADAR_POWER_SHORT 10 // kW
#define SUB_RADAR_POWER_LONG  50 // kW
#define SUB_SONAR_RANGE_PASSIVE 25000 // meters - surface + submerged contacts
#define SUB_SONAR_RANGE_ACTIVE  40000 // meters - surface + submerged contacts
#define SUB_SONAR_POWER_PASSIVE 5 // kW
#define SUB_SONAR_POWER_ACTIVE 100 // kW, high power draw

#define SUB_TICK_SCALE 0.5           // Scaling factor for virtual movement
#define SUB_TURN_RATE 3.0            // Degrees per tick the sub can rotate

// World Map Grid
#define SUB_MAP_SIZE 1000            // 1000x1000 virtual grid
#define SUB_MAP_SCALE 100            // meters per virtual unit (1 unit = 100m, map = 100km x 100km)
#define SUB_MAP_TICK_INTERVAL 20     // Process interval in ticks (2 seconds at 10 TPS)

// NPC AI States
#define SUB_AI_PATROL  1
#define SUB_AI_HUNT    2
#define SUB_AI_ATTACK  3

// Torpedo Constants
#define SUB_TORPEDO_SPEED     25     // Knots
#define SUB_TORPEDO_LIFE      800    // Max range in virtual units
#define SUB_TORPEDO_DETONATE  0.15   // Detonation distance threshold
#define SUB_TORPEDO_DAMAGE    250    // Base hull damage on hit

// Mission Types
#define SUB_MISSION_SINK_CARGO   "SINK_CARGO"
#define SUB_MISSION_PATROL       "PATROL_AREA"
#define SUB_MISSION_REFIT        "REFIT"
#define SUB_MISSION_ESCORT       "ESCORT"
#define SUB_MISSION_RECON        "RECON"
#define SUB_MISSION_RESCUE       "RESCUE"
#define SUB_MISSION_AMBUSH       "AMBUSH"

// Mission Timing
#define SUB_MISSION_RECON_DURATION   30    // Ticks to survive at recon target
#define SUB_MISSION_AMBUSH_TIMEOUT   120   // Ticks to clear all hostiles
#define SUB_MISSION_RESCUE_RANGE     20    // nm - must bring target this close to start
#define SUB_MISSION_FAIL_DELAY       20    // Ticks before next mission after failure
#define SUB_MISSION_SUCCESS_DELAY_MIN 30
#define SUB_MISSION_SUCCESS_DELAY_MAX 60

// Noise Thresholds (for NPC passive sonar detection)
#define SUB_NOISE_SILENT    0
#define SUB_NOISE_LOW       10
#define SUB_NOISE_MEDIUM    30
#define SUB_NOISE_HIGH      60
#define SUB_NOISE_ACTIVE_SONAR 100

// Flooding & Water Physics
#define SUB_BREACH_INFLOW_BASE  5     // cm of water per tick from a fresh hull breach
#define SUB_WATER_DROWNING_LIGHT  50  // cm - ankle deep, minor annoyance
#define SUB_WATER_DROWNING_MOD   100  // cm - waist deep, movement penalty
#define SUB_WATER_DROWNING_HEAVY  150  // cm - chest deep, drowning risk
#define SUB_WATER_FLOODED         200  // cm - fully flooded tile
#define SUB_BILGE_PUMP_DRAIN      10   // cm removed per pump tick
#define SUB_BILGE_PUMP_POWER      15   // kW per pump tick

// Compartment IDs (used on /turf/floor/sub_deck)
#define SUB_COMP_NONE                ""
#define SUB_COMP_FORWARD_TORPEDO     "forward_torpedo"
#define SUB_COMP_STORAGE             "storage"
#define SUB_COMP_OPERATIONS          "operations"
#define SUB_COMP_MEDICAL_BAY         "medical_bay"
#define SUB_COMP_GALLEY              "galley"
#define SUB_COMP_CENTRAL_CORRIDOR    "central_corridor"
#define SUB_COMP_REAR_CORRIDOR       "rear_corridor"
#define SUB_COMP_REACTOR_ROOM        "reactor_room"
#define SUB_COMP_ENGINE_ROOM         "engine_room"
#define SUB_COMP_MANEUVERING         "maneuvering"
#define SUB_COMP_AFT_TORPEDO         "aft_torpedo"

// Compartment air (one habitat ledger per compartment). Partial pressures
// are kPa; amounts are kPa-tiles (kPa times tiles of air).
#define SUB_AIR_SEA_O2_KPA        21     // Fresh air per tile: oxygen
#define SUB_AIR_SEA_INERT_KPA     79     // Fresh air per tile: nitrogen
#define SUB_AIR_MAX_O2_KPA        30     // Electrolysis stops here
#define SUB_AIR_SUFFOCATE_O2_KPA  6      // Below this, crew suffocate
#define SUB_AIR_DANGER_CO2_KPA    5      // Above this, CO2 chokes the crew
#define SUB_AIR_VACUUM_O2_KPA     2      // Panel reports VACUUM below this
#define SUB_AIR_MIN_POCKET        0.1    // A flooded compartment keeps this fraction of its tiles as an air pocket
#define SUB_AIR_VENT_FLOW         0.3    // Fraction ventilation moves toward the shared air each second
#define SUB_AIR_ELECTROLYSIS_O2   0.02   // kPa-tiles of oxygen per compartment per second
#define SUB_AIR_SCRUB_RATE        0.05   // kPa-tiles of CO2 a scrubber removes per second
