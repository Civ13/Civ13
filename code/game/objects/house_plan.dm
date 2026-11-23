// ============================================================
// House plans (docs/house-plans.md)
// ------------------------------------------------------------
// A ship's draught can carry a house: every storey drawn on a grid of
// HOUSE_PLAN_SIDE tiles each way, north to the top of the sheet. A tile of a
// storey holds up to three things:
//   a floor   on the ground, what the walls stand on (a stone floor is a
//             foundation); upstairs, a finish laid over the upper floor
//   a piece   a wall, door, window, pillar, roof support, stairs or a ladder
//   a roof    the roofing over the tile, which is also the floor of the
//             storey above
// The plan builds nothing. It judges the drawing by the rules a roof builder
// meets on the ground (building_levels.dm): how far each support reaches,
// how many storeys timber, stone and concrete carry, soft ground, supports
// over supports and spans. It also looks for what the game never refuses but
// a builder regrets: a storey with no stairs, a room with no door, rooms open
// to the weather. The checks are design checks of kind "house_plan"
// (house_plan_checks.dm); the window is the house designer (house_designer.dm).
//
// A builder can pin notes to tiles of the plan; they travel with it.
//
// A plan travels as a design code (design_codes.dm):
//   C13HOUSE/1/<name>/<storey,x,y,count,floor piece roof>;.../<storey,x,y,note>;...
// Each run is count tiles eastwards from x,y holding the same three keys,
// "-" for nothing. A note's spaces are written as underscores.
// ============================================================

#define HOUSE_PLAN_NAME_MAX 40
// Soft ground carries this many storeys; a foundation carries any (as
// BUILDING_UNFOUNDED_STOREYS and BUILDING_GROUND_STRENGTH in building_levels.dm).
#define HOUSE_PLAN_SOFT_STOREYS 2
#define HOUSE_PLAN_GROUND_STRENGTH 1000
#define HOUSE_AT(x, y) (((y) - 1) * HOUSE_PLAN_SIDE + (x))

// The pieces a tile can hold.
//   kind    wall, door, window, pillar, stairs or ladder
//   tier    the storeys it carries (building_support_tier), 0 for none
//   reach   how many tiles away it holds a roof (building_support_reach)
//   solid   nobody walks through it
//   type    what it is built as, for the probe that compares the two
//   cost    what one costs by its usual recipe
/proc/house_plan_pieces()
	var/static/list/table
	if (!table)
		table = list(
		"T" = list("name" = "timber wall", "kind" = "wall", "tier" = 2, "reach" = 1, "solid" = TRUE, "type" = /obj/covers/wood_wall/log, "cost" = list("wood" = 4)),
		"S" = list("name" = "stone wall", "kind" = "wall", "tier" = 4, "reach" = 1, "solid" = TRUE, "type" = /obj/covers/stone_wall, "cost" = list("stone" = 8)),
		"C" = list("name" = "concrete wall", "kind" = "wall", "tier" = 6, "reach" = 1, "solid" = TRUE, "type" = /obj/covers/cement_wall, "cost" = list("cement bricks" = 2)),
		"D" = list("name" = "door", "kind" = "door", "tier" = 2, "reach" = 0, "solid" = FALSE, "type" = /obj/structure/simple_door/key_door/anyone/wood, "cost" = list("wood" = 5)),
		"N" = list("name" = "timber window", "kind" = "window", "tier" = 2, "reach" = 1, "solid" = TRUE, "type" = /obj/structure/window_frame, "cost" = list("wood" = 5)),
		"M" = list("name" = "stone window", "kind" = "window", "tier" = 4, "reach" = 1, "solid" = TRUE, "type" = /obj/structure/window_frame/stone, "cost" = list("stone" = 5)),
		"R" = list("name" = "roof support", "kind" = "pillar", "tier" = 2, "reach" = 3, "solid" = TRUE, "type" = /obj/structure/roof_support, "cost" = list("wood" = 2)),
		"P" = list("name" = "stone pillar", "kind" = "pillar", "tier" = 4, "reach" = 2, "solid" = TRUE, "type" = /obj/structure/mine_support/stone, "cost" = list("stone" = 2)),
		"Q" = list("name" = "concrete pillar", "kind" = "pillar", "tier" = 6, "reach" = 2, "solid" = TRUE, "type" = /obj/structure/mine_support/stone/concrete, "cost" = list("concrete" = 2)),
		"U" = list("name" = "stairs", "kind" = "stairs", "tier" = 0, "reach" = 0, "solid" = FALSE, "type" = /obj/covers/wood/stairs, "cost" = list("wood" = 2)),
		"H" = list("name" = "ladder", "kind" = "ladder", "tier" = 0, "reach" = 0, "solid" = FALSE, "type" = /obj/item/weapon/hole_ladder, "cost" = list("wood" = 4)),
		)
	return table

// The floors. foundation: ground-floor supports on it carry more than two storeys.
/proc/house_plan_floors()
	var/static/list/table
	if (!table)
		table = list(
		"w" = list("name" = "wood floor", "foundation" = FALSE, "type" = /obj/covers/wood, "cost" = list("wood" = 1)),
		"s" = list("name" = "stone floor", "foundation" = TRUE, "type" = /obj/covers/cobblestone, "cost" = list("stone" = 1)),
		"c" = list("name" = "concrete floor", "foundation" = TRUE, "type" = /obj/covers/concretefloor, "cost" = list("concrete" = 1)),
		)
	return table

// The roofing. Every kind is held up the same way.
/proc/house_plan_roofs()
	var/static/list/table
	if (!table)
		table = list(
		"t" = list("name" = "thatch roof", "type" = /obj/roof/thatch, "cost" = list("leaves" = 2)),
		"w" = list("name" = "wood roof", "type" = /obj/roof/wood, "cost" = list("wood" = 1)),
		"c" = list("name" = "clay tile roof", "type" = /obj/roof/clay, "cost" = list("clay" = 0.5)),
		"k" = list("name" = "concrete roof", "type" = /obj/roof/concrete, "cost" = list("concrete" = 1)),
		"g" = list("name" = "glass roof", "type" = /obj/roof/glass, "cost" = list("glass" = 1)),
		)
	return table

/datum/house_plan
	var/name = "house"
	// storeys[storey][HOUSE_AT(x, y)] = "<floor><piece><roof>" or null. Storey
	// 1 is the ground floor; x 1 is west, y 1 north.
	var/list/storeys
	// list(list(storey, x, y, text), ...)
	var/list/notes = list()
	// One reckoning's answers, dropped when the drawing changes.
	var/tmp/list/memo = null

/datum/house_plan/New()
	..()
	storeys = list()
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		storeys[++storeys.len] = new /list(HOUSE_PLAN_SIDE * HOUSE_PLAN_SIDE)

/datum/house_plan/proc/in_grid(s, x, y)
	return isnum(s) && isnum(x) && isnum(y) && s == round(s) && x == round(x) && y == round(y) && s >= 1 && s <= HOUSE_PLAN_STOREYS && x >= 1 && y >= 1 && x <= HOUSE_PLAN_SIDE && y <= HOUSE_PLAN_SIDE

// The three keys of a tile, or null when it is empty or off the sheet.
/datum/house_plan/proc/cell(s, x, y)
	if (s < 1 || s > HOUSE_PLAN_STOREYS || x < 1 || y < 1 || x > HOUSE_PLAN_SIDE || y > HOUSE_PLAN_SIDE)
		return null
	var/list/L = storeys[s]
	return L[HOUSE_AT(x, y)]

/datum/house_plan/proc/floor_key(s, x, y)
	var/text = cell(s, x, y)
	if (!text)
		return null
	text = copytext(text, 1, 2)
	return text == "-" ? null : text

/datum/house_plan/proc/piece_key(s, x, y)
	var/text = cell(s, x, y)
	if (!text)
		return null
	text = copytext(text, 2, 3)
	return text == "-" ? null : text

/datum/house_plan/proc/roof_key(s, x, y)
	var/text = cell(s, x, y)
	if (!text)
		return null
	text = copytext(text, 3, 4)
	return text == "-" ? null : text

/datum/house_plan/proc/has_roof(s, x, y)
	return !isnull(roof_key(s, x, y))

// The piece's row of house_plan_pieces(), or null.
/datum/house_plan/proc/piece_info(s, x, y)
	var/key = piece_key(s, x, y)
	return key ? house_plan_pieces()[key] : null

// Sets a tile's three keys; null (or "-") clears one. FALSE when the tile is
// off the sheet or a key is not in its table.
/datum/house_plan/proc/set_cell(s, x, y, floor, piece, roof)
	if (!in_grid(s, x, y))
		return FALSE
	if (floor == "-")
		floor = null
	if (piece == "-")
		piece = null
	if (roof == "-")
		roof = null
	if ((floor && !house_plan_floors()[floor]) || (piece && !house_plan_pieces()[piece]) || (roof && !house_plan_roofs()[roof]))
		return FALSE
	var/list/L = storeys[s]
	L[HOUSE_AT(x, y)] = (floor || piece || roof) ? "[floor ? floor : "-"][piece ? piece : "-"][roof ? roof : "-"]" : null
	memo = null
	return TRUE

// Changes one of a tile's keys and keeps the others.
/datum/house_plan/proc/set_floor(s, x, y, key)
	return set_cell(s, x, y, key, piece_key(s, x, y), roof_key(s, x, y))

/datum/house_plan/proc/set_piece(s, x, y, key)
	return set_cell(s, x, y, floor_key(s, x, y), key, roof_key(s, x, y))

/datum/house_plan/proc/set_roof(s, x, y, key)
	return set_cell(s, x, y, floor_key(s, x, y), piece_key(s, x, y), key)

// The highest storey with anything drawn on it, or 0 for a blank sheet.
/datum/house_plan/proc/top_storey()
	for (var/s = HOUSE_PLAN_STOREYS, s >= 1, s--)
		var/list/L = storeys[s]
		for (var/text in L)
			if (text)
				return s
	return 0

/datum/house_plan/proc/tile_count()
	. = 0
	for (var/list/L in storeys)
		for (var/text in L)
			if (text)
				.++

// The box round everything drawn: list(west, north, east, south), or null.
/datum/house_plan/proc/extent()
	var/west = 0
	var/north = 0
	var/east = 0
	var/south = 0
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!cell(s, x, y))
					continue
				if (!west || x < west)
					west = x
				if (!north || y < north)
					north = y
				east = max(east, x)
				south = max(south, y)
	return west ? list(west, north, east, south) : null

// ---- What holds a roof up ----
// The plan's own reading of building_slab_info(), building_support_base(),
// building_column_carries() and building_design_error(): the same answers
// for the same building, which tests/house_plans proves on a real one.

// Whether something stands under a tile of storey s: the ground, or a roof
// of the storey below that the plan can hold up.
/datum/house_plan/proc/stands(s, x, y, founded = FALSE)
	if (s <= 1)
		return TRUE
	return has_roof(s - 1, x, y) && !roof_fault(s - 1, x, y, founded)

/datum/house_plan/proc/founded_at(x, y)
	var/key = floor_key(1, x, y)
	var/list/F = key ? house_plan_floors()[key] : null
	return F && F["foundation"]

// What a support at a tile stands on: list(storey, strength), or null when
// it stands on nothing. founded reckons as if every ground-floor support had
// a foundation.
/datum/house_plan/proc/support_base(s, x, y, founded = FALSE)
	if (s <= 1)
		return list(0, (founded || founded_at(x, y)) ? HOUSE_PLAN_GROUND_STRENGTH : HOUSE_PLAN_SOFT_STOREYS)
	if (!stands(s, x, y, founded))
		return null
	return slab_info(s - 1, x, y, founded)

// The storey a roof on this tile is and the storeys its strongest chain of
// supports carries: list(storey, strength), or null when nothing holds it.
/datum/house_plan/proc/slab_info(s, x, y, founded = FALSE)
	if (!memo)
		memo = list()
	var/id = "i[founded ? "f" : ""][s],[x],[y]"
	var/known = memo[id]
	if (known)
		return islist(known) ? known : null
	memo[id] = -1
	var/list/best
	for (var/dy = -3 to 3)
		for (var/dx = -3 to 3)
			var/list/P = piece_info(s, x + dx, y + dy)
			if (!P || !P["tier"] || max(abs(dx), abs(dy)) > P["reach"])
				continue
			var/list/under = support_base(s, x + dx, y + dy, founded)
			if (!under)
				continue
			var/h = under[1] + 1
			// A chain is as strong as its weakest support.
			var/cap = min(P["tier"], under[2])
			if (h > cap)
				continue
			if (!best || cap > best[2])
				best = list(h, cap)
	if (best)
		memo[id] = best
	return best

// A support on an upper floor carries storey h only over supports that carry
// it too, within a tile of it on each floor below, founded where they meet
// the ground. The game follows the first such support it finds; the plan
// accepts any, the one straight below first.
/datum/house_plan/proc/column_carries(s, x, y, h, founded = FALSE)
	if (s <= 1)
		return TRUE
	if (!stands(s, x, y, founded))
		return FALSE
	for (var/list/step in list(list(0, 0), list(0, -1), list(0, 1), list(-1, 0), list(1, 0), list(-1, -1), list(1, -1), list(-1, 1), list(1, 1)))
		var/ax = x + step[1]
		var/ay = y + step[2]
		var/list/P = piece_info(s - 1, ax, ay)
		if (!P || P["tier"] < h)
			continue
		if (s == 2 && !founded && !founded_at(ax, ay) && HOUSE_PLAN_SOFT_STOREYS < h)
			continue
		if (column_carries(s - 1, ax, ay, h, founded))
			return TRUE
	return FALSE

// Why the roof on a tile cannot be built, or null when it can:
//   "none"    no wall, window, pillar or support reaches the tile
//   "soft"    the supports would do on a foundation, but stand on soft ground
//   "weak"    the supports in reach do not carry this storey
//   "air"     the supports in reach stand on nothing
//   "column"  the supports here have nothing strong enough beneath them
//   "span"    one distant pillar: no support beside the tile or on a second side
/datum/house_plan/proc/roof_fault(s, x, y, founded = FALSE)
	if (!memo)
		memo = list()
	var/id = "f[founded ? "f" : ""][s],[x],[y]"
	var/known = memo[id]
	if (known)
		return known == "ok" ? null : known
	. = roof_fault_of(s, x, y, founded)
	memo[id] = . ? . : "ok"

/datum/house_plan/proc/roof_fault_of(s, x, y, founded)
	var/list/info = slab_info(s, x, y, founded)
	if (!info)
		if (!founded)
			var/list/on_stone = slab_info(s, x, y, TRUE)
			if (on_stone && on_stone[1] > HOUSE_PLAN_SOFT_STOREYS)
				return "soft"
		var/any = FALSE
		var/weak = FALSE
		for (var/dy = -3 to 3)
			for (var/dx = -3 to 3)
				var/list/P = piece_info(s, x + dx, y + dy)
				if (!P || !P["tier"] || max(abs(dx), abs(dy)) > P["reach"])
					continue
				any = TRUE
				if (support_base(s, x + dx, y + dy, founded))
					weak = TRUE
		if (!any)
			return "none"
		return weak ? "weak" : "air"
	var/h = info[1]
	var/near = FALSE
	var/uncarried = FALSE
	var/list/sides = list()
	for (var/dy = -3 to 3)
		for (var/dx = -3 to 3)
			var/list/P = piece_info(s, x + dx, y + dy)
			if (!P || P["tier"] < h || max(abs(dx), abs(dy)) > P["reach"])
				continue
			var/list/under = support_base(s, x + dx, y + dy, founded)
			if (!under || under[1] + 1 != h || under[2] < h)
				continue
			if (!column_carries(s, x + dx, y + dy, h, founded))
				uncarried = TRUE
				continue
			if (max(abs(dx), abs(dy)) <= 1)
				near = TRUE
			sides |= "[dx > 0 ? 1 : (dx < 0 ? -1 : 0)],[dy > 0 ? 1 : (dy < 0 ? -1 : 0)]"
	// A ground-floor roof keeps the plain rule: any one support within reach.
	if (near || sides.len >= 2 || (h < 2 && sides.len))
		return null
	return uncarried ? "column" : "span"

// ---- Walking about ----

/datum/house_plan/proc/passable(s, x, y, doors_shut = FALSE)
	var/list/P = piece_info(s, x, y)
	if (!P)
		return TRUE
	if (P["solid"])
		return FALSE
	return !(doors_shut && P["kind"] == "door")

// Stairs or a ladder on this tile with the tile above left open.
/datum/house_plan/proc/way_up(s, x, y)
	var/list/P = piece_info(s, x, y)
	return P && (P["kind"] == "stairs" || P["kind"] == "ladder") && !has_roof(s, x, y)

// The tiles of storey s reached from beyond the sheet, walking north, south,
// east and west: a list by HOUSE_AT of TRUE. With doors_shut a door stops the
// walk, as it stops the weather.
/datum/house_plan/proc/outside(s, doors_shut = FALSE)
	if (!memo)
		memo = list()
	var/id = "o[doors_shut ? "s" : ""][s]"
	var/list/found = memo[id]
	if (found)
		return found
	found = new /list(HOUSE_PLAN_SIDE * HOUSE_PLAN_SIDE)
	memo[id] = found
	// The walk starts on a ring one tile outside the sheet.
	var/list/queue = list()
	for (var/i = 1, i <= HOUSE_PLAN_SIDE, i++)
		queue += list(list(i, 0), list(i, HOUSE_PLAN_SIDE + 1), list(0, i), list(HOUSE_PLAN_SIDE + 1, i))
	var/at = 1
	while (at <= queue.len)
		var/list/Q = queue[at++]
		for (var/list/step in list(list(0, -1), list(0, 1), list(-1, 0), list(1, 0)))
			var/x = Q[1] + step[1]
			var/y = Q[2] + step[2]
			if (x < 1 || y < 1 || x > HOUSE_PLAN_SIDE || y > HOUSE_PLAN_SIDE || found[HOUSE_AT(x, y)] || !passable(s, x, y, doors_shut))
				continue
			found[HOUSE_AT(x, y)] = TRUE
			queue += list(list(x, y))
	return found

// Whether a tile of storey s is a floor to stand on: the ground, or a roof
// of the storey below.
/datum/house_plan/proc/is_floor(s, x, y)
	if (x < 1 || y < 1 || x > HOUSE_PLAN_SIDE || y > HOUSE_PLAN_SIDE)
		return s <= 1
	return s <= 1 || has_roof(s - 1, x, y)

// The tiles of storey s a builder can walk to: on the ground from outside,
// upstairs from the head of stairs or a ladder that can itself be walked to.
/datum/house_plan/proc/reached(s)
	if (s <= 1)
		return outside(1, FALSE)
	if (!memo)
		memo = list()
	var/id = "r[s]"
	var/list/found = memo[id]
	if (found)
		return found
	found = new /list(HOUSE_PLAN_SIDE * HOUSE_PLAN_SIDE)
	memo[id] = found
	var/list/below = reached(s - 1)
	var/list/queue = list()
	for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
		for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
			if (way_up(s - 1, x, y) && below[HOUSE_AT(x, y)])
				queue += list(list(x, y))
	var/at = 1
	while (at <= queue.len)
		var/list/Q = queue[at++]
		for (var/list/step in list(list(0, -1), list(0, 1), list(-1, 0), list(1, 0)))
			var/x = Q[1] + step[1]
			var/y = Q[2] + step[2]
			if (x < 1 || y < 1 || x > HOUSE_PLAN_SIDE || y > HOUSE_PLAN_SIDE || found[HOUSE_AT(x, y)] || !has_roof(s - 1, x, y) || !passable(s, x, y))
				continue
			found[HOUSE_AT(x, y)] = TRUE
			queue += list(list(x, y))
	return found

// The stairs and ladders of storey s that lead up: list("x,y", ...).
/datum/house_plan/proc/ways_up(s)
	. = list()
	for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
		for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
			if (way_up(s, x, y))
				. += "[x],[y]"

// ---- What it takes ----

// The parts drawn: name = how many, pieces first, then floors and roofs.
/datum/house_plan/proc/parts()
	. = list()
	var/list/pieces = house_plan_pieces()
	var/list/floors = house_plan_floors()
	var/list/roofs = house_plan_roofs()
	for (var/list/table in list(pieces, floors, roofs))
		for (var/key in table)
			.[table[key]["name"]] = 0
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!cell(s, x, y))
					continue
				var/key = piece_key(s, x, y)
				if (key)
					.[pieces[key]["name"]]++
				key = floor_key(s, x, y)
				if (key)
					.[floors[key]["name"]]++
				key = roof_key(s, x, y)
				if (key)
					.[roofs[key]["name"]]++
	for (var/part in .)
		if (!.[part])
			. -= part

// The materials for those parts by their usual recipes: material = amount.
/datum/house_plan/proc/materials()
	. = list()
	var/list/count = parts()
	for (var/list/table in list(house_plan_pieces(), house_plan_floors(), house_plan_roofs()))
		for (var/key in table)
			var/list/row = table[key]
			var/n = count[row["name"]]
			if (!n)
				continue
			var/list/cost = row["cost"]
			for (var/material in cost)
				.[material] += cost[material] * n
	for (var/material in .)
		.[material] = CEILING(.[material], 1)

/datum/house_plan/proc/materials_text()
	var/list/M = materials()
	var/list/words = list()
	for (var/material in M)
		words += "[M[material]] [material]"
	return words.len ? english_list(words) : "nothing"

/datum/house_plan/proc/parts_text()
	var/list/P = parts()
	var/list/words = list()
	for (var/part in P)
		words += house_plan_count_text(P[part], part)
	return words.len ? english_list(words) : "nothing"

// "3 stone walls", "1 door", "2 stairs".
/proc/house_plan_count_text(n, name)
	if (n == 1 || copytext(name, length(name)) == "s")
		return "[n] [name]"
	return "[n] [name]s"

/datum/house_plan/proc/problems()
	return design_errors("house_plan", src)

/datum/house_plan/proc/check_design()
	return design_report("house_plan", src)

/proc/house_plan_storey_name(s)
	return s <= 1 ? "ground floor" : "[building_storey_name(s)] storey"

/datum/house_plan/proc/summary_text()
	var/list/lines = list()
	var/top = top_storey()
	if (!top)
		return "<b>[name]</b>: a house plan with nothing drawn on it yet."
	var/list/box = extent()
	lines += "<b>[name]</b>: a house plan of [top] storey\s, [box[3] - box[1] + 1] by [box[4] - box[2] + 1] tiles, north to the top of the sheet."
	lines += "It shows [parts_text()]."
	lines += "By the usual recipes that is about [materials_text()]."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>It cannot be built as drawn:</span>" : "As drawn it can be built."
	lines += R.chat_lines()
	qdel(R)
	for (var/list/N in notes)
		lines += "<i>Note, [house_plan_storey_name(N[1])], tile [N[2]],[N[3]]:</i> [N[4]]"
	return jointext(lines, "<br>")

// ---- Notes ----

// A note's text with only letters, digits, spaces and plain punctuation, so
// it reads the same after travelling in a design code.
/proc/house_plan_clean_note(text)
	if (!istext(text))
		return ""
	var/list/kept = list()
	var/length_kept = 0
	for (var/i = 1, i <= length(text) && length_kept < HOUSE_PLAN_NOTE_LENGTH, i++)
		var/c = text2ascii(text, i)
		if (c == 95) // an underscore is a space in a code
			c = 32
		if ((c >= 48 && c <= 57) || (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 32 || c == 33 || c == 40 || c == 41 || c == 43 || c == 45 || c == 46 || c == 58 || c == 61 || c == 63)
			kept += ascii2text(c)
			length_kept++
	return trim(jointext(kept, ""))

/datum/house_plan/proc/note_at(s, x, y)
	for (var/list/N in notes)
		if (N[1] == s && N[2] == x && N[3] == y)
			return N[4]
	return null

// Pins a note to a tile; empty text takes it off. FALSE when the tile is off
// the sheet or the plan already holds its fill of notes.
/datum/house_plan/proc/set_note(s, x, y, text)
	if (!in_grid(s, x, y))
		return FALSE
	text = house_plan_clean_note(text)
	for (var/list/N in notes)
		if (N[1] == s && N[2] == x && N[3] == y)
			if (length(text))
				N[4] = text
			else
				notes -= list(N)
			return TRUE
	if (!length(text))
		return TRUE
	if (notes.len >= HOUSE_PLAN_NOTES_MAX)
		return FALSE
	notes += list(list(s, x, y, text))
	return TRUE

// ---- Design codes ----

/proc/house_plan_clean_name(text)
	if (!istext(text))
		return "house"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, HOUSE_PLAN_NAME_MAX + 1)))
	return length(text) ? text : "house"

/datum/house_plan/proc/to_code()
	var/list/runs = list()
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			var/x = 1
			while (x <= HOUSE_PLAN_SIDE)
				var/text = cell(s, x, y)
				if (!text)
					x++
					continue
				var/n = 1
				while (x + n <= HOUSE_PLAN_SIDE && cell(s, x + n, y) == text)
					n++
				runs += "[s],[x],[y],[n],[text]"
				x += n
	var/list/pinned = list()
	for (var/list/N in notes)
		pinned += "[N[1]],[N[2]],[N[3]],[replacetext(N[4], " ", "_")]"
	return "C13HOUSE/1/[replacetext(house_plan_clean_name(name), " ", "_")]/[jointext(runs, ";")]/[jointext(pinned, ";")]"

/proc/house_plan_from_code(code)
	var/list/F = design_code_fields(code, "HOUSE", DESIGN_CODE_HOUSE_MAX)
	if (!F || F.len != 3)
		return null
	var/datum/house_plan/D = new
	D.name = house_plan_clean_name(replacetext(F[1], "_", " "))
	for (var/run in (length(F[2]) ? splittext(F[2], ";") : list()))
		var/list/T = splittext(run, ",")
		if (T.len != 5 || length(T[5]) != 3)
			qdel(D)
			return null
		var/s = text2num(T[1])
		var/x = text2num(T[2])
		var/y = text2num(T[3])
		var/n = text2num(T[4])
		if (!isnum(n) || n != round(n) || n < 1 || !D.in_grid(s, x, y) || !D.in_grid(s, x + n - 1, y) || T[5] == "---")
			qdel(D)
			return null
		for (var/i = 0, i < n, i++)
			if (D.cell(s, x + i, y) || !D.set_cell(s, x + i, y, copytext(T[5], 1, 2), copytext(T[5], 2, 3), copytext(T[5], 3, 4)))
				qdel(D)
				return null
	var/list/pinned = length(F[3]) ? splittext(F[3], ";") : list()
	if (pinned.len > HOUSE_PLAN_NOTES_MAX)
		qdel(D)
		return null
	for (var/note in pinned)
		var/list/T = splittext(note, ",")
		if (T.len != 4)
			qdel(D)
			return null
		var/s = text2num(T[1])
		var/x = text2num(T[2])
		var/y = text2num(T[3])
		var/text = house_plan_clean_note(T[4])
		if (!D.in_grid(s, x, y) || !length(text) || D.note_at(s, x, y) || !D.set_note(s, x, y, text))
			qdel(D)
			return null
	return D

// ---- Ready-made plans ----

// Draws rows of keys on storey s with its top left tile at west, north. Each
// tile is three characters, floor piece roof, tiles split by spaces; "..."
// leaves a tile as it is.
/datum/house_plan/proc/draw_rows(s, west, north, list/rows)
	for (var/r = 1, r <= rows.len, r++)
		var/list/tiles = splittext(rows[r], " ")
		for (var/c = 1, c <= tiles.len, c++)
			var/text = tiles[c]
			if (text == "...")
				continue
			set_cell(s, west + c - 1, north + r - 1, copytext(text, 1, 2), copytext(text, 2, 3), copytext(text, 3, 4))

// Each one can be built as drawn (the probe checks).
/proc/house_plan_examples()
	. = list()
	// A one-room cabin: timber walls on bare ground under thatch.
	var/datum/house_plan/cabin = new
	cabin.name = "cabin"
	cabin.draw_rows(1, 8, 8, list(
		"-Tt -Tt -Nt -Tt -Tt",
		"-Tt --t --t --t -Tt",
		"-Nt --t --t --t -Tt",
		"-Tt -Tt -Dt -Tt -Tt",
	))
	cabin.set_note(1, 9, 9, "Hearth here")
	. += cabin
	// Two timber storeys: a roof support under the middle of the wide room,
	// stairs in a corner with the tile above left open and roofed over on
	// the top storey.
	var/datum/house_plan/house = new
	house.name = "two-storey house"
	house.draw_rows(1, 7, 7, list(
		"-Tw -Tw -Nw -Tw -Nw -Tw -Tw",
		"-Tw wU- w-w w-w w-w w-w -Tw",
		"-Nw w-w w-w wRw w-w w-w -Nw",
		"-Tw w-w w-w w-w w-w w-w -Tw",
		"-Tw w-w w-w w-w w-w w-w -Tw",
		"-Tw -Tw -Tw -Dw -Tw -Tw -Tw",
	))
	house.draw_rows(2, 7, 7, list(
		"-Tw -Tw -Nw -Tw -Nw -Tw -Tw",
		"-Tw --w --w --w --w --w -Tw",
		"-Nw --w --w -Rw --w --w -Nw",
		"-Tw --w --w --w --w --w -Tw",
		"-Tw --w --w --w --w --w -Tw",
		"-Tw -Tw -Tw -Nw -Tw -Tw -Tw",
	))
	house.set_note(2, 12, 8, "Beds upstairs")
	. += house
	// Three storeys of stone on a stone floor with a pillar up the middle,
	// a ladder in one corner and the next in the other.
	var/datum/house_plan/tower = new
	tower.name = "stone tower house"
	tower.draw_rows(1, 8, 8, list(
		"sSc sSc sSc sSc sSc",
		"sSc sH- s-c s-c sSc",
		"sSc s-c sPc s-c sSc",
		"sSc s-c s-c s-c sSc",
		"sSc sSc sDc sSc sSc",
	))
	tower.draw_rows(2, 8, 8, list(
		"-Sc -Sc -Mc -Sc -Sc",
		"-Sc --c --c -H- -Sc",
		"-Mc --c -Pc --c -Mc",
		"-Sc --c --c --c -Sc",
		"-Sc -Sc -Mc -Sc -Sc",
	))
	tower.draw_rows(3, 8, 8, list(
		"-Sc -Sc -Mc -Sc -Sc",
		"-Sc --c --c --c -Sc",
		"-Mc --c -Pc --c -Mc",
		"-Sc --c --c --c -Sc",
		"-Sc -Sc -Mc -Sc -Sc",
	))
	tower.set_note(1, 11, 11, "Store room. Beds on the top storey")
	. += tower

// ---- The sheet ----

/obj/item/ship_draught/proc/house_plan()
	return draught_code ? house_plan_from_code(draught_code) : null

/obj/item/ship_draught/proc/house_plan_kind()
	return draught_code && design_code_kind(draught_code) == "HOUSE"

/obj/item/ship_draught/proc/take_house(datum/house_plan/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "house plan ([D.name])" : initial(name)

/obj/item/ship_draught/proc/house_sheet_menu(mob/living/human/H, datum/house_plan/D)
	var/pegged = peg_z && length(peg_set)
	var/list/options = list("Draw on the sheet", pegged ? "Peg out the storey I stand on" : "Peg it out on the ground")
	if (pegged)
		options += "Pull up the pegs and forget the site"
	options += list("Copy its design code", "Paste a design code", "Cancel")
	var/text = D.summary_text()
	if (pegged)
		text += "<br>[house_pegs_text()]"
	var/choice = WWinput(H, text, name, "Cancel", options)
	if (QDELETED(src) || loc != H)
		return
	if (choice == "Draw on the sheet")
		open_house_designer(H)
	else if (choice == "Peg it out on the ground" || choice == "Peg out the storey I stand on")
		var/datum/house_plan/now = house_plan()
		if (now)
			house_peg_menu(H, now)
			qdel(now)
	else if (choice == "Pull up the pegs and forget the site")
		house_pegs_forget(H)
	else if (choice == "Copy its design code")
		design_code_show(H, "House plan: [D.name]", draught_code, "Paste it into any ship's draught to draw the same house.")
	else if (choice == "Paste a design code")
		paste_any_code(H)

#undef HOUSE_PLAN_NAME_MAX
#undef HOUSE_PLAN_SOFT_STOREYS
#undef HOUSE_PLAN_GROUND_STRENGTH
#undef HOUSE_AT
