// Packed multi-depth mining: floor registry schema (Phase 1, docs/multi-depth-mining.md).
// Shared by code/modules/multiz/mine_floor_registry.dm and its probe, so they live here
// and civ13.dme compiles in any include order.

// Highest registry schema this binary reads. A newer version is refused, never dropped.
#define MINE_REGISTRY_SCHEMA_VERSION 1

// Hard caps checked before any list is walked or allocated. A registry header may
// declare smaller limits; it may never declare larger ones.
#define MINE_REGISTRY_MAX_TEXT 131072      // encoded JSON characters
#define MINE_REGISTRY_MAX_INT 16777215     // largest integer a BYOND number holds exactly
#define MINE_REGISTRY_MAX_MINES 64         // mine records (issued identities)
#define MINE_REGISTRY_MAX_DEPTH 8          // deepest logical floor of one mine
#define MINE_REGISTRY_MAX_FLOORS 128       // floor records across all mines
#define MINE_REGISTRY_MAX_SIDE 255         // floor interior width or height, in tiles
#define MINE_REGISTRY_MAX_BORDER 8         // solid border around a floor, in tiles
#define MINE_REGISTRY_MAX_RESERVED 64      // caller-supplied reserved rectangles
#define MINE_REGISTRY_LINEAGE_MAX 64       // world lineage characters

// floor_state() answers
#define MINE_FLOOR_PRESENT "present"   // a committed record exists
#define MINE_FLOOR_NEW "new"           // issued mine, next depth, never committed: may be generated later
#define MINE_FLOOR_CORRUPT "corrupt"   // the identity was committed but its record is missing: never regenerate
#define MINE_FLOOR_UNKNOWN "unknown"   // unissued mine or depth out of range
