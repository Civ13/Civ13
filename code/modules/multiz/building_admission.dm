// Admission of the open-air building levels a map opts into
// (building_levels.dm); the budget default in world_z_budget.dm refuses them.
// A map opts in with building_levels = N: roofs may add up to N open-air
// levels above the compiled map, one at a time and only as high as something
// is built. The levels are saved sparsely (persistence/functions.dm) and
// their untouched cells stay asleep (building_lighting.dm). Measured
// 2026-11-13 on 516.1688 with Gaia (500 x 350): an added level takes 0.29 s
// and 0.9 MB, costs nothing per tick, saves in about half a second while
// empty, and a world with ten of them saved and reloaded without error. Cost
// follows what is built (about 3.4 KB resident and 2.5 KB of save per floor
// cell), so the ceiling stays at Gaia's plane with four building levels.
#define NEW_Z_BUILDING_MEASURED_CELLS 1050000
/obj/map_metadata/var/building_levels = 0

/datum/world_z_budget/building_admitted(target_z)
	if (!map || !map.building_levels || target_z > building_base_maxz() + min(map.building_levels, NEW_Z_ROOF_CEILING))
		return FALSE
	// A dig-down map's cave is already the level above the surface plane.
	if (dug_underground_supported())
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	return world.maxx * world.maxy * (target_z + pending) <= NEW_Z_BUILDING_MEASURED_CELLS
