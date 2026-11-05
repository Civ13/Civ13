// Zombie city interiors: rooms, furniture, room-aware loot spots and the
// mess the horde leaves behind. Called by the generator for every building
// shell after its outer walls, doors and windows are planned and before the
// plan is checked, so everything here is still pure grid work: no world
// access and no rand(). Furniture only sits on cells along a room's walls,
// never within two steps of a door, and rooms are at least three cells each
// way, so the free cells of every room stay connected to its door; the
// generator's breadth-first check still guards the whole plan afterwards.

/datum/zombie_city_room
	var/id = 0
	var/x1
	var/y1
	var/x2
	var/y2
	var/kind = "room"
	var/building_id = 0

// Room kinds in the order they are handed out along a building's corridor.
/datum/zombie_city_generator/proc/room_kinds(kind)
	switch (kind)
		if ("house")
			return list("living", "kitchen", "bedroom", "bathroom", "bedroom", "storage")
		if ("apartment")
			return list("living", "kitchen", "bedroom", "bathroom", "bedroom", "bedroom", "bathroom", "storage")
		if ("office")
			return list("office", "office", "meeting", "storage", "office", "office", "meeting")
		if ("hospital")
			return list("ward", "ward", "surgery", "pharmacy", "ward", "office", "storage", "ward", "surgery")
		if ("police")
			return list("office", "armory", "cell", "cell", "locker", "office", "storage", "cell")
	return list("room")

// Furniture per room kind: path, then whether it blocks movement. Beds,
// chairs, toilets, sinks and the like are walked over, so they never count
// against reachability.
/datum/zombie_city_generator/proc/room_furniture(kind)
	switch (kind)
		if ("living")
			return list(list(/obj/structure/bed/chair/sofa, FALSE), list(/obj/structure/table/wood, TRUE), list(/obj/structure/bed/chair/wood, FALSE), list(/obj/structure/bookcase, TRUE))
		if ("kitchen")
			return list(list(/obj/structure/closet/fridge, TRUE), list(/obj/structure/props/stove, TRUE), list(/obj/structure/sink, FALSE), list(/obj/structure/table/wood, TRUE), list(/obj/structure/closet/cabinet, TRUE))
		if ("bedroom")
			return list(list(/obj/structure/bed/wood, FALSE), list(/obj/structure/closet/wardrobe, TRUE), list(/obj/structure/table/wood, TRUE), list(/obj/structure/bookcase, TRUE))
		if ("bathroom")
			return list(list(/obj/structure/toilet, FALSE), list(/obj/structure/sink, FALSE), list(/obj/structure/closet/cabinet, TRUE))
		if ("office")
			return list(list(/obj/structure/table/modern, TRUE), list(/obj/structure/bed/chair/office/light, FALSE), list(/obj/structure/filingcabinet/filingcabinet, TRUE), list(/obj/structure/props/computerprops/modern, TRUE), list(/obj/structure/bookcase, TRUE))
		if ("meeting")
			return list(list(/obj/structure/table/modern, TRUE), list(/obj/structure/bed/chair/office/light, FALSE))
		if ("storage", "stockroom")
			return list(list(/obj/structure/closet/crate, TRUE), list(/obj/structure/largecrate, TRUE), list(/obj/structure/shelf/palette, TRUE), list(/obj/structure/closet, TRUE), list(/obj/structure/props/junk, FALSE))
		if ("ward")
			return list(list(/obj/structure/medicalbed, FALSE), list(/obj/structure/iv_drip, FALSE), list(/obj/structure/bed/roller, FALSE), list(/obj/structure/closet/cabinet/first_aid, FALSE), list(/obj/structure/table/modern, TRUE))
		if ("surgery")
			return list(list(/obj/structure/optable, TRUE), list(/obj/structure/table/modern, TRUE), list(/obj/structure/closet/cabinet/first_aid, FALSE), list(/obj/structure/sink, FALSE))
		if ("pharmacy")
			return list(list(/obj/structure/table/rack/shelf/store, TRUE), list(/obj/structure/closet/cabinet/first_aid, FALSE), list(/obj/structure/closet/cabinet, TRUE))
		if ("armory")
			return list(list(/obj/structure/closet, TRUE), list(/obj/structure/closet/safe, TRUE), list(/obj/structure/table/rack, TRUE), list(/obj/structure/largecrate, TRUE))
		if ("cell")
			return list(list(/obj/structure/bed, FALSE), list(/obj/structure/toilet, FALSE))
		if ("locker")
			return list(list(/obj/structure/closet, TRUE), list(/obj/structure/bed/chair/steel, FALSE))
		if ("garage")
			return list(list(/obj/structure/table/modern, TRUE), list(/obj/structure/props/fueltank, TRUE), list(/obj/structure/props/barrel, TRUE), list(/obj/structure/closet/crate, TRUE), list(/obj/structure/props/junk, FALSE))
	return list()

// Share of a room's wall-side cells that get furniture.
/datum/zombie_city_generator/proc/room_fill(kind)
	switch (kind)
		if ("hall", "sales", "floor")
			return 0
		if ("cell")
			return 30
		if ("bathroom")
			return 35
		if ("bedroom", "garage")
			return 40
		if ("living", "meeting", "surgery")
			return 45
		if ("office")
			return 50
		if ("pharmacy", "armory")
			return 60
	return 55

// Rooms that loot prefers over corridors and bathrooms.
/datum/zombie_city_generator/proc/loot_room(kind)
	return kind in list("bedroom", "kitchen", "storage", "stockroom", "armory", "pharmacy", "ward", "surgery", "office", "sales", "floor", "garage")

/datum/zombie_city_generator/proc/is_door(code)
	return code == ZC_DOOR_HOUSE || code == ZC_DOOR_STORE || code == ZC_DOOR_INNER

/datum/zombie_city_generator/proc/is_wall(code)
	return code == ZC_WALL_CEMENT || code == ZC_WALL_BLOCKS || code == ZC_WALL_INNER

// Within two steps of a door. The cell inside a door and the cells next to
// that one stay free, so a door in a room's corner still opens onto the room.
/datum/zombie_city_generator/proc/beside_door(x, y)
	for (var/dx = -2 to 2)
		for (var/dy = -2 to 2)
			if (abs(dx) + abs(dy) <= 2 && is_door(cell(x + dx, y + dy)))
				return TRUE
	return FALSE

/datum/zombie_city_generator/proc/add_door(datum/zombie_city_building/D, x, y, code)
	set_cell(x, y, code)
	door_cells += index(x, y)
	D.door_cells += index(x, y)

/datum/zombie_city_generator/proc/add_room(datum/zombie_city_building/D, x1, y1, x2, y2, kind)
	var/datum/zombie_city_room/R = new
	R.id = D.rooms.len + 1
	R.x1 = min(x1, x2)
	R.y1 = min(y1, y2)
	R.x2 = max(x1, x2)
	R.y2 = max(y1, y2)
	R.kind = kind
	R.building_id = D.id
	D.rooms += R
	layout.counts["rooms"] = (layout.counts["rooms"] || 0) + 1
	return R

// Row k of a building's interior counted from its front wall: k = 0 is the
// row just inside the front door, whichever way the building faces.
/datum/zombie_city_generator/proc/depth_row(datum/zombie_city_building/D, k)
	return D.facing == NORTH ? D.y2 - 1 - k : D.y1 + 1 + k

/datum/zombie_city_generator/proc/furnish_building(datum/zombie_city_building/D, datum/zombie_city_block/B)
	var/ix1 = D.x1 + 1
	var/ix2 = D.x2 - 1
	var/depth = D.y2 - D.y1 - 1
	var/width = ix2 - ix1 + 1
	switch (D.kind)
		if ("grocery", "pharmacy", "hardware_store", "bigbox", "hardware")
			layout_shop(D, B, ix1, ix2, width, depth)
		if ("warehouse")
			layout_warehouse(D, B, ix1, ix2, width, depth)
		if ("workshop", "garage")
			layout_garage(D, B, ix1, ix2, width, depth)
		else
			layout_rooms(D, B, ix1, ix2, width, depth)
	clear_door_approaches(D)
	for (var/datum/zombie_city_room/R in D.rooms)
		furnish_room(R, D, B)
	dress_interior(D, B)

// Houses, apartments, offices, the hospital and the police station: an
// entrance hall two rows deep, a two-cell corridor running back from the
// front door, and rooms three to five rows deep stacked along both sides of
// the corridor, each with its own door onto it. A side too narrow for a room
// stays part of the hall. Buildings too shallow or narrow for that get rooms
// stacked straight back from the hall, with a door through each dividing
// wall, or stay one open room.
/datum/zombie_city_generator/proc/layout_rooms(datum/zombie_city_building/D, datum/zombie_city_block/B, ix1, ix2, width, depth)
	var/list/kinds = room_kinds(D.kind)
	var/next_kind = 1
	if (depth < 6 || width < 3)
		add_room(D, ix1, depth_row(D, 0), ix2, depth_row(D, depth - 1), kinds[1])
		return
	var/inner = (D.kind == "house" || D.kind == "apartment") ? ZC_WALL_INNER : wall_code(D.kind, B.district)
	var/sx1 = min(D.front_door_x, ix2 - 1)
	var/sx2 = sx1 + 1
	var/left = sx1 - 1 - ix1
	var/right = ix2 - (sx2 + 1)
	var/list/sides = list()
	if (left >= 3)
		sides += list(list(ix1, sx1 - 2, sx1 - 1))
	if (right >= 3)
		sides += list(list(sx2 + 2, ix2, sx2 + 1))
	if (!sides.len)
		// Stacked rooms: a dividing wall row with one door every few rows.
		add_room(D, ix1, depth_row(D, 0), ix2, depth_row(D, 1), "hall")
		var/k = 2
		while (depth - k - 1 >= 3)
			var/wall_y = depth_row(D, k)
			for (var/x = ix1 to ix2)
				set_cell(x, wall_y, inner)
			var/door_x = rng.between(ix1 + 1, ix2 - 1)
			add_door(D, door_x, wall_y, ZC_DOOR_INNER)
			var/d = rng.between(3, 5)
			if (depth - (k + 1) - d < 4)
				d = depth - (k + 1)
			add_room(D, ix1, depth_row(D, k + 1), ix2, depth_row(D, k + d), kinds[next_kind])
			next_kind = next_kind % kinds.len + 1
			k += d + 1
		return
	// Hall rows, then the corridor; the corridor is part of the hall room.
	var/hall_x1 = sides.len == 2 ? sx1 : (left >= 3 ? sx1 : ix1)
	var/hall_x2 = sides.len == 2 ? sx2 : (right >= 3 ? sx2 : ix2)
	add_room(D, ix1, depth_row(D, 0), ix2, depth_row(D, 1), "hall")
	add_room(D, hall_x1, depth_row(D, 2), hall_x2, depth_row(D, depth - 1), "hall")
	for (var/list/side in sides)
		var/rx1 = side[1]
		var/rx2 = side[2]
		var/wall_x = side[3]
		var/wall_y = depth_row(D, 2)
		for (var/x = rx1 to rx2)
			set_cell(x, wall_y, inner)
		set_cell(wall_x, wall_y, inner)
		for (var/k = 3 to depth - 1)
			set_cell(wall_x, depth_row(D, k), inner)
		var/k = 3
		while (depth - k >= 3)
			var/d = rng.between(3, 5)
			if (depth - k - d < 4)
				d = depth - k
			var/door_y = depth_row(D, k + round((d - 1) / 2))
			add_door(D, wall_x, door_y, ZC_DOOR_INNER)
			add_room(D, rx1, depth_row(D, k), rx2, depth_row(D, k + d - 1), kinds[next_kind])
			next_kind = next_kind % kinds.len + 1
			if (k + d < depth)
				var/divider_y = depth_row(D, k + d)
				for (var/x = rx1 to rx2)
					set_cell(x, divider_y, inner)
			k += d + 1

// Shops: a free row inside the door, a counter on the row behind it away
// from the door, shelf aisles running back from there with free ends, and a
// stockroom across the back behind its own door when there is depth for it.
/datum/zombie_city_generator/proc/layout_shop(datum/zombie_city_building/D, datum/zombie_city_block/B, ix1, ix2, width, depth)
	var/sales_depth = depth
	if (depth >= 9)
		sales_depth = depth - 4
		var/wall_y = depth_row(D, sales_depth)
		for (var/x = ix1 to ix2)
			set_cell(x, wall_y, wall_code(D.kind, B.district))
		var/door_x = rng.between(ix1 + 1, ix2 - 1)
		add_door(D, door_x, wall_y, ZC_DOOR_INNER)
		add_room(D, ix1, depth_row(D, sales_depth + 1), ix2, depth_row(D, depth - 1), "stockroom")
	var/datum/zombie_city_room/sales = add_room(D, ix1, depth_row(D, 0), ix2, depth_row(D, sales_depth - 1), "sales")
	if (sales_depth >= 5 && width >= 5)
		var/counter_y = depth_row(D, 1)
		var/counter_left = D.front_door_x - ix1 > ix2 - D.front_door_x
		var/cx1 = counter_left ? ix1 : ix2 - 2
		var/cx2 = counter_left ? ix1 + 2 : ix2
		var/blocked_counter = FALSE
		for (var/x = cx1 to cx2)
			if (beside_door(x, counter_y))
				blocked_counter = TRUE
		if (!blocked_counter)
			for (var/x = cx1 to cx2)
				set_prop(x, counter_y, /obj/structure/table/modern)
			set_prop(counter_left ? cx2 + 1 : cx1 - 1, counter_y, /obj/structure/closet/crate/cash_register, FALSE)
		for (var/x = ix1 + 1, x <= ix2 - 1, x += 2)
			for (var/k = 3 to sales_depth - 2)
				if (rng.chance(85))
					set_prop(x, depth_row(D, k), /obj/structure/table/rack/shelf/store)
	else
		sales.kind = "floor"

// Warehouses: crate rows with free ends across the floor and a small office
// walled off in a back corner when the building is big enough.
/datum/zombie_city_generator/proc/layout_warehouse(datum/zombie_city_building/D, datum/zombie_city_block/B, ix1, ix2, width, depth)
	var/floor_x2 = ix2
	if (width >= 10 && depth >= 8)
		var/wall = wall_code(D.kind, B.district)
		var/ox1 = ix2 - 3
		var/wall_x = ox1 - 1
		for (var/k = depth - 5 to depth - 1)
			set_cell(wall_x, depth_row(D, k), wall)
		for (var/x = ox1 to ix2)
			set_cell(x, depth_row(D, depth - 5), wall)
		var/door_y = depth_row(D, depth - 3)
		add_door(D, wall_x, door_y, ZC_DOOR_INNER)
		add_room(D, ox1, depth_row(D, depth - 4), ix2, depth_row(D, depth - 1), "office")
		floor_x2 = wall_x - 1
	add_room(D, ix1, depth_row(D, 0), floor_x2, depth_row(D, depth - 1), "floor")
	if (depth < 6 || floor_x2 - ix1 + 1 < 4)
		return
	for (var/x = ix1 + 1, x <= floor_x2 - 1, x += 3)
		for (var/k = 2 to depth - 3)
			var/roll = rng.between(1, 100)
			if (roll <= 55)
				set_prop(x, depth_row(D, k), /obj/structure/largecrate)
			else if (roll <= 75)
				set_prop(x, depth_row(D, k), /obj/structure/shelf/palette)

// Workshops and the garage: benches, tanks and barrels along the walls and
// a wreck or two on the floor of the garage, clear of the walls and doors.
/datum/zombie_city_generator/proc/layout_garage(datum/zombie_city_building/D, datum/zombie_city_block/B, ix1, ix2, width, depth)
	add_room(D, ix1, depth_row(D, 0), ix2, depth_row(D, depth - 1), "garage")
	if (D.kind != "garage" || width < 7 || depth < 7)
		return
	var/wrecks = rng.between(1, 2)
	for (var/i = 1 to wrecks)
		var/x = rng.between(ix1 + 2, ix2 - 2)
		var/y = depth_row(D, rng.between(3, depth - 3))
		if (props[index(x, y)] || beside_door(x, y))
			continue
		set_prop(x, y, rng.chance(50) ? /obj/structure/props/car_wreck/vertical : /obj/structure/props/car_wreck)

// A door whose inside cell was walled by a partition gets that cell back.
/datum/zombie_city_generator/proc/clear_door_approaches(datum/zombie_city_building/D)
	var/floor = floor_code(D.kind)
	for (var/x = D.x1 to D.x2)
		for (var/y = D.y1 to D.y2)
			if (!is_door(cell(x, y)))
				continue
			for (var/list/step in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
				var/nx = x + step[1]
				var/ny = y + step[2]
				if (nx <= D.x1 || nx >= D.x2 || ny <= D.y1 || ny >= D.y2)
					continue
				if (is_wall(cell(nx, ny)))
					set_cell(nx, ny, floor)

/datum/zombie_city_generator/proc/furnish_room(datum/zombie_city_room/R, datum/zombie_city_building/D, datum/zombie_city_block/B)
	if (R.kind == "bathroom" || R.kind == "kitchen")
		fill_rect(R.x1, R.y1, R.x2, R.y2, ZC_FLOOR_TILE)
	else if (R.kind == "cell")
		fill_rect(R.x1, R.y1, R.x2, R.y2, ZC_FLOOR_CONCRETE)
	var/fill = room_fill(R.kind)
	var/list/choices = room_furniture(R.kind)
	if (!fill || !choices.len)
		return
	if (R.x2 - R.x1 < 2 || R.y2 - R.y1 < 2)
		return
	for (var/x = R.x1 to R.x2)
		for (var/y = R.y1 to R.y2)
			if (x != R.x1 && x != R.x2 && y != R.y1 && y != R.y2)
				continue
			if (props[index(x, y)] || beside_door(x, y) || !rng.chance(fill))
				continue
			var/list/choice = rng.choose(choices)
			set_prop(x, y, choice[1], choice[2])
			layout.counts["furniture"] = (layout.counts["furniture"] || 0) + 1

// Blood, junk and broken windows, more of them the denser the block.
/datum/zombie_city_generator/proc/dress_interior(datum/zombie_city_building/D, datum/zombie_city_block/B)
	var/blood = 1
	var/broken = 10
	switch (B.density)
		if ("normal")
			blood = 3
			broken = 25
		if ("dense")
			blood = 6
			broken = 40
		if ("infested")
			blood = 12
			broken = 60
	for (var/x = D.x1 to D.x2)
		for (var/y = D.y1 to D.y2)
			var/code = cell(x, y)
			if (code == ZC_WINDOW)
				if (rng.chance(broken))
					set_cell(x, y, ZC_WINDOW_BROKEN)
					layout.counts["broken_windows"] = (layout.counts["broken_windows"] || 0) + 1
				continue
			if (x == D.x1 || x == D.x2 || y == D.y1 || y == D.y2 || is_wall(code) || is_door(code) || props[index(x, y)])
				continue
			if (rng.chance(blood))
				set_prop(x, y, rng.chance(50) ? /obj/effect/decal/cleanable/blood : /obj/effect/decal/cleanable/blood/splatter, FALSE)
				layout.counts["decals"] = (layout.counts["decals"] || 0) + 1
			else if (rng.chance(round(blood / 2)))
				set_prop(x, y, /obj/structure/props/junk, FALSE)
				layout.counts["decals"] = (layout.counts["decals"] || 0) + 1

// Loot spots: free floor cells with at least two free neighbours, out of
// the doorways, in the rooms worth searching first and beside something to
// search when possible. Hospitals alternate medical and pharmacy tables and
// the police armory is always searched first.
/datum/zombie_city_generator/proc/place_loot(datum/zombie_city_building/D)
	var/count = 1 + D.tier
	if (D.kind == "hospital")
		count = 6
	else if (D.kind == "police")
		count = 4
	var/list/first = list()
	var/list/preferred = list()
	var/list/other = list()
	var/list/table_of = list()
	for (var/datum/zombie_city_room/R in D.rooms)
		var/table = D.table
		if (D.kind == "hospital" && R.kind == "pharmacy")
			table = "pharmacy"
		for (var/x = R.x1 to R.x2)
			for (var/y = R.y1 to R.y2)
				var/i = index(x, y)
				if (props[i] || is_wall(cells[i]) || is_door(cells[i]) || beside_door(x, y))
					continue
				var/free = 0
				var/beside_something = FALSE
				for (var/list/step in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
					var/j = index(x + step[1], y + step[2])
					if (blocked[j] || !passable(cells[j]))
						if (blocked[j])
							beside_something = TRUE
						continue
					free++
				if (free < 2)
					continue
				table_of["[i]"] = table
				if (R.kind == "armory")
					first += i
				else if (loot_room(R.kind) && beside_something)
					preferred += i
				else
					other += i
	rng.shuffle(first)
	rng.shuffle(preferred)
	rng.shuffle(other)
	var/placed = 0
	for (var/i in first + preferred + other)
		if (placed >= count)
			break
		var/table = table_of["[i]"]
		if (D.kind == "hospital" && table == D.table && placed % 2)
			table = "pharmacy"
		loot_cells["[i]"] = list(D, table, D.tier)
		placed++
