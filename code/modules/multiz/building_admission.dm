// Admission of the open-air building levels every map has (building_levels.dm);
// the budget default in world_z_budget.dm refuses them. Every map may grow
// four (building_levels, 0 opts out): roofs may add up to N open-air
// levels above the compiled map, one at a time and only as high as something
// is built. The levels are saved sparsely (persistence/functions.dm) and
// their untouched cells stay asleep (building_lighting.dm). Measured
// 2026-11-13 on 516.1688 with Gaia (500 x 350): an added level takes 0.29 s
// and 0.9 MB, costs nothing per tick, saves in about half a second while
// empty, and a world with ten of them saved and reloaded without error. Cost
// follows what is built (about 3.4 KB resident and 2.5 KB of save per floor
// cell), so the ceiling stays at Gaia's plane with four building levels.
#define NEW_Z_BUILDING_MEASURED_CELLS 1050000
// A large one-level map with a standing open-air level (the Americas, 1132 x
// 920 and 848 x 1224; standing_building_level.dm) may grow every open-air
// level above its unformed cave: at most five planes of 1,050,000 cells, the
// cave not counted. Measured 2026-11-15 on 516.1688 with the north map: the
// standing level costs about 5 MB while empty, a reload peak of 1526 MB
// against 1401 MB without it (docs/americas-regions.md); with the cave 1657 MiB
// (docs/underground-level.md). Measured 2026-11-16 with the cave and all four
// open-air levels (z 6): save 181 s at a 1416 MiB peak, reload 536 s at a
// 2053 MiB peak, each empty plane saved in 465 bytes.
#define NEW_Z_STANDING_MEASURED_CELLS 5300000
/obj/map_metadata/var/building_levels = 4

/datum/world_z_budget/building_admitted(target_z)
	if (!map || !map.building_levels)
		return FALSE
	// A dig-down map's cave (dug_underground.dm) is one more added level beside
	// the building levels, wherever it lies among them. Its two full planes must
	// fit the measured profile whether or not the cave is dug yet.
	var/cave = dug_underground_supported() ? 1 : 0
	if (target_z > building_base_maxz() + min(map.building_levels, NEW_Z_ROOF_CEILING) + cave)
		return FALSE
	if (cave && !dug_underground_fits())
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	// A standing map's open-air levels: every full plane but the unformed cave
	// (a restore cannot see the cave yet, so it is counted on a map that has one).
	if (map.building_level_standing && building_base_maxz() == 1 && !pending && world.maxx * world.maxy * (target_z - cave) <= NEW_Z_STANDING_MEASURED_CELLS)
		return TRUE
	return world.maxx * world.maxy * (target_z + pending) <= NEW_Z_BUILDING_MEASURED_CELLS
