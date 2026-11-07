// Admission of the one open-air building level a map opts into
// (building_levels.dm); the budget default in world_z_budget.dm refuses it.
// Maps opt into one roof-added open-air level with building_levels = 1. The
// level is saved sparsely (persistence/functions.dm): an empty Gaia-sized
// plane costs about 40 KB and well under a second to save instead of 34 MB
// and 9 s, and its full-file read-back during a load (about 350 MB of
// savefile tree at peak) disappears. Measured 2026-11-07 on 516.1688 with a
// 500 x 350 x 2 world: native growth plus /turf/sky/building replacement took
// 0.3 s and 20 MiB of resident memory in a bare world; the game's turfs and
// lighting add to that, so the ceiling stays at Gaia's size.
#define NEW_Z_BUILDING_MEASURED_CELLS 525000
/obj/map_metadata/var/building_levels = 0

/datum/world_z_budget/building_admitted(target_z)
	if (!map || !map.building_levels || target_z != building_base_maxz() + 1)
		return FALSE
	// A dig-down map's cave is already the level above the surface plane.
	if (dug_underground_supported())
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	return world.maxx * world.maxy * (target_z + pending) <= NEW_Z_BUILDING_MEASURED_CELLS
