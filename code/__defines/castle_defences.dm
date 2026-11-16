// Castle defences (code/modules/1713/siege/castle_defences.dm).

// What is cut through a wall to shoot out of.
#define SLIT_NONE 0
#define SLIT_ARROW 1
#define SLIT_GUN 2

// directional_cover_verdict(): what a one-sided defence does to a shot.
#define DIRECTIONAL_COVER_DEFAULT 0	// not one-sided for this shot: the usual cover rules
#define DIRECTIONAL_COVER_PASS 1	// the shot flies on through
#define DIRECTIONAL_COVER_BLOCK 2	// the shot hits the stone
