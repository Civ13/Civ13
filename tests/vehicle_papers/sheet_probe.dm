// Vehicle sheets (code/modules/craft/vehicle_draught.dm, docs/vehicle-sheets.md):
// design codes, the ready-made sheets, the "vehicle_sheet" design checks and
// their part book, a sheet clipped to an axis comparing the frames laid
// around it, and drawing an assembled vehicle back onto a sheet.
/world
	hub = ""
	hub_password = ""
	maxx = 60
	maxy = 60
	maxz = 1
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
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/naval_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/beach/sand)


/proc/sheet_report_has(datum/vehicle_draught/D, level, text)
	var/datum/design_report/R = D.check_design()
	. = FALSE
	for (var/t in R.texts(level))
		if (findtext(t, text))
			. = TRUE
	qdel(R)

/proc/naval_checks()
	naval_fixture()

	// ---- Codes and the ready-made sheets ----
	var/list/examples = vehicle_draught_examples()
	naval_check(examples.len == 5, "five ready-made sheets")
	for (var/datum/vehicle_draught/E in examples)
		var/datum/design_report/R = E.check_design()
		naval_check(!R.blocked(), "the [E.name] can be built as drawn ([jointext(R.texts(DESIGN_ERROR), " ")])")
		qdel(R)
		var/code = E.to_code()
		var/datum/vehicle_draught/back = vehicle_draught_from_code(code)
		naval_check(back && back.to_code() == code && length(code) <= DESIGN_CODE_CAR_MAX, "the [E.name] reads back from its code ([code])")
		naval_check(findtext(E.summary_text(), "Building it takes"), "and has a summary")
	var/datum/vehicle_draught/car = examples[1]
	var/good = car.to_code()
	naval_check(!vehicle_draught_from_code(replacetext(good, "/2/3/", "/2/4/")), "a code whose tiles do not fill its size is refused")
	naval_check(!vehicle_draught_from_code(replacetext(good, "/gasoline/2000/", "/gasoline/90000/")), "an engine bigger than the engine maker makes is refused")
	naval_check(!vehicle_draught_from_code(replacetext(good, "1,1,s,W,E", "1,1,s,W,%")), "an unknown part is refused")
	naval_check(!vehicle_draught_from_code(replacetext(good, "/car/", "/plane/")), "a 2 wide plane is refused")
	naval_check(!vehicle_draught_from_code(replacetext(good, "1,1,s,W,E", "1,1,a,W,E")), "an airframe section on a car axis is refused")
	naval_check(vehicle_draught_kinds_ok(), "the sheet is a kind of ship's draught")

	// ---- The checks ----
	var/datum/vehicle_draught/D = vehicle_draught_from_code(good)
	D.set_frame(1, 2, null)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "needs a frame"), "a tile with no frame is an error")
	D.set_frame(1, 2, "s")
	D.set_part(1, 1, null)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "no engine"), "no engine is an error")
	D.set_part(1, 1, "E")
	D.set_mover(2, 3, null)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "corner frames needs a wheel"), "a bare corner is an error")
	D.set_mover(2, 3, "W")
	D.set_mover(1, 2, "W")
	naval_check(sheet_report_has(D, DESIGN_WARNING, "left out"), "a wheel off the corners is a warning")
	D.set_mover(1, 2, null)
	D.set_engine("twostroke", 49)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "will stall"), "a tiny engine cannot move it")
	D.set_engine("gasoline", 2000)
	D.set_part(2, 1, null)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "no fuel tank"), "no tank is an error")
	D.set_part(2, 1, "T")
	D.set_part(1, 2, null)
	naval_check(sheet_report_has(D, DESIGN_ERROR, "no driver's seat"), "no seat is an error")
	D.set_part(1, 2, "D")
	D.set_part(2, 2, "D")
	naval_check(sheet_report_has(D, DESIGN_WARNING, "only one takes the controls"), "two driver's seats are a warning")
	qdel(D)
	var/datum/vehicle_draught/plane = examples[4]
	plane.set_part(2, 2, null)
	plane.set_part(2, 3, "D")
	naval_check(sheet_report_has(plane, DESIGN_WARNING, "no cockpit"), "a pilot's seat out of the wing row gets no cockpit")
	plane.set_part(1, 2, "U")
	naval_check(sheet_report_has(plane, DESIGN_ERROR, "cannot carry a tank turret"), "a plane cannot carry a turret")
	// A plane's sizes are its airframe's: 3 wide and 3 to 6 long, or a twin
	// 5 wide and 4 to 6 long, whose wings bear more the longer it is.
	naval_check(plane.size_allowed(3, 3) && plane.size_allowed(3, 6) && plane.size_allowed(5, 4) && plane.size_allowed(5, 6), "a plane may be 3 wide and 3 to 6 long or 5 wide and 4 to 6 long")
	naval_check(!plane.size_allowed(3, 7) && !plane.size_allowed(5, 3) && !plane.size_allowed(4, 4) && !plane.size_allowed(5, 7) && !plane.size_allowed(2, 4), "and no other size")
	var/datum/vehicle_draught/twin = examples[5]
	naval_check(twin.plane() && twin.width == 5 && twin.length == 5 && twin.axis_power() == 1500 && twin.crew() == 5, "the twin transport is 5 by 5 with wings bearing 1500 and five seats ([twin.axis_power()], [twin.crew()])")
	naval_check(twin.set_size(5, 6) && twin.axis_power() == 1600 && twin.set_size(5, 4) && twin.axis_power() == 1400, "a twin's wings bear 1400 at 4 long and 1600 at 6")
	naval_check(twin.set_axis("car") && twin.width == 5 && twin.length == 4 && twin.set_size(5, 5) && twin.set_axis("plane") && twin.length == 5 && twin.width == 5, "and it keeps a size both kinds allow when the axis changes")
	var/list/book = design_part_help_for("vehicle_sheet")
	var/list/missing = list()
	for (var/list/table in list(vehicle_draught_axes, vehicle_draught_frames, vehicle_draught_movers, vehicle_draught_parts, vehicle_draught_engines))
		for (var/key in table)
			if (!book[key])
				missing += key
	naval_check(!missing.len && book["x"], "every key on the sheet has a part description ([jointext(missing, " ")])")

	// ---- Building from a clipped sheet ----
	// The field car laid facing north: column 1 at x 20, row 1 at y 22.
	for (var/dx = 0, dx < 2, dx++)
		for (var/dy = 0, dy < 3, dy++)
			new /obj/structure/vehicleparts/frame(locate(20 + dx, 20 + dy, 1))
	var/obj/structure/engine/internal/gasoline/E = new(locate(20, 22, 1))
	E.enginesize = 2000
	E.anchored = FALSE
	var/obj/item/weapon/reagent_containers/glass/barrel/fueltank/T = new(locate(21, 22, 1))
	var/obj/structure/bed/chair/drivers/seat = new(locate(20, 21, 1))
	seat.anchored = FALSE
	for (var/turf/W in list(locate(20, 20, 1), locate(21, 20, 1), locate(20, 22, 1), locate(21, 22, 1)))
		new /obj/structure/vehicleparts/movement(W)
	var/obj/structure/vehicleparts/axis/car/A = new(locate(20, 21, 1))
	var/obj/item/ship_draught/sheet = new(locate(1, 1, 1))
	sheet.take_vehicle(car)
	naval_check(sheet.vehicle_draught_kind() && findtext(sheet.name, "vehicle sheet"), "the sheet carries the field car")
	naval_check(A.clip_sheet(sheet, null) && A.vehicle_sheet_code == sheet.draught_code, "the sheet clips to a light axis")
	var/datum/vehicle_survey/S = new(A)
	var/report = S.report()
	naval_check(findtext(report, "commander's seat") && findtext(report, "front to the north"), "the axis says the commander's seat is still missing ([report])")
	var/obj/structure/bed/chair/commander/C = new(locate(21, 21, 1))
	C.anchored = FALSE
	S = new(A)
	report = S.report()
	naval_check(findtext(report, "Everything on the sheet is laid out, front to the north"), "with it, everything is laid out ([report])")
	naval_check(A.sheet_facing() == NORTH, "and assembly offers north first")
	qdel(T)
	S = new(A)
	naval_check(findtext(S.report(), "large fuel tank"), "a missing tank is named")
	T = new(locate(21, 22, 1))
	var/obj/structure/vehicleparts/axis/heavy/H = new(locate(40, 40, 1))
	naval_check(!H.clip_sheet(sheet, null) && !H.vehicle_sheet_code, "a heavy axis does not take a light axis's sheet")

	// ---- Drawing it back ----
	naval_check(istext(vehicle_draught_survey(A)), "a loose axis has no lines to draw")
	naval_check(isnull(A.assemble(NORTH)), "the laid-out car assembles")
	var/datum/vehicle_draught/drawn = vehicle_draught_survey(A)
	naval_check(istype(drawn) && drawn.width == 2 && drawn.length == 3 && drawn.engine == "gasoline" && drawn.cc == 2000, "its lines are drawn 2 by 3 with its engine")
	if (istype(drawn))
		var/list/want = splittext(car.to_code(), "/")
		var/list/got = splittext(drawn.to_code(), "/")
		naval_check(want[want.len] == got[got.len], "tile for tile as the sheet ([got[got.len]])")

/proc/vehicle_draught_kinds_ok()
	var/list/K = draught_kinds["CAR"]
	return K && K["read"] == /proc/vehicle_draught_from_code

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
