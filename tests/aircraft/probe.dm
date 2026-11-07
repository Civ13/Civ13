// Modular aircraft phase 1: runway takeoff, flight on the level above,
// cruise, landing, crashes, stalls and passengers over open air.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 60
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/aircraft_probe/New()
	return
/mob/living/aircraft_probe/New()
	return
/obj/structure/aircraft_probe_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE
var/aircraft_failures = 0
var/aircraft_runtime_error = FALSE
/proc/aircraft_check(condition, label)
	if (!condition)
		aircraft_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	aircraft_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/aircraft_frames_z(obj/structure/vehicleparts/axis/aircraft/A, z)
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		if (F.z != z)
			return FALSE
	return TRUE

/proc/aircraft_front_y(obj/structure/vehicleparts/axis/aircraft/A)
	. = 1000
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		. = min(., F.y)

// One movement step the way movementloop() takes it.
/proc/aircraft_step(obj/structure/vehicleparts/axis/aircraft/A)
	if (!A.do_vehicle_check())
		return FALSE
	if (!A.do_move())
		return FALSE
	A.after_aircraft_move()
	return TRUE

/proc/aircraft_roll(obj/structure/vehicleparts/axis/aircraft/A, steps)
	A.moving = TRUE
	A.currentspeed = A.speeds
	for (var/i = 1, i <= steps, i++)
		if (A.airborne() || !aircraft_step(A))
			return i - 1
	return steps

/proc/aircraft_repair(obj/structure/vehicleparts/axis/aircraft/A)
	for (var/obj/structure/vehicleparts/movement/W in A.wheels)
		W.broken = FALSE
	A.engine.on = TRUE

// Every frame casts a shadow on the ground turf straight below it.
/proc/aircraft_shadows_below(obj/structure/vehicleparts/axis/aircraft/A, ground)
	var/list/F = A.frames()
	if (!A.shadows || A.shadows.len != F.len)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		var/obj/effect/aircraft_shadow/S = A.shadows[FR]
		var/turf/below = locate(FR.x, FR.y, ground)
		if (!S || !(S in below.vis_contents) || S.icon != FR.icon || S.color != "#000000" || S.loc || FR.vis_locs.len)
			return FALSE
	return TRUE

/proc/aircraft_ground_shown(obj/structure/vehicleparts/axis/aircraft/A, turf/T)
	return A.ground_view && (T in A.ground_view.vis_contents)

/proc/aircraft_visuals_gone(obj/structure/vehicleparts/axis/aircraft/A, list/old_turfs)
	if (A.shadows || A.ground_view || A.ground_view_anchor)
		return FALSE
	for (var/turf/T in old_turfs)
		for (var/atom/V in T.vis_contents)
			if (istype(V, /obj/effect/aircraft_shadow) || istype(V, /obj/effect/aircraft_ground_view))
				return FALSE
	return TRUE

/proc/aircraft_checks()
	// Ground: dirt-less plain turf on z1, open air over x 1-10 on z2.
	for (var/x = 1, x <= 10, x++)
		for (var/y = 1, y <= 60, y++)
			new /turf/sky/building(locate(x, y, 2))
	for (var/y = 1, y <= 55, y++)
		for (var/x = 3, x <= 5, x++)
			new /obj/covers/roads/modern/runway(locate(x, y, 1))

	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(2, 50, 1))
	aircraft_check(istype(A) && A.frames().len == 12 && A.components.len == 16, "the light plane builds twelve frames in a 4x4 turning square")
	aircraft_check(A.wheels.len == 4 && A.engine && A.engine.fueltank, "four wheels, an engine and a tank are connected")
	aircraft_check(istype(A.wheel, /obj/item/vehicleparts/wheel/modular/aircraft) && A.wheel.control && A.wheel.control.axis == A, "the pilot holds a control column that steers this aircraft")
	aircraft_check(A.on_runway(), "the plane starts on the runway")
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	aircraft_check(A.check_engine(), "the fuelled engine runs")

	var/mob/living/aircraft_probe/M = new(locate(4, 51, 1))
	var/obj/item/cargo = new /obj/item(locate(3, 52, 1))
	var/mob/living/aircraft_probe/walker = new(locate(5, 52, 1))

	// A slow roll never takes off.
	A.moving = TRUE
	A.currentspeed = 2
	for (var/i = 1, i <= 3, i++)
		aircraft_step(A)
	aircraft_check(!A.airborne() && A.runway_roll == 0 && A.flight_z() == 1, "rolling below full throttle stays on the ground")

	// Full throttle along the runway lifts it to the level above.
	var/rolled = aircraft_roll(A, A.takeoff_roll + 2)
	aircraft_check(A.airborne() && A.flight_state == AIRCRAFT_LOW && rolled == A.takeoff_roll, "a full-throttle roll of [A.takeoff_roll] runway tiles takes off")
	aircraft_check(aircraft_frames_z(A, 2) && A.flight_z() == 2 && E.z == 2, "the whole airframe moves to the level above")
	aircraft_check(M.z == 2 && cargo.z == 2, "the passenger and the cargo ride along instead of falling")
	aircraft_check(A in airborne_aircraft, "the aircraft is listed as airborne")
	aircraft_check(aircraft_shadows_below(A, 1), "each frame casts a shadow on the ground below it")
	var/obj/structure/vehicleparts/frame/nose = A.corners[2]
	aircraft_check(aircraft_ground_shown(A, locate(nose.x, nose.y, 1)) && aircraft_ground_shown(A, locate(nose.x - 3, nose.y - 6, 1)), "the open air shows the ground below and around the aircraft")
	aircraft_check(A.ground_view_anchor && A.ground_view_anchor.z == 2 && (A.ground_view in A.ground_view_anchor.vis_contents) && !A.ground_view.loc, "the ground view is drawn through the open air, not placed on the map")
	var/obj/covers/roof_floor = new /obj/covers/wood(locate(nose.x + 3, nose.y - 2, 2))
	A.update_flight_visuals()
	aircraft_check(!aircraft_ground_shown(A, locate(nose.x + 3, nose.y - 2, 1)) && aircraft_ground_shown(A, locate(nose.x + 4, nose.y - 2, 1)), "a floor on the upper level hides the ground under it")
	qdel(roof_floor)
	aircraft_check(A.shadows[nose]:pixel_x == 8, "low flight casts a close shadow")

	// Over open air: aboard is held, overboard falls.
	var/obj/structure/vehicleparts/frame/side = locate(/obj/structure/vehicleparts/frame) in locate(3, aircraft_front_y(A), 2)
	var/obj/item/dropped = new /obj/item(locate(8, 30, 1))
	dropped.forceMove(locate(8, 30, 2))
	aircraft_check(dropped.z == 1, "an item dropped onto open air away from the aircraft falls")
	var/obj/item/held = new /obj/item(locate(8, 31, 1))
	if (side)
		held.forceMove(side.loc)
	aircraft_check(side && held.z == 2, "an item put down on an airborne frame stays aboard")
	aircraft_check(walker.z == 2, "a second passenger rides along")
	walker.forceMove(locate(1, aircraft_front_y(A), 2))
	aircraft_check(walker.z == 1, "a passenger who steps off an airborne aircraft falls")

	// Low flight moves with everything aboard.
	var/y_before = aircraft_front_y(A)
	A.currentspeed = A.speeds
	aircraft_check(aircraft_step(A) && aircraft_front_y(A) == y_before - 1 && M.z == 2 && aircraft_frames_z(A, 2), "low flight moves the aircraft one tile and keeps the passenger aboard")
	aircraft_check(aircraft_shadows_below(A, 1) && !(locate(/obj/effect/aircraft_shadow) in locate(nose.x, nose.y + 4, 1).vis_contents), "the shadows follow the aircraft and leave the tiles behind it")

	// Cruise passes over upper storeys and will not descend into them.
	aircraft_check(A.climb(M) && A.flight_state == AIRCRAFT_CRUISE, "climb reaches cruising height")
	aircraft_check(A.shadows[nose]:pixel_x == 16, "cruise casts a farther shadow")
	aircraft_check(!A.climb(M), "climbing again is refused")
	var/obj/structure/aircraft_probe_wall/W = new(locate(4, aircraft_front_y(A) - 1, 2))
	aircraft_check(aircraft_step(A) && A.flight_state == AIRCRAFT_CRUISE, "cruise flies over an upper storey")
	aircraft_check(!A.descend(M) && A.flight_state == AIRCRAFT_CRUISE, "descending onto an upper storey is refused")
	for (var/i = 1, i <= 4, i++)
		aircraft_step(A)
	qdel(W)
	aircraft_check(A.descend(M) && A.flight_state == AIRCRAFT_LOW, "past it, descend returns to low flight")

	// Landing needs the runway below and approach speed.
	A.currentspeed = A.speeds
	aircraft_check(!A.descend(M) && A.airborne(), "landing too fast is refused")
	A.currentspeed = A.landing_gear
	var/list/shadowed = list()
	for (var/obj/effect/aircraft_shadow/S in A.shadow_turfs)
		shadowed += A.shadow_turfs[S]
	shadowed += A.ground_view_anchor
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1) && M.z == 1, "a slow descent over the runway lands with the passenger")
	aircraft_check(shadowed.len == 13 && aircraft_visuals_gone(A, shadowed), "a landed aircraft leaves no shadow or ground view behind")
	aircraft_check(!(A in airborne_aircraft) && A.currentspeed == 1, "a landed aircraft leaves the airborne list and slows")
	aircraft_check(!A.descend(M), "descending on the ground is refused")

	// Hitting an upper storey in low flight crashes.
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off again")
	var/obj/structure/aircraft_probe_wall/W2 = new(locate(4, aircraft_front_y(A) - 1, 2))
	A.currentspeed = A.speeds
	aircraft_check(!aircraft_step(A) && !A.airborne() && aircraft_frames_z(A, 1), "flying into an upper storey in low flight crashes to the ground")
	var/all_broken = TRUE
	for (var/obj/structure/vehicleparts/movement/WH in A.wheels)
		all_broken = all_broken && WH.broken
	aircraft_check(all_broken && !E.on && !A.moving, "a crash breaks the wheels and stops the engine")
	qdel(W2)

	// Losing lift in the air stalls it.
	aircraft_repair(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the repaired aircraft takes off again")
	E.on = FALSE
	sleep(4.5 SECONDS)
	aircraft_check(!A.airborne() && aircraft_frames_z(A, 1), "with the engine off it stalls and comes down")

	// Off the runway a landing must be forced with a second Descend.
	aircraft_repair(A)
	aircraft_roll(A, A.takeoff_roll)
	aircraft_check(A.airborne(), "the aircraft takes off a fourth time")
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		for (var/obj/covers/roads/modern/runway/R in locate(F.x, F.y, 1))
			qdel(R)
	A.currentspeed = A.landing_gear
	aircraft_check(!A.descend(M) && A.airborne() && A.force_landing_until > world.time, "descending with no runway below asks for confirmation")
	aircraft_check(A.descend(M) && !A.airborne() && aircraft_frames_z(A, 1), "a second Descend forces a crash landing")
	aircraft_check(aircraft_visuals_gone(A, list()), "a crashed aircraft drops its shadow and ground view")

	// Saved in flight: after a load the aircraft is set down on the ground.
	var/obj/structure/vehicleparts/axis/aircraft/D = build_light_plane(locate(6, 5, 2))
	aircraft_check(D.aloft_over_open_air() && !D.airborne(), "an aircraft restored over open air is aloft without flight state")
	D.engine.on = TRUE
	aircraft_check(D.set_down_after_restore() && aircraft_frames_z(D, 1) && !D.airborne() && !D.engine.on, "it is set down on the clear ground below with its engine off")
	var/intact = TRUE
	for (var/obj/structure/vehicleparts/movement/DW in D.wheels)
		intact = intact && !DW.broken
	aircraft_check(intact && !D.set_down_after_restore(), "a clear set-down keeps the wheels and happens once")
	new /obj/structure/aircraft_probe_wall(locate(8, 13, 1))
	var/obj/structure/vehicleparts/axis/aircraft/G = build_light_plane(locate(6, 12, 2))
	aircraft_check(G.set_down_after_restore() && aircraft_frames_z(G, 1), "one restored over an obstacle still comes down")
	var/wrecked = TRUE
	for (var/obj/structure/vehicleparts/movement/GW in G.wheels)
		wrecked = wrecked && GW.broken
	aircraft_check(wrecked, "and lands hard, breaking its wheels")
	var/obj/structure/vehicleparts/axis/aircraft/S = build_airstrip(locate(14, 30, 1))
	var/strip = 0
	for (var/turf/RT in block(locate(15, 18, 1), locate(17, 33, 1)))
		if (locate(/obj/covers/roads/modern/runway) in RT)
			strip++
	aircraft_check(istype(S) && S.on_runway() && strip == 48, "the airstrip spawner lays a 3x16 runway with the plane at its north end")
	S.engine.fueltank.reagents.add_reagent(S.engine:fuels[1], 100, safety = TRUE)
	S.engine.on = TRUE
	aircraft_roll(S, S.takeoff_roll)
	aircraft_check(S.airborne() && S.flight_z() == 2, "the plane takes off from the spawned airstrip")
	S.currentspeed = S.landing_gear
	aircraft_check(S.descend(null) && !S.airborne(), "and lands back on it")
	var/obj/structure/vehicleparts/axis/aircraft/P = build_light_plane(locate(11, 30, 1))
	aircraft_check(!P.aloft_over_open_air() && !P.set_down_after_restore(), "an aircraft restored on the ground stays put")

	// Off the runway it never takes off; with no level above it cannot.
	var/obj/structure/vehicleparts/axis/aircraft/B = build_light_plane(locate(11, 40, 1))
	var/obj/structure/engine/internal/BE = B.engine
	BE.fueltank.reagents.add_reagent(BE.fuels[1], 100, safety = TRUE)
	B.engine.on = TRUE
	aircraft_roll(B, 12)
	aircraft_check(!B.airborne() && B.flight_z() == 1 && B.runway_roll == 0, "a full-throttle roll off the runway stays on the ground")
	var/obj/structure/vehicleparts/axis/aircraft/C = build_light_plane(locate(12, 20, 2))
	aircraft_check(!C.try_takeoff() && C.flight_z() == 2 && !C.airborne(), "with no level above there is nowhere to climb")
	aircraft_check(!A.climb(M), "climb on the ground is refused")

	// The open-air hook only holds what an airborne aircraft carries.
	aircraft_check(!aircraft_holds(locate(8, 8, 2), dropped), "nothing is held once no aircraft is airborne")

/proc/aircraft_run()
	try
		aircraft_checks()
	catch(var/exception/e)
		aircraft_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = aircraft_failures, "runtime_error" = aircraft_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/aircraft_probe
		aircraft_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		aircraft_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		aircraft_run()
