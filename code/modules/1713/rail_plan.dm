// ============================================================
// Rail plans (docs/trains.md "Rail plans")
// ------------------------------------------------------------
// A ship's draught can carry a railway: track drawn tile by tile on a grid of
// RAIL_PLAN_SIDE tiles each way, north to the top of the sheet. A tile is
// track or not; its shape follows from the track beside it, as rails laid on
// the ground do (track_laying.dm): straight between two tiles in line, a
// sharp corner between two at a right angle. A corner can be marked to be
// eased into a wide curve of radius 4 or 8 (train_arcs.dm).
//
// The plan builds nothing. It judges the drawing by the rules a platelayer
// meets on the ground: bends too close together will not be spiked down,
// a corner is eased only with that many straight tiles on each side and room
// for the curve. It can be pegged out on the ground as builders' pegs
// (build_markers.dm), one per tile of track.
//
// A plan travels as a design code (design_codes.dm):
//   C13RAIL/1/<name>/<x,y,count>;.../<x,y,radius>;...
// Each run is count tiles of track eastwards from x,y; each curve names the
// corner it eases.
// ============================================================

#define RAIL_PLAN_NAME_MAX 40
#define RAIL_PEG_TIME_BASE 30
#define RAIL_PEG_TIME_TILE 1
#define RAIL_PEG_TIME_MAX 150

/proc/rail_plan_key(x, y)
	return "[x],[y]"

/datum/rail_plan
	var/name = "railway"
	var/list/track = list() // "x,y" -> TRUE
	var/list/curves = list() // "x,y" of a corner -> radius

/datum/rail_plan/proc/in_grid(x, y)
	return x >= 1 && y >= 1 && x <= RAIL_PLAN_SIDE && y <= RAIL_PLAN_SIDE

/datum/rail_plan/proc/has(x, y)
	return track[rail_plan_key(x, y)] ? TRUE : FALSE

// Lays or lifts track on a tile; lifting a corner forgets its curve.
/datum/rail_plan/proc/set_track(x, y, on)
	if (!in_grid(x, y))
		return FALSE
	var/key = rail_plan_key(x, y)
	if (on)
		track[key] = TRUE
	else
		track -= key
		curves -= key
	return TRUE

// Marks a corner to be eased to radius R (0 for a sharp corner).
/datum/rail_plan/proc/set_curve(x, y, R)
	var/key = rail_plan_key(x, y)
	if (!R)
		curves -= key
		return TRUE
	if (!has(x, y) || !(R in train_arc_radii()))
		return FALSE
	curves[key] = R
	return TRUE

/datum/rail_plan/proc/curve_at(x, y)
	return curves[rail_plan_key(x, y)] || 0

/datum/rail_plan/proc/tile_count()
	return track.len

// The tile one step from x,y the given way (north is up the sheet).
/proc/rail_plan_step(x, y, d)
	return list(x + train_arc_dx(d), y - train_arc_dy(d))

// The ways from a tile to the track beside it.
/datum/rail_plan/proc/links(x, y)
	. = list()
	for (var/d in cardinal)
		var/list/n = rail_plan_step(x, y, d)
		if (has(n[1], n[2]))
			. += d

// TRUE when the track on a tile turns a right angle.
/datum/rail_plan/proc/is_corner(x, y)
	if (!has(x, y))
		return FALSE
	var/list/L = links(x, y)
	return L.len == 2 && L[1] != OPPOSITE_DIR(L[2])

// The box round everything drawn: list(west, north, east, south), or null.
/datum/rail_plan/proc/extent()
	if (!track.len)
		return null
	. = list(RAIL_PLAN_SIDE, RAIL_PLAN_SIDE, 1, 1)
	for (var/key in track)
		var/list/p = splittext(key, ",")
		var/x = text2num(p[1])
		var/y = text2num(p[2])
		.[1] = min(.[1], x)
		.[2] = min(.[2], y)
		.[3] = max(.[3], x)
		.[4] = max(.[4], y)

// ---- Curves ----

// The tiles a corner eased to radius R lies on, as "x,y" keys in order, or
// null when it runs off the sheet. The corner's legs are its two links.
/datum/rail_plan/proc/curve_tiles(x, y, R)
	var/list/L = links(x, y)
	if (L.len != 2)
		return null
	var/h1 = OPPOSITE_DIR(L[1]) // heading into the corner along its first leg
	var/b = L[2]
	var/sx = x - R * train_arc_dx(h1)
	var/sy = y + R * train_arc_dy(h1)
	. = list()
	for (var/list/at in train_arc_path(R))
		var/px = sx + at[1] * train_arc_dx(b) + at[2] * train_arc_dx(h1)
		var/py = sy - (at[1] * train_arc_dy(b) + at[2] * train_arc_dy(h1))
		if (!in_grid(px, py))
			return null
		. += rail_plan_key(px, py)

// The straight tiles a curve of radius R at a corner takes up: R each way.
/datum/rail_plan/proc/curve_legs(x, y, R)
	. = list()
	for (var/d in links(x, y))
		for (var/k in 1 to R)
			. += rail_plan_key(x + k * train_arc_dx(d), y - k * train_arc_dy(d))

// Why the corner at x,y cannot be eased as marked, or null.
/datum/rail_plan/proc/curve_problem(x, y)
	var/R = curve_at(x, y)
	if (!R)
		return null
	if (!is_corner(x, y))
		return "Only a sharp corner can be eased into a curve; this tile is not one."
	var/list/legs = curve_legs(x, y, R)
	for (var/key in legs)
		var/list/p = splittext(key, ",")
		var/lx = text2num(p[1])
		var/ly = text2num(p[2])
		if (!has(lx, ly) || is_corner(lx, ly) || length(links(lx, ly)) > 2 || curve_at(lx, ly))
			return "A curve of radius [R] needs [R] tiles of plain straight track on each side of its corner."
	var/list/tiles = curve_tiles(x, y, R)
	if (!tiles)
		return "A curve of radius [R] here would run off the sheet."
	for (var/key in tiles)
		if (track[key] && !(key in legs))
			return "Other track is in the way of this curve."
	return null

// The tiles of track the plan has once its curves are eased: "x,y" -> TRUE.
/datum/rail_plan/proc/finished_tiles()
	. = track.Copy()
	for (var/key in curves)
		var/list/p = splittext(key, ",")
		var/x = text2num(p[1])
		var/y = text2num(p[2])
		if (curve_problem(x, y))
			continue
		var/R = curves[key]
		. -= key
		for (var/leg in curve_legs(x, y, R))
			. -= leg
		for (var/tile in curve_tiles(x, y, R))
			.[tile] = TRUE

// ---- Bends ----

// How far along the line from the sharp corner at x,y the next sharp corner
// lies, up to reach tiles: the smaller of its two ways, or 0 when none.
/datum/rail_plan/proc/bend_gap(x, y, reach = TRAIN_LONG_CAR_LENGTH)
	. = 0
	for (var/d in links(x, y))
		var/cx = x
		var/cy = y
		var/way = d
		for (var/i in 1 to reach)
			cx += train_arc_dx(way)
			cy -= train_arc_dy(way)
			if (!has(cx, cy))
				break
			if (is_corner(cx, cy))
				if (!curve_at(cx, cy))
					. = . ? min(., i) : i
				break
			var/list/L = links(cx, cy)
			if (L.len != 2)
				break
			way = (L[1] == OPPOSITE_DIR(way)) ? L[2] : L[1]

// ---- Checks ----

/datum/rail_plan/proc/check_design()
	return design_report("rail_plan", src)

/datum/design_check/rail_plan
	kind = "rail_plan"
	abstract_type = /datum/design_check/rail_plan

/datum/design_check/rail_plan/check(datum/rail_plan/D, datum/design_report/R)
	if (istype(D))
		plan_check(D, R)

/datum/design_check/rail_plan/proc/plan_check(datum/rail_plan/D, datum/design_report/R)
	return

/datum/design_check/rail_plan/blank
	order = 10

/datum/design_check/rail_plan/blank/plan_check(datum/rail_plan/D, datum/design_report/R)
	if (!D.tile_count())
		R.error("Nothing is drawn yet. Draw the line of the track tile by tile; where it turns a right angle it makes a corner.")

// Laying refuses to spike down a bend this close to the next (train_bends.dm).
/datum/design_check/rail_plan/bends
	order = 20

/datum/design_check/rail_plan/bends/plan_check(datum/rail_plan/D, datum/design_report/R)
	var/list/close = list()
	var/list/tight = list()
	for (var/key in D.track)
		var/list/p = splittext(key, ",")
		var/x = text2num(p[1])
		var/y = text2num(p[2])
		if (!D.is_corner(x, y) || D.curve_at(x, y))
			continue
		var/gap = D.bend_gap(x, y)
		if (!gap)
			continue
		if (gap < TRAIN_CAR_LENGTH)
			close += key
		else if (gap < TRAIN_LONG_CAR_LENGTH)
			tight += key
	if (close.len)
		R.error("[close.len] corner\s [close.len == 1 ? "is" : "are"] fewer than [TRAIN_CAR_LENGTH] tiles from the next corner. The rails will not be spiked down there: a railway car would fold onto itself.", close)
	if (tight.len)
		R.warning("[tight.len] corner\s [tight.len == 1 ? "is" : "are"] fewer than [TRAIN_LONG_CAR_LENGTH] tiles from the next corner. Four-wheel cars take them, but long bogie cars and main-line engines need [TRAIN_LONG_CAR_LENGTH].", tight)

/datum/design_check/rail_plan/curves
	order = 30

/datum/design_check/rail_plan/curves/plan_check(datum/rail_plan/D, datum/design_report/R)
	for (var/key in D.curves)
		var/list/p = splittext(key, ",")
		var/problem = D.curve_problem(text2num(p[1]), text2num(p[2]))
		if (problem)
			R.error(problem, list(key))

// The planner draws plain track; where lines meet, a switch is laid by hand.
/datum/design_check/rail_plan/junctions
	order = 40

/datum/design_check/rail_plan/junctions/plan_check(datum/rail_plan/D, datum/design_report/R)
	var/list/meets = list()
	for (var/key in D.track)
		var/list/p = splittext(key, ",")
		if (length(D.links(text2num(p[1]), text2num(p[2]))) > 2)
			meets += key
	if (meets.len)
		R.warning("Track meets more than two ways on [meets.len] tile\s. Lay a switch there by hand: the plan only shows plain track.", meets)

/datum/design_check/rail_plan/sharp
	order = 50

/datum/design_check/rail_plan/sharp/plan_check(datum/rail_plan/D, datum/design_report/R)
	var/list/sharp = list()
	for (var/key in D.track)
		var/list/p = splittext(key, ",")
		var/x = text2num(p[1])
		var/y = text2num(p[2])
		if (D.is_corner(x, y) && !D.curve_at(x, y))
			sharp += key
	if (sharp.len)
		R.note("[sharp.len] sharp corner\s: trains take them at up to 3 tiles a second. Eased to a wide curve they take radius 4 at [train_arc_speed(4)] and radius 8 at [train_arc_speed(8)].", sharp)

// ---- Text ----

/datum/rail_plan/proc/summary_text()
	if (!tile_count())
		return "<b>[name]</b>: a rail plan with nothing drawn on it yet."
	var/list/box = extent()
	var/list/lines = list()
	var/list/done = finished_tiles()
	lines += "<b>[name]</b>: a rail plan of [tile_count()] tile\s of track, [box[3] - box[1] + 1] by [box[4] - box[2] + 1] tiles, north to the top of the sheet."
	if (curves.len)
		lines += "[curves.len] corner\s [curves.len == 1 ? "is" : "are"] to be eased into wide curves; laid and eased, the line is [done.len] tile\s long."
	lines += "Each tile takes a stack of railway sleepers and a rail length: about [tile_count()] of each."
	var/datum/design_report/R = check_design()
	lines += R.blocked() ? "<span class='warning'>It cannot be laid as drawn:</span>" : "As drawn it can be laid."
	lines += R.chat_lines()
	qdel(R)
	return jointext(lines, "<br>")

// ---- Codes ----

/proc/rail_plan_clean_name(text)
	if (!istext(text))
		return "railway"
	text = replacetext(replacetext(replacetext(text, "/", " "), ";", " "), ",", " ")
	text = trim(sanitize(copytext(text, 1, RAIL_PLAN_NAME_MAX + 1)))
	return length(text) ? text : "railway"

/datum/rail_plan/proc/to_code()
	var/list/runs = list()
	for (var/y in 1 to RAIL_PLAN_SIDE)
		var/x = 1
		while (x <= RAIL_PLAN_SIDE)
			if (!has(x, y))
				x++
				continue
			var/n = 1
			while (x + n <= RAIL_PLAN_SIDE && has(x + n, y))
				n++
			runs += "[x],[y],[n]"
			x += n
	var/list/bent = list()
	for (var/key in curves)
		bent += "[key],[curves[key]]"
	return "C13RAIL/1/[replacetext(name, " ", "_")]/[jointext(runs, ";")]/[jointext(bent, ";")]"

// The plan a code describes, or null when it is not a working rail plan code.
// The designer window saves through this too, so a pasted plan is held to the
// same rules as one drawn by hand.
/proc/rail_plan_from_code(code)
	var/list/F = design_code_fields(code, "RAIL", DESIGN_CODE_RAIL_MAX)
	if (!F || F.len != 3)
		return null
	var/datum/rail_plan/D = new
	D.name = rail_plan_clean_name(replacetext(F[1], "_", " "))
	for (var/run in (length(F[2]) ? splittext(F[2], ";") : list()))
		var/list/T = splittext(run, ",")
		var/x = T.len == 3 ? text2num(T[1]) : null
		var/y = T.len == 3 ? text2num(T[2]) : null
		var/n = T.len == 3 ? text2num(T[3]) : null
		if (!isnum(x) || !isnum(y) || !isnum(n) || n < 1 || !D.in_grid(x, y) || !D.in_grid(x + n - 1, y))
			qdel(D)
			return null
		for (var/i in 0 to n - 1)
			D.set_track(x + i, y, TRUE)
	for (var/bend in (length(F[3]) ? splittext(F[3], ";") : list()))
		var/list/T = splittext(bend, ",")
		if (T.len != 3 || !D.set_curve(text2num(T[1]), text2num(T[2]), text2num(T[3])))
			qdel(D)
			return null
	return D

// ---- The sheet ----

/obj/item/ship_draught/proc/rail_plan()
	return draught_code && design_code_kind(draught_code) == "RAIL" ? rail_plan_from_code(draught_code) : null

/obj/item/ship_draught/proc/take_rail(datum/rail_plan/D)
	draught_code = D ? D.to_code() : ""
	name = D ? "rail plan ([D.name])" : initial(name)

/obj/item/ship_draught/proc/rail_sheet_menu(mob/living/human/H, datum/rail_plan/D)
	var/pegged = peg_z && length(peg_set)
	var/list/options = list("Draw on the sheet", "Peg it out on the ground")
	if (pegged)
		options += "Pull up the pegs and forget the site"
	options += list(DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel")
	var/text = D.summary_text()
	if (pegged)
		text += "<br>[rail_pegs_text()]"
	var/choice = WWinput(H, text, name, "Cancel", options)
	if (QDELETED(src) || loc != H)
		return
	if (choice == "Draw on the sheet")
		open_rail_designer(H)
	else if (choice == "Peg it out on the ground")
		var/datum/rail_plan/now = rail_plan()
		if (now)
			rail_peg_menu(H, now)
			qdel(now)
	else if (choice == "Pull up the pegs and forget the site")
		house_pegs_forget(H)
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		draught_import(H)

// ---- Pegging it out ----

// Pegs plan D out with tile 0,0 of the sheet at origin_x, origin_y on level
// z: one peg asking for track on every tile of the line as laid before its
// corners are eased, and a note on each corner to be eased. Returns
// list("pegs", "blocked", "full"), or null when it does not fit on the map.
/proc/rail_plan_peg_out(datum/rail_plan/D, origin_x, origin_y, z, set_id)
	var/list/box = D.extent()
	if (!box || z < 1 || z > world.maxz)
		return null
	if (origin_x + box[1] < 1 || origin_x + box[3] > world.maxx || origin_y - box[4] < 1 || origin_y - box[2] > world.maxy)
		return null
	build_markers_pull(set_id, z)
	var/list/result = list("pegs" = 0, "blocked" = 0, "full" = FALSE)
	for (var/key in D.track)
		var/list/p = splittext(key, ",")
		var/x = text2num(p[1])
		var/y = text2num(p[2])
		var/R = D.curve_at(x, y)
		var/note = R ? "Lay this corner sharp with [R] straight tiles each side, then ease it into a curve of radius [R] with a hammer." : null
		var/turf/T = locate(origin_x + x, origin_y - y, z)
		if (!T)
			continue
		var/before = length(build_marker_registry())
		var/obj/effect/build_marker/M = build_marker_place(T, list("rail=track"), set_id, D.name, note)
		if (!M)
			if (before >= BUILD_MARKER_WORLD_MAX)
				result["full"] = TRUE
			continue
		result["pegs"]++
		if (T.density || istype(T, /turf/floor/beach/water))
			result["blocked"]++
	return result

/obj/item/ship_draught/proc/rail_pegs_text()
	if (!peg_z || !length(peg_set))
		return ""
	var/pegs = length(build_markers_of(peg_set))
	if (!pegs)
		return "It is pegged out, and every tile of its track is laid."
	return "It is pegged out: [pegs] peg\s still stand along the line."

/obj/item/ship_draught/proc/rail_peg_menu(mob/living/human/H, datum/rail_plan/D)
	var/turf/here = get_turf(H)
	if (!here || loc != H)
		return
	var/list/box = D.extent()
	if (!box)
		to_chat(H, SPAN_WARNING("Nothing is drawn on the sheet to peg out."))
		return
	var/datum/design_report/R = D.check_design()
	var/blocked = R.blocked()
	qdel(R)
	var/question = "Peg out [D.name] here? The south-west corner of the drawing goes on the tile you stand on, and the plan runs [box[3] - box[1] + 1] tile\s east and [box[4] - box[2] + 1] north of it. Any pegs it already has are pulled first."
	if (blocked)
		question += " The plan cannot be laid as drawn: examine the sheet for what is wrong."
	if (WWinput(H, question, name, "Cancel", list("Peg it out", "Cancel")) != "Peg it out")
		return
	if (QDELETED(src) || QDELETED(H) || loc != H || get_turf(H) != here)
		return
	H.visible_message(SPAN_NOTICE("[H] starts pegging a railway out on the ground."), SPAN_NOTICE("You start pegging the line out."))
	if (!do_after(H, min(RAIL_PEG_TIME_MAX, RAIL_PEG_TIME_BASE + D.tile_count() * RAIL_PEG_TIME_TILE), src) || QDELETED(src) || loc != H || get_turf(H) != here)
		return
	if (length(peg_set))
		build_markers_pull(peg_set)
	var/origin_x = here.x - box[1]
	var/origin_y = here.y + box[4]
	var/set_id = "rail-[H.ckey]-[world.realtime]-[rand(1000, 9999)]"
	var/list/result = rail_plan_peg_out(D, origin_x, origin_y, here.z, set_id)
	if (!result)
		to_chat(H, SPAN_WARNING("The plan does not fit here: it would run off the edge of the land."))
		return
	if (!result["pegs"])
		to_chat(H, SPAN_WARNING(result["full"] ? "There are too many pegs in the ground already." : "Every tile of this line is laid here already."))
		return
	peg_set = set_id
	peg_x = origin_x
	peg_y = origin_y
	peg_z = here.z
	var/list/lines = list("You peg out [D.name]: [result["pegs"]] peg\s, one on each tile of track to lay.")
	if (D.curves.len)
		lines += "The pegs on corners to be eased carry a note saying how wide a curve to make."
	if (result["blocked"])
		lines += SPAN_WARNING("[result["blocked"]] peg\s stand on rock or water.")
	if (result["full"])
		lines += SPAN_WARNING("There are too many pegs in the ground already: some tiles got none.")
	to_chat(H, jointext(lines, "<br>"))

#undef RAIL_PLAN_NAME_MAX
#undef RAIL_PEG_TIME_BASE
#undef RAIL_PEG_TIME_TILE
#undef RAIL_PEG_TIME_MAX
