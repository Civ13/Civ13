// Zombie city levels: the upper floor of two-storey buildings, the stairs
// between the floors, the roofs and the indoor area.
//
// The upper floor is planned on a second grid of the same size (sky
// everywhere a building is not) with the same procs that plan the ground
// floor: use_level(TRUE) swaps the grids, door and loot lists under the
// generator's feet, and use_level(FALSE) swaps them back. Both levels are
// checked before anything touches the world: every upper door and loot spot
// must be reachable from a staircase. Stairs are the one-cell ww2 ladder
// pair the maps use, so no z-level connection table is needed; the two
// halves share a ladder id and sit on the same x, y.

/area/caribbean/zombie_city/indoors
	name = "Zombie City (indoors)"
	location = AREA_INSIDE

var/global/area/caribbean/zombie_city/indoors/zombie_city_indoor_area = null

// City roofs are fixed architecture over a shared indoor area: they never
// swap the turf's area in and out and never collapse for want of support.
/obj/roof/concrete/zombie_city
	switch_area = FALSE
	current_area_type = /area/caribbean/zombie_city

/obj/roof/concrete/zombie_city/is_supported()
	return TRUE

/obj/roof/concrete/zombie_city/collapse_check()
	return

/obj/roof/wood/zombie_city
	switch_area = FALSE
	current_area_type = /area/caribbean/zombie_city

/obj/roof/wood/zombie_city/is_supported()
	return TRUE

/obj/roof/wood/zombie_city/collapse_check()
	return

/datum/zombie_city_generator/proc/use_level(upper)
	if (!layout.upper_z || upper == planning_upper)
		return
	var/list/swap = cells
	cells = other_cells
	other_cells = swap
	swap = props
	props = other_props
	other_props = swap
	swap = blocked
	blocked = other_blocked
	other_blocked = swap
	swap = loot_cells
	loot_cells = other_loot_cells
	other_loot_cells = swap
	swap = door_cells
	door_cells = other_door_cells
	other_door_cells = swap
	planning_upper = upper
	z = upper ? layout.upper_z : layout.ground_z

// The upper floor of one building: the same shell without exterior doors,
// windows that never break, rooms along the same corridor (the room kinds
// carry on from the ground floor), furniture, mess and a few loot spots.
/datum/zombie_city_generator/proc/plan_upper_floor(datum/zombie_city_building/D, datum/zombie_city_block/B)
	use_level(TRUE)
	var/wall = wall_code(D.kind, B.district)
	fill_rect(D.x1, D.y1, D.x2, D.y2, floor_code(D.kind))
	for (var/x = D.x1 to D.x2)
		set_cell(x, D.y1, wall)
		set_cell(x, D.y2, wall)
	for (var/y = D.y1 to D.y2)
		set_cell(D.x1, y, wall)
		set_cell(D.x2, y, wall)
	var/front_y = D.facing == NORTH ? D.y2 : D.y1
	var/back_y = D.facing == NORTH ? D.y1 : D.y2
	for (var/x = D.x1 + 2, x <= D.x2 - 2, x += 3)
		set_cell(x, front_y, ZC_WINDOW)
		set_cell(x, back_y, ZC_WINDOW)
	for (var/y = D.y1 + 2, y <= D.y2 - 2, y += 4)
		set_cell(D.x1, y, ZC_WINDOW)
		set_cell(D.x2, y, ZC_WINDOW)
	var/ix1 = D.x1 + 1
	var/ix2 = D.x2 - 1
	layout_rooms(D, B, ix1, ix2, ix2 - ix1 + 1, D.y2 - D.y1 - 1)
	clear_door_approaches(D)
	furnish_level(D, B)
	place_loot(D)
	layout.counts["upper_floors"] = (layout.counts["upper_floors"] || 0) + 1
	use_level(FALSE)

// Every upper door and loot spot must be walkable from a staircase. The
// walk runs from all staircases at once; upper floors never touch.
/datum/zombie_city_generator/proc/validate_upper()
	if (!layout.upper_z)
		return TRUE
	use_level(TRUE)
	var/list/reached = new/list(w * h)
	var/list/steps = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	var/list/queue = list()
	for (var/i in stairs_cells)
		reached[i] = TRUE
		queue += i
	var/head = 1
	while (head <= queue.len)
		var/j = queue[head++]
		var/jy = round((j - 1) / w) + 1
		var/jx = j - (jy - 1) * w
		for (var/list/step in steps)
			var/nx = jx + step[1]
			var/ny = jy + step[2]
			if (nx < 1 || ny < 1 || nx > w || ny > h)
				continue
			var/k = index(nx, ny)
			if (reached[k] || blocked[k] || !passable(cells[k]) || cells[k] == ZC_SKY)
				continue
			reached[k] = TRUE
			queue += k
	var/list/unreachable = list()
	for (var/i in door_cells)
		if (!reached[i])
			unreachable += "upper door [i - (round((i - 1) / w)) * w],[round((i - 1) / w) + 1]"
	for (var/key in loot_cells)
		var/i = text2num(key)
		if (!reached[i])
			unreachable += "upper loot [i - (round((i - 1) / w)) * w],[round((i - 1) / w) + 1]"
	layout.counts["upper_reachable_cells"] = queue.len
	layout.counts["upper_doors"] = door_cells.len
	layout.counts["upper_loot"] = loot_cells.len
	use_level(FALSE)
	if (unreachable.len)
		failure = "[unreachable.len] upper cells unreachable from the stairs: [jointext(unreachable, "; ", 1, min(unreachable.len, 6) + 1)]"
		return FALSE
	return TRUE

// Interior cells of every building, on every floor it has, join one
// indoor area so daylight and weather stop at the walls and roofs hide the
// inside from the street but not from whoever stands in it.
/datum/zombie_city_generator/proc/commit_areas()
	if (!zombie_city_indoor_area)
		zombie_city_indoor_area = new
	var/moved = 0
	for (var/datum/zombie_city_building/D in layout.buildings)
		for (var/level = 1 to D.floors)
			var/level_z = level == 2 ? layout.upper_z : layout.ground_z
			if (!level_z)
				continue
			for (var/x = D.x1 to D.x2)
				for (var/y = D.y1 to D.y2)
					var/turf/T = locate(x, y, level_z)
					if (!T || (x == D.x1 || x == D.x2 || y == D.y1 || y == D.y2) && !istype(T, /turf/floor))
						continue
					ChangeArea(T, zombie_city_indoor_area)
					moved++
			TICK_CHECK
	layout.counts["indoor_cells"] = moved

// Stairs on both floors of every two-storey building, then a roof over the
// top floor of every building.
/datum/zombie_city_generator/proc/commit_levels()
	var/roofs = 0
	for (var/datum/zombie_city_building/D in layout.buildings)
		var/top_z = D.floors == 2 && layout.upper_z ? layout.upper_z : layout.ground_z
		var/roof = (D.kind == "house") ? /obj/roof/wood/zombie_city : /obj/roof/concrete/zombie_city
		for (var/x = D.x1 to D.x2)
			for (var/y = D.y1 to D.y2)
				var/turf/T = locate(x, y, top_z)
				if (!T || !istype(T, /turf/floor))
					continue
				new roof(T)
				roofs++
		TICK_CHECK
	layout.counts["roofs"] = roofs
	if (!layout.upper_z)
		return
	for (var/i in stairs_cells)
		var/y = round((i - 1) / w) + 1
		var/x = i - (y - 1) * w
		var/turf/bottom = locate(x, y, layout.ground_z)
		var/turf/top = locate(x, y, layout.upper_z)
		if (!bottom || !top)
			continue
		var/obj/structure/multiz/ladder/ww2/stairsup/up = new(bottom)
		var/obj/structure/multiz/ladder/ww2/stairsdown/down = new(top)
		up.ladder_id = "zombie-city-[layout.seed]-[x]-[y]"
		down.ladder_id = up.ladder_id
		up.area_id = "zombie_city"
		down.area_id = "zombie_city"
		up.target = down
		down.target = up
		layout.stairs += bottom
	layout.counts["stairs_placed"] = layout.stairs.len
