// Native probe for solid pillars, bollards and barriers
// (code/game/objects/building_defences.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/building_defences/probe.dm 300
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
/obj/map_metadata/building_defences_probe/New()
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
		map = new /obj/map_metadata/building_defences_probe
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
	var/mob/living/human/walker = new /mob/living/human(locate(1, 10, 1))
	var/obj/item/projectile/shot = new /obj/item/projectile(locate(1, 11, 1))

	// Pillars are solid to people but shots often get past.
	var/obj/structure/roof_support/RS = new /obj/structure/roof_support(locate(2, 10, 1))
	var/obj/structure/mine_support/stone/SP = new /obj/structure/mine_support/stone(locate(3, 10, 1))
	var/obj/structure/mine_support/stone/concrete/CP = new /obj/structure/mine_support/stone/concrete(locate(4, 10, 1))
	var/obj/structure/roof_support/admin/AR = new /obj/structure/roof_support/admin(locate(5, 10, 1))
	var/obj/structure/mine_support/MS = new /obj/structure/mine_support(locate(6, 10, 1))
	vr_check(RS.density && !RS.CanPass(walker, RS.loc), "a roof support blocks people")
	vr_check(SP.density && !SP.CanPass(walker, SP.loc), "a stone pillar blocks people")
	vr_check(CP.density && !CP.CanPass(walker, CP.loc), "a concrete pillar blocks people")
	vr_check(!AR.density, "the map's hidden roof props stay walk-through")
	vr_check(!MS.density, "wooden mine timbering stays walk-through")
	var/passed = 0
	for (var/i in 1 to 200)
		if (RS.CanPass(shot, RS.loc))
			passed++
	vr_check(passed > 100 && passed < 200, "most shots get past a pillar, some do not ([passed]/200)")
	vr_check(RS.opacity == FALSE && SP.opacity == FALSE, "pillars stay see-through")
	vr_check(!walker.Move(locate(2, 10, 1)), "walking into a pillar fails")

	// Bollards let people through but are building parts that stop vehicles.
	var/obj/structure/bollard/stone/B1 = new /obj/structure/bollard/stone(locate(4, 5, 1))
	new /obj/structure/bollard/stone(locate(5, 5, 1))
	var/obj/covers/wood_wall/behind = new /obj/covers/wood_wall(locate(4, 6, 1))
	var/mob/living/human/stroller = new /mob/living/human(locate(4, 4, 1))
	vr_check(B1.CanPass(stroller, B1.loc), "people walk between bollards")
	vr_check(is_structure_impact_part(B1) && B1.structure_impact_material() == "stone", "a stone bollard is a stone building part")
	qdel(stroller)
	var/obj/structure/vehicleparts/axis/A = vr_car(4, 2)
	A.get_weight()
	A.currentspeed = 4
	A.moving = TRUE
	vr_check(!A.do_vehicle_check(), "a row of stone bollards stops a car at speed")
	vr_check(!QDELETED(B1) && B1.health < B1.maxhealth, "the bollard is battered but stands")
	vr_check(behind.health == behind.maxhealth, "the wall behind the bollards is untouched")

	// A wooden bollard only slows a car down.
	var/obj/structure/vehicleparts/axis/C = vr_car(12, 2)
	C.get_weight()
	var/obj/structure/bollard/W1 = new /obj/structure/bollard(locate(12, 5, 1))
	C.currentspeed = 4
	C.moving = TRUE
	vr_check(C.do_vehicle_check() && QDELETED(W1) && C.currentspeed == 3, "a car breaks a wooden bollard and loses a gear")

	// Barriers absorb a crash too.
	var/obj/structure/vehicleparts/axis/D = vr_car(20, 2)
	D.get_weight()
	var/obj/structure/window/barrier/jersey/J = new /obj/structure/window/barrier/jersey(locate(20, 5, 1))
	vr_check(is_structure_impact_part(J) && J.structure_impact_material() == "concrete", "a jersey barrier is a concrete building part")
	D.currentspeed = 4
	D.moving = TRUE
	var/hp = J.health
	vr_check(!D.do_vehicle_check(), "a jersey barrier stops a car")
	vr_check(!QDELETED(J) && J.health < hp, "the jersey barrier took the blow")
	var/obj/structure/window/barrier/sandbag/SB = new /obj/structure/window/barrier/sandbag(locate(25, 15, 1))
	vr_check(is_structure_impact_part(SB), "sandbags are a building part")
	var/left = SB.structure_impact(100000)
	vr_check(QDELETED(SB) && left > 0, "a big enough hit smashes sandbags")
