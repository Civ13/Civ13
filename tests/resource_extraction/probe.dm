// Real production types and procs; startup and human constructor adapters only.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 2
	turf = /turf
	area = /area
	visibility = 0

// Never expose this constructor fixture to network clients.
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/extraction_probe/New()
	return
/mob/living/human/extraction_probe/New()
	return
/mob/living/human/extraction_probe
	var/wait_mode = "pass"
/mob/living/human/extraction_probe/sifting_wait(turf/T, obj/item/tool)
	if (wait_mode == "timed" || wait_mode == "timed_move" || wait_mode == "timed_drop")
		if (wait_mode == "timed_move")
			spawn(2)
				loc = locate(10,10,1)
		if (wait_mode == "timed_drop")
			spawn(2)
				l_hand = null
		return do_after(src, 5, T, TRUE, FALSE)
	if (wait_mode == "cancel")
		return FALSE
	if (wait_mode == "replace")
		new /turf/floor/dirt(T)
	if (wait_mode == "drop")
		l_hand = null
	if (wait_mode == "move")
		loc = locate(10,10,1)
	if (wait_mode == "overlap")
		extraction_check(!sift_resource(T, /obj/item/stack/ore/copper), "overlapping action rejected")
	return TRUE

var/extraction_failures = 0
var/extraction_runtime_error = FALSE
/proc/extraction_check(condition, label)
	if (!condition)
		extraction_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	extraction_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		extraction_check(!world.port, "fixture has no listening port")
		map = new /obj/map_metadata/extraction_probe
		map.ordinal_age = 2
		populate_material_list()
		build_research_tree()
		extraction_check(get_recipe_node_req("/obj/structure/drill") == "electricity", "drill unlock at electricity")
		extraction_check(get_recipe_node_req("/obj/item/stack/material/electronics") == "electricity", "electronics unlock at electricity")
		var/turf/T = locate(5,5,1)
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		var/obj/structure/drill/D = new(T)
		D.anchored = TRUE
		for (var/type in D.ore_types)
			extraction_check(ispath(type, /obj/item/stack), "ore pool contains stack [type]")
		var/obj/item/stack/ore/iron/I = new(T,49,FALSE)
		extraction_check(D.produce_minerals(/obj/item/stack/ore/iron, 5), "near-full output accepted")
		var/total = 0
		var/stacks = 0
		for (var/obj/item/stack/S in T)
			total += S.amount
			stacks++
			extraction_check(S.amount <= S.max_amount, "stack stays capped")
		extraction_check(total == 54 && stacks == 2 && I.amount == 50, "batch conserved across capped stacks")
		for (var/i in 1 to 10)
			new /obj/item/stack/ore/iron(T,50,FALSE)
		extraction_check(!D.produce_minerals(/obj/item/stack/ore/copper,2), "12-stack output blocks new types")
		extraction_check(!D.produce_minerals(/obj/item/weapon/barrier,2), "non-stack output rejected")
		extraction_check(D.produce_minerals(/obj/item/stack/ore/iron,2), "existing space remains usable at cap")
		for (var/obj/item/stack/S in T)
			qdel(S)
		var/obj/structure/cable/C = new(locate(6,5,1))
		var/obj/structure/engine/E = new(locate(7,5,1))
		E.on = TRUE
		E.maxpower = 200
		E.connections = list(C)
		C.connections = list(D,E)
		D.powersource = C
		var/mob/living/human/extraction_probe/H = new(T)
		D.attack_hand(H)
		extraction_check(D.active && D.process_pending && C.currentflow == 150 && D.next_spawn == 60, "startup reserves power and full interval")
		for (var/i in 1 to 30)
			D.attack_hand(H)
			D.attack_hand(H)
		sleep(21)
		extraction_check(D.next_spawn == 59 && D.process_pending, "30 restarts leave one callback")
		D.stop_drilling()
		extraction_check(!D.active && C.currentflow == 0, "stop releases reservation")
		D.attack_hand(H)
		D.next_spawn = 0
		sleep(21)
		extraction_check(!(locate(/obj/item/stack) in T), "restart deadline prevents early output")
		D.stop_drilling()
		sleep(21)
		extraction_check(!D.process_pending, "stopped callback settles")
		D.active = TRUE
		D.next_spawn = 0
		D.production_due = world.time
		D.process_machine()
		extraction_check(D.next_spawn == 60 && (locate(/obj/item/stack) in T), "real machine produces bounded batch")
		E.on = FALSE
		sleep(21)
		extraction_check(!D.active && !D.powered && C.currentflow == 0, "power loss stops production and releases load")
		E.on = TRUE
		D.attack_hand(H)
		D.before_save()
		extraction_check(!D.active && C.currentflow == 0, "before-save stops live extraction")
		D.active = TRUE
		D.after_load()
		extraction_check(!D.active && D.next_spawn == -1, "legacy active save loads stopped")
		qdel(D)
		for (var/obj/item/stack/S in T)
			qdel(S)
		H.wait_mode = "overlap"
		extraction_check(H.sift_resource(T,/obj/item/stack/ore/copper), "hand sifting production path")
		var/obj/item/stack/ore/copper/copper = locate() in T
		extraction_check(copper && copper.amount == 1 && !H.sifting_action && T.type == /turf/floor/dirt, "one hand output without terrain destruction")
		qdel(copper)
		for (var/mode in list("cancel","replace","move"))
			H.wait_mode = mode
			H.loc = T
			extraction_check(!H.sift_resource(T,/obj/item/stack/ore/copper), "sifting rejects [mode]")
			extraction_check(!(locate(/obj/item/stack/ore/copper) in T), "no output after [mode]")
		H.loc = T
		H.wait_mode = "pass"
		var/obj/item/weapon/resource_sieve/sieve = new(H)
		H.l_hand = sieve
		H.hand = TRUE
		extraction_check(H.sift_resource(T,/obj/item/stack/ore/tin,sieve), "simple sieve production route")
		H.wait_mode = "timed"
		extraction_check(H.sift_resource(T,/obj/item/stack/ore/tin,sieve), "production do_after completes")
		H.wait_mode = "timed_move"
		extraction_check(!H.sift_resource(T,/obj/item/stack/ore/tin,sieve), "production do_after rejects movement")
		H.loc = T
		H.wait_mode = "timed_drop"
		extraction_check(!H.sift_resource(T,/obj/item/stack/ore/tin,sieve), "production do_after rejects active tool loss")
		H.wait_mode = "pass"
		var/obj/item/kitchen/wood_bowl/bowl = new(H)
		H.l_hand = bowl
		extraction_check(!H.sift_resource(T,/obj/item/stack/ore/gold,bowl,TRUE), "pan requires river, not held container")
		var/turf/floor/beach/water/W = new /turf/floor/beach/water(locate(4,5,1))
		extraction_check(H.sift_resource(T,/obj/item/stack/ore/gold,bowl,TRUE), "freshwater panning production route")
		W.salty = TRUE
		extraction_check(!H.sift_resource(T,/obj/item/stack/ore/gold,bowl,TRUE), "salt water rejected")
		W.salty = FALSE
		H.wait_mode = "drop"
		extraction_check(!H.sift_resource(T,/obj/item/stack/ore/gold,bowl,TRUE), "dropped pan rejected")
		extraction_construction(H)
		extraction_save_roundtrip()
	catch(var/exception/e)
		extraction_check(FALSE, "exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = extraction_failures, "runtime_error" = extraction_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build, "maxx" = world.maxx, "maxy" = world.maxy, "maxz" = world.maxz)), "result.json")
	del(world)

/proc/extraction_construction(mob/living/human/extraction_probe/H)
	var/turf/T = locate(8,8,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	H.loc = T
	var/obj/item/stack/material/electronics/electronics = new(H,40,FALSE)
	var/obj/item/stack/material/steel/steel = new(H,40,FALSE)
	H.l_hand = electronics
	H.r_hand = steel
	var/datum/stack_recipe/R = new("industrial drill", /obj/structure/drill, 20, _time = 0, _one_per_turf = TRUE, _on_floor = TRUE)
	steel.amount = 19
	electronics.produce_recipe(R,1,H)
	extraction_check(electronics.amount == 40 && steel.amount == 19 && !(locate(/obj/structure/drill) in T), "short steel consumes neither input")
	steel.amount = 40
	electronics.produce_recipe(R,1,H)
	extraction_check(electronics.amount == 20 && steel.amount == 20 && (locate(/obj/structure/drill) in T), "construction pays 20 electronics and 20 steel")
	electronics.produce_recipe(R,1,H)
	extraction_check(electronics.amount == 20 && steel.amount == 20, "occupied tile consumes neither input")

/proc/extraction_save_roundtrip()
	var/turf/T = locate(11,11,1)
	var/obj/structure/drill/D = new(T)
	D.name = "saved extraction drill"
	D.anchored = TRUE
	D.active = TRUE
	D.next_spawn = 1
	D.process_pending = TRUE
	D.production_due = world.time + 1200
	var/mob/living/human/extraction_probe/H = new(T)
	H.sifting_resources = TRUE
	H.sifting_action = TRUE
	var/list/human_saved = H.get_saved_vars()
	extraction_check(!("sifting_resources" in human_saved) && !("sifting_action" in human_saved), "gathering locks excluded from custom saves")
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new("extraction.sav")
	F["/format_version"] << 2
	var/id = map_storage.BuildVarDirectory(F, D, 1)
	F.Flush()
	extraction_check(id && !D.active, "serializer invokes drill stop hook")
	qdel(D)
	F = null
	map_storage.clear_bookkeeping()
	F = new("extraction.sav")
	D = map_storage.Load_Entry(F, id, null, T)
	for (var/datum/A in map_storage.all_loaded)
		A.after_load()
	extraction_check(D && D.name == "saved extraction drill" && D.anchored && !D.active && !D.process_pending && D.next_spawn == -1, "serialized drill reloads stopped with durable identity")
	map_storage.clear_bookkeeping()
