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
/obj/map_metadata/trace_probe/New()
	return
/mob/living/human/trace_probe/New()
	return
var/trace_failures = 0
var/trace_runtime_error = FALSE
/proc/trace_check(condition, label)
	if (!condition)
		trace_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	trace_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/trace_probe
		map.ordinal_age = 5
		trace_check(!world.port, "fixture has no listening port")
		var/turf/T = locate(5,5,1)
		T = T.ChangeTurf(/turf/floor/beach/sand, FALSE, FALSE)
		var/obj/structure/drill/sifter/S = new(T)
		S.anchored = TRUE
		var/obj/structure/cable/C = new(locate(6,5,1))
		var/obj/structure/engine/E = new(locate(7,5,1))
		E.on = TRUE
		E.maxpower = 200
		E.connections = list(C)
		C.connections = list(S,E)
		S.powersource = C
		var/mob/living/human/trace_probe/H = new(T)
		for (var/type in list(/obj/structure/drill/sifter, /obj/structure/drill/sifter/panner))
			var/obj/structure/drill/sifter/machine = new type(null)
			trace_check(get_recipe_node_req("[type]") == "electricity", "machine unlocks at Electricity [type]")
			var/list/states = icon_states(machine.icon)
			trace_check((machine.machine_icon in states) && ("[machine.machine_icon]_powered" in states) && ("[machine.machine_icon]_active" in states), "all effective conventional sprite states exist [type]")
			qdel(machine)
		S.attack_hand(H)
		trace_check(S.active && C.currentflow == 150 && S.process_pending, "sifter starts on non-mineable sand with reserved cable demand")
		for (var/i in 1 to 30)
			S.attack_hand(H)
			S.attack_hand(H)
		sleep(21)
		trace_check(S.next_spawn == 59 && S.process_pending && !(locate(/obj/item/stack) in T), "thirty toggles leave one callback and no early output")
		S.next_spawn = 0
		S.production_due = world.time
		sleep(21)
		var/obj/item/stack/output = locate() in T
		trace_check(output && output.amount == 2 && !T.is_mineable, "one bounded two-unit trace batch leaves terrain intact")
		S.stop_drilling()
		sleep(21)
		trace_check(!S.process_pending && C.currentflow == 0, "stop settles callback and releases demand")
		qdel(output)
		for (var/i in 1 to 12)
			new /obj/item/stack/material/stone(T,50,FALSE)
		S.ore_types = list(/obj/item/stack/ore/copper)
		S.active = TRUE
		S.trace_soil_identity = T.sifting_identity
		S.next_spawn = 0
		S.production_due = world.time
		S.process_machine()
		trace_check(!S.active && !S.process_pending && C.currentflow == 0 && !(locate(/obj/item/stack/ore/copper) in T), "congestion stops before creating output or retaining demand")
		for (var/obj/item/stack/item in T)
			qdel(item)
		E.on = FALSE
		S.attack_hand(H)
		trace_check(!S.active && !S.process_pending && C.currentflow == 0 && !S.trace_soil_identity, "disconnected power rejects start and releases site identity")
		E.on = TRUE
		S.attack_hand(H)
		T = new /turf/floor/beach/sand(T)
		sleep(21)
		trace_check(!S.active && !S.process_pending && !S.trace_soil_identity && C.currentflow == 0, "same-kind soil replacement stops extraction and releases identity")
		qdel(S)
		var/obj/structure/drill/sifter/panner/P = new(T)
		P.anchored = TRUE
		P.powersource = C
		C.connections = list(P,E)
		trace_check(!P.valid_trace_site(), "panner rejects absent river")
		var/turf/floor/beach/water/river = new(locate(4,5,1))
		river.salty = TRUE
		river.water_level = 20
		river.watertile = TRUE
		trace_check(!P.valid_trace_site(), "panner rejects salt water")
		river.salty = FALSE
		river.water_level = 60
		trace_check(!P.valid_trace_site(), "panner rejects deep water")
		river.water_level = 20
		P.attack_hand(H)
		trace_check(P.active && P.process_pending && C.currentflow == 150, "panner starts beside shallow freshwater")
		P.next_spawn = 0
		P.production_due = world.time
		sleep(21)
		output = locate() in T
		trace_check(output && output.amount == 2 && (output.type in P.ore_types), "river output is a bounded allowed ore batch")
		river = new /turf/floor/beach/water(river)
		river.salty = FALSE
		river.water_level = 20
		river.watertile = TRUE
		sleep(21)
		trace_check(!P.active && !P.process_pending && !P.trace_water && C.currentflow == 0, "freshwater replacement stops old panning identity")
		P.attack_hand(H)
		new /turf/floor/beach/sand(river)
		sleep(21)
		trace_check(!P.active && !P.process_pending && C.currentflow == 0, "removed river stops panning and releases demand")
		P.active = TRUE
		P.after_load()
		trace_check(!P.active && !P.process_pending && P.next_spawn == -1, "inherited load hook stops automated extraction")
		P.powersource = null
		P.name = "saved river concentrator"
		P.active = TRUE
		P.process_pending = TRUE
		P.production_due = world.time + 1200
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("automated-trace.sav")
		F["/format_version"] << 2
		var/id = map_storage.BuildVarDirectory(F, P, 1)
		F.Flush()
		qdel(P)
		F = null
		map_storage.clear_bookkeeping()
		F = new("automated-trace.sav")
		P = map_storage.Load_Entry(F, id, null, T)
		for (var/datum/A in map_storage.all_loaded)
			A.after_load()
		trace_check(P && P.name == "saved river concentrator" && !P.active && !P.process_pending && P.next_spawn == -1 && P.production_due == 0, "disk-backed automated machine reloads stopped without callback state")
		map_storage.clear_bookkeeping()
		trace_catalog_and_inputs(H)
	catch(var/exception/e)
		trace_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = trace_failures, "runtime_error" = trace_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/trace_catalog_and_inputs(mob/living/human/trace_probe/H)
	var/list/rows = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1)
			rows += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = rows
	var/material/electronics/M = get_material_by_name("electronic")
	map.faction_baseline_era["trace-before"] = 4
	M.generate_recipes_civs(list(0,0,0), "global", "trace-before")
	var/locked = TRUE
	for (var/datum/stack_recipe/R in trace_recipe_rows(M.recipes))
		if (ispath(R.result_type, /obj/structure/drill/sifter))
			locked = FALSE
	trace_check(locked, "actual catalog hides automated machines before Electricity")
	map.faction_baseline_era["trace-after"] = 5
	M.generate_recipes_civs(list(0,0,0), "global", "trace-after")
	var/datum/stack_recipe/sifter_recipe
	var/datum/stack_recipe/panner_recipe
	for (var/datum/stack_recipe/R in trace_recipe_rows(M.recipes))
		if (R.result_type == /obj/structure/drill/sifter)
			sifter_recipe = R
		if (R.result_type == /obj/structure/drill/sifter/panner)
			panner_recipe = R
	trace_check(sifter_recipe && panner_recipe, "actual catalog exposes both machines at Electricity")
	if (!sifter_recipe || !panner_recipe)
		return
	// Crafting wait cancellation is covered by the existing resource fixture.
	// Shorten only this catalog recipe's wait to isolate atomic two-input payment.
	for (var/datum/stack_recipe/R in list(sifter_recipe, panner_recipe))
		R.time = 0
		var/turf/T = locate(R == sifter_recipe ? 9 : 10,9,1)
		T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
		H.loc = T
		H.stats = list("strength" = list(100,100), "crafting" = list(220,220))
		var/obj/item/stack/material/electronics/electronics = new(H,40,FALSE)
		var/obj/item/stack/material/steel/steel = new(H,19,FALSE)
		H.l_hand = electronics
		H.r_hand = steel
		H.hand = TRUE
		electronics.produce_recipe(R,1,H)
		trace_check(electronics.amount == 40 && steel.amount == 19 && !(locate(/obj/structure/drill/sifter) in T), "short steel consumes neither input [R.title]")
		steel.amount = 40
		electronics.produce_recipe(R,1,H)
		var/obj/structure/drill/sifter/built = locate() in T
		trace_check(electronics.amount == 20 && steel.amount == 20 && built && built.type == R.result_type, "actual recipe pays twenty electronics and twenty steel [R.title]")

/proc/trace_recipe_rows(list/recipes)
	var/list/rows = list()
	for (var/datum/R in recipes)
		if (istype(R, /datum/stack_recipe))
			rows += R
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/category = R
			rows += trace_recipe_rows(category.recipes)
	return rows
