// Deeper underground ores (docs/underground-level.md, "What each depth
// holds"). Each underground level has its own table: the cave under the
// surface keeps today's rates, the second level is the iron, copper, tin and
// coal level, the third holds the silver, gold, gems, sulphur and saltpetre,
// and the fourth the richest precious veins, diamonds, uranium and the heavy
// alloy ores. Shallow ores thin out with depth: bauxite is weathered surface
// rock and flint is chalk that only the upper two levels reach.
//
// The factor multiplies a resource's chance alongside the continent's own
// (continent_ore_factor in continent_resources.dm), so era gates stay as they
// are: depth makes an ore richer where it is already found, never earlier.

// Factors for depths 2, 3 and 4; depth 1 and the surface are always 1.
/proc/underground_ore_depth_table()
	var/static/list/table = list(
		"copper" = list(1.5, 1.25, 1),
		"tin" = list(1.5, 1.25, 1),
		"iron" = list(1.5, 1.25, 1),
		"zinc" = list(1.5, 1.25, 1),
		"lead" = list(1.5, 1.5, 1.25),
		"coal" = list(2, 1.5, 1),
		"saltpeter" = list(1.25, 2, 1.5),
		"sulphur" = list(1.25, 2, 2.5),
		"silver" = list(1.5, 2.5, 3),
		"gold" = list(1.5, 2.5, 3),
		"diamond" = list(1.5, 2.5, 4),
		"uranium" = list(1.5, 2, 3),
		"gems" = list(1.5, 2, 3),
		"nickel" = list(1.5, 2, 2),
		"cobalt" = list(1.25, 1.5, 2),
		"chromite" = list(1.25, 1.5, 2),
		"bauxite" = list(0.5, 0.25, 0.25),
		"flint" = list(0.5, 0, 0),
		"obsidian" = list(1, 1.5, 2),
		"cinnabar" = list(1, 1.5, 2),
	)
	return table

// What resource's chance is multiplied by at turf T for its depth.
/proc/underground_ore_factor(resource, turf/T)
	if (!T)
		return 1
	var/depth = underground_depth_of(T.z)
	if (depth < 2)
		return 1
	var/list/table = underground_ore_depth_table()
	var/list/row = table[resource]
	if (!row)
		return 1
	return row[min(depth, row.len + 1) - 1]

// The surface tile over an underground cell, for checks that look at the
// land above (volcanoes); null when T is not underground.
/proc/underground_surface_over(turf/T)
	if (!T || !underground_depth_of(T.z))
		return null
	return locate(T.x, T.y, underground_surface_z())
