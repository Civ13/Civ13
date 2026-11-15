// Taxiing: on the ground a plane drives like a car. Runs on a clean fixture
// before the flight cases and removes everything it builds.

/proc/aircraft_taxi_square(obj/structure/vehicleparts/axis/aircraft/A)
	var/list/box = list(1000, 1000, 0, 0)
	for (var/atom/movable/C in A.components)
		var/turf/T = get_turf(C)
		if (!T)
			continue
		box[1] = min(box[1], T.x)
		box[2] = min(box[2], T.y)
		box[3] = max(box[3], T.x)
		box[4] = max(box[4], T.y)
	return box

/proc/aircraft_taxi_turn(obj/structure/vehicleparts/axis/aircraft/A, side)
	A.wheel.lastdirchange = world.time - 1
	return A.wheel.turndir(null, side)

// Steps in the current heading until the test says stop or a step fails.
/proc/aircraft_taxi_until(obj/structure/vehicleparts/axis/aircraft/A, x_to = 0, y_to = 0, limit = 30)
	for (var/i = 1, i <= limit, i++)
		var/list/box = aircraft_taxi_square(A)
		if ((x_to && box[1] == x_to) || (y_to && box[2] == y_to))
			return TRUE
		if (A.airborne() || !aircraft_step(A))
			return FALSE
	return FALSE

/proc/aircraft_taxi_checks()
	// Plain ground at x 11-20, y 1-28 with a hangar whose bay is x 15-18, y 3-6.
	var/obj/structure/car_workshop/hangar/hangar = new(locate(14, 2, 1))
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(11, 20, 1))
	aircraft_check(istype(A) && A.dir == SOUTH && aircraft_taxi_square(A) ~= list(11, 20, 14, 23), "a plane parked facing south fills its 4x4 square")
	A.engine.on = TRUE
	A.moving = TRUE
	A.currentspeed = 1
	A.vehicle_m_delay = A.get_speed()
	aircraft_check(aircraft_step(A) && aircraft_step(A) && aircraft_taxi_square(A)[2] == 18 && !A.airborne(), "first gear taxis the plane forward on open ground")
	aircraft_check(aircraft_taxi_turn(A, "left") && A.dir == EAST, "steering left on the ground turns the plane east")
	aircraft_check(aircraft_taxi_until(A, x_to = 15) && A.dir == EAST && !A.airborne(), "it taxis east along the apron")
	aircraft_check(aircraft_taxi_turn(A, "right") && A.dir == SOUTH, "steering right turns it back south toward the hangar")
	A.reverse = TRUE
	var/back_y = aircraft_taxi_square(A)[2]
	aircraft_check(aircraft_step(A) && aircraft_taxi_square(A)[2] == back_y + 1 && A.dir == SOUTH, "reverse backs the plane up without turning it")
	A.reverse = FALSE
	aircraft_check(aircraft_taxi_until(A, y_to = 3) && !vehicle_storage_parked(hangar, FALSE).len, "it taxis forward into the hangar bay")
	var/list/parked = vehicle_storage_parked(hangar, TRUE)
	aircraft_check((A in parked) && aircraft_taxi_square(A) ~= list(15, 3, 18, 6), "the taxied plane sits wholly in the bay, ready to hangar")
	A.reverse = TRUE
	aircraft_check(aircraft_taxi_until(A, y_to = 8) && !(A in vehicle_storage_parked(hangar, TRUE)), "it backs out of the bay again")
	A.reverse = FALSE

	// Full throttle along open ground stays on the ground: no surprise takeoff.
	A.currentspeed = A.speeds
	aircraft_check(aircraft_taxi_turn(A, "left") && A.dir == EAST, "at full throttle it still steers")
	A.reverse = TRUE
	var/rolled = 0
	for (var/i = 1, i <= 2, i++)
		if (aircraft_step(A))
			rolled++
	A.reverse = FALSE
	aircraft_check(rolled == 2 && !A.airborne() && A.runway_roll == 0, "reversing at full throttle never builds a takeoff roll")

	for (var/atom/movable/part in A.components.Copy())
		if (part != A)
			qdel(part)
	for (var/turf/T in block(locate(11, 1, 1), locate(20, 28, 1)))
		for (var/atom/movable/M in T)
			if (!istype(M, /atom/movable/lighting_overlay))
				qdel(M)
	qdel(A)
	qdel(hangar)
