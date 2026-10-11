/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/fracture_probe/New()
	return
/mob/living/human/fracture_probe/New()
	return
var/fracture_failures = 0
var/fracture_runtime_error = FALSE
/proc/fracture_check(condition, label)
	if (!condition)
		fracture_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	fracture_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/fracture_probe
		map.ordinal_age = 8
		var/turf/T = locate(5,5,1)
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		var/turf/R = locate(4,5,1)
		R = R.ChangeTurf(/turf/floor/dirt/underground, FALSE, FALSE)
		var/obj/structure/drill/fracking/D = new(T)
		D.anchored = TRUE
		var/obj/structure/cable/C = new(locate(6,5,1))
		var/obj/structure/engine/E = new(locate(7,5,1))
		E.on = TRUE
		E.maxpower = 400
		E.connections = list(C)
		C.connections = list(D,E)
		D.powersource = C
		var/mob/living/human/fracture_probe/H = new(T)
		var/obj/item/weapon/reagent_containers/glass/barrel/W = new(D)
		var/obj/item/weapon/reagent_containers/glass/barrel/O = new(D)
		W.reagents.clear_reagents()
		O.reagents.clear_reagents()
		W.reagents.add_reagent("water", 40)
		var/obj/item/stack/ore/glass/S = new(D,10,FALSE)
		fracture_check(get_recipe_node_req("/obj/structure/drill/fracking") == "hydraulic_fracturing", "explicit Modern research mapping")
		var/list/states = icon_states(D.icon)
		fracture_check(("mining_drill" in states) && ("mining_drill_powered" in states) && ("mining_drill_active" in states), "effective conventional sprite states exist")
		for (var/i in 1 to 30)
			D.attack_hand(H)
			D.stop_drilling()
		D.attack_hand(H)
		fracture_check(D.active && D.process_pending && C.currentflow == 300 && !O.reagents.total_volume, "thirty restarts reserve once without early output")
		D.next_spawn = 0
		D.production_due = world.time
		sleep(25)
		fracture_check(!D.active && !D.process_pending && C.currentflow == 0, "one batch stops and releases power")
		fracture_check(W.reagents.get_reagent_amount("water") == 20 && S.amount == 5 && O.reagents.get_reagent_amount("petroleum") == 50, "one batch pays exact inputs for fifty petroleum")
		R = locate(4,5,1)
		fracture_check(!R.is_mineable && !D.valid_fracture_target(R), "depleted terrain cannot be reused")
		R = R.ChangeTurf(/turf/floor/dirt/underground, FALSE, FALSE)
		D.attack_hand(H)
		R = new /turf/floor/dirt/underground(R)
		sleep(25)
		fracture_check(!D.active && C.currentflow == 0 && O.reagents.get_reagent_amount("petroleum") == 50, "same-kind target replacement cancels without output")
		S.amount = 4
		D.attack_hand(H)
		fracture_check(!D.active && W.reagents.get_reagent_amount("water") == 20 && S.amount == 4, "short sand consumes nothing")
		S.amount = 5
		W.reagents.add_reagent("petroleum", 1)
		D.attack_hand(H)
		fracture_check(!D.active && R.is_mineable, "contaminated freshwater rejected")
		W.reagents.remove_reagent("petroleum", 1)
		D.powersource = null
		D.name = "saved finite rig"
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("fracture.sav")
		F["/format_version"] << 2
		var/id = map_storage.BuildVarDirectory(F,D,1)
		F.Flush()
		qdel(D)
		F = null
		map_storage.clear_bookkeeping()
		F = new("fracture.sav")
		D = map_storage.Load_Entry(F,id,null,T)
		for (var/datum/A in map_storage.all_loaded)
			A.after_load()
		fracture_check(D && D.name == "saved finite rig" && !D.active && !D.process_pending && !D.fracture_target && D.contents.len == 3, "disk save reloads stopped with contained inputs")
	catch(var/exception/e)
		fracture_check(FALSE, "exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fracture_failures, "runtime_error" = fracture_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
