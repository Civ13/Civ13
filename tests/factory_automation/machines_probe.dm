// Factory automation phase 2b: furnace and powered saw mill ports. Runs the
// production sources through the shared resource-extraction fixture with
// ordinary game startup disabled; machine steps are called directly.
/world
	hub = ""
	hub_password = ""
	maxx = 16
	maxy = 16
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/machine_probe/New()
	return
/mob/living/human/machine_probe/New()
	return
/mob/living/human/machine_probe/update_icons()
	return
var/machine_failures = 0
var/machine_runtime_error = FALSE
/proc/machine_check(condition, label)
	if (!condition)
		machine_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	machine_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/belt_floor(x, y)
	var/turf/T = locate(x, y, 1)
	return T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
/proc/belt_run(steps)
	for (var/i in 1 to steps)
		factory_belts_step()
/proc/belt_count(atom/A, type)
	var/total = 0
	for (var/obj/item/stack/S in A)
		if (S.type == type)
			total += S.amount
	return total
/proc/belt_closed_crate(turf/T, capacity = 20)
	var/obj/structure/closet/crate/C = new(T)
	C.opened = FALSE
	C.storage_capacity = capacity
	for (var/obj/item/I in C)
		qdel(I)
	return C
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/machine_probe
		map.ordinal_age = 8
		for (var/x in 1 to 16)
			for (var/y in 1 to 16)
				belt_floor(x, y)
		machine_check(!world.port, "fixture has no listening port")
		machine_furnace_checks()
		machine_blast_furnace_checks()
		machine_mill_checks()
	catch(var/exception/e)
		machine_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = machine_failures, "runtime_error" = machine_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/machine_power(obj/O, x, y)
	var/obj/structure/cable/C = new(locate(x, y, 1))
	var/obj/structure/engine/E = new(locate(x, y, 1))
	E.on = TRUE
	E.maxpower = 50
	E.connections = list(C)
	C.connections = list(O, E)
	O.powersource = C
	return list(C, E)

/proc/machine_furnace_checks()
	var/obj/structure/furnace/F = new(locate(2, 2, 1))
	F.smelt_time = 5 // the probe's daemon has thirty seconds
	var/obj/item/stack/ore/iron/ore = new(locate(1, 2, 1), 60)
	var/obj/item/stack/ore/coal/coal = new(locate(1, 3, 1), 5)
	var/obj/item/stack/material/stone/stone = new(locate(1, 4, 1), 5, FALSE)
	machine_check(F.factory_accepts(ore) == 50, "a bloomery takes up to fifty iron ore from automation")
	machine_check(!F.factory_accepts(stone), "a bloomery refuses what it cannot smelt or burn")
	F.anchored = FALSE
	machine_check(!F.factory_accepts(ore), "an unanchored bloomery has no port")
	F.anchored = TRUE
	machine_check(F.factory_insert(ore) == 50 && F.iron == 50 && ore.amount == 10 && !F.on, "ore alone loads without starting a smelt and the rest stays behind")
	machine_check(!F.factory_accepts(ore), "a full bloomery refuses more ore")
	machine_check(F.factory_insert(coal) == 5 && QDELETED(coal) && F.on && F.fuel == 13, "fuel from automation starts the smelt and pays its two fuel")
	machine_check(!F.factory_offer(), "a smelting bloomery offers nothing yet")
	sleep(10)
	var/obj/item/stack/ore/iron_sponge/sponge = locate() in F.loc
	machine_check(!F.on && F.iron == 0 && sponge && sponge.amount == 50, "the smelt leaves sponge iron on the bloomery's tile")
	machine_check(F.factory_offer() == sponge, "the bloomery offers its sponge iron")
	var/obj/structure/closet/crate/C = belt_closed_crate(locate(3, 2, 1))
	machine_check(F.factory_take(sponge, C) && sponge.loc == C, "an arm can take the sponge iron away")
	var/obj/item/stack/ore/iron/more = new(locate(1, 7, 1), 5)
	machine_check(F.factory_insert(more) == 5 && F.on, "a loaded bloomery restarts when more ore arrives")
	var/obj/structure/furnace/kiln/K = new(locate(5, 2, 1))
	var/obj/item/stack/ore/iron/kiln_ore = new(locate(1, 8, 1), 5)
	machine_check(!K.factory_accepts(kiln_ore) && !K.factory_offer(), "clay kilns stay manual")
	for (var/obj/O in list(ore, stone, C, K, kiln_ore))
		qdel(O)
	F.on = FALSE

/proc/machine_blast_furnace_checks()
	var/obj/structure/furnace/blast_furnace/B = new(locate(2, 5, 1))
	var/obj/item/stack/ore/iron/ore = new(locate(1, 5, 1), 10)
	var/obj/item/stack/ore/charcoal/charcoal = new(locate(1, 6, 1), 2)
	machine_check(B.factory_insert(ore) == 10 && B.factory_insert(charcoal) == 2 && B.on && B.fuel == 3, "a blast furnace loads ore and charcoal and starts")
	var/obj/item/stack/ore/iron_sponge/wrong = new(B.loc, 1)
	var/obj/item/stack/ore/iron_pig/pig = new(B.loc, 3)
	machine_check(B.factory_offer() == pig, "a blast furnace offers pig iron, not other stacks on its tile")
	qdel(wrong)
	qdel(pig)

/proc/machine_mill_checks()
	var/obj/structure/sawmill/powered/M = new(locate(2, 9, 1))
	var/obj/item/stack/material/wood/logs = new(locate(1, 9, 1), 25, FALSE)
	machine_check(M.factory_accepts(logs) == 20, "a powered saw mill hopper takes twenty logs")
	machine_check(M.factory_insert(logs) == 20 && M.factory_logs == 20 && logs.amount == 5 && (M in factory_active_mills), "inserted logs fill the hopper and wake the mill")
	factory_mills_step()
	machine_check(M.factory_logs == 20 && !(locate(/obj/item/stack/material/woodplank) in M.loc), "an unpowered mill cuts nothing")
	var/list/power = machine_power(M, 2, 10)
	factory_mills_step()
	var/obj/item/stack/material/woodplank/P = locate() in M.loc
	machine_check(M.factory_logs == 19 && P && P.amount == 12, "a powered mill cuts one log into twelve planks a step")
	factory_mills_step()
	machine_check(M.factory_logs == 18 && P.amount == 24, "planks merge into the stack on the tile")
	machine_check(M.factory_offer() == P, "the mill offers its planks")
	M.anchored = FALSE
	factory_mills_step()
	machine_check(M.factory_logs == 18 && !M.factory_accepts(logs), "an unanchored mill neither cuts nor takes logs")
	M.anchored = TRUE
	M.factory_logs = 99
	M.after_load()
	machine_check(M.factory_logs == 20 && (M in factory_active_mills), "load clamps the hopper and resumes a fed mill")
	machine_check(!M.persistence_runtime_var("factory_logs"), "the hopper is saved")
	var/turf/T = M.loc
	qdel(P)
	qdel(logs)
	qdel(M)
	var/obj/item/stack/material/wood/returned = locate() in T
	machine_check(returned && returned.amount == 20 && !(M in factory_active_mills), "removing a mill returns its hopper logs")
	for (var/obj/O in power)
		qdel(O)
