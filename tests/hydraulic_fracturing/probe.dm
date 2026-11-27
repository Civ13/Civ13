/world
	hub = ""
	hub_password = ""
	maxx = 24
	maxy = 24
	maxz = 2
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
		O.reagents.add_reagent("petroleum", O.reagents.get_free_space() - 49)
		D.attack_hand(H)
		fracture_check(!D.active && W.reagents.get_reagent_amount("water") == 20 && S.amount == 5 && R.is_mineable && C.currentflow == 0, "full output rejects batch without payment or power")
		O.reagents.clear_reagents()
		E.on = FALSE
		D.attack_hand(H)
		fracture_check(!D.active && !D.fracture_identity && W.reagents.get_reagent_amount("water") == 20, "disconnected power rejects without payment or identity")
		E.on = TRUE
		D.attack_hand(H)
		S.loc = T
		sleep(25)
		fracture_check(!D.active && C.currentflow == 0 && !O.reagents.total_volume && R.is_mineable, "removed sand cancels without payment")
		S.loc = D
		var/prior_map_id = map.ID
		map.ID = MAP_NOMADS_AMERICAS_NORTH
		map.province_map_loaded = TRUE
		var/datum/province_map/PM = new
		PM.maxx = world.maxx
		PM.maxy = world.maxy
		for (var/y in 1 to world.maxy)
			PM.rows += "AAAAAAAAAAAAAAAAAAAAAAAA"
		PM.names["A"] = "Fixture province"
		map.province_map_cache = PM
		var/list/holding = province_holder_row("A")
		H.civilization = "fixture owner"
		holding[1] = province_group_of(H.civilization)
		fracking_foul_sites.Cut()
		var/original_pollution = T.pollution
		D.attack_hand(H)
		fracture_check(D.active && D.fracture_faction == "fixture owner" && C.currentflow == 300, "current province holder can start and its faction is pinned")
		holding[1] = province_group_of("fixture rival")
		D.next_spawn = 0
		D.production_due = world.time
		sleep(25)
		fracture_check(!D.active && !D.process_pending && !D.fracture_faction && C.currentflow == 0, "loss of province stops the due batch and clears its reservation and faction")
		fracture_check(W.reagents.get_reagent_amount("water") == 20 && S.amount == 5 && !O.reagents.total_volume && R.is_mineable && T.pollution == original_pollution && !fracking_foul_sites.len, "denied completion changes no inputs, output, rock or pollution")
		D.attack_hand(H)
		fracture_check(!D.active && C.currentflow == 0, "former holder cannot restart the rig")
		holding[1] = province_group_of(H.civilization)
		D.attack_hand(H)
		fracture_check(D.active && C.currentflow == 300, "regaining the holding permits deliberate restart")
		D.stop_drilling()
		sleep(25)
		H.civilization = null
		map.ID = prior_map_id
		map.province_map_cache = null
		map.province_map_loaded = FALSE
		fracture_water_checks()
		fracture_catalog(H)
		H.loc = T
		D.attack_hand(H)
		D.next_spawn = 0
		D.production_due = world.time
		sleep(25)
		R = locate(4,5,1)
		fracture_check(!R.is_mineable && O.reagents.get_reagent_amount("petroleum") == 50, "second finite batch depletes replacement rock")
		W.reagents.add_reagent("water", 20)
		S = new(D,5,FALSE)
		D.powersource = null
		D.name = "saved finite rig"
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("fracture.sav")
		F["/format_version"] << 2
		var/id = map_storage.BuildVarDirectory(F,D,1)
		var/terrain_id = map_storage.BuildVarDirectory(F,R,1)
		F.Flush()
		qdel(D)
		R = new /turf/floor/dirt/underground(R)
		F = null
		map_storage.clear_bookkeeping()
		F = new("fracture.sav")
		D = map_storage.Load_Entry(F,id,null,T)
		R = map_storage.Load_Entry(F,terrain_id,R)
		for (var/datum/A in map_storage.all_loaded)
			A.after_load()
		fracture_check(D && D.name == "saved finite rig" && !D.active && !D.process_pending && !D.fracture_target && D.contents.len == 3, "disk save reloads stopped with contained inputs")
		fracture_check(R && !R.is_mineable && !istype(R,/turf/floor/dirt/underground), "disk save restores depleted terrain instead of mineable rock")
		var/obj/structure/drill/fracking/rebuilt = new(T)
		rebuilt.anchored = TRUE
		rebuilt.attack_hand(H)
		fracture_check(!rebuilt.active && !rebuilt.fracture_target, "rebuilding rig does not renew saved depleted terrain")
	catch(var/exception/e)
		fracture_check(FALSE, "exception [e]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = fracture_failures, "runtime_error" = fracture_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/fracture_water_checks()
	fracking_foul_sites.Cut()
	var/day = 864000
	var/now = 1000
	var/turf/well = locate(5, 5, 2)
	fracking_record_foul_site(5, 5, now)
	fracture_check(fracking_fouls_near(locate(11, 11, 2), now) && !fracking_fouls_near(locate(12, 5, 2), now) && !fracking_fouls_near(locate(5, 12, 2), now), "groundwater uses exactly the six-tile horizontal square, including diagonals")
	for (var/x in 14 to 21)
		for (var/y in 14 to 21)
			fracking_record_foul_site(x, y, now + 20)
	fracture_check(fracking_foul_sites.len == 65 && fracking_fouls_near(well, now + 20), "64 distant batches cannot evict nearby fouling across levels")
	fracture_check(fracking_fouls_near(well, now + day) && !fracking_fouls_near(well, now + day + 1), "read expires the original source by age without new batches")
	fracking_record_foul_site(5, 5, now + 50)
	fracture_check(fracking_foul_sites.len == 65 && fracking_fouls_near(well, now + day + 1), "reusing a column refreshes only its timestamp without duplicates")
	fracking_record_foul_site(24, 24, now + day + 21)
	fracture_check(fracking_foul_sites.len == 2 && !fracking_fouls_near(locate(15, 15, 2), now + day + 21), "new batches prune aged sites without expiring the refreshed site")
	var/no_row_growth = TRUE
	for (var/wave in 2 to 6)
		for (var/y in 14 to 21)
			fracking_record_foul_site(14 + wave, y, now + (day + 1) * wave + 100)
		if (fracking_foul_sites.len != 8)
			no_row_growth = FALSE
	fracture_check(no_row_growth, "repeated days of distinct distant batches retain only the current day's live sites")
	fracking_foul_sites.Cut()

/proc/fracture_recipe_rows(list/recipes)
	var/list/rows = list()
	for (var/datum/R in recipes)
		if (istype(R, /datum/stack_recipe))
			rows += R
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/category = R
			rows += fracture_recipe_rows(category.recipes)
	return rows

/proc/fracture_catalog(mob/living/human/fracture_probe/H)
	var/list/rows = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1)
			rows += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = rows
	var/material/electronics/M = get_material_by_name("electronic")
	map.faction_baseline_era["fracture-before"] = 7
	M.generate_recipes_civs(list(0,0,0), "global", "fracture-before")
	var/locked = TRUE
	for (var/datum/stack_recipe/R in fracture_recipe_rows(M.recipes))
		if (R.result_type == /obj/structure/drill/fracking)
			locked = FALSE
	fracture_check(locked, "actual catalog hides fracking before Modern")
	map.faction_baseline_era["fracture-after"] = 8
	M.generate_recipes_civs(list(0,0,0), "global", "fracture-after")
	var/datum/stack_recipe/recipe
	for (var/datum/stack_recipe/R in fracture_recipe_rows(M.recipes))
		if (R.result_type == /obj/structure/drill/fracking)
			recipe = R
	fracture_check(recipe, "actual catalog exposes fracking at Modern")
	if (!recipe)
		return
	// The shared extraction fixture covers construction wait cancellation.
	recipe.time = 0
	var/turf/T = locate(9,9,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	H.loc = T
	H.stats = list("strength" = list(100,100), "crafting" = list(220,220))
	var/obj/item/stack/material/electronics/electronics = new(H,40,FALSE)
	var/obj/item/stack/material/steel/steel = new(H,19,FALSE)
	H.l_hand = electronics
	H.r_hand = steel
	H.hand = TRUE
	electronics.produce_recipe(recipe,1,H)
	fracture_check(electronics.amount == 40 && steel.amount == 19 && !(locate(/obj/structure/drill/fracking) in T), "short construction steel consumes neither input")
	steel.amount = 40
	electronics.produce_recipe(recipe,1,H)
	var/obj/structure/drill/fracking/built = locate() in T
	fracture_check(electronics.amount == 20 && steel.amount == 20 && built, "actual fracking recipe pays twenty electronics and twenty steel")
