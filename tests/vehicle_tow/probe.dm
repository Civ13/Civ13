// Tow lines between modular vehicles (code/modules/craft/vehicle_tow.dm,
// docs/craft-core.md): hitching a car behind another, the towed car rolling
// and turning where the tug did, the tug pulling its weight, a blocked tow
// snapping, no reversing with a line out, casting off and the refusals.
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

/obj/structure/tow_probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

/proc/tow_layout(obj/structure/vehicleparts/axis/A)
	var/turf/at = get_turf(A)
	var/list/out = list("axis d[A.dir]")
	for (var/obj/O in A.components)
		out += "[O.type] [O.x - at.x],[O.y - at.y] d[O.dir]"
	return jointext(out, " | ")

/proc/tow_car(x, y, kind = /obj/effects/premadevehicles/asno/piccolino)
	new kind(locate(x, y, 1))
	sleep(40)
	for (var/obj/structure/vehicleparts/axis/A in vehicle_axes)
		var/turf/T = get_turf(A)
		if (T && T.x == x + 2 && T.y == y + 1)
			return A
	return null

/proc/naval_checks()
	naval_fixture()
	// Both cars face south: the tug stands south of the car it will tow, one
	// tile between them.
	var/obj/structure/vehicleparts/axis/tug = tow_car(20, 30)
	var/obj/structure/vehicleparts/axis/towed = tow_car(20, 34)
	naval_check(tug && towed && tug.dir == SOUTH && towed.dir == SOUTH && tug.components.len >= 6, "two cars stand in line, facing south")
	var/alone = tug.get_weight()
	var/list/plan = towed.tow_plan()
	naval_check(plan && plan[1] == tug && plan[2] == 4, "the rear car finds the tug four tiles ahead of its axis ([towed.tow_refusal])")
	naval_check(isnull(tug.tow_plan()) && findtext(tug.tow_refusal, "no vehicle stands within"), "the tug has nothing ahead of it to hitch to")
	var/datum/vehicle_tow/line = towed.hitch_tow()
	naval_check(line && tug.tow_out == line && towed.tow_in == line && line.gap == 4 && line.owed() == 0, "the line is made fast")
	var/obj/structure/vehicleparts/frame/any = towed.components[1]
	naval_check((/obj/structure/vehicleparts/frame/proc/cast_off_tow_line in any.verbs) && findtext(towed.tow_text(), "A tow line runs from it") && findtext(tug.tow_text(), "It tows"), "both cars show the line and offer to cast it off")
	naval_check(isnull(towed.hitch_tow()) && findtext(towed.tow_refusal, "already on a tow line"), "a car takes one tow line")
	naval_check(tug.get_weight() == alone + towed.get_weight() && tug.get_weight() > alone, "the tug pulls the weight of both ([alone] + [towed.get_weight()])")

	// ---- Straight ahead ----
	var/shape = tow_layout(towed)
	var/turf/tug_at = get_turf(tug)
	var/turf/towed_at = get_turf(towed)
	naval_check(tug.do_move() && tug.do_move() && tug.do_move(), "the tug rolls three tiles south")
	naval_check(get_turf(tug) == locate(tug_at.x, tug_at.y - 3, 1) && get_turf(towed) == locate(towed_at.x, towed_at.y - 3, 1) && tow_layout(towed) == shape && line.owed() == 0, "and the towed car rolls three tiles behind it, whole")

	// ---- Round a corner ----
	if (isemptylist(tug.corners) || !tug.corners[1])
		tug.check_corners()
	if (isemptylist(tug.matrix))
		tug.check_matrix()
	naval_check(tug.do_matrix(SOUTH, EAST, "left") && tug.dir == EAST && towed.dir == SOUTH, "the tug turns left to the east; the towed car has not reached the corner")
	var/turf/corner = get_turf(tug)
	var/turned_shape = tow_layout(tug)
	for (var/i = 1, i <= 3, i++)
		tug.do_move()
	naval_check(towed.dir == SOUTH, "three tiles on, the towed car is still coming up to the corner")
	tug.do_move()
	var/turf/reached = get_turf(towed)
	naval_check(reached == corner && towed.dir == EAST && tow_layout(towed) == turned_shape, "at the fourth it reaches the corner and turns exactly where the tug did ([reached.x],[reached.y] against [corner.x],[corner.y])")
	tug.do_move()
	tug_at = get_turf(tug)
	towed_at = get_turf(towed)
	naval_check(towed_at.y == tug_at.y && tug_at.x - towed_at.x == 4 && line.owed() == 0, "and follows four tiles behind on the new heading ([tug_at.x - towed_at.x])")

	// ---- No reversing ----
	tug.reverse = TRUE
	tug_at = get_turf(tug)
	naval_check(!tug.do_move() && get_turf(tug) == tug_at, "the tug will not reverse with a line out")
	tug.reverse = FALSE

	// ---- Blocked ----
	var/obj/structure/vehicleparts/frame/nose = null
	for (var/obj/structure/vehicleparts/frame/F in towed.components)
		if (!nose || F.x > nose.x)
			nose = F
	var/obj/structure/tow_probe_rock/rock = new(get_step(nose, EAST))
	naval_check(findtext(line.blocked_ahead(), "probe rock"), "a rock lies in the towed car's way")
	towed_at = get_turf(towed)
	for (var/i = 1, i <= 3, i++)
		tug.do_move()
	naval_check(tug.tow_out == line && get_turf(towed) == towed_at && line.owed() == 3, "the tug drives on and the line pays out three tiles")
	tug.do_move()
	naval_check(!tug.tow_out && !towed.tow_in && QDELETED(line) && !(/obj/structure/vehicleparts/frame/proc/cast_off_tow_line in any.verbs) && get_turf(towed) == towed_at, "at the fourth it snaps and the towed car stays behind")
	naval_check(tug.get_weight() == alone, "the tug pulls only itself again")
	qdel(rock)

	// ---- Refusals ----
	naval_check(isnull(towed.hitch_tow()) && findtext(towed.tow_refusal, "no vehicle stands within"), "seven tiles behind is too far to hitch")
	for (var/i = 1, i <= 5, i++)
		towed.do_move()
	plan = towed.tow_plan()
	naval_check(plan && plan[1] == tug, "driven up behind the tug it can be hitched again ([towed.tow_refusal])")
	tug.currentspeed = 1
	naval_check(isnull(towed.hitch_tow()) && findtext(towed.tow_refusal, "stand still"), "but not while the tug is in gear")
	tug.currentspeed = 0
	line = towed.hitch_tow()
	naval_check(line && isnull(tug.hitch_tow()), "hitched again")

	// ---- Cast off, and a wreck ----
	var/turf/beside = get_turf(towed)
	line.part(null, TRUE)
	naval_check(!tug.tow_out && !towed.tow_in && (locate(/obj/item/stack/material/rope) in beside), "cast off, the rope lies beside the towed car")
	line = towed.hitch_tow()
	naval_check(line && tug.tow_out == line, "hitched a third time")
	qdel(towed)
	naval_check(!tug.tow_out && QDELETED(line), "a towed car that is destroyed lets the tug go")

// A truck tows a light plane on the ground (out of a hangar, along a taxiway),
// but never one in the air, and a towed plane cannot take off.
/proc/tow_plane_checks()
	var/obj/structure/vehicleparts/axis/tug = tow_car(40, 20, /obj/effects/premadevehicles/truck/daf)
	var/obj/structure/vehicleparts/frame/rear = null
	for (var/obj/structure/vehicleparts/frame/F in tug.components)
		if (!rear || F.y > rear.y)
			rear = F
	var/obj/structure/vehicleparts/axis/aircraft/plane = build_light_plane(locate(40, rear.y + 2, 1))
	naval_check(istype(plane) && plane.dir == SOUTH && tug.dir == SOUTH, "a light plane stands behind a truck, both facing south")
	var/datum/vehicle_tow/line = plane.hitch_tow()
	naval_check(line && tug.tow_out == line && plane.tow_in == line, "the plane is hitched behind the truck ([plane.tow_refusal])")
	var/turf/plane_at = get_turf(plane)
	tug.engine.on = TRUE
	naval_check(tug.check_engine(), "the truck can pull the plane's weight ([tug.get_weight()] of [tug.maxpower])")
	naval_check(tug.do_move() && tug.do_move(), "the truck rolls two tiles")
	naval_check(get_turf(plane) == locate(plane_at.x, plane_at.y - 2, 1) && !plane.airborne(), "and the plane rolls after it on its wheels")
	plane.engine.on = TRUE
	plane.currentspeed = plane.speeds
	plane.runway_roll = plane.takeoff_roll
	naval_check(!plane.try_takeoff() && !plane.airborne() && plane.runway_roll == 0, "a towed plane cannot take off")
	line.part(null, TRUE)
	plane.currentspeed = 0
	plane.engine.on = FALSE
	tug.engine.on = FALSE
	plane.flight_state = AIRCRAFT_LOW
	naval_check(isnull(plane.hitch_tow()) && findtext(plane.tow_refusal, "in the air"), "a plane in the air cannot take a tow line")
	plane.flight_state = AIRCRAFT_GROUND

/proc/naval_run()
	try
		naval_checks()
		tow_plane_checks()
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
