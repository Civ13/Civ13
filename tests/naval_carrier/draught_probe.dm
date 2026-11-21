// Ship's draughts (naval/ship_draught.dm, docs/ship-draught.md): a ship drawn
// on paper keeps to the built hull's rules, reckons her cost and speed, travels
// as a design code, and a ship afloat can have her lines drawn bow up.
/world
	hub = ""
	hub_password = ""
	maxx = 70
	maxy = 60
	maxz = 3
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/naval_research_done = FALSE
/obj/map_metadata/naval_probe/New()
	return
/obj/map_metadata/naval_probe/is_node_done(faction, node_id)
	return naval_research_done
/mob/living/human/naval_probe/New()
	return
var/hull_probe_watched = FALSE
// Nobody has a client here; the probe says when a player is near.
/datum/vehicle_offset/hull/watched()
	return hull_probe_watched
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

// Rock under everything, sand ashore (x 1-20) and deep sea beyond, sky above.
/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(x <= 20 ? /turf/floor/beach/sand : /turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)


// A plank laid the way a player lays one, with its first update already run.
/proc/draught_lay(x, y, path = /obj/covers/repairedfloor/ship)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/C = new path(T)
	C.updateturf()
	return C

// A plain hull drawn on the sheet: w by h planks, the tiller in the middle.
/proc/draught_box(w, h, name = "Box")
	var/datum/ship_draught/D = new
	D.name = name
	for (var/x = 0, x < w, x++)
		for (var/y = 0, y < h, y++)
			D.set_floor(x, y, "w")
	D.set_piece(round(w / 2), round(h / 2), "T")
	return D

/proc/naval_checks()
	naval_fixture()
	// ---- Limits are the built hull's own ----
	naval_check(SHIP_DRAUGHT_MAX_TILES == BUILT_HULL_MAX_TILES && SHIP_DRAUGHT_MAX_DECK == BUILT_HULL_MAX_DECK_TILES, "a draught keeps to the built hull's tile limits")

	// ---- What each piece weighs is what it weighs afloat ----
	var/turf/yard = locate(5, 5, 2)
	for (var/key in ship_draught_pieces)
		var/list/P = ship_draught_pieces[key]
		var/path = P["path"]
		var/atom/movable/M = new path(yard)
		naval_check(M.hull_load() == P["load"], "a [P["name"]] weighs [P["load"]] on a deck, as hull_load() says ([M.hull_load()])")
		qdel(M)

	// ---- A sound draught ----
	var/datum/ship_draught/D = draught_box(3, 5, "Wren")
	naval_check(D.buildable() && D.hull_tiles() == 15, "a 3 by 5 hull with a tiller can be built ([jointext(D.problems(), " ")])")
	var/list/cost = D.costs()
	naval_check(cost["wood"] == 40 && cost.len == 1, "she costs her floors and her tiller: 40 wood ([D.costs_text()])")
	naval_check(D.size_class() == HULL_CLASS_BOAT, "fifteen tiles make a boat")
	D.set_upper(1, 1, TRUE)
	D.set_floor(1, 0, "s")
	cost = D.costs()
	naval_check(cost["wood"] == 40 && cost["steel"] == 1, "a steel floor costs steel and a deck above costs a floor ([D.costs_text()])")

	// ---- Codes ----
	var/code = D.to_code()
	naval_check(findtext(code, "C13SHIP/1/Wren/") == 1, "her code is a ship code ([code])")
	var/datum/ship_draught/back = ship_draught_from_code(code)
	naval_check(back && back.to_code() == code && back.upper_tiles() == 1 && back.cell(1, 0)[1] == "s", "her code draws the same ship again")
	naval_check(!ship_draught_from_code("C13FLAG/1/x/y"), "a flag code is not a ship")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,q,-,1,0"), "an unknown floor is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,-,1,0;0,0,w,-,1,0"), "a tile drawn twice is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,Z,1,0"), "an unknown piece is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,[SHIP_DRAUGHT_SIDE],w,-,1,0"), "a tile off the sheet is refused")
	naval_check(!ship_draught_from_code("C13SHIP/1/X/0,0,w,R,3,0"), "a piece facing no direction is refused")
	var/datum/ship_draught/named = ship_draught_from_code("C13SHIP/1/Sea_Wolf/0,0,w,T,1,0")
	naval_check(named && named.name == "Sea Wolf" && named.buildable(), "a one-tile code with a tiller is a ship named Sea Wolf")
	var/obj/item/ship_draught/sheet = new(yard)
	sheet.take(D)
	var/datum/ship_draught/again = sheet.draught()
	naval_check(again && again.to_code() == code && sheet.name == "ship's draught (Wren)", "the sheet keeps her code")

	// ---- What cannot be built ----
	var/datum/ship_draught/apart = draught_box(3, 3)
	apart.set_floor(10, 10, "w")
	naval_check(!apart.buildable() && findtext(jointext(apart.problems(), " "), "more than one piece"), "floors in two pieces are refused")
	var/datum/ship_draught/two = draught_box(3, 3)
	two.set_piece(0, 0, "O")
	naval_check(findtext(jointext(two.problems(), " "), "2 helms"), "two helms are refused")
	var/datum/ship_draught/none = draught_box(3, 3)
	none.set_piece(1, 1, null)
	naval_check(findtext(jointext(none.problems(), " "), "no helm"), "no helm is refused")
	var/datum/ship_draught/ark = draught_box(15, 14)
	naval_check(findtext(jointext(ark.problems(), " "), "at most [SHIP_DRAUGHT_MAX_TILES]"), "more tiles than a built hull may have are refused")
	var/datum/ship_draught/tall = draught_box(10, 18)
	for (var/x = 0, x < 10, x++)
		for (var/y = 0, y < 18, y++)
			tall.set_upper(x, y, TRUE)
	naval_check(findtext(jointext(tall.problems(), " "), "at most [SHIP_DRAUGHT_MAX_DECK]"), "more deck than can sail is refused")
	naval_check(!D.set_piece(20, 20, "M"), "a piece needs a floor under it")

	// ---- How she will go ----
	var/datum/ship_draught/sloop = draught_box(4, 5)
	sloop.set_piece(1, 3, "M")
	naval_check(sloop.sail_step() == VESSEL_SPEED_HALF && sloop.oar_step() == VESSEL_SPEED_SLOW, "one mast drives twenty tiles at half ahead on a reach")
	var/datum/ship_draught/galley = draught_box(3, 6)
	for (var/y = 0, y < 6, y++)
		galley.set_piece(0, y, "R", EAST)
		galley.set_piece(2, y, "R", WEST)
	naval_check(galley.oar_step() == VESSEL_SPEED_FULL, "twelve manned benches row eighteen tiles at full ahead ([galley.mass()])")
	var/datum/ship_draught/barge = draught_box(6, 10)
	barge.set_piece(2, 2, "M")
	naval_check(barge.sail_step() == VESSEL_SPEED_SLOW && barge.wants_ballast() > 0, "one mast is too little for sixty tiles, and she wants ballast ([barge.wants_ballast()])")
	naval_check(findtext(barge.summary_text(), "ballast"), "the summary tells her builder about ballast")

	// ---- The designer window ----
	var/list/examples = ship_draught_examples()
	naval_check(examples.len == 3, "three ready-made draughts to start from")
	for (var/datum/ship_draught/E in examples)
		naval_check(E.buildable(), "the ready-made [E.name] can be built as drawn ([jointext(E.problems(), " ")])")
		var/list/cells = ship_designer_cells(E)
		var/inside = TRUE
		for (var/list/C in cells)
			if (!ship_draught_on_sheet(C[1], C[2]))
				inside = FALSE
		naval_check(cells.len == E.hull_tiles() && inside, "the [E.name] is laid out on the sheet for the window")
	var/datum/ship_draught/galley_example = examples[1]
	naval_check(galley_example.oar_step() == VESSEL_SPEED_FULL, "the ready-made galley rows at full ahead")
	var/datum/ship_draught/sloop_example = examples[2]
	naval_check(sloop_example.sail_step() == VESSEL_SPEED_HALF, "the ready-made sloop sails at half ahead")
	var/obj/item/ship_draught/pad = new(yard)
	var/html = ship_designer_html(pad, null)
	naval_check(findtext(html, "C13SHIP") && findtext(html, "rowing galley"), "the window carries the drawing tools and the ready-made ships")
	var/mob/living/human/naval_probe/drawer = new(yard)
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/0,0,w,T,1,0;0,1,w,M,1,0", "Little/Auk", TRUE) == "Saved on the sheet." && pad.draughts_name() == "Little Auk", "saving keeps the drawing and its cleaned name on the sheet")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/0,0,w,T,1,0;0,0,w,T,1,0", "Bad", TRUE) != "Saved on the sheet." && pad.draughts_name() == "Little Auk", "a damaged drawing is refused and the sheet keeps what it had")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/", "Empty", FALSE) == null, "an empty sheet still gets a summary")
	naval_check(pad.accept_drawing(drawer, "C13SHIP/1/ship/", "Empty", FALSE) == "", "a summary asked for again at once is put off")

	// ---- Drawing a ship afloat ----
	for (var/x = 22, x <= 60, x++)
		for (var/y = 4, y <= 50, y++)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water)
	for (var/x = 30, x <= 34, x++)
		for (var/y = 10, y <= 12, y++)
			draught_lay(x, y, (x == 34 && y == 12) ? /obj/covers/steelplating : /obj/covers/repairedfloor/ship)
	var/obj/structure/hull_tiller/tiller = new(locate(32, 11, 2))
	new /obj/structure/vehicleparts/movement/sail(locate(33, 11, 2))
	var/obj/structure/bed/chair/wood/rowing_bench/bench = new(locate(31, 10, 2))
	bench.set_dir(NORTH)
	var/obj/structure/hull_tiller/spare = new(locate(30, 12, 2))
	naval_check(isnull(tiller.commission("Heron", EAST)) && tiller.craft, "a hull is commissioned bow to the east")
	var/datum/ship_draught/lines = ship_draught_survey(tiller)
	naval_check(istype(lines) && lines.hull_tiles() == 15 && lines.name == "Heron", "her lines are fifteen tiles named Heron")
	if (istype(lines))
		var/list/E = lines.extent()
		naval_check(E[3] - E[1] == 2 && E[4] - E[2] == 4, "drawn bow up, she is 3 wide and 5 long ([E[3] - E[1] + 1] by [E[4] - E[2] + 1])")
		// Tiller amidships at (1,2) on the sheet; ahead of it (east afloat) is up.
		naval_check(lines.cell(1, 2)[2] == "T" && lines.cell(1, 3)[2] == "M", "the mast that stood ahead of the tiller is drawn above it")
		// The bench stood one tile astern and to starboard (south of a ship
		// heading east), facing north: to port. Bow up, port is west.
		var/list/bench_cell = lines.cell(2, 1)
		naval_check(bench_cell && bench_cell[2] == "R" && bench_cell[3] == WEST, "the bench is drawn astern to starboard, facing to port ([bench_cell ? "[bench_cell[2]] [bench_cell[3]]" : "none"])")
		naval_check(lines.cell(0, 4)[1] == "s", "her steel tile is drawn as steel")
		naval_check(lines.helms().len == 1 && lines.buildable(), "the spare tiller is left off and her lines can be built ([jointext(lines.problems(), " ")])")
	qdel(spare)
	tiller.decommission()
	naval_check(istext(ship_draught_survey(tiller)), "a struck hull has no lines to draw")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/naval_probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
