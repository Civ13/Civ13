// Zombie city generator: streets, districts, lots, building shells and the
// markers other systems read, made at round start from one seed.
//
// zombie_city_generate(seed, ground_z, upper_z) plans the whole city in a
// private grid (no world access, no rand()), checks that every evacuation
// point, door and loot spot can be walked to from every insertion point, and
// only then writes turfs and objects into the world, spread over ticks. A
// plan that fails its own check is thrown away and the next seed is tried,
// three times at most. The result is stored in zombie_city_layout; a second
// call in the same world returns that layout instead of generating again.
//
// interiors.dm partitions each shell into rooms, furnishes them, picks the
// loot spots and adds the mess; upper floors are a later phase.
//
// The horde registers each block through zombie_horde_add_block, loot is
// rolled at each loot marker through zombie_city_roll_loot (horde.dm, loot.dm)
// and the city world takes its arrival and evacuation points through
// zombie_city_add_insertion and zombie_city_add_evacuation (world.dm).

#define ZC_RIM 1
#define ZC_ROAD 2
#define ZC_ROAD_CENTER 3
#define ZC_SIDEWALK 4
#define ZC_YARD_GRASS 5
#define ZC_YARD_PAVED 6
#define ZC_YARD_DIRT 7
#define ZC_FLOOR_WOOD 8
#define ZC_FLOOR_TILE 9
#define ZC_FLOOR_CONCRETE 10
#define ZC_FLOOR_MARBLE 11
#define ZC_FLOOR_WHITE 12
#define ZC_WALL_CEMENT 13
#define ZC_WALL_BLOCKS 14
#define ZC_DOOR_HOUSE 15
#define ZC_DOOR_STORE 16
#define ZC_WINDOW 17
#define ZC_PARK 18
#define ZC_PARKING 19
#define ZC_VACANT 20
#define ZC_ALLEY 21
#define ZC_WALL_INNER 22
#define ZC_DOOR_INNER 23
#define ZC_WINDOW_BROKEN 24

#define ZC_MIN_SIZE 64
#define ZC_RING_INNER 4
#define ZC_LAND_START 5
#define ZC_MAX_ATTEMPTS 3
#define ZC_ENTRY_SPACING 60
#define ZC_EXIT_SPACING 40

var/global/datum/zombie_city_layout/zombie_city_layout = null
var/global/zombie_city_generating = FALSE

/datum/zombie_city_block
	var/id = 0
	var/x1
	var/y1
	var/x2
	var/y2
	var/district = "residential"
	var/density = "sparse"
	var/special = ""
	var/list/buildings = list()

/datum/zombie_city_building
	var/id = 0
	var/x1
	var/y1
	var/x2
	var/y2
	var/kind = "house"
	var/tier = 1
	var/table = "residential"
	var/facing = SOUTH
	var/block_id = 0
	var/floors = 1
	var/front_door_x = 0
	var/list/door_cells = list()
	var/list/rooms = list()
	var/list/doors = list()
	var/list/loot = list()

/datum/zombie_city_layout
	var/seed = 0
	var/attempt = 1
	var/width = 0
	var/height = 0
	var/ground_z = 1
	var/upper_z = 0
	var/generation_ds = 0
	var/center_x = 0
	var/center_y = 0
	var/industrial_edge = "east"
	var/list/blocks = list()
	var/list/buildings = list()
	var/list/roads = list()
	var/list/entries = list()
	var/list/exits = list()
	var/list/entry_markers = list()
	var/list/exit_markers = list()
	var/list/loot_markers = list()
	var/list/pois = list()
	var/list/counts = list()
	var/list/ascii_rows = list()

/datum/zombie_city_layout/proc/turf_xy(turf/T)
	return T ? list(T.x, T.y) : null

/datum/zombie_city_layout/proc/manifest()
	var/list/block_rows = list()
	for (var/datum/zombie_city_block/B in blocks)
		block_rows += list(list("id" = B.id, "x1" = B.x1, "y1" = B.y1, "x2" = B.x2, "y2" = B.y2, "district" = B.district, "density" = B.density, "special" = B.special))
	var/list/building_rows = list()
	for (var/datum/zombie_city_building/D in buildings)
		var/list/door_rows = list()
		for (var/turf/T in D.doors)
			door_rows += list(turf_xy(T))
		if (!door_rows.len)
			for (var/i in D.door_cells)
				door_rows += list(list(i - round((i - 1) / width) * width, round((i - 1) / width) + 1))
		var/list/loot_rows = list()
		for (var/obj/effect/zombie_city/loot/L in D.loot)
			loot_rows += list(list("x" = L.x, "y" = L.y, "table" = L.table, "tier" = L.tier))
		var/list/room_rows = list()
		for (var/datum/zombie_city_room/R in D.rooms)
			room_rows += list(list("kind" = R.kind, "x1" = R.x1, "y1" = R.y1, "x2" = R.x2, "y2" = R.y2))
		building_rows += list(list("id" = D.id, "x1" = D.x1, "y1" = D.y1, "x2" = D.x2, "y2" = D.y2, "kind" = D.kind, "tier" = D.tier, "table" = D.table, "floors" = D.floors, "block" = D.block_id, "doors" = door_rows, "rooms" = room_rows, "loot" = loot_rows))
	var/list/entry_rows = list()
	for (var/obj/effect/zombie_city/entry/E in entry_markers)
		entry_rows += list(list("x" = E.x, "y" = E.y, "edge" = E.side, "ordinal" = E.ordinal))
	var/list/exit_rows = list()
	for (var/obj/effect/zombie_city/exit/X in exit_markers)
		exit_rows += list(list("x" = X.x, "y" = X.y, "edge" = X.side, "ordinal" = X.ordinal, "checkpoint" = X.checkpoint))
	var/list/poi_rows = list()
	for (var/kind in pois)
		var/datum/zombie_city_building/D = pois[kind]
		poi_rows[kind] = D.id
	return list("schema" = 2, "seed" = seed, "attempt" = attempt, "width" = width, "height" = height, "ground_z" = ground_z, "upper_z" = upper_z, "generation_ds" = generation_ds, "center" = list(center_x, center_y), "industrial_edge" = industrial_edge, "blocks" = block_rows, "buildings" = building_rows, "roads" = roads, "entries" = entry_rows, "exits" = exit_rows, "pois" = poi_rows, "counts" = counts)

/datum/zombie_city_layout/proc/to_json()
	return json_encode(manifest())

// Planning state for one attempt. Pure until commit(): it reads world.maxx
// and world.maxy and nothing else from the world.
/datum/zombie_city_generator
	var/datum/zombie_city_rng/rng
	var/datum/zombie_city_layout/layout
	var/w
	var/h
	var/z
	var/list/cells
	var/list/props
	var/list/blocked
	var/list/owner
	var/list/vertical_cuts = list()
	var/list/horizontal_cuts = list()
	var/list/entry_cells = list()
	var/list/exit_cells = list()
	var/list/loot_cells = list()
	var/list/door_cells = list()
	var/failure = null

/datum/zombie_city_generator/New(seed, attempt, ground_z, upper_z)
	..()
	rng = new(seed + (attempt - 1) * 7919)
	layout = new
	layout.seed = seed
	layout.attempt = attempt
	layout.ground_z = ground_z
	layout.upper_z = upper_z
	w = world.maxx
	h = world.maxy
	z = ground_z
	layout.width = w
	layout.height = h

/datum/zombie_city_generator/proc/index(x, y)
	return (y - 1) * w + x

/datum/zombie_city_generator/proc/cell(x, y)
	if (x < 1 || y < 1 || x > w || y > h)
		return ZC_RIM
	return cells[index(x, y)]

/datum/zombie_city_generator/proc/set_cell(x, y, value)
	if (x < 1 || y < 1 || x > w || y > h)
		return
	cells[index(x, y)] = value

/datum/zombie_city_generator/proc/set_prop(x, y, path, dense = TRUE)
	if (x < 1 || y < 1 || x > w || y > h)
		return
	var/i = index(x, y)
	props[i] = path
	blocked[i] = dense

/datum/zombie_city_generator/proc/is_road(code)
	return code == ZC_ROAD || code == ZC_ROAD_CENTER || code == ZC_PARKING

/datum/zombie_city_generator/proc/passable(code)
	return !(code == ZC_RIM || code == ZC_WALL_CEMENT || code == ZC_WALL_BLOCKS || code == ZC_WALL_INNER || code == ZC_WINDOW)

// ---------------------------------------------------------------- planning

/datum/zombie_city_generator/proc/plan()
	if (w < ZC_MIN_SIZE || h < ZC_MIN_SIZE)
		failure = "world [w]x[h] is smaller than [ZC_MIN_SIZE]x[ZC_MIN_SIZE]"
		return FALSE
	cells = new/list(w * h)
	props = new/list(w * h)
	blocked = new/list(w * h)
	owner = new/list(w * h)
	for (var/i = 1 to w * h)
		cells[i] = ZC_VACANT
	plan_center()
	plan_cuts()
	paint_ring()
	paint_cuts()
	find_blocks()
	assign_districts()
	assign_specials()
	for (var/datum/zombie_city_block/B in layout.blocks)
		fill_block(B)
	place_entries_and_exits()
	dress_roads()
	return validate()

/datum/zombie_city_generator/proc/plan_center()
	layout.center_x = round(w / 2) + rng.between(-round(w / 14), round(w / 14))
	layout.center_y = round(h / 2) + rng.between(-round(h / 14), round(h / 14))
	layout.industrial_edge = rng.choose(list("north", "south", "east", "west"))

// Distance from the centre as a share of the half-size, Chebyshev style.
/datum/zombie_city_generator/proc/centrality(x, y)
	var/dx = abs(x - layout.center_x) / (w / 2)
	var/dy = abs(y - layout.center_y) / (h / 2)
	return max(dx, dy)

/datum/zombie_city_generator/proc/district_at(x, y)
	var/edge_distance = w
	switch (layout.industrial_edge)
		if ("north")
			edge_distance = h - y
		if ("south")
			edge_distance = y
		if ("east")
			edge_distance = w - x
		if ("west")
			edge_distance = x
	var/c = centrality(x, y)
	if (c < 0.28)
		return "downtown"
	if (edge_distance <= round(h / 5.5))
		return "industrial"
	if (c < 0.6)
		return "commercial"
	return "residential"

// Street positions along one axis: each cut is list(start, width). Width 3
// is an avenue with a centre line, width 2 a street.
/datum/zombie_city_generator/proc/axis_cuts(length)
	var/list/result = list()
	var/pos = ZC_LAND_START
	while (TRUE)
		var/gap = rng.between(18, 28)
		var/start = pos + gap
		var/width = rng.chance(40) ? 3 : 2
		if (start + width + 14 > length - ZC_RING_INNER)
			break
		result += list(list(start, width))
		pos = start + width
	return result

/datum/zombie_city_generator/proc/plan_cuts()
	vertical_cuts = axis_cuts(w)
	horizontal_cuts = axis_cuts(h)

/datum/zombie_city_generator/proc/paint_road_cell(x, y, center)
	var/code = cell(x, y)
	if (code == ZC_RIM)
		return
	if (center)
		set_cell(x, y, ZC_ROAD_CENTER)
	else if (code != ZC_ROAD_CENTER)
		set_cell(x, y, ZC_ROAD)

/datum/zombie_city_generator/proc/paint_ring()
	for (var/x = 1 to w)
		for (var/y = 1 to h)
			if (x == 1 || y == 1 || x == w || y == h)
				set_cell(x, y, ZC_RIM)
			else if (x <= ZC_RING_INNER || y <= ZC_RING_INNER || x >= w - ZC_RING_INNER + 1 || y >= h - ZC_RING_INNER + 1)
				var/center = (x == 3 || y == 3 || x == w - 2 || y == h - 2) && !(x == 2 || y == 2 || x == w - 1 || y == h - 1)
				paint_road_cell(x, y, center)
	layout.roads += list(list("kind" = "ring", "x1" = 2, "y1" = 2, "x2" = w - 1, "y2" = h - 1))

/datum/zombie_city_generator/proc/paint_cuts()
	for (var/list/cut in vertical_cuts)
		var/start = cut[1]
		var/width = cut[2]
		for (var/x = start, x < start + width, x++)
			for (var/y = 2 to h - 1)
				paint_road_cell(x, y, width == 3 && x == start + 1)
		layout.roads += list(list("kind" = width == 3 ? "avenue" : "street", "x1" = start, "y1" = 2, "x2" = start + width - 1, "y2" = h - 1))
	// Horizontal streets are painted one segment at a time so a suburb can
	// drop a segment and merge two blocks into a longer one.
	var/list/column_edges = list(ZC_RING_INNER)
	for (var/list/cut in vertical_cuts)
		column_edges += cut[1] - 1
		column_edges += cut[1] + cut[2]
	column_edges += w - ZC_RING_INNER + 1
	for (var/list/cut in horizontal_cuts)
		var/start = cut[1]
		var/width = cut[2]
		layout.roads += list(list("kind" = width == 3 ? "avenue" : "street", "x1" = 2, "y1" = start, "x2" = w - 1, "y2" = start + width - 1))
		for (var/i = 1, i < column_edges.len, i += 2)
			var/left = column_edges[i]
			var/right = column_edges[i + 1]
			var/mid_x = round((left + right) / 2)
			var/skip = width == 2 && left > ZC_RING_INNER && right < w - ZC_RING_INNER + 1 && district_at(mid_x, start) == "residential" && rng.chance(30)
			if (skip)
				continue
			for (var/x = left, x <= right, x++)
				for (var/y = start, y < start + width, y++)
					paint_road_cell(x, y, width == 3 && y == start + 1)

// Blocks are the 4-connected patches of land between roads. Every patch is a
// rectangle: only whole horizontal segments between vertical cuts are dropped.
/datum/zombie_city_generator/proc/find_blocks()
	var/list/seen = new/list(w * h)
	var/list/steps = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	var/next_id = 0
	for (var/y = ZC_LAND_START to h - ZC_LAND_START + 1)
		for (var/x = ZC_LAND_START to w - ZC_LAND_START + 1)
			var/i = index(x, y)
			if (seen[i] || is_road(cells[i]) || cells[i] == ZC_RIM)
				continue
			var/list/queue = list(i)
			seen[i] = TRUE
			var/x1 = x
			var/y1 = y
			var/x2 = x
			var/y2 = y
			var/count = 0
			var/head = 1
			while (head <= queue.len)
				var/j = queue[head++]
				count++
				var/jy = round((j - 1) / w) + 1
				var/jx = j - (jy - 1) * w
				x1 = min(x1, jx)
				x2 = max(x2, jx)
				y1 = min(y1, jy)
				y2 = max(y2, jy)
				for (var/list/step in steps)
					var/nx = jx + step[1]
					var/ny = jy + step[2]
					if (nx < 1 || ny < 1 || nx > w || ny > h)
						continue
					var/k = index(nx, ny)
					if (seen[k] || is_road(cells[k]) || cells[k] == ZC_RIM)
						continue
					seen[k] = TRUE
					queue += k
			var/datum/zombie_city_block/B = new
			B.id = ++next_id
			B.x1 = x1
			B.y1 = y1
			B.x2 = x2
			B.y2 = y2
			layout.blocks += B
			for (var/j in queue)
				owner[j] = B.id
			if (count != (x2 - x1 + 1) * (y2 - y1 + 1))
				B.special = "irregular"
			for (var/bx = x1 to x2)
				for (var/by = y1 to y2)
					if (owner[index(bx, by)] != B.id)
						continue
					if (is_road(cell(bx - 1, by)) || is_road(cell(bx + 1, by)) || is_road(cell(bx, by - 1)) || is_road(cell(bx, by + 1)))
						set_cell(bx, by, ZC_SIDEWALK)

/datum/zombie_city_generator/proc/assign_districts()
	for (var/datum/zombie_city_block/B in layout.blocks)
		B.district = district_at(round((B.x1 + B.x2) / 2), round((B.y1 + B.y2) / 2))
		switch (B.district)
			if ("downtown")
				B.density = rng.chance(60) ? "dense" : "infested"
			if ("commercial")
				B.density = rng.chance(50) ? "normal" : "dense"
			if ("industrial")
				B.density = rng.chance(60) ? "sparse" : "normal"
			else
				B.density = rng.chance(50) ? "sparse" : "normal"

/datum/zombie_city_generator/proc/pick_special(kind, list/districts, min_w, min_h)
	var/datum/zombie_city_block/best = null
	var/best_area = 0
	for (var/pass = 1 to 2)
		for (var/datum/zombie_city_block/B in layout.blocks)
			if (B.special)
				continue
			if (pass == 1 && !(B.district in districts))
				continue
			var/iw = B.x2 - B.x1 - 1
			var/ih = B.y2 - B.y1 - 1
			if (iw < min_w || ih < min_h)
				continue
			var/area = iw * ih
			if (area > best_area)
				best = B
				best_area = area
		if (best)
			break
	if (best)
		best.special = kind
	return best

/datum/zombie_city_generator/proc/assign_specials()
	var/datum/zombie_city_block/B
	B = pick_special("hospital", list("downtown"), 20, 16)
	if (B)
		B.density = "infested"
	B = pick_special("police", list("commercial", "downtown"), 14, 12)
	if (B)
		B.density = "dense"
	pick_special("hardware", list("commercial"), 16, 12)
	pick_special("garage", list("industrial", "commercial"), 16, 12)

// ---------------------------------------------------------------- lots

/datum/zombie_city_generator/proc/yard_code(district)
	switch (district)
		if ("residential")
			return ZC_YARD_GRASS
		if ("industrial")
			return ZC_YARD_DIRT
	return ZC_YARD_PAVED

/datum/zombie_city_generator/proc/fill_rect(x1, y1, x2, y2, code)
	for (var/x = x1 to x2)
		for (var/y = y1 to y2)
			set_cell(x, y, code)

/datum/zombie_city_generator/proc/fill_block(datum/zombie_city_block/B)
	var/ix1 = B.x1 + 1
	var/iy1 = B.y1 + 1
	var/ix2 = B.x2 - 1
	var/iy2 = B.y2 - 1
	var/iw = ix2 - ix1 + 1
	var/ih = iy2 - iy1 + 1
	if (B.special == "irregular")
		for (var/x = B.x1 to B.x2)
			for (var/y = B.y1 to B.y2)
				if (owner[index(x, y)] == B.id && cell(x, y) != ZC_SIDEWALK)
					set_cell(x, y, ZC_VACANT)
		return
	if (iw < 6 || ih < 6)
		fill_open(ix1, iy1, ix2, iy2, B.district)
		return
	if (B.special)
		var/datum/zombie_city_building/D = new_building(B, ix1 + 1, iy1 + 1, ix2 - 1, iy2 - 1, B.special)
		fill_rect(ix1, iy1, ix2, iy2, yard_code(B.district))
		paint_building(D, B)
		layout.pois[B.special] = D
		return
	if (ih >= 16)
		var/depth = round(ih / 2)
		fill_row(B, ix1, iy1, ix2, iy1 + depth - 1, SOUTH)
		fill_row(B, ix1, iy2 - depth + 1, ix2, iy2, NORTH)
		if (ih % 2)
			fill_rect(ix1, iy1 + depth, ix2, iy1 + depth, ZC_ALLEY)
	else
		fill_row(B, ix1, iy1, ix2, iy2, SOUTH)

/datum/zombie_city_generator/proc/fill_open(x1, y1, x2, y2, district)
	var/choice = rng.between(1, 100)
	if (district == "residential" && choice <= 60)
		fill_rect(x1, y1, x2, y2, ZC_PARK)
		for (var/x = x1 to x2)
			for (var/y = y1 to y2)
				if (rng.chance(12))
					set_prop(x, y, /obj/structure/wild/tree/live_tree)
	else if (district == "industrial" || choice <= 50)
		fill_rect(x1, y1, x2, y2, ZC_VACANT)
		for (var/x = x1 to x2)
			for (var/y = y1 to y2)
				if (rng.chance(8))
					set_prop(x, y, /obj/structure/props/junk, FALSE)
				else if (rng.chance(3))
					set_prop(x, y, /obj/structure/closet/crate/dumpster)
	else
		fill_rect(x1, y1, x2, y2, ZC_PARKING)
		for (var/x = x1 to x2)
			for (var/y = y1 to y2)
				if (rng.chance(18))
					set_prop(x, y, rng.chance(30) ? /obj/structure/props/car_wreck/van : /obj/structure/props/car_wreck)

/datum/zombie_city_generator/proc/lot_width_range(district)
	switch (district)
		if ("residential")
			return list(8, 11)
		if ("commercial")
			return rng.chance(25) ? list(18, 24) : list(10, 14)
		if ("downtown")
			return list(12, 18)
	return list(16, 24)

/datum/zombie_city_generator/proc/choose_kind(district, lot_width)
	var/roll = rng.between(1, 100)
	switch (district)
		if ("residential")
			return "house"
		if ("commercial")
			if (lot_width >= 18)
				return roll <= 60 ? "bigbox" : "hardware_store"
			if (roll <= 45)
				return "grocery"
			if (roll <= 60)
				return "pharmacy"
			if (roll <= 85)
				return "hardware_store"
			return "apartment"
		if ("downtown")
			if (roll <= 35)
				return "office"
			if (roll <= 70)
				return "apartment"
			if (roll <= 85)
				return "grocery"
			return "pharmacy"
	return roll <= 60 ? "warehouse" : "workshop"

/datum/zombie_city_generator/proc/fill_row(datum/zombie_city_block/B, x1, y1, x2, y2, facing)
	fill_rect(x1, y1, x2, y2, yard_code(B.district))
	var/list/widths = lot_width_range(B.district)
	var/x = x1
	while (x <= x2)
		var/lw = rng.between(widths[1], widths[2])
		if (x2 - x + 1 < widths[1])
			fill_open(x, y1, x2, y2, B.district)
			break
		if (x + lw - 1 > x2)
			lw = x2 - x + 1
		var/bx1 = x + 1
		var/bx2 = x + lw - 2
		var/by1 = y1 + 1
		var/by2 = y2 - 1
		if (bx2 - bx1 >= 5 && by2 - by1 >= 5)
			var/datum/zombie_city_building/D = new_building(B, bx1, by1, bx2, by2, choose_kind(B.district, lw))
			D.facing = facing
			paint_building(D, B)
		x += lw

/datum/zombie_city_generator/proc/new_building(datum/zombie_city_block/B, x1, y1, x2, y2, kind)
	var/datum/zombie_city_building/D = new
	D.id = layout.buildings.len + 1
	D.x1 = x1
	D.y1 = y1
	D.x2 = x2
	D.y2 = y2
	D.kind = kind
	D.block_id = B.id
	switch (kind)
		if ("house")
			D.tier = 1
			D.table = "residential"
		if ("apartment", "office")
			D.tier = 2
			D.table = "residential"
		if ("grocery", "bigbox")
			D.tier = 2
			D.table = "grocery"
		if ("pharmacy")
			D.tier = 2
			D.table = "pharmacy"
		if ("hardware_store", "warehouse")
			D.tier = 2
			D.table = "hardware"
		if ("workshop")
			D.tier = 2
			D.table = "garage"
		if ("hospital")
			D.tier = 3
			D.table = "medical"
		if ("police")
			D.tier = 3
			D.table = "police"
		if ("hardware")
			D.tier = 3
			D.table = "hardware"
		if ("garage")
			D.tier = 3
			D.table = "garage"
	if (B.district == "downtown" && D.tier < 3 && rng.chance(40))
		D.tier++
	layout.buildings += D
	B.buildings += D
	return D

/datum/zombie_city_generator/proc/floor_code(kind)
	switch (kind)
		if ("house", "apartment")
			return ZC_FLOOR_WOOD
		if ("grocery", "bigbox", "pharmacy", "hardware_store", "hardware")
			return ZC_FLOOR_TILE
		if ("office", "police")
			return ZC_FLOOR_MARBLE
		if ("hospital")
			return ZC_FLOOR_WHITE
	return ZC_FLOOR_CONCRETE

/datum/zombie_city_generator/proc/wall_code(kind, district)
	if (kind == "warehouse" || kind == "workshop" || kind == "garage" || district == "industrial")
		return ZC_WALL_BLOCKS
	return ZC_WALL_CEMENT

/datum/zombie_city_generator/proc/paint_building(datum/zombie_city_building/D, datum/zombie_city_block/B)
	var/wall = wall_code(D.kind, B.district)
	var/floor = floor_code(D.kind)
	fill_rect(D.x1, D.y1, D.x2, D.y2, floor)
	for (var/x = D.x1 to D.x2)
		set_cell(x, D.y1, wall)
		set_cell(x, D.y2, wall)
	for (var/y = D.y1 to D.y2)
		set_cell(D.x1, y, wall)
		set_cell(D.x2, y, wall)
	for (var/x = D.x1 to D.x2)
		for (var/y = D.y1 to D.y2)
			owner[index(x, y)] = -D.id
	// Front wall, door and windows.
	var/front_y = D.facing == NORTH ? D.y2 : D.y1
	var/wide = !(D.kind in list("house", "apartment", "office"))
	var/door_x = rng.between(D.x1 + 1, D.x2 - (wide ? 2 : 1))
	var/door = wide ? ZC_DOOR_STORE : ZC_DOOR_HOUSE
	add_door(D, door_x, front_y, door)
	D.front_door_x = door_x
	if (wide)
		add_door(D, door_x + 1, front_y, door)
	for (var/x = D.x1 + 2, x <= D.x2 - 2, x += 3)
		if (cell(x, front_y) == wall)
			set_cell(x, front_y, ZC_WINDOW)
	if (D.kind == "house" || D.kind == "apartment" || D.kind == "office")
		for (var/y = D.y1 + 2, y <= D.y2 - 2, y += 4)
			if (cell(D.x1, y) == wall)
				set_cell(D.x1, y, ZC_WINDOW)
			if (cell(D.x2, y) == wall)
				set_cell(D.x2, y, ZC_WINDOW)
	// Special lots get a second door on the opposite side.
	if (D.tier >= 3 && D.kind != "house")
		var/back_y = D.facing == NORTH ? D.y1 : D.y2
		var/back_x = rng.between(D.x1 + 1, D.x2 - 2)
		add_door(D, back_x, back_y, ZC_DOOR_STORE)
		add_door(D, back_x + 1, back_y, ZC_DOOR_STORE)
	furnish_building(D, B)
	place_loot(D)

// ---------------------------------------------------------------- markers

/datum/zombie_city_generator/proc/ring_cell(edge, along)
	switch (edge)
		if ("north")
			return list(along, h - 2)
		if ("south")
			return list(along, 3)
		if ("east")
			return list(w - 2, along)
	return list(3, along)

/datum/zombie_city_generator/proc/place_entries_and_exits()
	var/list/slots = list()
	for (var/edge in list("north", "south", "east", "west"))
		var/length = (edge == "north" || edge == "south") ? w : h
		slots += list(list(edge, round(length / 3) + rng.between(-2, 2)))
		slots += list(list(edge, round(length * 2 / 3) + rng.between(-2, 2)))
	rng.shuffle(slots)
	var/entry_count = rng.between(4, 6)
	for (var/i = 1 to entry_count)
		var/list/slot = slots[i]
		var/list/xy = ring_cell(slot[1], slot[2])
		entry_cells += list(list(xy[1], xy[2], slot[1]))
	var/list/corners = list(list("north", w - 2), list("south", 3), list("east", 3), list("west", h - 2))
	rng.shuffle(corners)
	var/exit_count = rng.between(3, 4)
	for (var/i = 1 to exit_count)
		var/list/slot = corners[i]
		var/list/xy = ring_cell(slot[1], slot[2])
		exit_cells += list(list(xy[1], xy[2], slot[1], i == 1))
	// The checkpoint: barriers across both outer lanes beside the first exit,
	// a military cache on the road, and the centre lane left open.
	var/list/check = exit_cells[1]
	var/cx = check[1]
	var/cy = check[2]
	for (var/list/offset in list(list(-3, 1), list(-3, -1), list(3, 1), list(3, -1), list(1, -3), list(-1, -3), list(1, 3), list(-1, 3)))
		var/bx = cx + offset[1]
		var/by = cy + offset[2]
		if (cell(bx, by) == ZC_ROAD)
			set_prop(bx, by, /obj/structure/window/barrier/jersey)
	var/list/cache = null
	for (var/list/offset in list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1)))
		if (cell(cx + offset[1], cy + offset[2]) == ZC_ROAD_CENTER || cell(cx + offset[1], cy + offset[2]) == ZC_ROAD)
			cache = list(cx + offset[1], cy + offset[2])
			break
	if (cache)
		loot_cells["[index(cache[1], cache[2])]"] = list(null, "military", 3)

// Wrecks on the outer lanes of avenues and the ring road, never on a centre
// line, a sidewalk, or within six tiles of an insertion or evacuation point.
/datum/zombie_city_generator/proc/dress_roads()
	var/list/keep_clear = list()
	for (var/list/p in entry_cells)
		keep_clear += list(p)
	for (var/list/p in exit_cells)
		keep_clear += list(p)
	for (var/x = 2 to w - 1)
		for (var/y = 2 to h - 1)
			if (cell(x, y) != ZC_ROAD || props[index(x, y)])
				continue
			var/lane_of_avenue = cell(x - 1, y) == ZC_ROAD_CENTER || cell(x + 1, y) == ZC_ROAD_CENTER || cell(x, y - 1) == ZC_ROAD_CENTER || cell(x, y + 1) == ZC_ROAD_CENTER
			if (!lane_of_avenue || !rng.chance(4))
				continue
			var/near = FALSE
			for (var/list/p in keep_clear)
				if (abs(p[1] - x) <= 6 && abs(p[2] - y) <= 6)
					near = TRUE
					break
			if (near)
				continue
			var/roll = rng.between(1, 100)
			var/path = /obj/structure/props/car_wreck
			if (roll <= 20)
				path = /obj/structure/props/car_wreck/van
			else if (roll <= 30)
				path = /obj/structure/props/car_wreck/truck
			else if (roll <= 40)
				path = /obj/structure/closet/crate/dumpster
			set_prop(x, y, path)

// ---------------------------------------------------------------- checks

// Breadth-first walk from the first insertion point over passable cells.
/datum/zombie_city_generator/proc/validate()
	if (!entry_cells.len || !exit_cells.len)
		failure = "no insertion or evacuation points"
		return FALSE
	for (var/list/a in entry_cells)
		for (var/list/b in entry_cells)
			if (a != b && max(abs(a[1] - b[1]), abs(a[2] - b[2])) < ZC_ENTRY_SPACING)
				failure = "insertion points closer than [ZC_ENTRY_SPACING]"
				return FALSE
		for (var/list/b in exit_cells)
			if (max(abs(a[1] - b[1]), abs(a[2] - b[2])) < ZC_EXIT_SPACING)
				failure = "evacuation point closer than [ZC_EXIT_SPACING] to an insertion point"
				return FALSE
	if (!layout.pois["hospital"] || !layout.pois["police"] || !layout.pois["hardware"] || !layout.pois["garage"])
		failure = "a special lot was not placed"
		return FALSE
	var/list/reached = new/list(w * h)
	var/list/steps = list(list(1, 0), list(-1, 0), list(0, 1), list(0, -1))
	var/list/start = entry_cells[1]
	var/list/queue = list(index(start[1], start[2]))
	reached[queue[1]] = TRUE
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
			if (reached[k] || blocked[k] || !passable(cells[k]))
				continue
			reached[k] = TRUE
			queue += k
	var/list/unreachable = list()
	for (var/list/p in entry_cells)
		if (!reached[index(p[1], p[2])])
			unreachable += "insertion [p[1]],[p[2]]"
	for (var/list/p in exit_cells)
		if (!reached[index(p[1], p[2])])
			unreachable += "evacuation [p[1]],[p[2]]"
	for (var/i in door_cells)
		if (!reached[i])
			unreachable += "door [i - (round((i - 1) / w)) * w],[round((i - 1) / w) + 1]"
	for (var/key in loot_cells)
		var/i = text2num(key)
		if (!reached[i])
			unreachable += "loot [i - (round((i - 1) / w)) * w],[round((i - 1) / w) + 1]"
	if (unreachable.len)
		failure = "[unreachable.len] required cells unreachable from the first insertion point: [jointext(unreachable, "; ", 1, min(unreachable.len, 6) + 1)]"
		var/list/first = splittext(copytext(unreachable[1], findtext(unreachable[1], " ") + 1), ",")
		var/fx = text2num(first[1])
		var/fy = text2num(first[2])
		var/list/rows = ascii_rows()
		for (var/y = min(h, fy + 6), y >= max(1, fy - 6), y--)
			failure += "\n" + copytext(rows[h - y + 1], max(1, fx - 8), min(w, fx + 8) + 1)
		return FALSE
	var/list/totals = list("reachable_cells" = queue.len, "blocks" = layout.blocks.len, "buildings" = layout.buildings.len, "doors" = door_cells.len, "loot" = loot_cells.len, "entries" = entry_cells.len, "exits" = exit_cells.len)
	for (var/key in totals)
		layout.counts[key] = totals[key]
	return TRUE

// ---------------------------------------------------------------- commit

/datum/zombie_city_generator/proc/turf_path(code)
	switch (code)
		if (ZC_RIM)
			return /turf/wall/indestructable
		if (ZC_ROAD, ZC_PARKING)
			return /turf/floor/plating/road
		if (ZC_ROAD_CENTER)
			return /turf/floor/plating/road/yellowline_center
		if (ZC_SIDEWALK)
			return /turf/floor/plating/concrete
		if (ZC_YARD_GRASS, ZC_PARK)
			return /turf/floor/grass
		if (ZC_YARD_PAVED, ZC_ALLEY)
			return /turf/floor/plating/dark
		if (ZC_FLOOR_WOOD)
			return /turf/floor/wood
		if (ZC_FLOOR_TILE, ZC_WINDOW, ZC_WINDOW_BROKEN, ZC_DOOR_STORE)
			return /turf/floor/plating/tiled
		if (ZC_FLOOR_CONCRETE)
			return /turf/floor/plating/concrete
		if (ZC_FLOOR_MARBLE)
			return /turf/floor/plating/marble/tile
		if (ZC_FLOOR_WHITE)
			return /turf/floor/plating/white
		if (ZC_WALL_CEMENT)
			return /turf/wall/cement
		if (ZC_WALL_BLOCKS)
			return /turf/wall/concrete_blocks
		if (ZC_WALL_INNER)
			return /turf/wall/wood
		if (ZC_DOOR_HOUSE, ZC_DOOR_INNER)
			return /turf/floor/wood
	return /turf/floor/dirt

/datum/zombie_city_generator/proc/ascii_char(code)
	switch (code)
		if (ZC_RIM)
			return "#"
		if (ZC_ROAD, ZC_PARKING)
			return "="
		if (ZC_ROAD_CENTER)
			return "-"
		if (ZC_SIDEWALK)
			return "."
		if (ZC_YARD_GRASS, ZC_PARK)
			return ","
		if (ZC_YARD_PAVED, ZC_ALLEY)
			return "_"
		if (ZC_YARD_DIRT, ZC_VACANT)
			return " "
		if (ZC_WALL_CEMENT, ZC_WALL_BLOCKS, ZC_WALL_INNER)
			return "W"
		if (ZC_DOOR_HOUSE, ZC_DOOR_STORE, ZC_DOOR_INNER)
			return "D"
		if (ZC_WINDOW)
			return "w"
		if (ZC_WINDOW_BROKEN)
			return "o"
	return "f"

/datum/zombie_city_generator/proc/ascii_rows()
	var/list/rows = list()
	for (var/y = h, y >= 1, y--)
		var/row = ""
		for (var/x = 1 to w)
			var/i = index(x, y)
			var/c = ascii_char(cells[i])
			if (loot_cells["[i]"])
				c = "L"
			else if (props[i] && blocked[i] && c != "W")
				c = "X"
			else if (props[i] && c != "W")
				c = "x"
			row += c
		rows += row
	for (var/list/p in entry_cells)
		rows[h - p[2] + 1] = copytext(rows[h - p[2] + 1], 1, p[1]) + "E" + copytext(rows[h - p[2] + 1], p[1] + 1)
	for (var/list/p in exit_cells)
		rows[h - p[2] + 1] = copytext(rows[h - p[2] + 1], 1, p[1]) + "V" + copytext(rows[h - p[2] + 1], p[1] + 1)
	return rows

// Writes the plan into the world. Turfs first, one row per yield slot, then
// doors, windows, props and markers; the horde and loot calls come last.
/datum/zombie_city_generator/proc/commit()
	var/phase_started = world.timeofday
	// Each new wall would otherwise refresh every lighting overlay within 21
	// tiles; with thousands of walls that is minutes. Refresh once at the end.
	wall_bulk_placement = TRUE
	try
		commit_turfs()
	catch (var/exception/placement_error)
		wall_bulk_placement = FALSE
		throw placement_error
	wall_bulk_placement = FALSE
	layout.counts["turf_ds"] = world.timeofday - phase_started
	phase_started = world.timeofday
	for (var/y = 1 to h)
		for (var/x = 1 to w)
			var/turf/T = locate(x, y, z)
			if (T?.lighting_overlay)
				T.lighting_overlay.update_overlay()
		TICK_CHECK
	layout.counts["lighting_ds"] = world.timeofday - phase_started
	phase_started = world.timeofday
	commit_objects()
	layout.counts["object_ds"] = world.timeofday - phase_started
	phase_started = world.timeofday
	place_markers()
	layout.counts["marker_ds"] = world.timeofday - phase_started

/datum/zombie_city_generator/proc/commit_turfs()
	var/replaced = 0
	for (var/y = 1 to h)
		for (var/x = 1 to w)
			var/i = index(x, y)
			var/path = turf_path(cells[i])
			var/turf/T = locate(x, y, z)
			if (!T)
				continue
			if (T.type != path)
				new path(T)
				replaced++
		TICK_CHECK
	layout.counts["turfs_replaced"] = replaced

/datum/zombie_city_generator/proc/commit_objects()
	for (var/y = 1 to h)
		for (var/x = 1 to w)
			var/i = index(x, y)
			var/code = cells[i]
			var/turf/T = locate(x, y, z)
			if (!T)
				continue
			switch (code)
				if (ZC_DOOR_HOUSE)
					new /obj/structure/simple_door/key_door/anyone/singledoor/housedoor(T)
				if (ZC_DOOR_STORE)
					new /obj/structure/simple_door/key_door/anyone/doubledoor/steel/store_door(T)
				if (ZC_DOOR_INNER)
					new /obj/structure/simple_door/key_door/anyone/singledoor/privacy(T)
				if (ZC_WINDOW)
					new /obj/structure/window_frame/metal(T)
					new /obj/structure/window/classic/metal(T)
				if (ZC_WINDOW_BROKEN)
					new /obj/structure/window_frame/metal(T)
			if (props[i])
				var/path = props[i]
				new path(T)
		TICK_CHECK

/datum/zombie_city_generator/proc/place_markers()
	var/ordinal = 0
	for (var/list/p in entry_cells)
		var/turf/T = locate(p[1], p[2], z)
		var/obj/effect/zombie_city/entry/E = new(T)
		E.side = p[3]
		E.ordinal = ++ordinal
		E.layout_id = layout.seed
		layout.entries += T
		layout.entry_markers += E
		zombie_city_add_insertion(T)
	ordinal = 0
	for (var/list/p in exit_cells)
		var/turf/T = locate(p[1], p[2], z)
		var/obj/effect/zombie_city/exit/X = new(T)
		X.side = p[3]
		X.ordinal = ++ordinal
		X.checkpoint = p[4]
		X.layout_id = layout.seed
		layout.exits += T
		layout.exit_markers += X
		zombie_city_add_evacuation(T, X.ordinal)
	var/rolled = 0
	for (var/key in loot_cells)
		var/list/spec = loot_cells[key]
		var/i = text2num(key)
		var/y = round((i - 1) / w) + 1
		var/x = i - (y - 1) * w
		var/turf/T = locate(x, y, z)
		var/obj/effect/zombie_city/loot/L = new(T)
		var/datum/zombie_city_building/D = spec[1]
		L.table = spec[2]
		L.tier = spec[3]
		L.building_id = D ? D.id : 0
		L.layout_id = layout.seed
		if (D)
			D.loot += L
		layout.loot_markers += L
		var/list/made = zombie_city_roll_loot(T, L.table, L.tier)
		if (islist(made))
			rolled += made.len
		TICK_CHECK
	layout.counts["loot_items"] = rolled
	var/registered = 0
	for (var/datum/zombie_city_block/B in layout.blocks)
		if (B.special == "irregular")
			continue
		if (zombie_horde_add_block(B.id, locate(B.x1, B.y1, z), locate(B.x2, B.y2, z), B.density))
			registered++
	layout.counts["horde_blocks"] = registered

// ---------------------------------------------------------------- entry

/proc/zombie_city_generate(seed, ground_z = 1, upper_z = 0)
	if (zombie_city_layout)
		return zombie_city_layout
	if (zombie_city_generating)
		return null
	if (!isnum(seed))
		seed = world.realtime
	seed = abs(round(seed))
	zombie_city_generating = TRUE
	var/started = world.timeofday
	var/datum/zombie_city_layout/result = null
	for (var/attempt = 1 to ZC_MAX_ATTEMPTS)
		var/datum/zombie_city_generator/G = new(seed, attempt, ground_z, upper_z)
		if (!G.plan())
			log_game("Zombie city: seed [seed] attempt [attempt] rejected: [G.failure]")
			continue
		G.commit()
		result = G.layout
		result.ascii_rows = G.ascii_rows()
		break
	if (result)
		result.generation_ds = world.timeofday - started
		if (result.generation_ds < 0)
			result.generation_ds += 864000
		zombie_city_layout = result
		log_game("Zombie city: seed [seed] attempt [result.attempt] generated [result.width]x[result.height] in [result.generation_ds / 10] s: [result.counts["buildings"]] buildings, [result.counts["blocks"]] blocks, [result.counts["entries"]] entries, [result.counts["exits"]] exits, [result.counts["loot"]] loot spots")
	else
		log_game("Zombie city: seed [seed] failed after [ZC_MAX_ATTEMPTS] attempts")
	zombie_city_generating = FALSE
	return result
