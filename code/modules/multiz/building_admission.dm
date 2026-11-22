// Admission of the open-air building levels every map has (building_levels.dm);
// the budget default in world_z_budget.dm refuses them. Every map may grow
// ten (building_levels, 0 opts out), the full height planned for towers of
// the strongest supports: roofs may add up to N open-air
// levels above the compiled map, one at a time and only as high as something
// is built. The levels are saved sparsely (persistence/functions.dm) and
// their untouched cells stay asleep (building_lighting.dm). Measured
// 2026-11-13 on 516.1688 with Gaia (500 x 350): an added level takes 0.29 s
// and 0.9 MB, costs nothing per tick, saves in about half a second while
// empty, and a world with ten of them saved and reloaded without error. Cost
// follows what is built (about 3.4 KB resident and 2.5 KB of save per floor
// cell), so the ceiling is Gaia's plane with ten building levels (500 x 350 x
// 12), the ten-level world that was saved and reloaded.
#define NEW_Z_BUILDING_MEASURED_CELLS 2100000
// A large one-level map with a standing open-air level (the Americas, 1132 x
// 920 and 848 x 1224; standing_building_level.dm) may grow every open-air
// level above its unformed cave: at most five planes of 1,050,000 cells, the
// cave not counted. Measured 2026-11-15 on 516.1688 with the north map: the
// standing level costs about 5 MB while empty, a reload peak of 1526 MB
// against 1401 MB without it (docs/americas-regions.md); with the cave 1657 MiB
// (docs/underground-level.md). Measured 2026-11-16 with the cave and all four
// open-air levels (z 6): save 181 s at a 1416 MiB peak, reload 536 s at a
// 2053 MiB peak, each empty plane saved in 465 bytes.
// Raised 2026-11-17 to ten open-air levels over the surface (11 planes of
// up to 1,045,000 cells, the cave not charged): levels are added only as high
// as something is built, and the standby loader takes the reload off play.
#define NEW_Z_STANDING_MEASURED_CELLS 11500000
/obj/map_metadata/var/building_levels = 10

/datum/world_z_budget/building_admitted(target_z)
	if (!map || !map.building_levels)
		return FALSE
	// The underground levels (dug_underground.dm) are added levels beside the
	// building levels, wherever they lie among them. A restore cannot tell
	// them apart until their cells load, so every one the map may add counts,
	// and as unformed rock none of them is charged cells.
	var/caves = underground_added_limit()
	if (target_z > building_base_maxz() + min(map.building_levels, initial(roof_limit)) + caves)
		return FALSE
	if (caves && !dug_underground_fits())
		return FALSE
	var/pending = (instance_reserve - instance_used) + (safehouse_reserve - safehouse_used)
	// A standing map's open-air levels: every full plane but the unformed underground.
	if (map.building_level_standing && building_base_maxz() == 1 && !pending && world.maxx * world.maxy * (target_z - caves) <= NEW_Z_STANDING_MEASURED_CELLS)
		return TRUE
	return world.maxx * world.maxy * (target_z + pending - caves) <= NEW_Z_BUILDING_MEASURED_CELLS
