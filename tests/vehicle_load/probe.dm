// Vehicle load (code/modules/1713/machinery/modular_vehicles/vehicle_load.dm):
// a crewed vehicle keeps its listed gear delays, cargo past the allowance
// slows it within the cap, a light vehicle gets the extra top gear, turning
// follows the load, and boats and aircraft keep their own speeds.
/world
	hub = ""
	hub_password = ""
	maxx = 40
	maxy = 40
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/load_probe/New()
	return
/obj/map_metadata/load_probe/is_node_done(faction, node_id)
	return TRUE
/mob/living/human/load_probe/New()
	return
var/load_failures = 0
var/load_runtime_error = FALSE
/proc/load_check(condition, label)
	if (!condition)
		load_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	load_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/load_fixture()
	for (var/x = 1, x <= world.maxx, x++)
		for (var/y = 1, y <= world.maxy, y++)
			var/turf/T = locate(x, y, 1)
			T.ChangeTurf(/turf/floor/beach/sand)

// A hand-built w by h vehicle with an engine, a tank, a driver's seat, extra
// seats and four wheels, assembled facing north on axis type A_type.
/proc/load_vehicle(x, y, w, h, A_type, extra_seats = 0, armour = 0)
	for (var/dx = 0, dx < w, dx++)
		for (var/dy = 0, dy < h, dy++)
			var/obj/structure/vehicleparts/frame/F = new(locate(x + dx, y + dy, 1))
			if (armour)
				if (dy == h - 1)
					F.w_front = list("c_armoredwall", TRUE, TRUE, armour, 90, FALSE, FALSE)
				if (dy == 0)
					F.w_back = list("c_armoredwall", TRUE, TRUE, armour, 90, FALSE, FALSE)
				if (dx == 0)
					F.w_left = list("c_armoredwall", TRUE, TRUE, armour, 90, FALSE, FALSE)
				if (dx == w - 1)
					F.w_right = list("c_armoredwall", TRUE, TRUE, armour, 90, FALSE, FALSE)
	var/obj/structure/engine/internal/E = new /obj/structure/engine/internal/gasoline/premade/v6(locate(x, y + 1, 1))
	E.anchored = FALSE
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline(locate(x + 1, y + 1, 1))
	var/obj/structure/bed/chair/drivers/D = new(locate(x + 1, y, 1))
	D.anchored = FALSE
	for (var/i = 1, i <= extra_seats, i++)
		var/obj/structure/bed/chair/gunner/G = new(locate(x + (i % w), y + h - 1, 1))
		G.anchored = FALSE
	for (var/turf/T in list(locate(x, y, 1), locate(x + w - 1, y, 1), locate(x, y + h - 1, 1), locate(x + w - 1, y + h - 1, 1)))
		new /obj/structure/vehicleparts/movement(T)
	var/obj/structure/vehicleparts/axis/A = new A_type(locate(x, y, 1))
	var/why = A.assemble(NORTH)
	load_check(isnull(why), "a [w] by [h] vehicle assembles ([why])")
	return A

/proc/load_person(turf/T)
	var/mob/living/human/load_probe/H = new(T)
	H.mob_size = MOB_MEDIUM
	// A crew member takes the seat on their tile, as a driver does.
	var/obj/structure/bed/chair/C = locate() in T
	if (C && !C.buckled_mob)
		H.buckled = C
		C.buckled_mob = H
	return H

/proc/load_checks()
	load_fixture()

	// ---- A crewed car drives at its listed speeds ----
	var/obj/structure/vehicleparts/axis/car/car = load_vehicle(5, 5, 2, 3, /obj/structure/vehicleparts/axis/car)
	load_check(car.uses_load_factor(), "a car's speed follows its load")
	load_check(car.get_load_factor(TRUE) == 1, "an empty car reads exactly 1.0 ([car.load_factor])")
	load_check(load_person(locate(6, 5, 1)), "the driver sits in")
	load_check(car.get_load_factor(TRUE) == 1, "with its driver it still reads 1.0 ([car.load_factor])")
	var/same = TRUE
	for (var/gear = 1, gear <= car.speeds, gear++)
		car.currentspeed = gear
		if (car.get_speed() != car.speedlist[gear])
			same = FALSE
	load_check(same, "every gear keeps its listed delay")
	load_check(car.top_gear() == car.speeds, "and there is no extra gear")
	var/turn_was = car.loaded_turntimer()
	load_check(turn_was == car.turntimer, "turning takes its usual time ([turn_was])")

	// ---- Cargo past the allowance slows it ----
	var/list/crates = list()
	for (var/i = 1, i <= 6, i++)
		crates += new /obj/structure/closet/crate(locate(5, 7, 1))
	load_check(car.get_load_factor(TRUE) == 1, "six empty crates fit in its allowance ([car.load_factor])")
	var/obj/structure/closet/crate/packed = crates[1]
	for (var/i = 1, i <= 10, i++)
		new /obj/item/weapon/reagent_containers/glass/bucket(packed)
	var/loaded = car.get_load_factor(TRUE)
	load_check(loaded > 1 && loaded < VEHICLE_LOAD_MAX, "packing one with buckets slows it down ([loaded])")
	car.currentspeed = car.speeds
	load_check(abs(car.get_speed() + 1 - (car.speedlist[car.speeds] + 1) * loaded) < 0.001, "the time its top gear takes per tile grows with the load ([car.get_speed()])")
	load_check(car.loaded_turntimer() > turn_was, "and turns take longer ([car.loaded_turntimer()])")
	load_check(findtext(car.load_description(), "loaded down"), "examine says it is loaded down ([car.load_description()])")
	for (var/i = 1, i <= 40, i++)
		crates += new /obj/structure/closet/crate(locate(6, 6, 1))
	load_check(car.get_load_factor(TRUE) == VEHICLE_LOAD_MAX, "a huge load is held to the cap ([car.load_factor])")
	load_check(findtext(car.load_description(), "overloaded"), "and examine says it is overloaded")
	for (var/obj/O in crates)
		qdel(O)
	load_check(car.get_load_factor(TRUE) == 1, "unloaded it reads 1.0 again ([car.load_factor])")

	// ---- The cache ----
	car.get_load_factor(TRUE)
	var/obj/structure/closet/crate/late = new(locate(5, 5, 1))
	for (var/i = 1, i <= 9, i++)
		new /obj/structure/closet/crate(locate(5, 5, 1))
	load_check(car.get_load_factor() == 1, "within the recheck window the cached factor is used")
	load_check(car.get_load_factor(TRUE) > 1, "a forced check sees the new cargo ([car.load_factor])")
	for (var/obj/structure/closet/crate/C in get_turf(late))
		qdel(C)
	car.get_load_factor(TRUE)

	// ---- A light vehicle gets an extra top gear ----
	car.load_factor = 0.75
	car.load_checked_at = world.time
	load_check(car.top_gear() == car.speeds + 1, "a light vehicle can shift into one more gear")
	car.currentspeed = car.speeds + 1
	var/bonus = car.get_speed()
	load_check(car.gear_delay(car.speeds + 1) < car.speedlist[car.speeds], "that gear is quicker than the last ([car.gear_delay(car.speeds + 1)])")
	load_check(bonus <= car.gear_delay(car.speeds + 1) && bonus >= 0.2, "and lightened, down to the floor ([bonus])")
	car.currentspeed = car.speeds
	var/base_top = car.speedlist[car.speeds] + 1
	load_check(car.get_speed() + 1 <= max(1.2, base_top * 0.75) + 0.001, "a hull a quarter lighter takes a quarter less time per tile ([car.get_speed() + 1] against [base_top])")
	car.currentspeed = car.speeds + 1

	// ---- The speed ladder (vehicle_speeds.dm) ----
	load_check(car.gear_interval(car.speeds) == 1.6, "a car's top gear takes 1.6 a tile ([car.gear_interval(car.speeds)])")
	load_check(car.gear_interval(car.speeds) < bicycle_step_delay(0), "which beats an unloaded bicycle ([bicycle_step_delay(0)])")
	var/obj/structure/vehicleparts/axis/heavy/m41/bulldog = new(locate(2, 2, 1))
	var/obj/structure/vehicleparts/axis/heavy/kv1a/heavy_tank = new(locate(2, 2, 1))
	var/obj/structure/vehicleparts/axis/heavy/t34/medium_tank = new(locate(2, 2, 1))
	var/obj/structure/vehicleparts/axis/heavy/hago/hago = new(locate(2, 2, 1))
	load_check(bulldog.gear_interval(bulldog.speeds) < medium_tank.gear_interval(medium_tank.speeds), "an M41 outruns a T-34")
	load_check(medium_tank.gear_interval(medium_tank.speeds) < heavy_tank.gear_interval(heavy_tank.speeds), "which outruns a KV-1")
	load_check(hago.gear_interval(hago.speeds) > car.gear_interval(car.speeds), "and no Ha-Go keeps up with a car")
	var/ordered = TRUE
	for (var/class in vehicle_speed_ladder)
		var/list/row = vehicle_speed_ladder[class]
		for (var/g = 2, g <= row.len, g++)
			if (row[g] >= row[g - 1])
				ordered = FALSE
	load_check(ordered, "every ladder row gets quicker gear by gear")
	for (var/obj/O in list(bulldog, heavy_tank, medium_tank, hago))
		qdel(O)
	load_check(car.loaded_turntimer() == car.turntimer * 0.75, "and turns a little faster ([car.loaded_turntimer()])")
	car.load_factor = 1
	car.currentspeed = car.speeds + 1
	car.get_speed()
	load_check(car.currentspeed == car.speeds, "when it is heavy again the extra gear drops away")

	// ---- An armoured tank with a crew ----
	var/obj/structure/vehicleparts/axis/heavy/tank = load_vehicle(15, 15, 3, 3, /obj/structure/vehicleparts/axis/heavy, 2, 50)
	load_person(locate(16, 15, 1))
	load_check(tank.get_load_factor(TRUE) == 1, "an armoured tank with a driver reads 1.0 ([tank.load_factor])")
	var/list/W = tank.vehicle_load_weights()
	load_check(W[2] > 300, "its steel walls weigh into the reference ([W[2]])")
	for (var/i = 1, i <= 2, i++)
		load_person(locate(16, 16, 1))
	load_check(tank.get_load_factor(TRUE) == 1, "a full crew is within the allowance ([tank.load_factor])")
	// ---- Composite panels on the tank (composite_armour.dm) ----
	var/obj/structure/vehicleparts/frame/CF
	for (var/obj/structure/vehicleparts/frame/candidate in tank.components)
		if (candidate.w_front[1] == "c_armoredwall")
			CF = candidate
			break
	var/before_armour = CF.w_front[4]
	var/before_health = CF.w_front[5]
	var/before_factor = tank.get_load_factor(TRUE)
	var/list/before_w = tank.vehicle_load_weights()
	load_check(("front" in CF.composite_free_sides()) && CF.fit_composite("front"), "a composite panel fits over an armoured wall")
	load_check(CF.w_front[4] == before_armour + max(20, round(before_armour / 2)) && CF.w_front[5] > before_health, "it adds half the wall's armour and some health ([before_armour] to [CF.w_front[4]])")
	load_check(!CF.fit_composite("front") && !("front" in CF.composite_free_sides()), "one panel per wall")
	var/list/after_w = tank.vehicle_load_weights()
	load_check(after_w[2] == before_w[2] && after_w[1] - before_w[1] == max(20, round(before_armour / 2)) * 0.5 * COMPOSITE_PANEL_WEIGHT, "it weighs half its armour in steel, and the steel reference is unchanged ([after_w[1] - before_w[1]])")
	load_check(tank.get_load_factor(TRUE) >= before_factor, "so it never makes the tank lighter ([before_factor] to [tank.load_factor])")
	load_check(findtext(CF.composite_examine_text(), "front"), "examine names the covered wall")
	var/mob/living/human/load_probe/rider = load_person(locate(16, 16, 1))
	var/standing = vehicle_rider_weight(rider)
	rider.buckled = locate(/obj/structure/bed/chair) in locate(16, 15, 1)
	if (!rider.buckled)
		rider.buckled = new /obj/structure/bed/chair(locate(18, 18, 1))
	load_check(standing == MOB_MEDIUM * 2 && vehicle_rider_weight(rider) == MOB_MEDIUM, "a seated rider counts half a standing one ([standing], [vehicle_rider_weight(rider)])")
	rider.buckled = null
	qdel(rider)
	load_check(tank.do_move(), "and it still drives")

	// ---- Boats and aircraft keep their own speeds ----
	var/obj/structure/vehicleparts/axis/boat/B = new(locate(30, 30, 1))
	load_check(!B.uses_load_factor() && B.get_load_factor(TRUE) == 1, "a boat ignores load")
	B.currentspeed = 2
	load_check(B.get_speed() == B.speedlist[2], "and keeps its listed delay")
	var/obj/structure/vehicleparts/axis/aircraft/P = new(locate(33, 33, 1))
	load_check(!P.uses_load_factor() && P.top_gear() == P.speeds, "an aircraft ignores load")

/proc/load_run()
	try
		load_checks()
	catch(var/exception/e)
		load_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = load_failures, "runtime_error" = load_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/load_probe
		load_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		load_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		load_run()
