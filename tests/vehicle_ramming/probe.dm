// Native probe for vehicles and trains ramming buildings
// (code/modules/1713/machinery/modular_vehicles/vehicle_ram.dm, trains.dm rail_hit).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/vehicle_ramming/probe.dm 300
/world
	hub = ""
	hub_password = ""
	maxx = 30
	maxy = 20
	maxz = 1
	turf = /turf/floor/dirt
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/vehicle_ramming_probe/New()
	return
var/vr_failures = 0
var/vr_runtime_error = FALSE
/proc/vr_check(condition, label)
	if (!condition)
		vr_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	vr_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	sleep(1)
	try
		config = new
		config.webhook_can_fire = FALSE
		makeDatumRefLists()
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		movementMachine = new
		map = new /obj/map_metadata/vehicle_ramming_probe
		Master.start_timer_loop()
		vr_checks()
	catch(var/exception/e)
		vr_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = vr_failures, "runtime_error" = vr_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

// A 2 by 3 car facing north with its south-west corner at x,y.
/proc/vr_car(x, y)
	for (var/dx = 0, dx < 2, dx++)
		for (var/dy = 0, dy < 3, dy++)
			new /obj/structure/vehicleparts/frame(locate(x + dx, y + dy, 1))
	var/obj/structure/engine/internal/E = new /obj/structure/engine/internal/gasoline/premade/v6(locate(x, y + 1, 1))
	E.anchored = FALSE
	new /obj/item/weapon/reagent_containers/glass/barrel/fueltank/smalltank/fueledgasoline(locate(x + 1, y + 1, 1))
	var/obj/structure/bed/chair/drivers/D = new(locate(x + 1, y, 1))
	D.anchored = FALSE
	for (var/turf/T in list(locate(x, y, 1), locate(x + 1, y, 1), locate(x, y + 2, 1), locate(x + 1, y + 2, 1)))
		new /obj/structure/vehicleparts/movement(T)
	var/obj/structure/vehicleparts/axis/A = new /obj/structure/vehicleparts/axis/car(locate(x, y, 1))
	var/why = A.assemble(NORTH)
	vr_check(isnull(why), "car assembled ([why])")
	if (A.engine)
		A.engine.on = TRUE
	return A

/proc/vr_frame(obj/structure/vehicleparts/axis/A, turf/T)
	for (var/obj/structure/vehicleparts/frame/F in T)
		if (F.axis == A)
			return F
	return null

/proc/vr_checks()
	vr_check(is_structure_impact_part(new /obj/covers/wood_wall(locate(1, 1, 1))), "a wood wall is a building part")

	// A car in fourth gear smashes through a plank wall, a gear slower.
	var/obj/structure/vehicleparts/axis/A = vr_car(4, 2)
	A.get_weight()
	world.log << "car weight [A.current_weight] engine [A.engine] maxpower [A.maxpower]"
	vr_check(A.ram_leading_frames().len == 2, "two frames lead a car two wide")
	var/obj/covers/wood_wall/W1 = new /obj/covers/wood_wall(locate(4, 5, 1))
	var/obj/covers/wood_wall/W2 = new /obj/covers/wood_wall(locate(5, 5, 1))
	var/obj/structure/vehicleparts/frame/lead = vr_frame(A, locate(4, 4, 1))
	var/hull_before = lead ? lead.w_front[5] : 0
	var/mob/living/human/driver = new /mob/living/human(locate(5, 2, 1))
	driver.stat = CONSCIOUS
	var/brute_before = driver.getBruteLoss()
	A.currentspeed = 4
	A.moving = TRUE
	var/force = A.ram_force()
	world.log << "car ram force at gear 4: [force]"
	vr_check(force > 600, "a car at speed hits harder than two plank walls")
	var/ok = A.do_vehicle_check()
	vr_check(ok, "the car drives on through a plank wall")
	vr_check(QDELETED(W1) && QDELETED(W2), "both plank walls gave way")
	vr_check(A.currentspeed == 3, "breaking through cost a gear")
	vr_check(lead && lead.w_front[5] <= hull_before, "the leading hull plate took the blow")
	vr_check(driver.getBruteLoss() >= brute_before, "the crew were thrown about")

	// The same car into stone stops, and the stone only cracks.
	var/obj/structure/vehicleparts/axis/B = vr_car(12, 2)
	B.get_weight()
	var/obj/covers/stone_wall/S1 = new /obj/covers/stone_wall(locate(12, 5, 1))
	var/obj/covers/stone_wall/S2 = new /obj/covers/stone_wall(locate(13, 5, 1))
	B.currentspeed = 4
	B.moving = TRUE
	vr_check(!B.do_vehicle_check(), "a stone wall stops the car")
	vr_check(!QDELETED(S1) && !QDELETED(S2), "the stone walls stand")
	vr_check(S1.health < S1.maxhealth, "the stone wall took damage")
	vr_check(!B.moving && B.currentspeed == 0, "the car came to a stop")

	// A crawl only dents a plank wall and stops.
	var/obj/structure/vehicleparts/axis/C = vr_car(20, 2)
	C.get_weight()
	var/obj/covers/wood_wall/W3 = new /obj/covers/wood_wall(locate(20, 5, 1))
	W3.health = W3.maxhealth = 3000
	C.currentspeed = 1
	C.moving = TRUE
	vr_check(!C.do_vehicle_check(), "a crawl into a sturdy wall stops")
	vr_check(!QDELETED(W3) && W3.health < 3000, "the crawl still dents the wall")

	// Nothing in the way: no ram.
	var/obj/structure/vehicleparts/axis/D = vr_car(24, 10)
	D.get_weight()
	D.currentspeed = 2
	D.moving = TRUE
	vr_check(D.do_vehicle_check() && D.currentspeed == 2, "an open road costs nothing")

	// Trains: a plank wall on the line breaks and the train runs on; stone stops it.
	var/obj/structure/trains/T = new /obj/structure/trains(locate(2, 15, 1))
	var/obj/covers/wood_wall/TW = new /obj/covers/wood_wall(locate(3, 15, 1))
	var/train_hp = T.health
	var/hit = T.rail_hit(locate(3, 15, 1), EAST, 1)
	vr_check(!hit, "a train at speed runs through a plank wall")
	vr_check(QDELETED(TW), "the plank wall on the line broke")
	vr_check(T.health < train_hp, "the train took damage")
	var/obj/covers/stone_wall/TS = new /obj/covers/stone_wall(locate(4, 15, 1))
	T.automovement = TRUE
	vr_check(T.rail_hit(locate(4, 15, 1), EAST, 1), "a stone wall stops a train")
	vr_check(!T.automovement && !QDELETED(TS), "the train stopped at the stone wall")
	var/obj/covers/wood_wall/TW2 = new /obj/covers/wood_wall(locate(5, 15, 1))
	vr_check(T.rail_hit(locate(5, 15, 1), EAST, 0.2) && !QDELETED(TW2) && TW2.health == TW2.maxhealth, "a crawling train only bumps")
