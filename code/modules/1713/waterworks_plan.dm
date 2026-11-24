// A single ordered, same-level water route on a ship's draught. The sheet
// records an intended route, not a new network or permission to craft it.
#define WATERWORKS_SIDE 7
#define WATERWORKS_LIMIT 24

/proc/waterworks_parts()
	var/static/list/parts = list(
		"I" = list("mode" = "A", "role" = "start", "type" = /obj/structure/aqueduct_intake, "name" = "aqueduct intake", "stock" = "stone", "units" = 4, "research" = "Irrigation", "use" = "A source on a bank beside fresh water."),
		"C" = list("mode" = "A", "role" = "run", "type" = /obj/structure/aqueduct/channel, "name" = "aqueduct channel", "stock" = "stone", "units" = 2, "research" = "Irrigation", "use" = "Open water drops to the height of this tile."),
		"A" = list("mode" = "A", "role" = "run", "type" = /obj/structure/aqueduct/arch, "name" = "aqueduct arches", "stock" = "stone", "units" = 5, "research" = "Irrigation", "use" = "Keeps the water at its incoming height across low, supported ground."),
		"F" = list("mode" = "A", "role" = "run", "type" = /obj/structure/aqueduct/flume, "name" = "timber flume", "stock" = "wood", "units" = 3, "research" = "Irrigation", "use" = "Keeps the water level across a dip without climbing."),
		"P" = list("mode" = "A", "role" = "run", "type" = /obj/structure/aqueduct/pipe, "name" = "clay water pipe", "stock" = "clay", "units" = 1, "research" = "Irrigation", "use" = "A buried run carries incoming head through a rise or dip."),
		"U" = list("mode" = "A", "role" = "end", "type" = /obj/structure/sink/aqueduct_fountain, "name" = "public fountain", "stock" = "stone", "units" = 6, "research" = "Irrigation", "use" = "A draw point supplied by an adjoining wet aqueduct piece."),
		"V" = list("mode" = "A", "role" = "end", "type" = /obj/structure/reagent_dispensers/cistern, "name" = "cistern", "stock" = "stone", "units" = 10, "research" = "Paved Infrastructure", "use" = "Stores water supplied by an adjoining wet aqueduct piece."),
		"D" = list("mode" = "S", "role" = "start", "type" = /obj/structure/sewer_piece/drain/floor, "name" = "floor drain", "stock" = "stone", "units" = 1, "research" = "Sanitation", "use" = "A floor grate for puddles and slops."),
		"S" = list("mode" = "S", "role" = "run", "type" = /obj/structure/sewer_piece/drain/stone, "name" = "stone drain", "stock" = "stone", "units" = 2, "research" = "Sanitation", "use" = "A covered link along the route."),
		"B" = list("mode" = "S", "role" = "run", "type" = /obj/structure/sewer_piece/drain/brick, "name" = "brick sewer", "stock" = "stone bricks", "units" = 3, "research" = "Imperial Architecture", "use" = "A high-capacity covered link with a manhole drawn on its tile; not a separate hatch."),
		"O" = list("mode" = "S", "role" = "end", "type" = /obj/structure/sewer_piece/drain/stone, "name" = "stone drain outfall", "stock" = "stone", "units" = 2, "research" = "Sanitation", "use" = "Build a stone drain on the bank; the drain itself spills into the adjacent water."),
	)
	return parts

/proc/waterworks_name(value)
	var/result = ""
	if (istext(value))
		for (var/i = 1, i <= min(length(value), 40), i++)
			var/c = copytext(value, i, i + 1)
			if (findtextEx("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 -", c))
				result += c
	result = trim(result)
	return length(result) ? result : "waterworks"

/proc/waterworks_turf(turf/origin, list/cell)
	return locate(origin.x + cell[1] - 1, origin.y + cell[2] - 1, origin.z)

/proc/waterworks_cell_key(list/cell)
	return "[cell[1]],[cell[2]]"

/datum/waterworks_plan
	var/name = "waterworks"
	var/mode = "A"
	var/list/route = list() // Ordered list of [x, y, part], x east, y north.

/datum/waterworks_plan/proc/to_code()
	var/list/rows = list()
	for (var/list/cell in route)
		rows += "[cell[1]],[cell[2]],[cell[3]]"
	return "C13WATER/1/[replacetext(waterworks_name(name), " ", "_")]/[mode]/[rows.len ? jointext(rows, ";") : "-"]"

/proc/waterworks_plan_from_code(code)
	var/list/F = design_code_fields(code, "WATER", DESIGN_CODE_WATER_MAX)
	if (!F || F.len != 3 || !(F[2] in list("A", "S")))
		return null
	var/list/rows = F[3] == "-" ? list() : splittext(F[3], ";")
	if (rows.len > WATERWORKS_LIMIT)
		return null
	var/list/route = list()
	var/list/seen = list()
	var/list/parts = waterworks_parts()
	for (var/row in rows)
		var/list/cell = splittext(row, ",")
		if (cell.len != 3)
			return null
		var/x = text2num(cell[1])
		var/y = text2num(cell[2])
		var/list/P = parts[cell[3]]
		if (!isnum(x) || !isnum(y) || "[x]" != cell[1] || "[y]" != cell[2] || x != round(x) || y != round(y) || x < 1 || y < 1 || x > WATERWORKS_SIDE || y > WATERWORKS_SIDE || !P || P["mode"] != F[2])
			return null
		cell[1] = x
		cell[2] = y
		var/key = waterworks_cell_key(cell)
		if (seen[key])
			return null
		seen[key] = TRUE
		route += list(cell)
	var/datum/waterworks_plan/D = new
	D.name = waterworks_name(replacetext(F[1], "_", " "))
	D.mode = F[2]
	D.route = route
	return D

/datum/waterworks_plan/proc/check_design()
	return design_report("waterworks", src)

/datum/design_check/waterworks
	kind = "waterworks"

/datum/design_check/waterworks/check(datum/waterworks_plan/D, datum/design_report/R)
	var/list/parts = waterworks_parts()
	if (D.route.len < 3)
		R.error("Draw a source, at least one run piece and an end.")
	for (var/i = 1, i <= D.route.len, i++)
		var/list/cell = D.route[i]
		var/key = waterworks_cell_key(cell)
		var/list/P = parts[cell[3]]
		var/role = i == 1 ? "start" : (i == D.route.len ? "end" : "run")
		if (P["role"] != role)
			R.error(i == 1 ? "Start with an intake or floor drain for this route." : (i == D.route.len ? "End with an outlet or a shore outfall for this route." : "Use a run piece between the two ends."), list(key))
		if (i > 1)
			var/list/previous = D.route[i - 1]
			if (abs(cell[1] - previous[1]) + abs(cell[2] - previous[2]) != 1)
				R.error("Successive pieces must touch on a tile edge.", list(waterworks_cell_key(previous), key))
		// Infrastructure joins by tile edge, not by the order it was laid.
		// An aqueduct fixture is not a connecting network piece.
		if (i < D.route.len || D.mode == "S")
			for (var/j = 1, j < i - 1, j++)
				var/list/earlier = D.route[j]
				if (abs(cell[1] - earlier[1]) + abs(cell[2] - earlier[2]) == 1)
					R.error("Nonconsecutive pieces would join and bypass this route.", list(waterworks_cell_key(earlier), key))

// Both bank helpers use the first eligible cardinal neighbor. An unseen
// neighbor could change the selected bank, so require all such tiles in sight.
/proc/waterworks_can_survey(mob/H, atom/A)
	return !H || (A.invisibility <= H.see_invisible && los_read_allowed(H, A, "examine"))

/proc/waterworks_bank_surveyed(turf/T, list/seen, mob/H)
	for (var/d in cardinal)
		var/turf/W = get_step(T, d)
		if (W && (!(W in seen) || !waterworks_can_survey(H, W)))
			return FALSE
	return TRUE

// Report buildability at this site, not the state of a network after it is
// built. Measurements are bounded to the drawn route and its immediately
// adjacent banks. Ground checks are conservative planner checks.
/datum/waterworks_plan/proc/check_site(turf/origin, datum/design_report/R, list/seen, mob/H)
	if (!origin || !islist(seen) || R.blocked())
		return
	var/list/parts = waterworks_parts()
	var/head = null
	var/previous_height = null
	if (!map || !map.terrain_heights())
		R.note("No usable terrain-height data here; the game treats this site as level.")
	if (mode == "S" && !sewers_apply())
		R.warning("The sewer simulation is not active on this map.")
	for (var/i = 1, i <= route.len, i++)
		var/list/cell = route[i]
		var/part = cell[3]
		var/key = waterworks_cell_key(cell)
		var/list/where = list(key)
		var/turf/T = waterworks_turf(origin, cell)
		if (!T || !(T in seen) || !waterworks_can_survey(H, T))
			R.error("This tile is outside your survey. Move to open, lit ground before pegging.", where, part)
			head = null
			previous_height = null
			continue
		var/desired = parts[part]["type"]
		if (!build_marker_ground(T) || T.density || istype(T, /turf/floor/beach/water))
			R.error("This part needs dry ground or a supporting floor on the map.", where, part)
			head = null
			previous_height = null
			continue
		for (var/obj/structure/O in T)
			if (QDELETED(O))
				continue
			var/in_way = (O.density && O.anchored) || (mode == "A" && (istype(O, /obj/structure/aqueduct) || istype(O, /obj/structure/aqueduct_intake))) || (mode == "S" && istype(O, /obj/structure/sewer_piece))
			if (!in_way && O.type != desired)
				continue
			if (!waterworks_can_survey(H, O))
				R.error("This tile cannot be fully surveyed.", where, part)
				break
			if (O.type == desired)
				var/obj/structure/sewer_piece/drain/D = O
				if (istype(D) && D.clogged)
					R.warning("The existing drain is clogged; clear it before use.", where, part)
				continue
			R.error("An existing structure is in the way of this part.", where, part)
			break
		for (var/obj/covers/C in T)
			if (C.density && !QDELETED(C))
				R.error(waterworks_can_survey(H, C) ? "A wall or other solid cover is in the way." : "This tile cannot be fully surveyed.", where, part)
				break
		if ((mode == "S" || i == 1) && !waterworks_bank_surveyed(T, seen, H))
			R.error("An adjoining bank tile is outside your survey.", where, part)
			head = null
			previous_height = null
			continue
		if (mode == "A")
			if (i == 1)
				var/turf/W = aqueduct_bank_water(T)
				if (!W)
					R.error("The intake needs a bank touching unfrozen fresh water.", where, part)
				else
					head = terrain_height_at(W)
					if (weather_heat_at(W))
						R.warning("The current heat has dried the intake's water.", where, part)
					if (istype(W, /turf/floor/beach/water/swamp) || river_fouled_at(W))
						R.warning("This intake source is currently fouled.", where, part)
			else if (i < route.len && !isnull(head))
				head = aqueduct_route_level(T, head, initial(desired:raised), initial(desired:underground))
				if (isnull(head))
					R.error("Water cannot climb to this piece. Reroute it, keep the head across a dip or use clay pipe.", where, part)
		else
			var/h = terrain_height_at(T)
			if (!isnull(previous_height) && h > previous_height)
				R.warning("This section goes uphill. The current sewer joins by adjacency, not by grade.", where, part)
			previous_height = h
			var/outfall = sewer_bank_outfall_dir(T)
			if (i == route.len)
				if (!outfall)
					R.error("The outfall needs a bank touching open water.", where, part)
				else
					var/turf/W = get_step(T, outfall)
					if (istype(W, /turf/floor/beach/water/ice))
						R.warning("The current outfall faces ice; check the bank before building.", where, part)
					if (aqueduct_fresh_water(W))
						R.warning("Freshwater discharge can foul water supplies and downstream intakes. Consider another outfall or a settling tank.", where, part)
			else if (outfall)
				R.error("This earlier bank tile would also act as an outfall. Move the run away from the shore.", where, part)

/datum/waterworks_plan/proc/materials(turf/origin, list/seen, mob/H)
	. = list()
	var/list/parts = waterworks_parts()
	for (var/list/cell in route)
		var/list/P = parts[cell[3]]
		var/turf/T = origin ? waterworks_turf(origin, cell) : null
		var/built = FALSE
		if (T && (T in seen) && waterworks_can_survey(H, T))
			for (var/obj/structure/S in T)
				if (S.type == P["type"] && !QDELETED(S) && waterworks_can_survey(H, S))
					built = TRUE
					break
		if (!built)
			.[P["stock"]] += P["units"]

/obj/item/ship_draught
	var/waterworks_peg_set = ""

/obj/item/ship_draught/proc/waterworks_held(mob/living/human/H)
	return H && !QDELETED(H) && !H.incapacitated() && (H.get_active_hand() == src || H.get_inactive_hand() == src)

/obj/item/ship_draught/proc/waterworks_context(mob/living/human/H, client/C, datum/identity, expected_code)
	return !QDELETED(src) && waterworks_held(H) && C && H.client == C && C.mob == H && !persistence_admission_changed(identity) && draught_code == expected_code

/obj/item/ship_draught/proc/waterworks_plan()
	return design_code_kind(draught_code) == "WATER" ? waterworks_plan_from_code(draught_code) : null

/obj/item/ship_draught/proc/take_waterworks(datum/waterworks_plan/D)
	draught_code = D.to_code()
	name = "waterworks plan ([D.name])"

/obj/item/ship_draught/proc/waterworks_sheet_menu(mob/living/human/H, datum/waterworks_plan/D)
	var/current = draught_code
	var/client/actor = H.client
	var/datum/identity = persistence_admission_identity
	var/request = "Peg out the saved route here"
	var/pull = "Pull up its pegs"
	var/list/options = list("Edit the route", request, DRAUGHT_EXPORT_LABEL, DRAUGHT_IMPORT_LABEL, "Cancel")
	if (length(waterworks_peg_set))
		options.Insert(3, pull)
	var/choice = WWinput(H, "[D.name]: [D.route.len] drawn tiles. For a site preview, stand at the south-west corner and open the planner.", name, "Cancel", options)
	if (!waterworks_context(H, actor, identity, current))
		return
	if (choice == "Edit the route")
		open_waterworks_designer(H)
	else if (choice == request)
		waterworks_peg_menu(H, D)
	else if (choice == pull)
		var/n = build_markers_pull(waterworks_peg_set)
		waterworks_peg_set = ""
		to_chat(H, SPAN_NOTICE("You pull up the route's [n] remaining peg\s."))
	else if (choice == DRAUGHT_EXPORT_LABEL)
		draught_export(H, D.name)
	else if (choice == DRAUGHT_IMPORT_LABEL)
		var/datum/callback/recheck = CALLBACK(src, PROC_REF(waterworks_context), H, actor, identity, current)
		draught_import(H, recheck)
		qdel(recheck)

// Stage only a checked, saved drawing. Capacity is reserved by a bounded
// pre-count before replacing anything, so refusal never loses the old pegs.
/datum/waterworks_plan/proc/peg_out(turf/origin, set_id, list/seen, mob/H)
	if (!origin || !length(set_id) || !islist(seen) || !(origin in seen) || persistence_admission_blocked())
		return null
	var/datum/design_report/R = check_design()
	check_site(origin, R, seen, H)
	var/blocked = R.blocked()
	qdel(R)
	if (blocked)
		return null
	var/list/missing = list()
	for (var/list/cell in route)
		var/turf/T = waterworks_turf(origin, cell)
		if ((tutorial_region_here() || (practice_room_z && origin.z == practice_room_z)) && (!T || !tutorial_workshop_footprint(H, T.x, T.y, T.x, T.y, origin.z)))
			return null
		if (!build_marker_built("waterworks_[cell[3]]", T))
			missing += list(cell)
	if (length(build_marker_registry()) - length(build_markers_of(set_id)) + missing.len > BUILD_MARKER_WORLD_MAX)
		return null
	build_markers_pull(set_id)
	var/list/parts = waterworks_parts()
	for (var/list/cell in missing)
		build_marker_place(waterworks_turf(origin, cell), list("waterworks_[cell[3]]=[parts[cell[3]]["name"]]"), set_id, name)
	return missing.len

/obj/item/ship_draught/proc/waterworks_peg_menu(mob/living/human/H, datum/waterworks_plan/D)
	var/turf/origin = get_turf(H)
	if (!origin || !waterworks_held(H) || persistence_admission_blocked())
		return
	var/current = draught_code
	var/client/actor = H.client
	var/datum/identity = persistence_admission_identity
	if (!waterworks_context(H, actor, identity, current))
		return
	var/datum/design_report/R = D.check_design()
	D.check_site(origin, R, cartography_visible_turfs(H), H)
	var/blocked = R.blocked()
	for (var/line in R.chat_lines())
		to_chat(H, line)
	qdel(R)
	if (blocked)
		return
	if (WWinput(H, "Peg this route with the south-west grid corner on the tile under you? Any old pegs of this sheet are replaced. Pegs are guides; build each part normally.", name, "Cancel", list("Peg the route", "Cancel")) != "Peg the route")
		return
	if (!waterworks_context(H, actor, identity, current) || get_turf(H) != origin)
		return
	if (!do_after(H, 30 + D.route.len, src) || !waterworks_context(H, actor, identity, current) || get_turf(H) != origin)
		return
	var/set_id = length(waterworks_peg_set) ? waterworks_peg_set : "waterworks-[H.ckey]-[world.realtime]-[rand(1000, 9999)]"
	var/n = D.peg_out(origin, set_id, cartography_visible_turfs(H), H)
	if (isnull(n))
		to_chat(H, SPAN_WARNING("The route no longer fits or there are too many pegs. Preview the site again."))
		return
	waterworks_peg_set = n ? set_id : ""
	to_chat(H, SPAN_NOTICE(n ? "You drive [n] pegs for the parts still to build." : "Every marked part is already built."))

// Shared by the preview and browser grid setup; keep dimension defines local.
/proc/waterworks_dimensions()
	return list(WATERWORKS_SIDE, WATERWORKS_LIMIT)

#undef WATERWORKS_SIDE
#undef WATERWORKS_LIMIT
