// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Feature switches, on by default. A test fixture may define one to 0 first;
// los_context.dm keeps the same guarded defaults for fixtures that use it alone.
#ifndef CIV13_GEOMETRIC_LOS_CORE
#define CIV13_GEOMETRIC_LOS_CORE 1
#endif
#ifndef CIV13_ROOT_TREE_PRESENTATION
#define CIV13_ROOT_TREE_PRESENTATION 1
#endif

// Visibility verdicts (los_context.dm)
#define LOS_DENY 0
#define LOS_WORLD 1
#define LOS_SURFACE 2
#define LOS_OWN_SLOT 3
#define LOS_SELF 4
