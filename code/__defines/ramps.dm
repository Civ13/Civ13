// What a ramp (code/modules/multiz/ramps.dm) lets a climber bring along.
// level_change_load_problem in lifting_machines.dm reads these too.
#define RAMP_FOOT 1 // walk up it, dragging what stairs take
#define RAMP_WHEELS 2 // and wheeled carts, wheelchairs
#define RAMP_HEAVY 3 // and a hoist-only load, with a helper
#define RAMP_HEAVY_TIME 100 // a heavy haul up a ramp, as long as a heavy hoist
