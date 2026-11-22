// Sprinting: a faster run that burns stamina hard (code/game/mob/living/carbon/human/sprint.dm).

// A sprint step takes the run delay divided by this.
#define SPRINT_SPEED_MULT 1.35
// Stamina a sprint step costs, in running steps.
#define SPRINT_STAMINA_MULT 4
// Food and water a sprint step costs, in running steps.
#define SPRINT_UPKEEP_MULT 2
// A sprint drops back to a run below this share of maximum stamina...
#define SPRINT_STOP_FRACTION 0.2
// ...and cannot start again until stamina is back above this share.
#define SPRINT_START_FRACTION 0.35
// Deciseconds between two sprint collisions.
#define SPRINT_COLLIDE_COOLDOWN 10
// Percent chance, between equals, that a sprinter knocks a standing person over.
#define SPRINT_KNOCKDOWN_CHANCE 60
// Percent chance, between equals, that the sprinter goes down too.
#define SPRINT_SELF_FALL_CHANCE 20
// Percent chance, for an average person, of going down after slamming into a wall or door.
#define SPRINT_SLAM_FALL_CHANCE 15
// Force a sprinting shoulder puts into a door, gate or barricade, in wooden hit points,
// for an average person (structure_impact()).
#define SPRINT_RAM_FORCE 15
// Stamina a collision costs the sprinter.
#define SPRINT_COLLIDE_STAMINA 10
