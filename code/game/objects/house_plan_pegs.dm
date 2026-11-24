// ============================================================
// Pegging a house plan out (docs/house-plans.md, docs/build-markers.md)
// ------------------------------------------------------------
// A house plan is marked out on the ground a storey at a time as builders'
// pegs (build_markers.dm). The first marking-out fixes the site: the tile the
// builder stands on takes the south-west corner of the drawing, north on the
// sheet is north on the ground. The sheet remembers the site, so a later
// storey lands over the first: the builder stands on that storey and pegs
// again. Only tiles with a floor to stand on take a peg, and a peg asks only
// for what is not built yet, so pegging a storey again after building some of
// it (or after redrawing it) is safe.
// ============================================================

#define HOUSE_PEG_TIME_BASE 30
#define HOUSE_PEG_TIME_TILE 1
#define HOUSE_PEG_TIME_MAX 150
// How far from the site a builder may stand and still peg one of its storeys.
#define HOUSE_PEG_REACH (HOUSE_PLAN_SIDE + 5)

/obj/item/ship_draught
	// Saved: the site a house plan is pegged out on. peg_x and peg_y are where
	// tile 0,0 of the sheet would fall (tile x,y is at peg_x + x, peg_y - y);
	// peg_z is the ground floor's level.
	var/peg_set = ""
	var/peg_x = 0
	var/peg_y = 0
	var/peg_z = 0

// What a tile asks a builder for, as build marker wants: the piece first
// (the tag shows it), then the floor, then the roof.
/datum/house_plan/proc/tile_wants(s, x, y)
	. = list()
	var/key = piece_key(s, x, y)
	if (key)
		var/list/row = house_plan_pieces()[key]
		. += "[row["kind"]]=[row["name"]]"
	key = floor_key(s, x, y)
	if (key)
		. += "floor=[house_plan_floors()[key]["name"]]"
	key = roof_key(s, x, y)
	if (key)
		. += "roof=[house_plan_roofs()[key]["name"]]"

// The level storey s of a house whose ground floor is on ground_z stands on,
// or 0 when no such level has been built yet.
/proc/house_peg_level(ground_z, s)
	. = ground_z
	for (var/i = 2, i <= s && . > 0, i++)
		. = building_upper_z(.)
	if (. > world.maxz)
		. = 0

// The storey of the sheet's site that level z is, or 0.
/obj/item/ship_draught/proc/house_peg_storey(z)
	if (!peg_z)
		return 0
	for (var/s = 1, s <= HOUSE_PLAN_STOREYS, s++)
		var/level = house_peg_level(peg_z, s)
		if (!level)
			return 0
		if (level == z)
			return s
	return 0

// Pegs storey s of plan D out with tile 0,0 of the sheet at origin_x,
// origin_y on level z. Returns list("pegs", "skipped" (tiles with no floor
// under them yet), "blocked" (tiles on rock or water), "full" (the world
// holds its fill of pegs)), or null when the storey does not fit on the map.
/proc/house_plan_peg_out(datum/house_plan/D, s, origin_x, origin_y, z, set_id)
	var/list/box = D.extent()
	if (!box || z < 1 || z > world.maxz)
		return null
	if (origin_x + box[1] < 1 || origin_x + box[3] > world.maxx || origin_y - box[4] < 1 || origin_y - box[2] > world.maxy)
		return null
	build_markers_pull(set_id, z)
	var/list/result = list("pegs" = 0, "skipped" = 0, "blocked" = 0, "full" = FALSE)
	for (var/y = box[2], y <= box[4], y++)
		for (var/x = box[1], x <= box[3], x++)
			var/list/wants = D.tile_wants(s, x, y)
			var/note = D.note_at(s, x, y)
			if (!wants.len && !note)
				continue
			var/turf/T = locate(origin_x + x, origin_y - y, z)
			if (!build_marker_ground(T))
				result["skipped"]++
				continue
			var/before = length(build_marker_registry())
			var/obj/effect/build_marker/M = build_marker_place(T, wants, set_id, D.name, note)
			if (!M)
				if (before >= BUILD_MARKER_WORLD_MAX)
					result["full"] = TRUE
				continue
			result["pegs"]++
			if (T.density || istype(T, /turf/floor/beach/water))
				result["blocked"]++
	return result

// What the sheet's pegs still ask for, as a line for the sheet's menu.
/obj/item/ship_draught/proc/house_pegs_text()
	if (!peg_z || !length(peg_set))
		return ""
	var/list/left = build_markers_left(peg_set)
	if (!left.len)
		return "It is pegged out, and nothing its pegs ask for is left to build. Peg out the next storey from its floor."
	var/list/parts = list()
	var/pegs = length(build_markers_of(peg_set))
	for (var/label in left)
		parts += house_plan_count_text(left[label], label)
	return "It is pegged out: [pegs] peg\s still ask for [english_list(parts)]."

/obj/item/ship_draught/proc/house_peg_menu(mob/living/human/H, datum/house_plan/D)
	var/turf/here = get_turf(H)
	if (!here || loc != H)
		return
	if (!D.top_storey())
		to_chat(H, "<span class='warning'>Nothing is drawn on the sheet to peg out.</span>")
		return
	var/s = 1
	var/fresh = !peg_z || !length(peg_set)
	if (!fresh)
		s = house_peg_storey(here.z)
		if (!s || abs(here.x - peg_x) > HOUSE_PEG_REACH * 2 || abs(here.y - peg_y) > HOUSE_PEG_REACH * 2)
			to_chat(H, "<span class='warning'>This plan is pegged out somewhere else. Stand on a storey of that building to peg it, or forget the site first.</span>")
			return
		if (s > D.top_storey())
			to_chat(H, "<span class='warning'>The plan has nothing drawn on the [house_plan_storey_name(s)].</span>")
			return
	var/list/box = D.extent()
	var/datum/design_report/R = D.check_design()
	var/blocked = R.blocked()
	qdel(R)
	var/question
	if (fresh)
		question = "Peg out the ground floor of [D.name] here? The south-west corner of the drawing goes on the tile you stand on, and the plan runs [box[3] - box[1] + 1] tile\s east and [box[4] - box[2] + 1] north of it."
	else
		question = "Peg out the [house_plan_storey_name(s)] of [D.name] again? Its old pegs on this level are pulled first."
	if (blocked)
		question += " The plan cannot be built as drawn: examine the sheet for what is wrong."
	if (WWinput(H, question, name, "Cancel", list("Peg it out", "Cancel")) != "Peg it out")
		return
	if (QDELETED(src) || QDELETED(H) || loc != H || get_turf(H) != here)
		return
	var/tiles = (box[3] - box[1] + 1) * (box[4] - box[2] + 1)
	H.visible_message("<span class='notice'>[H] starts pegging a plan out on the ground.</span>", "<span class='notice'>You start pegging the plan out.</span>")
	if (!do_after(H, min(HOUSE_PEG_TIME_MAX, HOUSE_PEG_TIME_BASE + tiles * HOUSE_PEG_TIME_TILE), src) || QDELETED(src) || loc != H || get_turf(H) != here)
		return
	var/origin_x = fresh ? here.x - box[1] : peg_x
	var/origin_y = fresh ? here.y + box[4] : peg_y

	if ((practice_room_z && here.z == practice_room_z && s != 1) || !tutorial_workshop_footprint(H, origin_x + box[1], origin_y - box[4], origin_x + box[3], origin_y - box[2], here.z))
		to_chat(H, SPAN_WARNING("Keep the plan inside your practice workshop on this level."))
		return
	var/set_id = fresh ? "house-[H.ckey]-[world.realtime]-[rand(1000, 9999)]" : peg_set
	var/list/result = house_plan_peg_out(D, s, origin_x, origin_y, here.z, set_id)
	if (!result)
		to_chat(H, "<span class='warning'>The plan does not fit here: it would run off the edge of the land.</span>")
		return
	if (fresh)
		if (!result["pegs"])
			to_chat(H, "<span class='warning'>[result["full"] ? "There are too many pegs in the ground already." : "Nothing of the ground floor is left to build here."]</span>")
			return
		peg_set = set_id
		peg_x = origin_x
		peg_y = origin_y
		peg_z = here.z
	var/list/lines = list("You peg out the [house_plan_storey_name(s)] of [D.name]: [result["pegs"]] peg\s, each tagged with what to build on its tile.")
	if (result["skipped"])
		lines += "[result["skipped"]] tile\s have no floor under them yet. Peg this storey again when the roof below is laid."
	if (result["blocked"])
		lines += "<span class='warning'>[result["blocked"]] peg\s stand on rock or water.</span>"
	if (result["full"])
		lines += "<span class='warning'>There are too many pegs in the ground already: some tiles got none.</span>"
	if (s < D.top_storey())
		lines += "For the next storey, stand on its floor and peg the plan out again."
	to_chat(H, jointext(lines, "<br>"))

/obj/item/ship_draught/proc/house_pegs_forget(mob/living/human/H)
	var/n = build_markers_pull(peg_set)
	peg_set = ""
	peg_x = 0
	peg_y = 0
	peg_z = 0
	to_chat(H, "<span class='notice'>You strike the site off the sheet[n ? " and its [n] peg\s come up" : ""]. The plan can be pegged out afresh anywhere.</span>")

#undef HOUSE_PEG_TIME_BASE
#undef HOUSE_PEG_TIME_TILE
#undef HOUSE_PEG_TIME_MAX
#undef HOUSE_PEG_REACH
