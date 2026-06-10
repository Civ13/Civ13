// Submarine Constants
#define SUB_SONAR_PASSIVE 1
#define SUB_SONAR_ACTIVE  2

#define SUB_CONTACT_SURFACE   "Surface"
#define SUB_CONTACT_SUBMERGED "Submerged"
#define SUB_CONTACT_AIR       "Air"

#define SUB_NATION_FRIENDLY "Friendly"
#define SUB_NATION_NEUTRAL  "Neutral"
#define SUB_NATION_HOSTILE  "Hostile"

// Thermodynamic / Physics Constants
#define SUB_AMBIENT_TEMP 20
#define SUB_MELTDOWN_TEMP 1000
#define SUB_ACCEL_RATE 0.1
#define SUB_MAX_SPEED_NUCLEAR 30
#define SUB_MAX_SPEED_ELECTRIC 8
#define SUB_BATTERY_DRAIN_ELECTRIC 10 // kW per tick

#define SUB_RADAR_RANGE_SHORT 20000 // meters
#define SUB_RADAR_RANGE_LONG  50000 // meters
#define SUB_RADAR_POWER_SHORT 10 // kW
#define SUB_RADAR_POWER_LONG  50 // kW
#define SUB_SONAR_POWER_PASSIVE 5 // kW
#define SUB_SONAR_POWER_ACTIVE 100 // kW, high power draw

#define SUB_TICK_SCALE 0.5           // Scaling factor for virtual movement
#define SUB_TURN_RATE 1.5            // Degrees per tick the sub can rotate
