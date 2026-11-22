// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Fishing water kinds (fishing_grounds.dm)
#define FISH_WATER_SALT "salt"
#define FISH_WATER_FRESH "fresh"
#define FISH_WATER_JUNGLE "jungle"
#define FISH_WATER_SWAMP "swamp"
#define FISH_WATER_FLOODED "flooded"

// Ice (ice_breaking.dm, ice_dynamics.dm), in degrees C of air over the tile.
#define ICE_FREEZE_TEMP -2    // air at or below this freezes open water
#define ICE_MELT_TEMP 1       // air above this melts thin ice and rots thick ice
#define ICE_SALT_LIMIT -12    // salted ice and water stay open above this
#define ICE_SALT_MINUTES 120  // real minutes a handful of salt keeps working
