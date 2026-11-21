#define GUN_TYPE_GENERIC 0
#define GUN_TYPE_RIFLE 1
#define GUN_TYPE_PISTOL 2
#define GUN_TYPE_MG  3
#define GUN_TYPE_BOW 4
#define GUN_TYPE_SHOTGUN 5

// Projectile height_enter verdicts (projectile_heights.dm)
// height_enter verdicts.
#define PROJECTILE_HEIGHT_CLEAR 0
#define PROJECTILE_HEIGHT_GROUND 1
#define PROJECTILE_HEIGHT_OVER 2

// Spent casings a fired gun leaves on one tile before later ones are thrown
// away, so machine-gun nests do not bury a tile in brass (projectile.dm).
#define CASINGS_PER_TILE 12
