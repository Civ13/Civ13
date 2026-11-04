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
/obj/map_metadata/crush_probe/New()
	return
/mob/living/human/crush_probe/New()
	return
// The fixture actor has no species appearance to redraw.
/mob/living/human/crush_probe/update_icons()
	return
// Bounded action-delay adapter; the production loop body is unchanged.
/obj/structure/stone_crusher/crush_probe/crushing_wait(mob/living/human/H)
	return TRUE
var/crush_failures = 0
var/crush_runtime_error = FALSE
/proc/crush_check(condition, label)
	if (!condition)
		crush_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	crush_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/proc/crush_table_total(list/table)
	var/total = 0
	for (var/ore_type in table)
		total += table[ore_type]
	return total
/proc/crush_count(turf/T, type)
	var/total = 0
	for (var/obj/item/stack/S in T)
		if (S.type == type)
			total += S.amount
	return total
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
		map = new /obj/map_metadata/crush_probe
		map.ordinal_age = 0
		crush_check(!world.port, "fixture has no listening port")
		crush_table_checks()
		crush_manual_checks()
		crush_stamp_mill_checks()
		crush_catalog_checks()
	catch(var/exception/e)
		crush_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = crush_failures, "runtime_error" = crush_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/crush_table_checks()
	var/list/stone_age = stone_crushing_table(0, FALSE)
	var/list/bronze = stone_crushing_table(1, FALSE)
	var/list/medieval = stone_crushing_table(2, FALSE)
	var/list/powered = stone_crushing_table(5, TRUE)
	crush_check(!(/obj/item/stack/ore/iron in stone_age) && (/obj/item/stack/ore/iron in bronze), "iron unlocks in the Bronze Age")
	crush_check(!(/obj/item/stack/ore/coal in bronze) && (/obj/item/stack/ore/coal in medieval) && (/obj/item/stack/ore/sulphur in medieval), "coal and powder minerals unlock in the Medieval age")
	crush_check(crush_table_total(stone_age) == 2650 && crush_table_total(medieval) == 3500, "manual odds: 6.5% ore in the Stone Age, 15% ore by the Medieval age, plus 20% sand")
	crush_check(crush_table_total(powered) == 4750 && powered[/obj/item/stack/ore/glass] == 2500 && powered[/obj/item/stack/ore/iron] == 450 && powered[/obj/item/stack/ore/diamond] == 15, "powered odds recover half again as much ore and 25% sand")
	crush_check(roll_stone_crushing(medieval, 1) == /obj/item/stack/ore/glass && roll_stone_crushing(medieval, 2001) == /obj/item/stack/ore/copper, "weighted roll walks the table in order")
	crush_check(isnull(roll_stone_crushing(medieval, 3501)) && isnull(roll_stone_crushing(powered, 10000)), "rolls past the table leave rubble")
	var/obj/item/stack/material/sandstone/sandstone = new(null)
	var/obj/item/stack/material/stone/stone = new(null)
	crush_check(is_crushable_stone(stone) && !is_crushable_stone(sandstone) && !is_crushable_stone(null), "only plain stone blocks are crushable")
	qdel(sandstone)
	qdel(stone)

/proc/crush_manual_checks()
	map.ordinal_age = 2
	var/turf/T = locate(3,3,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/stone_crusher/crush_probe/C = new(T)
	var/turf/standing = locate(3,4,1)
	standing = standing.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/crush_probe/H = new(standing)
	var/obj/item/stack/material/stone/S = new(H, 10, FALSE)
	crush_check(C.crush_one_stone(H, S, 1) && S.amount == 9 && crush_count(T, /obj/item/stack/ore/glass) == 1, "sand roll spends one stone and deposits one sand")
	crush_check(C.crush_one_stone(H, S, 9999) && S.amount == 8 && crush_count(T, /obj/item/stack/ore/glass) == 1, "rubble roll spends one stone and deposits nothing")
	crush_check(C.crush_one_stone(H, S, 2001) && crush_count(T, /obj/item/stack/ore/copper) == 1, "ore roll deposits ore under the crusher")
	for (var/obj/item/stack/item in T)
		qdel(item)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/wood(T, 50, FALSE)
	var/before = S.amount
	crush_check(!C.crush_one_stone(H, S, 1) && S.amount == before && !crush_count(T, /obj/item/stack/ore/glass), "full output refuses before spending stone")
	crush_check(C.crush_one_stone(H, S, 9999) && S.amount == before - 1, "rubble still clears with full output")
	for (var/obj/item/stack/item in T)
		qdel(item)
	// Held stone stays in the worker; equipment slots are not needed for the loop.
	var/remaining = S.amount
	var/crushed = C.crush_stones(H, S)
	crush_check(crushed == remaining && QDELETED(S) && !(H in C.crushing_workers), "worked loop crushes the held stack and releases the worker")
	var/obj/item/stack/material/stone/far = new(H, 5, FALSE)
	H.loc = locate(8,8,1)
	crush_check(!C.crush_stones(H, far) && far.amount == 5, "a distant worker crushes nothing")
	H.loc = standing
	C.anchored = FALSE
	crush_check(!C.crush_stones(H, far) && far.amount == 5, "an unanchored crusher refuses work")
	crush_check(!("crushing_workers" in C.get_saved_vars()), "worker list is runtime-only")
	qdel(far)
	qdel(C)
	qdel(H)
	for (var/obj/item/stack/item in T)
		qdel(item)

/proc/crush_stamp_mill_checks()
	map.ordinal_age = 5
	var/turf/T = locate(5,5,1)
	T = T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/obj/structure/drill/stamp_mill/M = new(T)
	M.anchored = TRUE
	var/obj/structure/cable/C = new(locate(6,5,1))
	var/obj/structure/engine/E = new(locate(7,5,1))
	E.on = TRUE
	E.maxpower = 200
	E.connections = list(C)
	C.connections = list(M,E)
	M.powersource = C
	var/turf/standing = locate(5,6,1)
	standing = standing.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	var/mob/living/human/crush_probe/H = new(standing)
	M.attack_hand(H)
	crush_check(!M.active && C.currentflow == 0, "empty hopper refuses to start")
	var/obj/item/stack/material/stone/S = new(H, 50, FALSE)
	var/obj/item/stack/material/stone/S2 = new(H, 10, FALSE)
	crush_check(M.load_stone(H, S) == 50 && QDELETED(S), "hopper takes a full stack")
	crush_check(!M.load_stone(H, S2) && S2.amount == 10 && M.loaded_stone_amount() == 50, "a full hopper takes no more stone")
	M.attack_hand(H)
	crush_check(M.active && M.process_pending && C.currentflow == 150, "loaded mill starts with reserved cable demand")
	for (var/i in 1 to 10)
		M.attack_hand(H)
		M.attack_hand(H)
	crush_check(M.active && M.loaded_stone_amount() == 50, "repeated toggles crush nothing early")
	sleep(45)
	crush_check(M.loaded_stone_amount() == 49, "one stone is stamped every four seconds")
	M.stop_drilling()
	sleep(21)
	crush_check(!M.process_pending && C.currentflow == 0, "stop settles callback and releases demand")
	for (var/obj/item/stack/item in T)
		qdel(item)
	for (var/i in 1 to 12)
		new /obj/item/stack/material/wood(T, 50, FALSE)
	crush_check(!M.stamp_one_stone(1) && M.loaded_stone_amount() == 49, "full output refuses before spending stone")
	for (var/obj/item/stack/item in T)
		qdel(item)
	crush_check(M.stamp_one_stone(1) && M.loaded_stone_amount() == 48 && crush_count(T, /obj/item/stack/ore/glass) == 1, "stamped sand roll spends one stone")
	for (var/obj/item/stack/item in T)
		qdel(item)
	var/obj/item/stack/material/stone/hopper = M.loaded_stone()
	hopper.amount = 1
	M.attack_hand(H)
	M.next_spawn = 0
	sleep(21)
	sleep(21)
	crush_check(!M.active && !M.loaded_stone() && C.currentflow == 0, "mill stops and releases demand once the hopper is empty")
	M.load_stone(H, S2)
	M.active = TRUE
	M.after_load()
	crush_check(!M.active && !M.process_pending && M.next_spawn == -1, "inherited load hook stops the mill")
	M.unload_stone()
	crush_check(!M.loaded_stone() && crush_count(T, /obj/item/stack/material/stone) == 10, "unloading returns hopper stone to the floor")
	qdel(M)
	qdel(H)

/proc/crush_catalog_checks()
	crush_check(get_recipe_node_req("/obj/structure/stone_crusher") == "resource_processing", "hand crusher unlocks at Resource Processing")
	crush_check(get_recipe_node_req("/obj/structure/drill/stamp_mill") == "electricity", "stamp mill unlocks at Electricity")
	var/list/states = icon_states('icons/obj/structures.dmi')
	crush_check("grindstone" in states, "hand crusher sprite state exists")
	var/obj/structure/drill/stamp_mill/M = new(null)
	states = icon_states(M.icon)
	crush_check(("mining_drill" in states) && ("mining_drill_powered" in states) && ("mining_drill_active" in states), "stamp mill sprite states exist")
	qdel(M)
	var/list/rows = list()
	for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
		if (findtext(line, "RECIPE: ") == 1)
			rows += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = rows
	var/material/stone/stone = get_material_by_name("stone")
	map.ordinal_age = 1
	map.faction_baseline_era["crush-before"] = 0
	stone.generate_recipes_civs(list(0,0,0), "global", "crush-before")
	crush_check(!crush_has_recipe(stone.recipes, /obj/structure/stone_crusher), "hand crusher hidden before Resource Processing")
	map.faction_baseline_era["crush-after"] = 1
	stone.generate_recipes_civs(list(0,0,0), "global", "crush-after")
	crush_check(crush_has_recipe(stone.recipes, /obj/structure/stone_crusher), "hand crusher craftable from stone at Resource Processing")
	var/material/electronics/electronics = get_material_by_name("electronic")
	map.ordinal_age = 5
	map.faction_baseline_era["crush-power-before"] = 4
	electronics.generate_recipes_civs(list(0,0,0), "global", "crush-power-before")
	crush_check(!crush_has_recipe(electronics.recipes, /obj/structure/drill/stamp_mill), "stamp mill hidden before Electricity")
	map.faction_baseline_era["crush-power-after"] = 5
	electronics.generate_recipes_civs(list(0,0,0), "global", "crush-power-after")
	crush_check(crush_has_recipe(electronics.recipes, /obj/structure/drill/stamp_mill), "stamp mill buildable at Electricity")

/proc/crush_has_recipe(list/recipes, result_type)
	for (var/datum/R in recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/recipe = R
			if (recipe.result_type == result_type)
				return TRUE
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/category = R
			if (crush_has_recipe(category.recipes, result_type))
				return TRUE
	return FALSE
