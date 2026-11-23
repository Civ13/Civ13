// House plan probe (tests/house_plans/run.py). A small world with soft ground
// and open air above it, where every plan is first judged as drawn and then
// really built: each wall, window, door and pillar as the object a builder
// would place, each roof tile through building_design_error() and
// building_construct_roof(). The plan's verdict on every roof tile must be
// the game's.

/world
	maxx = HOUSE_PLAN_SIDE + 2
	maxy = HOUSE_PLAN_SIDE + 2
	maxz = HOUSE_PLAN_STOREYS + 1
	turf = /turf/floor/dirt
	area = /area/caribbean
	hub = ""
	hub_password = ""

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/house_tester/New()
	return

var/global/house_probe_checks = 0

/proc/house_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	house_probe_checks++
	world.log << "HOUSE PASS: [message]"

// The turf of a plan tile: the sheet's north is the world's.
/proc/house_probe_turf(s, x, y)
	return locate(x + 1, HOUSE_PLAN_SIDE + 2 - y, s)

/proc/house_probe_clear()
	// A new roof looks at its tile a tick after it is built: let it.
	sleep(3)
	for (var/turf/T in world)
		for (var/atom/movable/A in T)
			if (istype(A, /atom/movable/lighting_overlay) || istype(A, /atom/movable/lighting_fullbright))
				continue
			qdel(A)
	sleep(1)

// Whether a real floor of the storey below lies under a tile.
/proc/house_probe_floor_under(turf/T)
	if (T.z <= 1)
		return TRUE
	for (var/obj/covers/C in T)
		if (C.building_roof())
			return TRUE
	return FALSE

// Builds plan D storey by storey and compares every roof tile. Returns the
// roof tiles the game and the plan both refused.
/proc/house_probe_build(datum/house_plan/D, label)
	house_probe_clear()
	var/list/pieces = house_plan_pieces()
	var/list/floors = house_plan_floors()
	var/refused = 0
	var/built = 0
	for (var/s = 1, s <= D.top_storey(), s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				var/turf/T = house_probe_turf(s, x, y)
				if (!house_probe_floor_under(T))
					continue
				var/key = D.floor_key(s, x, y)
				if (key && s == 1)
					var/floor_type = floors[key]["type"]
					new floor_type(T)
				key = D.piece_key(s, x, y)
				if (key && pieces[key]["tier"])
					var/piece_type = pieces[key]["type"]
					new piece_type(T)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!D.has_roof(s, x, y))
					continue
				var/turf/T = house_probe_turf(s, x, y)
				var/error = building_design_error(T)
				var/fault = D.roof_fault(s, x, y)
				if (!error != !fault)
					throw EXCEPTION("[label]: storey [s] tile [x],[y]: the plan says [fault ? fault : "sound"], the game says [error ? error : "sound"]")
				if (error)
					refused++
					continue
				if (!building_construct_roof(T, /obj/roof/wood, null))
					throw EXCEPTION("[label]: storey [s] tile [x],[y]: the roof would not build")
				built++
	world.log << "HOUSE BUILT: [label]: [built] roof tiles built, [refused] refused by both"
	return refused

// The faults a plan's roofs have, as "fault" = count.
/proc/house_probe_faults(datum/house_plan/D)
	. = list()
	for (var/s = 1, s <= D.top_storey(), s++)
		for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
			for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
				if (!D.has_roof(s, x, y))
					continue
				var/fault = D.roof_fault(s, x, y)
				if (fault)
					.[fault]++

// A box of walls w by h with its top left tile at 6,6 on storey s, roofed all
// over with wood. key is the wall; floor goes under the walls.
/proc/house_probe_box(datum/house_plan/D, s, w, h, key, floor = null)
	for (var/y = 6, y < 6 + h, y++)
		for (var/x = 6, x < 6 + w, x++)
			var/edge = x == 6 || y == 6 || x == 5 + w || y == 5 + h
			D.set_cell(s, x, y, edge ? floor : null, edge ? key : null, "w")

/proc/house_probe_texts(datum/house_plan/D, level)
	var/datum/design_report/R = D.check_design()
	. = jointext(R.texts(level), " | ")
	qdel(R)

// Builds what storey s of plan D draws, as a builder following its pegs
// would: floors, every piece (stairs too) and, with roofs, the roofing.
/proc/house_probe_follow(datum/house_plan/D, s, roofs = FALSE)
	var/list/pieces = house_plan_pieces()
	var/list/floors = house_plan_floors()
	for (var/y = 1, y <= HOUSE_PLAN_SIDE, y++)
		for (var/x = 1, x <= HOUSE_PLAN_SIDE, x++)
			var/turf/T = house_probe_turf(s, x, y)
			if (!house_probe_floor_under(T))
				continue
			if (roofs)
				if (D.has_roof(s, x, y) && !building_construct_roof(T, /obj/roof/wood, null))
					throw EXCEPTION("pegs: storey [s] tile [x],[y]: the roof would not build")
				continue
			var/key = D.floor_key(s, x, y)
			if (key)
				var/floor_type = floors[key]["type"]
				new floor_type(T)
			key = D.piece_key(s, x, y)
			if (key)
				var/piece_type = pieces[key]["type"]
				new piece_type(T)
	if (roofs)
		sleep(3)

/proc/house_probe_look(set_id)
	for (var/obj/effect/build_marker/M in build_markers_of(set_id))
		M.look()

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		map = new /obj/map_metadata/house_tester
		map_storage.record_compiled_dimensions()
		for (var/turf/T in world)
			if (T.z > 1)
				new /turf/sky/building(T)

		// ---- The tables say what the built things do ----
		var/turf/bench = locate(3, 3, 1)
		var/list/pieces = house_plan_pieces()
		for (var/key in pieces)
			var/list/P = pieces[key]
			if (!P["tier"])
				continue
			var/piece_type = P["type"]
			var/atom/A = new piece_type(bench)
			house_assert(A.building_support_tier() == P["tier"], "[P["name"]] carries [P["tier"]] storeys as built")
			house_assert(building_support_reach(A) == P["reach"], "[P["name"]] reaches [P["reach"]] tile\s as built")
			qdel(A)
		var/list/floors = house_plan_floors()
		for (var/key in floors)
			var/list/F = floors[key]
			var/floor_type = F["type"]
			var/atom/A = new floor_type(bench)
			house_assert(!building_founded(A) == !F["foundation"], "[F["name"]] is [F["foundation"] ? "a" : "no"] foundation as built")
			qdel(A)
		house_assert(!building_founded(bench), "the probe's ground is soft")
		var/list/roofs = house_plan_roofs()
		for (var/key in roofs)
			house_assert(ispath(roofs[key]["type"], /obj/roof), "[roofs[key]["name"]] is a roof")

		// ---- The ready-made plans ----
		var/list/dump = list()
		for (var/datum/house_plan/E in house_plan_examples())
			var/code = E.to_code()
			var/datum/house_plan/again = house_plan_from_code(code)
			house_assert(again && again.to_code() == code, "[E.name] survives its design code")
			house_assert(again.notes.len == E.notes.len && again.notes.len >= 1 && again.notes[1][4] == E.notes[1][4], "[E.name] keeps its note")
			house_assert(!length(E.problems()), "[E.name] can be built as drawn: [jointext(E.problems(), " | ")]")
			house_assert(!length(house_probe_texts(E, DESIGN_WARNING)), "[E.name] draws no warning: [house_probe_texts(E, DESIGN_WARNING)]")
			house_assert(house_probe_build(again, E.name) == 0, "[E.name] stands when really built")
			house_assert(length(E.materials_text()) && length(E.summary_text()), "[E.name] has its bill of materials")
			dump += list(list("data" = house_designer_data(null, E), "answer" = house_designer_answer(E), "code" = code))
			qdel(again)

		// ---- Faults the game refuses ----
		// A room three tiles across: the middle tile is two from every wall.
		var/datum/house_plan/wide = new
		house_probe_box(wide, 1, 5, 5, "T")
		wide.set_piece(1, 8, 10, "D")
		var/list/faults = house_probe_faults(wide)
		house_assert(faults.len == 1 && faults["none"] == 1 && wide.roof_fault(1, 8, 8) == "none", "the middle of a room three tiles across has no support")
		house_assert(house_probe_build(wide, "wide room") == 1, "the game refuses the same tile")
		house_assert(findtext(house_probe_texts(wide, DESIGN_ERROR), "nothing holding it up"), "the check says so")
		wide.set_piece(1, 8, 8, "R")
		house_assert(!length(wide.problems()) && house_probe_build(wide, "propped room") == 0, "a roof support in the middle mends it")

		// Three storeys of stone on bare ground: soft ground carries two.
		var/datum/house_plan/soft = new
		for (var/s = 1, s <= 3, s++)
			house_probe_box(soft, s, 4, 4, "S")
		// The same with a wide ground floor and no stairs, for the window's pictures.
		var/datum/house_plan/soft_shot = house_plan_from_code(soft.to_code())
		soft_shot.name = "tall stone house"
		house_probe_box(soft_shot, 1, 6, 5, "S")
		soft_shot.set_piece(1, 8, 10, "D")
		soft_shot.set_note(1, 8, 8, "Hall")
		dump += list(list("data" = house_designer_data(null, soft_shot), "answer" = house_designer_answer(soft_shot), "code" = soft_shot.to_code()))
		faults = house_probe_faults(soft)
		house_assert(faults.len == 1 && faults["soft"] == 16, "the third storey of a stone house on bare ground needs a foundation")
		house_assert(house_probe_build(soft, "stone on soft ground") == 16, "the game refuses the same sixteen tiles")
		house_assert(findtext(house_probe_texts(soft, DESIGN_ERROR), "needs a foundation") || findtext(house_probe_texts(soft, DESIGN_ERROR), "need a foundation"), "the check names the foundation")
		for (var/y = 6, y <= 9, y++)
			for (var/x = 6, x <= 9, x++)
				if (soft.piece_key(1, x, y))
					soft.set_floor(1, x, y, "s")
		house_assert(!length(soft.problems()) && house_probe_build(soft, "stone on a stone floor") == 0, "a stone floor under the walls mends it")

		// Three storeys of timber: timber carries two.
		var/datum/house_plan/timber = new
		for (var/s = 1, s <= 3, s++)
			house_probe_box(timber, s, 4, 4, "T", "s")
		faults = house_probe_faults(timber)
		house_assert(faults.len == 1 && faults["weak"] == 16, "timber does not carry a third storey")
		house_assert(house_probe_build(timber, "three timber storeys") == 16, "the game refuses the same sixteen tiles")
		// Stone over timber is as weak as the timber.
		for (var/y = 6, y <= 9, y++)
			for (var/x = 6, x <= 9, x++)
				if (timber.piece_key(3, x, y))
					timber.set_piece(3, x, y, "S")
					timber.set_piece(2, x, y, "S")
		faults = house_probe_faults(timber)
		house_assert(faults["weak"] == 16, "stone over timber is as weak as the timber")
		house_assert(house_probe_build(timber, "stone over timber") == 16, "the game agrees")

		// A wall upstairs with no roof under it.
		var/datum/house_plan/adrift = new
		house_probe_box(adrift, 1, 4, 4, "T")
		house_probe_box(adrift, 2, 4, 4, "T")
		for (var/x = 6, x <= 9, x++)
			adrift.set_roof(1, x, 6, null)
		house_assert(findtext(house_probe_texts(adrift, DESIGN_ERROR), "nothing under"), "a wall on open air is refused")
		house_probe_build(adrift, "walls on open air")
		// Only supports on nothing in reach: the roof over the unroofed row,
		// with the walls of the next row taken away.
		for (var/x = 6, x <= 9, x++)
			adrift.set_piece(2, x, 7, null)
		house_assert(adrift.roof_fault(2, 7, 6) == "air", "supports on open air hold nothing")
		house_probe_build(adrift, "walls on open air, bare row")

		// One stone pillar upstairs holds only the tiles beside it.
		var/datum/house_plan/span = new
		for (var/y = 6, y <= 10, y++)
			for (var/x = 6, x <= 10, x++)
				span.set_cell(1, x, y, (x == 8 && y == 8) ? "s" : null, (x == 8 && y == 8) ? "P" : null, "w")
				span.set_cell(2, x, y, null, (x == 8 && y == 8) ? "P" : null, "w")
		faults = house_probe_faults(span)
		house_assert(faults.len == 1 && faults["span"] == 16, "a lone pillar upstairs holds only the nine tiles round it")
		house_assert(house_probe_build(span, "lone pillar") == 16, "the game refuses the same sixteen tiles")

		// A wall upstairs with nothing beneath it on the floor below.
		var/datum/house_plan/column = new
		for (var/y = 6, y <= 12, y++)
			for (var/x = 6, x <= 12, x++)
				column.set_cell(1, x, y, null, (x == 9 && y == 9) ? "R" : null, "w")
		column.set_cell(2, 12, 12, null, "T", "w")
		house_assert(column.roof_fault(2, 12, 12) == "column", "a wall upstairs needs a support beneath it")
		house_probe_build(column, "wall over nothing")

		// ---- What the game allows and a builder regrets ----
		var/datum/house_plan/shut = new
		house_probe_box(shut, 1, 4, 4, "T")
		house_probe_box(shut, 2, 4, 4, "T")
		var/warnings = house_probe_texts(shut, DESIGN_WARNING)
		house_assert(findtext(warnings, "walled in with no way in"), "a room with no door draws a warning")
		house_assert(findtext(warnings, "Nothing leads up to the second storey"), "a storey with no stairs draws a warning")
		house_assert(!length(shut.problems()), "neither stops the building")
		shut.set_piece(1, 7, 9, "D")
		shut.set_piece(1, 7, 7, "U")
		warnings = house_probe_texts(shut, DESIGN_WARNING)
		house_assert(findtext(warnings, "roofed over"), "stairs under a roof draw a warning")
		shut.set_roof(1, 7, 7, null)
		shut.set_roof(2, 7, 7, null)
		warnings = house_probe_texts(shut, DESIGN_WARNING)
		house_assert(!findtext(warnings, "roofed over") && !findtext(warnings, "Nothing leads up") && findtext(warnings, "no roof over it on any storey"), "an open stairwell lets the rain in")
		shut.set_roof(2, 7, 7, "w")
		house_assert(!length(house_probe_texts(shut, DESIGN_WARNING)), "roofed over on the top storey it is sound: [house_probe_texts(shut, DESIGN_WARNING)]")
		house_assert(house_probe_build(shut, "house with stairs") == 0, "and stands when built")
		// A gap in the wall leaves the room open to the weather.
		shut.set_piece(1, 9, 7, null)
		house_assert(findtext(house_probe_texts(shut, DESIGN_NOTE), "not closed in"), "a gap in the wall draws a note")
		// Stone on bare ground, two storeys: advice about a third.
		var/datum/house_plan/two = new
		house_probe_box(two, 1, 4, 4, "S")
		house_probe_box(two, 2, 4, 4, "S")
		house_assert(findtext(house_probe_texts(two, DESIGN_NOTE), "third storey"), "stone on soft ground draws the foundation advice")
		// An upper floor wider than its walls has open edges.
		var/datum/house_plan/terrace = new
		house_probe_box(terrace, 1, 5, 4, "T")
		house_probe_box(terrace, 2, 4, 4, "T")
		house_assert(findtext(house_probe_texts(terrace, DESIGN_NOTE), "open edge"), "a terrace draws the drop note")
		var/datum/house_plan/blank = new
		house_assert(length(blank.problems()) == 1 && !blank.top_storey(), "a blank sheet says to start drawing")

		// ---- Notes and codes ----
		house_assert(house_plan_clean_note("Keep_the <b>grain</b>; dry, up/here!") == "Keep the bgrainb dry uphere!", "a note keeps only plain characters")
		var/datum/house_plan/noted = new
		noted.set_piece(1, 5, 5, "T")
		for (var/i = 1, i <= HOUSE_PLAN_NOTES_MAX, i++)
			house_assert(noted.set_note(1, i, 1, "Note [i]"), "note [i] pins")
		house_assert(!noted.set_note(1, 1, 2, "One too many"), "a plan holds [HOUSE_PLAN_NOTES_MAX] notes")
		house_assert(noted.set_note(1, 1, 1, "") && noted.notes.len == HOUSE_PLAN_NOTES_MAX - 1, "an empty note takes one off")
		var/datum/house_plan/read = house_plan_from_code(noted.to_code())
		house_assert(read && read.note_at(1, 2, 1) == "Note 2" && read.notes.len == noted.notes.len, "notes travel in the code")
		var/datum/house_plan/slab = new
		for (var/y = 1, y <= 10, y++)
			for (var/x = 1, x <= 10, x++)
				slab.set_cell(1, x, y, "s", null, "w")
		house_assert(length(slab.to_code()) < 200, "runs keep a code short: [length(slab.to_code())] characters for 100 tiles")
		for (var/bad in list(
			"C13HOUSE/1/x/1,1,1,1,-T-",            // no notes field
			"C13HOUSE/1/x/1,21,1,1,-T-/",          // off the sheet
			"C13HOUSE/1/x/1,19,1,3,-T-/",          // a run off the sheet
			"C13HOUSE/1/x/7,1,1,1,-T-/",           // no such storey
			"C13HOUSE/1/x/1,1,1,1,-Z-/",           // no such piece
			"C13HOUSE/1/x/1,1,1,1,zT-/",           // no such floor
			"C13HOUSE/1/x/1,1,1,1,---/",           // an empty tile
			"C13HOUSE/1/x/1,1,1,2,-T-;1,2,1,1,-S-/", // a tile written twice
			"C13HOUSE/1/x/1,1,1,1,-T-/1,1,1,a;1,1,1,b", // two notes on one tile
			"C13HOUSE/2/x/1,1,1,1,-T-/",           // another version
			"C13SHIP/1/x/1,1,1,1,-T-/",            // another kind
			))
			house_assert(!house_plan_from_code(bad), "refuses [bad]")
		var/list/kind = draught_kinds["HOUSE"]
		house_assert(kind && call(kind["read"])(wide.to_code()), "the sheet reads a house code")
		var/obj/item/ship_draught/sheet = new(bench)
		sheet.take_house(wide)
		house_assert(sheet.house_plan_kind() && findtext(sheet.name, "house plan") && !sheet.station_plan() && !sheet.draught(), "a sheet holding a house is a house plan and nothing else")

		// ---- Pegging a plan out (build_markers.dm, house_plan_pegs.dm) ----
		house_probe_clear()
		var/list/examples = house_plan_examples()
		var/datum/house_plan/pegged = examples[2]
		var/datum/house_plan/keep = examples[3]
		house_assert(jointext(keep.tile_wants(1, 8, 8), ";") == "wall=stone wall;floor=stone floor;roof=clay tile roof", "a tile asks for its piece, its floor and its roof")
		// Tile x,y of the sheet falls on house_probe_turf(): the sheet's 0,0 is at 1, HOUSE_PLAN_SIDE + 2.
		var/list/laid = house_plan_peg_out(pegged, 1, 1, HOUSE_PLAN_SIDE + 2, 1, "probe")
		house_assert(laid && laid["pegs"] == 42 && !laid["skipped"] && !laid["blocked"], "the ground floor takes a peg on each of its 42 tiles")
		var/obj/effect/build_marker/door_peg = build_marker_at(house_probe_turf(1, 10, 12), "probe")
		house_assert(door_peg && door_peg.icon_state == "door" && door_peg.name == "peg (door)" && door_peg.wants == "door=door;roof=wood roof" && door_peg.set_name == pegged.name, "the door's peg is tagged with the door and still asks for its roof")
		house_assert(!door_peg.density && door_peg.anchored && !door_peg.opacity, "a peg stops nobody and hides nothing")
		for (var/tag_kind in build_marker_kinds())
			house_assert((build_marker_kinds()[tag_kind]["state"] in icon_states('icons/obj/build_markers.dmi')), "the [tag_kind] tag is drawn")
		house_assert(("note" in icon_states('icons/obj/build_markers.dmi')) && ("peg" in icon_states('icons/obj/build_markers.dmi')), "the bare peg and the note tag are drawn")
		laid = house_plan_peg_out(pegged, 1, 1, HOUSE_PLAN_SIDE + 2, 1, "probe")
		house_assert(laid["pegs"] == 42 && length(build_markers_of("probe")) == 42, "pegging a storey again replaces its pegs")
		house_assert(!house_plan_peg_out(pegged, 1, 10, HOUSE_PLAN_SIDE + 2, 1, "edge") && !length(build_markers_of("edge")), "a plan that runs off the land is not pegged")
		house_assert(house_peg_level(1, 2) == 2 && house_peg_level(1, 1) == 1, "the storey above the ground is the level above")
		laid = house_plan_peg_out(pegged, 2, 1, HOUSE_PLAN_SIDE + 2, 2, "probe")
		house_assert(laid && !laid["pegs"] && laid["skipped"] == 42, "a storey with no floor under it yet takes no pegs")
		house_probe_follow(pegged, 1)
		house_probe_look("probe")
		var/list/left = build_markers_left("probe")
		house_assert(left.len == 1 && left["wood roof"] == 41 && length(build_markers_of("probe")) == 41, "with the walls up the pegs ask only for the roof: [json_encode(left)]")
		house_assert(!build_marker_at(house_probe_turf(1, 8, 8), "probe"), "the stairs' peg went when the stairs and their floor were built")
		var/obj/effect/build_marker/roof_peg = build_marker_at(house_probe_turf(1, 9, 9), "probe")
		house_assert(roof_peg && roof_peg.icon_state == "roof" && roof_peg.name == "peg (wood roof)", "a tile's tag moves on to what is left")
		house_probe_follow(pegged, 1, TRUE)
		house_probe_look("probe")
		house_assert(!length(build_markers_of("probe")), "every peg of the ground floor goes when it is built")
		laid = house_plan_peg_out(pegged, 2, 1, HOUSE_PLAN_SIDE + 2, 2, "probe")
		house_assert(laid["pegs"] == 41 && laid["skipped"] == 1, "the storey above is pegged on its floor, all but the stairwell: [json_encode(laid)]")
		var/obj/effect/build_marker/note_peg = build_marker_at(house_probe_turf(2, 12, 8), "probe")
		house_assert(note_peg && note_peg.note == "Beds upstairs" && note_peg.icon_state == "roof", "a note rides on its tile's peg")
		house_probe_follow(pegged, 2)
		house_probe_follow(pegged, 2, TRUE)
		house_probe_look("probe")
		house_assert(length(build_markers_of("probe")) == 1 && !QDELETED(note_peg) && note_peg.icon_state == "note" && !length(note_peg.wants), "with the house built only the note's peg stands")
		var/obj/item/ship_draught/site = new(bench)
		site.take_house(pegged)
		site.peg_set = "probe"
		site.peg_x = 1
		site.peg_y = HOUSE_PLAN_SIDE + 2
		site.peg_z = 1
		house_assert(site.house_peg_storey(1) == 1 && site.house_peg_storey(2) == 2, "the sheet knows which storey of its site a level is")
		house_assert(findtext(site.house_pegs_text(), "nothing its pegs ask for is left"), "the sheet says when its pegs are done")
		house_assert(build_markers_pull("probe") == 1 && !length(build_marker_registry()), "pulling the pegs leaves none standing")
		// A peg whose floor is gone goes too.
		var/turf/sky = house_probe_turf(3, 3, 3)
		var/obj/effect/build_marker/lost_peg = new(sky)
		lost_peg.wants = "wall=timber wall"
		lost_peg.look()
		house_assert(QDELETED(lost_peg), "a peg over open air goes")
		house_assert(!build_marker_place(sky, list("nonsense=thing"), "probe", "x", null), "a peg asks only for work it knows")

		text2file(json_encode(dump), "designer.json")
		world.log << "HOUSE CHECKS: [house_probe_checks]"
		text2file("PASS: house plans", "result.txt")
	catch (var/exception/E)
		world.log << "HOUSE exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
