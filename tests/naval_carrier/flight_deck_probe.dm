// Turf-built vessels, phase 2: the carrier's flight deck is a runway. A light
// plane takes off along it, a parked plane rides a hop, a landing on the
// arresting wires stops on the spot, the crash barrier keeps a rolling plane
// on the deck, and the elevators move aircraft and cargo between the hangar
// and the flight deck.
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
/obj/map_metadata/naval_probe/New()
	return
/mob/living/human/naval_probe/New()
	return
/obj/structure/naval_probe_wall
	name = "probe wall"
	density = TRUE
	anchored = TRUE
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
			var/turf/R = locate(x, y, 1)
			R.ChangeTurf(/turf/wall/rockwall)
			var/turf/W = locate(x, y, 2)
			W.ChangeTurf(/turf/floor/beach/water/deep/saltwater)
			var/turf/S = locate(x, y, 3)
			S.ChangeTurf(/turf/sky/building)

/proc/naval_count(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			if (istype(locate(x, y, z), path))
				.++

/proc/naval_count_objects(z, path)
	. = 0
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, z)
			if (locate(path) in T)
				.++

// All frames on level z, inside the x and y ranges given.
/proc/naval_frames_in(obj/structure/vehicleparts/axis/aircraft/A, z, x1, x2, y1, y2)
	var/list/F = A.frames()
	if (F.len != 12)
		return FALSE
	for (var/obj/structure/vehicleparts/frame/FR in F)
		if (FR.z != z || FR.x < x1 || FR.x > x2 || FR.y < y1 || FR.y > y2)
			return FALSE
	return TRUE

/proc/naval_frames_on(obj/structure/vehicleparts/axis/aircraft/A, path)
	for (var/obj/structure/vehicleparts/frame/FR in A.frames())
		if (!istype(get_turf(FR), path))
			return FALSE
	return TRUE

/proc/naval_front_y(obj/structure/vehicleparts/axis/aircraft/A)
	. = 1000
	for (var/obj/structure/vehicleparts/frame/F in A.frames())
		. = min(., F.y)

/proc/naval_step(obj/structure/vehicleparts/axis/aircraft/A)
	if (!A.do_vehicle_check())
		return FALSE
	if (!A.do_move())
		return FALSE
	A.after_aircraft_move()
	return TRUE

/proc/naval_roll(obj/structure/vehicleparts/axis/aircraft/A, steps)
	A.moving = TRUE
	A.currentspeed = A.speeds
	for (var/i = 1, i <= steps, i++)
		if (A.airborne() || !naval_step(A))
			return i - 1
	return steps

/proc/naval_fuel(obj/structure/vehicleparts/axis/aircraft/A)
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE

/proc/naval_checks()
	naval_fixture()

	// The carrier lies bow north with its south-west corner at (10, 10): ship
	// cell (u, v) is world tile (10 + v, 10 + u). The deck runs from y 10
	// (stern) to y 49 (bow), the wires lie at y 16-19, the elevator platforms
	// at x 11-14, y 24-27 and y 36-39 with their levers at (12, 28) and
	// (12, 35), and the island stands at x 16-18, y 28-32 on the level above.
	// The light plane is three frames wide in a 4x4 turning square: built at
	// (11, y) it stands on x 12-14.
	var/datum/vessel/carrier/C = carrier_lay_down(locate(10, 10, 2), NORTH)
	naval_check(istype(C) && C.placed && C.dir == NORTH, "the carrier is laid down bow north")
	if (!istype(C))
		return
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck) == 360 && naval_count(2, /turf/floor/plating/carrier_deck/wires) == 36 && naval_count(2, /turf/floor/plating/carrier_deck/elevator) == 32, "the flight deck has 360 tiles, 36 of arresting wires and 32 of elevator platform")
	naval_check(naval_count(1, /turf/floor/sub_deck/carrier/hangar) == 113 && naval_count(1, /turf/floor/sub_deck/carrier/hangar/elevator) == 32, "the hangar keeps 113 deck tiles, 32 of them elevator floor")
	naval_check(naval_count_objects(2, /obj/structure/vessel_elevator_lever) == 2 && naval_count_objects(1, /obj/structure/vessel_elevator_lever) == 2, "each elevator has a lever on the flight deck and one in the hangar")
	naval_check(istype(locate(12, 17, 2), /turf/floor/plating/carrier_deck/wires) && istype(locate(11, 24, 2), /turf/floor/plating/carrier_deck/elevator) && istype(locate(14, 39, 1), /turf/floor/sub_deck/carrier/hangar/elevator) && (locate(/obj/structure/vessel_elevator_lever) in locate(12, 28, 2)) && (locate(/obj/structure/vessel_elevator_lever) in locate(12, 35, 1)), "wires, platforms and levers lie where the plan puts them")
	var/obj/structure/vessel_elevator_lever/L1 = locate(/obj/structure/vessel_elevator_lever) in locate(12, 28, 2)
	var/obj/structure/vessel_elevator_lever/L1_hangar = locate(/obj/structure/vessel_elevator_lever) in locate(12, 28, 1)
	var/obj/structure/vessel_elevator_lever/L2 = locate(/obj/structure/vessel_elevator_lever) in locate(12, 35, 2)
	naval_check(L1 && L1.vessel == C && L1.platform().len == 16 && L2 && L2.platform().len == 16 && (L1.platform() & L2.platform()).len == 0 && L1_hangar && L1_hangar.platform().len == 16, "each lever serves its own 16-tile platform")
	naval_check(L1.target_z() == 1 && L1_hangar.target_z() == 2, "the deck lever goes down to the hangar and the hangar lever up to the deck")

	// The deck is a runway; the island deck and the sea are not.
	naval_check(aircraft_runway_at(locate(12, 20, 2)) && aircraft_runway_at(locate(12, 17, 2)) && aircraft_runway_at(locate(12, 25, 2)), "deck, wires and elevator tiles count as runway")
	naval_check(!aircraft_runway_at(locate(17, 30, 3)) && !aircraft_runway_at(locate(30, 30, 2)) && !aircraft_runway_at(locate(12, 20, 1)), "the island deck, the sea and the hangar floor do not")

	// A light plane takes off along the deck.
	var/mob/living/human/naval_probe/pilot = new(locate(30, 5, 2))
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(11, 40, 2))
	naval_check(istype(A) && A.frames().len == 12 && A.on_runway(), "a light plane built on the deck stands on runway")
	naval_fuel(A)
	var/rolled = naval_roll(A, A.takeoff_roll + 2)
	naval_check(A.airborne() && A.flight_state == AIRCRAFT_LOW && rolled == A.takeoff_roll && naval_frames_in(A, 3, 11, 14, 32, 35), "a full-throttle roll of [A.takeoff_roll] deck tiles lifts it into the air above the ship")

	// A parked plane and a crate ride a hop; the plane in the air does not.
	var/obj/structure/vehicleparts/axis/aircraft/P = build_light_plane(locate(11, 20, 2))
	var/obj/structure/closet/crate/crate = new(locate(12, 12, 2))
	C.bunker(C.fuel_capacity)
	C.set_anchor(FALSE)
	C.set_speed(VESSEL_SPEED_SLOW)
	C.stop_sailing()
	naval_check(C.sail_tick() && C.ox == 10 && C.oy == 12, "a hop at slow ahead moves the ship two tiles north ([C.ox],[C.oy])")
	naval_check(naval_frames_in(P, 2, 11, 14, 22, 25) && P.loc && istype(P.loc, /obj/structure/vehicleparts/frame) && naval_frames_on(P, /turf/floor/plating/carrier_deck), "the parked plane rides the hop whole and still stands on the deck")
	naval_check(crate.loc == locate(12, 14, 2) && istype(locate(12, 18, 2), /turf/floor/plating/carrier_deck/wires) && istype(locate(12, 16, 2), /turf/floor/plating/carrier_deck) && !istype(locate(12, 16, 2), /turf/floor/plating/carrier_deck/wires), "the crate and the wires move with the deck")
	naval_check(naval_frames_in(A, 3, 11, 14, 32, 35), "the plane in the air stays where it flies")
	naval_check(P.on_runway() && !P.airborne(), "the parked plane is still on runway after the hop")
	naval_check(C.relocate(10, 10, NORTH) && naval_frames_in(P, 2, 11, 14, 20, 23) && crate.loc == locate(12, 12, 2), "moving the ship back brings the plane and crate back")
	C.set_speed(VESSEL_SPEED_STOP)

	// Landing on the wires stops the plane on the spot.
	A.aircraft_shift(3, 0, 16 - naval_front_y(A))
	A.moving = TRUE
	A.currentspeed = A.landing_gear
	naval_check(A.descend(pilot) && !A.airborne() && naval_frames_in(A, 2, 11, 14, 16, 19), "descending over the wires lands on the deck")
	naval_check(A.currentspeed == 0 && !A.moving && A.on_arresting_wires(), "the tailhook catches the wire and the plane stops at once")

	// Landing on plain deck rolls on at taxi speed.
	A.aircraft_shift(3, 0, 31 - naval_front_y(A))
	A.set_flight_state(AIRCRAFT_LOW)
	A.moving = TRUE
	A.currentspeed = A.landing_gear
	naval_check(A.descend(pilot) && !A.airborne() && naval_frames_in(A, 2, 11, 14, 31, 34) && A.currentspeed == 1 && A.moving && !A.on_arresting_wires(), "a landing clear of the wires rolls on at taxi speed")

	// The crash barrier: the step off the stern is refused.
	A.aircraft_shift(2, 0, 10 - naval_front_y(A))
	A.moving = TRUE
	A.currentspeed = 1
	naval_check(!A.do_vehicle_check() && !A.moving && A.currentspeed == 0 && naval_frames_in(A, 2, 11, 14, 10, 13), "a plane rolling off the stern is stopped by the crash barrier")
	naval_check(A.deck_edge_ahead(), "the deck edge is reported ahead of it")
	A.aircraft_shift(2, 0, 30 - naval_front_y(A))
	A.moving = TRUE
	A.currentspeed = 1
	naval_check(!A.deck_edge_ahead() && A.do_vehicle_check(), "amidships the deck continues and the plane may roll")
	A.moving = FALSE
	A.currentspeed = 0

	// The elevator takes a plane and a crate down to the hangar and back up.
	A.aircraft_shift(2, 0, 24 - naval_front_y(A))
	var/obj/structure/closet/crate/load = new(locate(13, 25, 2))
	naval_check(naval_frames_on(A, /turf/floor/plating/carrier_deck/elevator), "the plane is parked on the forward elevator")
	var/refusal = L1.operate(pilot)
	naval_check(!refusal && naval_frames_in(A, 1, 11, 14, 24, 27) && naval_frames_on(A, /turf/floor/sub_deck/carrier/hangar/elevator) && load.loc == locate(13, 25, 1), "the deck lever lowers the plane and the crate to the hangar ([refusal])")
	naval_check(A.loc && istype(A.loc, /obj/structure/vehicleparts/frame) && A.flight_z() == 1 && !A.airborne(), "the plane's controls ride down inside the airframe")
	refusal = L1_hangar.operate(pilot)
	naval_check(!refusal && naval_frames_in(A, 2, 11, 14, 24, 27) && load.loc == locate(13, 25, 2), "the hangar lever lifts them back to the flight deck ([refusal])")

	// Refusals: a plane half on the platform, a blocked hangar, a moving plane.
	A.aircraft_shift(2, 0, 1)
	refusal = L1.operate(pilot)
	naval_check(refusal && naval_frames_in(A, 2, 11, 14, 25, 28), "a plane half on the platform keeps the elevator still ([refusal])")
	A.aircraft_shift(2, 0, -1)
	var/obj/structure/naval_probe_wall/block = new(locate(12, 24, 1))
	refusal = L1.operate(pilot)
	naval_check(refusal && naval_frames_in(A, 2, 11, 14, 24, 27) && load.z == 2, "a blocked hangar floor keeps the elevator still ([refusal])")
	qdel(block)
	A.moving = TRUE
	refusal = L1.operate(pilot)
	naval_check(refusal && naval_frames_in(A, 2, 11, 14, 24, 27), "a plane still rolling keeps the elevator still ([refusal])")
	A.moving = FALSE
	naval_check(!QDELETED(L2) && L2.loc == locate(12, 35, 2), "the plane that took off over the after lever left it standing")
	refusal = L2.operate(pilot)
	naval_check(!refusal && load.z == 2, "an empty elevator moves without complaint ([refusal])")

	// Removal puts the sea back under wires and platforms too.
	C.remove()
	naval_check(naval_count(2, /turf/floor/plating/carrier_deck) == 0 && naval_count(1, /turf/floor/sub_deck/carrier/hangar/elevator) == 0 && istype(locate(12, 17, 2), /turf/floor/beach/water/deep), "removing the ship restores the sea under wires and platforms")

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
