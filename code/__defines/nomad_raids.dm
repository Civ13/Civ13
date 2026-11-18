// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Nomad raid limits (nomad_raid.dm)
#define NOMAD_RAID_MIN_MEMBERS 2
#define NOMAD_RAID_MAX_MEMBERS 6
#define NOMAD_RAID_MIN_DEFENDERS 2 // automatic targeting skips smaller groups
#define NOMAD_RAID_FIGHT_RANGE 12
#define NOMAD_RAID_EDGE_LIMIT 120 // farthest spawn distance from the target
#define NOMAD_RAID_EDGE_SPREAD 30
#define NOMAD_RAID_VIEW_MARGIN 12
#define NOMAD_RAID_PARLEY_TIME (90 SECONDS)
#define NOMAD_RAID_EARLY_ASSAULT (30 SECONDS) // shortest parley before a coordinator may attack
