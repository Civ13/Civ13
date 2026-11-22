// ============================================================
// Checks and part book for house plans (docs/house-plans.md)
// ------------------------------------------------------------
// Design checks (craft/design_checks.dm) of kind "house_plan" judge a
// /datum/house_plan (house_plan.dm). An error is something the game will
// refuse when the house is built: a roof nothing holds up, a wall on open
// air. A warning is something it will let you build and you will regret: a
// storey with no stairs, a room with no door or open to the sky. A note is
// advice. Cells are the plan's "x,y" and the deck is the storey, 1 for the
// ground floor.
// ============================================================

/datum/design_check/house_plan
	kind = "house_plan"
	abstract_type = /datum/design_check/house_plan

/datum/design_check/house_plan/check(datum/house_plan/D, datum/design_report/R)
	if (istype(D))
		plan_check(D, R, D.top_storey())

/datum/design_check/house_plan/proc/plan_check(datum/house_plan/D, datum/design_report/R, top)
	return

// "is" or "are", "stands" or "stand", by the count.
/proc/house_plan_verb(n, one, many)
	return n == 1 ? one : many

/datum/design_check/house_plan/blank
	order = 10

/datum/design_check/house_plan/blank/plan_check(datum/house_plan/D, datum/design_report/R, top)
	if (!top)
		R.error("Nothing is drawn yet. Pick a wall and draw the outline of the ground floor, then a door, the roof and the storeys above.")

// Upstairs, everything stands on a roof of the storey below.
/datum/design_check/house_plan/standing
	order = 20

/datum/design_check/house_plan/standing/plan_check(datum/house_plan/D, datum/design_report/R, top)
	for (var/s = 2, s <= top, s++)
		var/list/adrift = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if ((D.piece_key(s, x, y) || D.floor_key(s, x, y)) && !D.has_roof(s - 1, x, y))
					adrift += "[x],[y]"
		if (adrift.len)
			R.error("[adrift.len] tile\s of the [house_plan_storey_name(s)] [house_plan_verb(adrift.len, "has", "have")] nothing under [house_plan_verb(adrift.len, "it", "them")]. A roof is the floor of the storey above: roof the same tile on the [house_plan_storey_name(s - 1)] first, the tiles its walls stand on included.", adrift, null, s)

// Every roof tile is held up by the rules of building_design_error().
/datum/design_check/house_plan/roofs
	order = 30

/datum/design_check/house_plan/roofs/plan_check(datum/house_plan/D, datum/design_report/R, top)
	for (var/s = 1, s <= top, s++)
		var/list/faults = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!D.has_roof(s, x, y))
					continue
				var/fault = D.roof_fault(s, x, y)
				if (!fault)
					continue
				if (!faults[fault])
					faults[fault] = list()
				faults[fault] += "[x],[y]"
		var/where = house_plan_storey_name(s)
		for (var/fault in list("none", "soft", "weak", "air", "column", "span"))
			var/list/cells = faults[fault]
			if (!cells)
				continue
			var/n = cells.len
			var/lead = "[n] roof tile\s of the [where]"
			switch (fault)
				if ("none")
					R.error("[lead] [house_plan_verb(n, "has", "have")] nothing holding [house_plan_verb(n, "it", "them")] up. A roof tile needs a wall or window within 1 tile, a stone or concrete pillar within 2 or a wooden roof support within 3; a door holds only its own tile. Put a pillar or roof support in the middle of a wide room.", cells, "R", s)
				if ("soft")
					R.error("[lead] [house_plan_verb(n, "needs", "need")] a foundation. The ground-floor walls and pillars under [house_plan_verb(n, "it", "them")] stand on soft ground, which carries two storeys. Draw a stone or concrete floor under those walls and pillars: it has to be laid before they are built.", cells, "floor_s", s)
				if ("weak")
					R.error("[lead] [house_plan_verb(n, "is", "are")] too high for the walls and pillars in reach. Timber walls, doors and wooden supports carry two storeys, stone four and concrete six, and a storey is only as strong as the weakest one under it.", cells, null, s)
				if ("air")
					R.error("[lead] [house_plan_verb(n, "has", "have")] only supports that stand on nothing. A wall or pillar upstairs holds a roof only when it stands on a roof tile of the storey below that is itself held up.", cells, null, s)
				if ("column")
					R.error("[lead] [house_plan_verb(n, "has", "have")] walls or pillars with nothing strong enough beneath them on the floor below. Build supports above supports of the same strength, on the same tile or right next to it, all the way down.", cells, null, s)
				if ("span")
					R.error("[lead] [house_plan_verb(n, "hangs", "hang")] from one distant pillar. From the second storey up a roof tile needs a wall or pillar right next to it, or supports within reach on two different sides.", cells, "P", s)

// Stairs and ladders, and whether each storey can be walked to.
/datum/design_check/house_plan/access
	order = 40

/datum/design_check/house_plan/access/plan_check(datum/house_plan/D, datum/design_report/R, top)
	for (var/s = 1, s <= top, s++)
		var/list/covered = list()
		var/list/nowhere = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				var/list/P = D.piece_info(s, x, y)
				if (!P || (P["kind"] != "stairs" && P["kind"] != "ladder"))
					continue
				if (D.has_roof(s, x, y))
					covered += "[x],[y]"
				else if (!D.has_roof(s, x, y - 1) && !D.has_roof(s, x, y + 1) && !D.has_roof(s, x - 1, y) && !D.has_roof(s, x + 1, y))
					nowhere += "[x],[y]"
		if (covered.len)
			R.warning("[covered.len] stairs or ladder\s on the [house_plan_storey_name(s)] [house_plan_verb(covered.len, "is", "are")] roofed over, so [house_plan_verb(covered.len, "it leads", "they lead")] nowhere. Leave the tile above stairs or a ladder open: take the roof off that tile.", covered, "U", s)
		if (nowhere.len)
			R.warning("[nowhere.len] stairs or ladder\s on the [house_plan_storey_name(s)] [house_plan_verb(nowhere.len, "comes", "come")] up beside no floor. Roof a tile north, south, east or west of [house_plan_verb(nowhere.len, "it", "them")], so there is a floor to step onto.", nowhere, "U", s)
	for (var/s = 2, s <= top, s++)
		var/list/reached = D.reached(s)
		var/list/cut_off = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (D.has_roof(s - 1, x, y) && D.passable(s, x, y) && !reached[(y - 1) * HOUSE_PLAN_SIDE + x])
					cut_off += "[x],[y]"
		if (!cut_off.len)
			continue
		var/list/ways = D.ways_up(s - 1)
		if (!ways.len)
			R.warning("Nothing leads up to the [house_plan_storey_name(s)]. Put stairs or a ladder on the [house_plan_storey_name(s - 1)] and leave the tile above them open; without them the only way up is to climb a wall.", null, "U", s - 1)
		else
			R.warning("[cut_off.len] tile\s of the [house_plan_storey_name(s)] cannot be walked to from its stairs or ladder: a wall is in the way, or the way up below cannot itself be reached. Draw a door in the wall or another way up.", cut_off, "D", s)

// A way in on the ground floor.
/datum/design_check/house_plan/doors
	order = 50

/datum/design_check/house_plan/doors/plan_check(datum/house_plan/D, datum/design_report/R, top)
	if (!top)
		return
	var/list/reached = D.reached(1)
	var/list/shut_in = list()
	for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
		for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
			if (D.cell(1, x, y) && D.passable(1, x, y) && !reached[(y - 1) * HOUSE_PLAN_SIDE + x])
				shut_in += "[x],[y]"
	if (shut_in.len)
		R.warning("[shut_in.len] tile\s of the ground floor [house_plan_verb(shut_in.len, "is", "are")] walled in with no way in. Draw a door in the wall.", shut_in, "D", 1)

// Rain, cold and warmth.
/datum/design_check/house_plan/weather
	order = 60

/datum/design_check/house_plan/weather/plan_check(datum/house_plan/D, datum/design_report/R, top)
	if (!top)
		return
	var/roofed = FALSE
	for (var/s = 1, s <= top, s++)
		var/list/outside = D.outside(s, TRUE)
		var/list/open_sky = list()
		var/list/draughty = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (D.has_roof(s, x, y))
					roofed = TRUE
				if (!D.is_floor(s, x, y) || !D.passable(s, x, y))
					continue
				if (outside[(y - 1) * HOUSE_PLAN_SIDE + x])
					if (D.has_roof(s, x, y))
						draughty += "[x],[y]"
					continue
				var/covered = FALSE
				for (var/above = s, above <= top, above++)
					if (D.has_roof(above, x, y))
						covered = TRUE
						break
				if (!covered)
					open_sky += "[x],[y]"
		if (open_sky.len)
			R.warning("[open_sky.len] tile\s inside the walls of the [house_plan_storey_name(s)] [house_plan_verb(open_sky.len, "has", "have")] no roof over [house_plan_verb(open_sky.len, "it", "them")] on any storey: rain, snow and cold come straight in. Roof [house_plan_verb(open_sky.len, "it", "them")], on the top storey if stairs come up below.", open_sky, null, s)
		if (draughty.len)
			R.note("[draughty.len] roofed tile\s of the [house_plan_storey_name(s)] [house_plan_verb(draughty.len, "is", "are")] not closed in by walls, windows and doors. That suits a porch or a shed, but a room keeps its warmth only when it is closed all the way round.", draughty, null, s)
	if (!roofed)
		R.warning("The plan has no roof, so it gives no shelter. Pick a roofing and draw it over every tile, the tiles the walls stand on included.")

// Advice worth having before the first wall goes up.
/datum/design_check/house_plan/advice
	order = 70

/datum/design_check/house_plan/advice/plan_check(datum/house_plan/D, datum/design_report/R, top)
	if (top == 2)
		var/list/soft = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				var/list/P = D.piece_info(1, x, y)
				if (P && P["tier"] > 2 && !D.founded_at(x, y))
					soft += "[x],[y]"
		if (soft.len)
			R.note("[soft.len] ground-floor wall\s or pillar\s could carry more than two storeys but [house_plan_verb(soft.len, "stands", "stand")] on soft ground, which carries only two. If the house may ever get a third storey, draw a stone or concrete floor under [house_plan_verb(soft.len, "it", "them")] now: a foundation cannot be added under a standing wall.", soft, "floor_s", 1)
	for (var/s = 2, s <= top, s++)
		var/list/edges = list()
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!D.has_roof(s - 1, x, y) || !D.passable(s, x, y))
					continue
				for (var/list/step in list(list(0, -1), list(0, 1), list(-1, 0), list(1, 0)))
					var/nx = x + step[1]
					var/ny = y + step[2]
					if (!D.has_roof(s - 1, nx, ny) && !D.way_up(s - 1, nx, ny))
						edges += "[x],[y]"
						break
		if (edges.len)
			R.note("[edges.len] tile\s of the [house_plan_storey_name(s)] [house_plan_verb(edges.len, "lies", "lie")] at an open edge with a drop beside [house_plan_verb(edges.len, "it", "them")]. Walking off is a hard fall: put a wall or a railing along the edge.", edges, null, s)

// ---- What each part is ----

/datum/design_part_book/house_plan
	kind = "house_plan"

/datum/design_part_book/house_plan/entries()
	return list(
		"T" = list("what" = "A timber wall: a log, plank, bamboo, straw or earth wall.", "use" = "Holds the roof on its own tile and every tile touching it, and carries two storeys.", "how" = "A log wall takes 4 logs; other timber walls cost what their own recipes say. Draw it along the outline of a room."),
		"S" = list("what" = "A stone wall: stone, brick, clay, sandstone or marble.", "use" = "Holds the roof on its own tile and every tile touching it, and carries four storeys.", "how" = "A stone wall takes 8 stone. For a third storey it must stand on rock or on a stone or concrete floor laid first."),
		"C" = list("what" = "A concrete wall, built from cement bricks.", "use" = "Holds the roof on its own tile and every tile touching it, and carries six storeys.", "how" = "2 fired cement bricks. Every storey under it must be concrete too, on a stone or concrete floor."),
		"D" = list("what" = "A door.", "use" = "The way in and out. It holds the roof over its own tile only, and carries two storeys.", "how" = "A wooden door takes 5 wood. Draw it in a wall, with a wall or window each side to hold the roof beside it."),
		"N" = list("what" = "A timber window: a window frame, glazed or not.", "use" = "Stands in a wall and holds the roof like the wall beside it: one tile, two storeys.", "how" = "5 wood. Glass can be fitted later."),
		"M" = list("what" = "A stone window frame.", "use" = "Stands in a stone wall and holds the roof like it: one tile, four storeys.", "how" = "5 stone. Glass can be fitted later."),
		"R" = list("what" = "A wooden roof support: a thick upright beam.", "use" = "Holds the roof up to 3 tiles away, and carries two storeys. The cheapest way to roof a wide room.", "how" = "2 wood. It is solid: leave room to walk round it."),
		"P" = list("what" = "A stone pillar.", "use" = "Holds the roof up to 2 tiles away, and carries four storeys.", "how" = "2 stone. From the second storey up a lone pillar holds only the tiles beside it; further tiles need a second support on another side."),
		"Q" = list("what" = "A concrete pillar.", "use" = "Holds the roof up to 2 tiles away, and carries six storeys.", "how" = "2 concrete blocks from a cement mixer."),
		"U" = list("what" = "Stairs to the storey above.", "use" = "People, animals, crates and loose items go up and down them.", "how" = "2 wood or 2 stone. Leave the tile above them open, with a roofed tile beside it to step onto, and roof over the opening on the top storey."),
		"H" = list("what" = "A wooden ladder to the storey above.", "use" = "A way up that takes one tile. Needs both hands, so crates and furniture cannot follow.", "how" = "4 wood. Leave the tile above it open, with a roofed tile beside it to step onto."),
		"floor_w" = list("what" = "A wood floor.", "use" = "A clean floor to live on. It is not a foundation: walls on it carry two storeys.", "how" = "1 wood a tile. Upstairs it is laid over the plain upper floor."),
		"floor_s" = list("what" = "A stone floor: cobblestone, brick, slate, marble or sandstone.", "use" = "On the ground it is a foundation: walls and pillars built on it carry as many storeys as their material allows.", "how" = "1 stone a tile, laid before the wall that stands on it."),
		"floor_c" = list("what" = "A concrete floor.", "use" = "A foundation, like a stone floor, for a concrete building.", "how" = "1 concrete block a tile, laid before the wall that stands on it."),
		"roof_t" = list("what" = "Thatch roofing.", "use" = "Shelter from rain, snow and sun, and the floor of the storey above.", "how" = "2 leaves a tile. Draw it over every tile of the storey, wall tiles included."),
		"roof_w" = list("what" = "Wood roofing.", "use" = "Shelter from rain, snow and sun, and the floor of the storey above.", "how" = "1 wood a tile. Draw it over every tile of the storey, wall tiles included."),
		"roof_c" = list("what" = "Clay tile roofing.", "use" = "Shelter from rain, snow and sun, and the floor of the storey above.", "how" = "Half a clay a tile, fired in a kiln. Draw it over every tile of the storey, wall tiles included."),
		"roof_k" = list("what" = "Concrete roofing.", "use" = "Shelter that does not burn, and the floor of the storey above.", "how" = "1 concrete block a tile."),
		"roof_g" = list("what" = "Glass roofing.", "use" = "A roof that lets the light through.", "how" = "1 glass a tile."),
		"x" = list("what" = "The eraser.", "use" = "Clears everything on a tile of this storey.", "how" = "Click or drag over tiles. A right-click with any other tool clears only what that tool draws: the piece, the floor or the roof. Undo brings it back."),
		"note" = list("what" = "A note pinned to a tile.", "use" = "A reminder for yourself or whoever builds from the plan: where the hearth goes, whose room it is.", "how" = "Click a tile and type up to 80 characters. Save an empty note to take it off. A plan holds 12 notes."),
	)
