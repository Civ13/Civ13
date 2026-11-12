// Vehicles aboard a craft (code/modules/craft/vehicle_aboard.dm,
// docs/craft-core.md): a modular car on a built hull rides a hop whole, is
// swung round by a turn exactly as if it had turned itself, still drives and
// steers afterwards, and a car parked half aboard holds the ship.
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

/datum/craft_drive/probe_push
	thrust = 1000

/obj/structure/probe_gun
	name = "probe gun"
	anchored = TRUE
/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

// A plank laid the way a player lays one, with its first update already run.
/proc/hull_lay(x, y)
	var/turf/T = locate(x, y, 2)
	var/obj/covers/repairedfloor/ship/C = new(T)
	C.updateturf()
	return C

/proc/hull_planks(turf/T)
	. = 0
	for (var/obj/covers/C in T)
		.++

// Every part of a vehicle as an offset from its axis, with its facing, so
// two vehicles can be compared wherever they stand.
/proc/ferry_layout(obj/structure/vehicleparts/axis/A)
	var/turf/at = get_turf(A)
	var/list/out = list("axis d[A.dir]")
	for (var/obj/O in A.components)
		out += "[O.type] [O.x - at.x],[O.y - at.y] d[O.dir]"
	return jointext(out, " | ")

// TRUE when every wheel faces as the vehicle's own turn would leave it.
/proc/ferry_wheels_true(obj/structure/vehicleparts/axis/A)
	for (var/obj/structure/vehicleparts/movement/W in A.wheels)
		if (W.dir != (W.reversed ? OPPOSITE_DIR(A.dir) : A.dir))
			return FALSE
	return TRUE

/proc/naval_checks()
	naval_fixture()
	for (var/x = 40, x <= 48, x++)
		for (var/y = 20, y <= 28, y++)
			hull_lay(x, y)
	var/obj/structure/hull_tiller/tiller = new(locate(40, 20, 2))
	naval_check(isnull(tiller.commission("Ferry", NORTH)), "the ferry is commissioned")
	var/datum/craft/C = tiller.craft
	// One car on her deck, one ashore to compare with, each built the way a
	// mapped car is.
	new /obj/effects/premadevehicles/asno/piccolino(locate(42, 22, 2))
	new /obj/effects/premadevehicles/asno/piccolino(locate(10, 10, 2))
	sleep(40)
	var/obj/structure/vehicleparts/axis/A = null
	var/obj/structure/vehicleparts/axis/L = null
	for (var/obj/structure/vehicleparts/axis/X in vehicle_axes)
		var/turf/T = get_turf(X)
		if (T && T.x > 30)
			A = X
		else
			L = X
	naval_check(A && L && A.components.len >= 6 && A.wheels.len == 4, "two cars are assembled, one aboard")
	naval_check(C.body.contains(get_turf(A)) && isnull(craft_overhang(C.body.cells())), "the car aboard stands wholly on her deck")
	var/shape = ferry_layout(A)
	naval_check(shape == ferry_layout(L), "both cars start alike")

	// ---- A hop carries her whole ----
	C.set_anchor(FALSE)
	var/turf/was = get_turf(A)
	naval_check(C.body.move_to(C.body.origin().x, C.body.origin().y + 2, NORTH) && get_turf(A) == locate(was.x, was.y + 2, 2) && ferry_layout(A) == shape, "a hop carries the car two tiles with every part in place")

	// ---- A turn swings her round with the deck ----
	L.check_corners()
	L.check_matrix()
	naval_check(C.body.turn_to(EAST) && L.do_matrix(L.dir, turn(L.dir, -90), "right"), "the ferry comes about to the east; the car ashore turns right")
	naval_check(A.dir == L.dir && ferry_layout(A) == ferry_layout(L), "the car aboard is turned exactly as a car that turned itself ([ferry_layout(A)])")
	naval_check(ferry_wheels_true(A) && ferry_wheels_true(L), "and her wheels face as a turn of her own would leave them")
	naval_check(C.body.contains(get_turf(A)) && isnull(craft_overhang(C.body.cells())), "and still stands wholly on her deck")
	// She still drives and steers.
	was = get_turf(A)
	var/turf/ahead = get_step(was, A.dir)
	naval_check(A.do_move() && L.do_move() && get_turf(A) == ahead && ferry_layout(A) == ferry_layout(L), "the car drives one tile the way she now faces, as the car ashore does")
	if (!A.corners[1])
		A.check_corners()
	if (isemptylist(A.matrix))
		A.check_matrix()
	var/turned_a = A.do_matrix(A.dir, turn(A.dir, 90), "left")
	var/turned_l = L.do_matrix(L.dir, turn(L.dir, 90), "left")
	naval_check(turned_a && turned_l && ferry_layout(A) == ferry_layout(L), "and turns herself back as the car ashore does ([ferry_layout(A)])")
	var/round = C.body.turn_to(SOUTH) && C.body.turn_to(WEST) && C.body.turn_to(NORTH)
	naval_check(round && L.do_matrix(L.dir, turn(L.dir, 90), "left") && A.dir == EAST && ferry_layout(A) == ferry_layout(L) && ferry_wheels_true(A), "three more turns of the ferry swing the car three quarters round ([round], [C.body.last_refusal], d[A.dir])")
	naval_check(C.body.contains(get_turf(A)) && isnull(craft_overhang(C.body.cells())), "and she is still wholly aboard")

	// ---- Half aboard ----
	new /obj/effects/premadevehicles/asno/piccolino(locate(C.body.origin().x + 7, C.body.origin().y + 3, 2))
	sleep(40)
	var/obj/structure/vehicleparts/axis/half = craft_overhang(C.body.cells())
	naval_check(half && half != A, "a car parked over her side is found")
	var/turf/O = C.body.origin()
	naval_check(!C.body.can_move_to(O.x, O.y + 2, NORTH) && findtext(C.body.last_refusal, "stands half aboard"), "and the ferry will not hop and tear it in two ([C.body.last_refusal])")
	naval_check(!C.body.turn_to(EAST) && findtext(C.body.last_refusal, "stands half aboard"), "nor come about")
	for (var/obj/structure/vehicleparts/frame/F in half.components)
		qdel(F)
	naval_check(isnull(craft_overhang(C.body.cells())) && C.body.can_move_to(O.x, O.y + 2, NORTH), "with it gone she is free to sail")

	// ---- A slipway ship's deck checks the same ----
	var/datum/vessel/schooner/V = new
	naval_check(V.place(30, 40, 2, EAST), "a schooner is laid on the sea ([V.last_refusal])")
	naval_check(isnull(craft_overhang(V.cells())) && V.relocate(V.ox, V.oy + 1, EAST), "with nothing over her side she moves")

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
