// Headless probe for the Stone Age storage containers (code/modules/1713/stone_age_storage.dm).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/stone_age_storage/probe.dm
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Era gate only: a node counts as done once its era is reached.
/obj/map_metadata/storage_probe/New()
	return
/obj/map_metadata/storage_probe/is_node_done(faction, node_id)
	var/datum/research_node/N = get_research_node(node_id)
	return N && N.era_tier <= ordinal_age

var/store_failures = 0
var/store_runtime_error = FALSE
/proc/store_check(condition, label)
	if (!condition)
		store_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	store_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		map = new /obj/map_metadata/storage_probe
		build_research_tree()
		store_recipe_checks()
		store_capacity_checks()
		store_dump_checks()
		store_food_checks()
		store_zeer_checks()
		store_jar_firing_checks()
		store_reload_checks()
		store_sprite_checks()
	catch(var/exception/e)
		store_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = store_failures, "runtime_error" = store_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/store_recipe_paths(material_name)
	var/material/M = get_material_by_name(material_name)
	M.generate_recipes_civs(list(0,0,0), "global")
	. = list()
	for (var/R in M.recipes)
		if (istype(R, /datum/stack_recipe))
			var/datum/stack_recipe/SR = R
			. += SR.result_type
		else if (istype(R, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/L = R
			for (var/datum/stack_recipe/SR in L.recipes)
				. += SR.result_type

/proc/store_recipe_checks()
	var/list/catalog = list()
	for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
		if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
			catalog += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
	craftlist_lists["global"] = catalog
	store_check(catalog.len > 100, "global crafting catalog loaded")

	map.ordinal_age = 0
	var/list/rope = store_recipe_paths("rope")
	var/list/leaf = store_recipe_paths("leaf")
	var/list/bamboo = store_recipe_paths("bamboo")
	var/list/wood = store_recipe_paths("wood")
	var/list/clay = store_recipe_paths("clay")
	var/list/leather = store_recipe_paths("leather")
	store_check((/obj/structure/storage_container/basket in rope) && (/obj/structure/storage_container/basket in leaf) && (/obj/structure/storage_container/basket in bamboo), "Stone Age: rope, grass and bamboo make a woven basket")
	store_check(/obj/structure/storage_container/log_chest in wood, "Stone Age: logs make a hewn log chest")
	store_check(/obj/item/weapon/clay/storage_jar in clay, "Stone Age: clay makes an unfired storage jar")
	store_check(/obj/item/weapon/clay/storage_jar/zeer_pot in clay, "Stone Age: clay makes an unfired zeer pot")
	store_check((/obj/item/weapon/storage_pit_lining in leaf) && (/obj/item/weapon/storage_pit_lining in leather), "Stone Age: grass or leather makes a pit lining")
	store_check(!(/obj/structure/closet/crate/chest in store_recipe_paths("woodplank")), "Stone Age: the wood chest still waits for Cooperage")
	for (var/path in list("/obj/structure/storage_container/basket", "/obj/structure/storage_container/log_chest", "/obj/item/weapon/clay/storage_jar", "/obj/item/weapon/clay/storage_jar/zeer_pot", "/obj/item/weapon/storage_pit_lining"))
		var/node_id = get_recipe_node_req(path)
		var/datum/research_node/N = get_research_node(node_id)
		store_check(N && N.era_tier == 0, "[path] is gated by an era 0 node ([node_id])")
	store_check(potters_wheel_wares[/obj/item/weapon/clay/storage_jar], "the potter's wheel throws storage jars")

/proc/store_put(obj/structure/storage_container/C, obj/item/I)
	C.ensure_storage()
	if (!C.storage.can_be_inserted(I, TRUE))
		return FALSE
	C.storage.handle_item_insertion(I, TRUE)
	return I.loc == C.storage

/proc/store_item(turf/T, size)
	var/obj/item/weapon/storage/box/B = new(T)
	B.w_class = size
	return B

/proc/store_capacity_checks()
	var/turf/T = locate(5, 5, 1)
	var/obj/structure/storage_container/basket/basket = new(T)
	var/obj/structure/storage_container/storage_jar/jar = new(T)
	var/obj/structure/storage_container/log_chest/chest = new(T)
	var/obj/structure/storage_container/storage_pit/pit = new(T)
	store_check(basket.storage.storage_slots == 7 && jar.storage.storage_slots == 6 && chest.storage.storage_slots == 10 && pit.storage.storage_slots == 14, "slots: basket 7, jar 6, chest 10, pit 14")
	store_check(store_put(jar, store_item(T, ITEM_SIZE_SMALL)) && !store_put(jar, store_item(T, ITEM_SIZE_NORMAL)), "the jar takes small things only")
	store_check(store_put(basket, store_item(T, ITEM_SIZE_NORMAL)) && !store_put(basket, store_item(T, ITEM_SIZE_LARGE)), "the basket takes normal things, not large ones")
	store_check(store_put(chest, store_item(T, ITEM_SIZE_LARGE)) && !store_put(chest, store_item(T, ITEM_SIZE_HUGE)), "the log chest takes large tools, not huge things")
	var/fitted = 0
	for (var/i = 1 to 20)
		if (store_put(pit, store_item(T, ITEM_SIZE_SMALL)))
			fitted++
	store_check(fitted == 14, "the pit stops at its 14 slots (fitted [fitted])")
	store_check(pit.anchored && !basket.anchored && !chest.anchored && !jar.anchored, "only the pit is fixed in place")
	store_check(!jar.flammable && basket.flammable && chest.flammable, "the clay jar does not burn")
	store_check(basket.icon_state == "basket_full" && jar.icon_state == "storage_jar_full", "a filled container shows its full sprite")

/proc/store_dump_checks()
	var/turf/T = locate(8, 8, 1)
	var/obj/structure/storage_container/basket/basket = new(T)
	for (var/i = 1 to 3)
		store_put(basket, store_item(T, ITEM_SIZE_SMALL))
	var/turf/out = locate(9, 8, 1)
	var/came_out = basket.empty_out(out)
	var/on_floor = 0
	for (var/obj/item/weapon/storage/box/B in out)
		on_floor++
	store_check(came_out == 3 && on_floor == 3 && !basket.storage.contents.len, "Dump Out tips everything onto the floor")
	store_check(basket.icon_state == "basket", "an emptied basket shows its empty sprite")
	var/obj/structure/storage_container/log_chest/chest = new(T)
	store_put(chest, store_item(T, ITEM_SIZE_LARGE))
	var/before = 0
	for (var/obj/item/weapon/storage/box/B in T)
		before++
	qdel(chest)
	var/after = 0
	for (var/obj/item/weapon/storage/box/B in T)
		after++
	store_check(after == before + 1, "a destroyed chest spills what it held")

/proc/store_food_checks()
	var/turf/T = locate(11, 11, 1)
	var/obj/structure/storage_container/storage_jar/jar = new(T)
	var/obj/structure/storage_container/storage_pit/pit = new(T)
	var/obj/structure/storage_container/basket/basket = new(T)
	store_check(storage_food_decay_step(jar.storage) == 150, "food in a jar ages at half the container rate")
	store_check(storage_food_decay_step(pit.storage) == 200, "food in a pit ages slower than in a basket")
	store_check(storage_food_decay_step(basket.storage) == 300, "food in a basket ages like any container")
	var/obj/item/weapon/storage/internal/loose = new(T)
	store_check(storage_food_decay_step(loose) == 300, "an unowned holder keeps the container rate")

/proc/store_zeer_checks()
	var/turf/T = locate(12, 14, 1)
	var/obj/structure/storage_container/storage_jar/zeer_pot/Z = new(T)
	store_check(Z.rodent_access_level() == RODENT_PROOF && !Z.flammable, "a zeer pot is a fired jar: mouse-proof and fireproof")
	store_check(storage_food_decay_step(Z.storage) == 150 && Z.icon_state == "zeer_pot", "dry, it keeps food like a jar")
	var/obj/item/weapon/reagent_containers/glass/bucket/B = new(T)
	B.reagents.add_reagent("water", 100)
	var/mob/M = new(T)
	store_check(Z.pour_water(B, M) && Z.water == 60 && B.reagents.get_reagent_amount("water") == 40, "pouring soaks the sand up to its limit")
	store_check(storage_food_decay_step(Z.storage) == 100 && Z.icon_state == "zeer_pot_wet", "wet, it keeps food longer and looks wet")
	store_check(!Z.pour_water(B, M), "soaked sand takes no more water")
	Z.water_tick = world.time - 600 * 600 // ten hours
	var/rate = Z.water_sample_rate
	Z.settle_water()
	store_check(rate <= 0 ? Z.water == 60 : (Z.water == 0 && Z.icon_state == "zeer_pot"), "the sand dries out over time unless it is freezing")
	Z.water = 30
	Z.after_load()
	store_check(Z in processing_objects, "wet pots resume ambient sampling after load")
	Z.settle_water()
	store_check(Z.water == 30 && Z.water_tick == world.time, "time before a load does not dry it")
	store_check(Z.persistence_runtime_var("water_tick") && Z.persistence_runtime_var("water_sample_rate") && !Z.persistence_runtime_var("water"), "the water is saved, its clock is not")
	var/obj/item/weapon/clay/storage_jar/zeer_pot/wet = new(T)
	store_check(wet.result == /obj/structure/storage_container/storage_jar/zeer_pot, "the unfired pot fires into a zeer pot")
	store_zeer_transition_checks(T)

// Force the current ambient rate without requiring a real weather transition.
/obj/structure/storage_container/storage_jar/zeer_pot/probe_sampler
	var/probe_rate = 0

/obj/structure/storage_container/storage_jar/zeer_pot/probe_sampler/evaporation_rate()
	return probe_rate

/proc/store_zeer_transition_checks(turf/T)
	var/obj/structure/storage_container/storage_jar/zeer_pot/probe_sampler/Z = new(T)
	Z.water = 2
	Z.after_load()
	Z.process_interval()
	Z.water_tick = world.time - 6000
	Z.probe_rate = 0.33
	Z.settle_water()
	store_check(Z.water == 2 && Z.water_sample_rate == 0.33, "warming does not evaporate water from a prior frozen interval")
	Z.water_tick = world.time - 6000
	Z.probe_rate = 0
	Z.process_interval()
	store_check(Z.water == 0 && !(Z in processing_objects), "freezing does not restore water from a prior warm interval, and dry pots stop processing")
	qdel(Z)

/proc/store_jar_firing_checks()
	var/turf/T = locate(14, 14, 1)
	var/obj/item/weapon/clay/storage_jar/wet = new(T)
	var/returned = wet.fired_result(T)
	var/found = 0
	for (var/turf/near in range(1, T))
		for (var/obj/structure/storage_container/storage_jar/J in near)
			found++
	store_check(istype(returned, /obj/structure/storage_container/storage_jar) && found == 1, "firing an unfired jar sets a storage jar down beside the kiln")
	store_oven_jar_checks()
	store_jar_salvage_checks()

// Drive the real oven pass: one jar out, nothing left in the oven, and a second
// pass makes nothing more. An oven with nowhere to set a jar keeps the charge.
/proc/store_oven_jar_checks()
	var/turf/T = locate(4, 16, 1)
	var/obj/structure/oven/O = new(T)
	var/obj/item/weapon/clay/storage_jar/wet = new(O)
	var/obj/item/weapon/clay/storage_jar/zeer_pot/pot = new(O)
	var/obj/item/weapon/clay/washbasin/control = new(T) // an ordinary item result stays in the oven
	control.loc = O
	var/runtime_before = store_runtime_error
	O.process()
	O.process()
	var/jars = 0
	var/zeers = 0
	for (var/turf/near in range(1, T))
		for (var/obj/structure/storage_container/storage_jar/J in near)
			if (istype(J, /obj/structure/storage_container/storage_jar/zeer_pot))
				zeers++
			else
				jars++
	var/left = 0
	for (var/obj/item/weapon/clay/storage_jar/S in T)
		left++
	var/held_structures = 0
	for (var/obj/structure/S in O.contents)
		held_structures++
	store_check(jars == 1 && zeers == 1, "two oven passes fire one jar and one zeer pot, not more")
	store_check(QDELETED(wet) && QDELETED(pot) && !left, "the unfired jars are used up")
	store_check(!held_structures, "no fired jar is put inside the oven")
	store_check(QDELETED(control) && (locate(/obj/item/weapon/washbasin) in T), "an ordinary fired item still comes out of the oven")
	store_check(store_runtime_error == runtime_before, "firing jars in an oven raises no runtime error")
	var/before = 0
	for (var/obj/structure/storage_container/storage_jar/J in world)
		before++
	var/obj/structure/oven/lost = new(null)
	var/obj/item/weapon/clay/storage_jar/kept = new(T)
	kept.loc = lost
	lost.process()
	var/placed = 0
	for (var/obj/structure/storage_container/storage_jar/J in world)
		placed++
	store_check(!QDELETED(kept) && placed == before, "with nowhere to set a jar down the unfired jar is kept and nothing is made")

// Fired pottery has no recipe of its own and is not wood, so a hammer gives no wood.
/proc/store_jar_salvage_checks()
	var/turf/T = locate(10, 16, 1)
	var/obj/structure/storage_container/storage_jar/J = new(T)
	var/obj/structure/storage_container/storage_jar/zeer_pot/Z = new(T)
	var/obj/structure/storage_container/basket/B = new(T)
	var/obj/structure/S = new(T) // a recipe-less structure still gives back wood
	store_check(isnull(crafted_refund_stack(J.type, /obj/item/stack/material/wood)) && isnull(crafted_refund_stack(Z.type, /obj/item/stack/material/wood)), "a fired jar or zeer pot gives no wood when dismantled")
	store_check(crafted_refund_stack(S.type, /obj/item/stack/material/wood) == /obj/item/stack/material/wood, "a recipe-less wooden structure still gives back wood")
	store_check(crafted_refund_stack(B.type, /obj/item/stack/material/wood) != /obj/item/stack/material/wood || crafted_refund_units(B.type) > 0, "a crafted container keeps its recipe refund")

/proc/store_reload_checks()
	var/turf/T = locate(16, 5, 1)
	var/obj/structure/storage_container/log_chest/chest = new(T)
	var/obj/item/weapon/storage/internal/saved = chest.storage
	store_put(chest, store_item(T, ITEM_SIZE_SMALL))
	chest.storage = null // a load restores contents but not the runtime reference
	chest.after_load()
	store_check(chest.storage == saved && chest.storage.contents.len == 1 && chest.storage.master_item == chest, "after a load the chest binds its saved holder")
	store_check(chest.persistence_runtime_var("storage"), "the holder reference is runtime state")

/proc/store_sprite_checks()
	var/list/states = icon_states('icons/obj/stone_age_storage.dmi')
	for (var/state in list("basket", "basket_full", "storage_jar", "storage_jar_full", "storage_jar_unfired", "log_chest", "log_chest_full", "storage_pit", "storage_pit_full", "pit_lining", "zeer_pot", "zeer_pot_full", "zeer_pot_wet", "zeer_pot_wet_full", "zeer_pot_unfired"))
		store_check(state in states, "icon state [state]")
