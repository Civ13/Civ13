// Defines shared across files. They live here so civ13.dme compiles in any
// include order, including the alphabetical order the Dream Maker IDE saves.

// Painting size and palette (painting_codec.dm)
#define PAINT_MAX_COLOURS 16
#define PAINT_MAX_SIDE 128

// Paintings per world (paintings.dm)
#define PAINTING_REGION_CAP 300 // finished wall paintings per world; small ones count a quarter
