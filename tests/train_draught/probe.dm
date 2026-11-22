// Train sheets (code/modules/1713/train_draught.dm, train_draught_checks.dm,
// train_works.dm, docs/train-sheets.md): the ready-made sheets pass their
// checks and read back from their codes, bad codes are refused, each
// train_sheet check fires, every key has a part description, a drawn car
// lays out as a real platform car, and the rail works refuses what it cannot
// build, then builds and couples a whole train from its stock and draws it
// back onto a sheet.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 140
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
var/train_sheet_research_done = FALSE
/obj/map_metadata/train_sheet_probe/New()
	return
/obj/map_metadata/train_sheet_probe/is_node_done(faction, node_id)
	return train_sheet_research_done
/obj/map_metadata/train_sheet_probe/book_research_enabled()
	return FALSE
var/train_sheet_failures = 0
var/train_sheet_runtime_error = FALSE
/proc/train_sheet_check(condition, label)
	if (!condition)
		train_sheet_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	train_sheet_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/mob/living/human/train_sheet_probe/New()
	return

/proc/train_report_has(datum/train_draught/D, level, text)
	var/datum/design_report/R = D.check_design()
	. = FALSE
	for (var/t in R.texts(level))
		if (findtext(t, text))
			. = TRUE
	qdel(R)

/proc/train_sheet_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/dirt)
	// Straight track running north up column 20.
	for (var/y = 2, y <= world.maxy - 1, y++)
		var/obj/structure/rail_bed/B = track_place_bed(locate(20, y, 1), NORTH)
		B.place_rails()
		B.spike()

/proc/train_sheet_checks()
	train_sheet_fixture()
	if (!research_nodes.len)
		build_research_tree()

	// ---- Codes and the ready-made sheets ----
	var/list/examples = train_draught_examples()
	train_sheet_check(examples.len == 3, "three ready-made train sheets")
	for (var/datum/train_draught/E in examples)
		var/list/errors = E.problems()
		train_sheet_check(!errors.len, "[E.name] passes its checks ([jointext(errors, "; ")])")
		var/datum/train_draught/back = train_draught_from_code(E.to_code())
		train_sheet_check(back && back.to_code() == E.to_code() && back.cars.len == E.cars.len, "[E.name] reads back from its code")
		train_sheet_check(length(E.to_code()) <= DESIGN_CODE_TRAIN_MAX, "[E.name] code fits")
	var/datum/train_draught/branch = examples[1]
	train_sheet_check(draught_kinds["TRAIN"] && draught_kinds["TRAIN"]["read"] == /proc/train_draught_from_code, "train is a draught kind")
	train_sheet_check(design_code_kind_name("TRAIN") == "a train sheet", "pasted train codes have a name")
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/no_such_car"), "an unknown car kind is refused")
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/c:5:w:.:...:...:.....,.....,.....,.....,.....:odd"), "a drawn car five long is refused")
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/c:4:w:.:...:...:.....,.....,.....:short"), "a drawn car with too few sections is refused")
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/c:4:w:.:...:...:Q....,.....,.....,.....:bad"), "an unknown edge is refused")
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/c:4:w:.:...:...:..Z..,.....,.....,.....:bad"), "an unknown fitting is refused")
	var/list/many = list()
	for (var/i in 1 to TRAIN_DRAUGHT_MAX_CARS + 1)
		many += "flatbed"
	train_sheet_check(!train_draught_from_code("C13TRAIN/1/x/[jointext(many, ";")]"), "too many cars are refused")

	// ---- A drawn car is a real car kind ----
	var/saloon = branch.cars[3]
	var/list/L = train_car_layout(saloon)
	train_sheet_check(L && L["name"] == "private saloon" && train_car_length(saloon) == 4, "a drawn car has a layout of its own")
	var/list/first = L ? L["segments"][1] : null
	train_sheet_check(first && first["edges"].len == 5 && first["fit"][2] == /obj/structure/table/modern/table, "a drawn car's first section has its sides, front and fittings")
	train_sheet_check(L && L["roof"] == "coach" && L["center"] == "carpet" && L["side"] == "carpet", "a drawn car's floor and roof")
	var/list/costs = branch.costs()
	train_sheet_check(costs["iron"] == 16 + 12 + 24 && costs["steel"] == 45, "stock costs are their kits' and a drawn frame is a platform kit's")

	// ---- Checks ----
	var/datum/train_draught/D = train_draught_from_code("C13TRAIN/1/x/coach;flatbed")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "no locomotive"), "no engine warns")
	qdel(D)
	D = train_draught_from_code("C13TRAIN/1/x/loco_mainline;coach")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "put a tender right behind it"), "a main-line engine with no tender warns")
	qdel(D)
	D = train_draught_from_code("C13TRAIN/1/x/loco_diesel;tender")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "not next to a steam engine"), "a tender away from steam warns")
	qdel(D)
	D = train_draught_from_code("C13TRAIN/1/x/loco_steam;coach;coach;coach;coach")
	train_sheet_check(train_report_has(D, DESIGN_NOTE, "no brake van"), "a long train with no brakes notes it")
	qdel(D)
	D = train_draught_from_code("C13TRAIN/1/x/loco_steam;c:4:w:.:www:www:wwL.L,ww...,ww...,ww...:sealed")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "nobody can get aboard"), "a car with no way in warns")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "no ice bunker"), "cold lockers with no bunker warn")
	qdel(D)
	D = train_draught_from_code("C13TRAIN/1/x/loco_steam;c:4:w:.:...:...:...R.,...R.,...R.,...R.:blocked")
	train_sheet_check(train_report_has(D, DESIGN_WARNING, "nobody can walk its length"), "a car blocked down the middle warns")
	qdel(D)
	var/list/long = list()
	for (var/i in 1 to 16)
		long += "long_flatbed"
	D = train_draught_from_code("C13TRAIN/1/x/[jointext(long, ";")]")
	train_sheet_check(D && train_report_has(D, DESIGN_ERROR, "tiles long; a train can be"), "a train over the tile cap is an error")
	qdel(D)
	D = new
	train_sheet_check(train_report_has(D, DESIGN_ERROR, "no cars"), "an empty sheet is an error")
	qdel(D)
	var/list/book = design_part_help_for("train_sheet")
	var/list/missing = list()
	for (var/key in train_draught_stock())
		if (!book[key])
			missing += key
	var/list/tables = list("floor_" = train_draught_floors(), "roof_" = train_draught_roofs(), "edge_" = train_draught_edges(), "fit_" = train_draught_fittings())
	for (var/prefix in tables)
		for (var/key in tables[prefix])
			if (!book["[prefix][key]"])
				missing += "[prefix][key]"
	train_sheet_check(!missing.len && book["custom"] && book["x"], "every key has a part description ([jointext(missing, ", ")])")

	// ---- The rail works ----
	var/obj/structure/rail_works/W = new(locate(18, 130, 1))
	W.dir = EAST // the rail tile in front is (20, 130); a train heading north runs back south from it
	var/mob/living/human/train_sheet_probe/builder = new(locate(17, 130, 1))
	var/refusal = W.sheet_refusal(builder, branch)
	train_sheet_check(findtext(refusal, "research"), "the works refuses without the research ([refusal])")
	train_sheet_research_done = TRUE
	refusal = W.sheet_refusal(builder, branch)
	train_sheet_check(findtext(refusal, "The works needs"), "the works refuses without the stock ([refusal])")
	W.stock = list("iron" = 500, "steel" = 500, "wood" = 500, "glass" = 100, "cloth" = 100)
	train_sheet_check(!W.sheet_refusal(builder, branch), "the works takes a sheet it can build")
	train_sheet_check(findtext(W.track_problem(branch, SOUTH), "track"), "the works refuses a heading the track does not have room for")
	train_sheet_check(!W.track_problem(branch, NORTH), "the track north is clear")
	var/steel_was = W.stock["steel"]
	var/obj/structure/trains/head = W.build_train(branch, NORTH)
	train_sheet_check(istype(head, /obj/structure/trains/locomotive), "the works builds the train engine first ([head])")
	if (istype(head))
		var/obj/structure/trains/locomotive/E = head
		train_sheet_check(E.loc == locate(20, 130, 1) && E.dir == NORTH, "the front car stands in front of the works")
		var/list/consist = train_consist_list(head)
		train_sheet_check(consist.len == branch.total_tiles(), "every section is coupled into one train ([consist.len] of [branch.total_tiles()])")
		var/list/kinds = list()
		for (var/obj/structure/trains/platform/P in consist)
			kinds |= P.car_kind
		train_sheet_check((saloon in kinds) && ("coach" in kinds) && ("brake_van" in kinds), "the drawn saloon and the stock cars are in it")
		var/obj/structure/trains/platform/S = null
		for (var/obj/structure/trains/platform/P in consist)
			if (P.car_kind == saloon && P.seg_index == 1)
				S = P
		train_sheet_check(S && S.name == "private saloon" && S.deck_parts && S.deck_parts.len >= 7, "the saloon is laid out with its walls")
		var/list/tiles = S ? train_platform_tiles(S.loc, S.dir) : list(null, null, null)
		train_sheet_check(tiles[2] && (locate(/obj/structure/table/modern/table) in tiles[2]), "the saloon is furnished")
		train_sheet_check(W.stock["steel"] == steel_was - 45 && W.stock["iron"] == 500 - 52, "the works spends its stock")
		train_sheet_check(W.track_problem(branch, NORTH), "the built train blocks the next build")
		var/datum/train_draught/drawn = train_draught_survey(W.train_in_front())
		train_sheet_check(istype(drawn) && drawn.cars.len == branch.cars.len && drawn.cars[3] == saloon && drawn.cars[1] == "loco_steam", "the train is drawn back onto a sheet car for car")
		// A drawn car keeps its layout in a kit.
		var/obj/structure/train_car_kit/K = S ? S.pack_car() : null
		train_sheet_check(K && K.car_kind == saloon && K.car_length() == 4, "a drawn car packs into a kit that keeps its design")

/proc/train_sheet_run()
	try
		train_sheet_checks()
	catch(var/exception/caught)
		train_sheet_runtime_error = TRUE
		world.log << "exception [caught] [caught.file]:[caught.line]"
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = train_sheet_failures, "runtime_error" = train_sheet_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/train_sheet_probe
	catch(var/exception/setup_error)
		world.log << "setup [setup_error]"
	spawn(0)
		train_sheet_run()
