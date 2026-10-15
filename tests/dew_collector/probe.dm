/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

// Actor startup and action waits only; collector, reagents, construction,
// temperature, area/roof eligibility and persistence remain production code.
/mob/living/human/dew_tester
	var/wait_mode = "complete"

/mob/living/human/dew_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build

/mob/living/human/dew_tester/religion_check()
	return "none"

/mob/living/human/dew_tester/drop_from_inventory(obj/item/W, atom/Target = null, ignore_nodrop = FALSE)
	W.forceMove(Target ? Target : loc)
	return TRUE

/mob/living/human/dew_tester/dew_drawing_wait(atom/target)
	if (wait_mode == "real_complete")
		return do_after(src, 2, target, progress = FALSE)
	if (wait_mode == "real_move")
		spawn(1)
			loc = locate(8,8,1)
		return do_after(src, 4, target, progress = FALSE)
	if (wait_mode == "cancel")
		return FALSE
	if (wait_mode == "move")
		loc = locate(8,8,1)
	if (wait_mode == "dispose")
		qdel(target)
	if (wait_mode == "overlap")
		var/obj/structure/reagent_dispensers/dew_collector/D = target
		var/obj/item/weapon/reagent_containers/C = locate() in src
		dew_assert(!D.draw_water(C, src), "overlapping draw rejected")
	return TRUE

/obj/map_metadata/dew_tester/New()
	return

// Roof presence is checked by production code; its area/lighting constructor
// is outside this isolated fixture and area exposure is tested separately.
/obj/roof/dew_tester/New()
	return

/obj/structure/reagent_dispensers/dew_collector/add_fingerprint(mob/living/M, ignoregloves = FALSE)
	return

/proc/dew_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "DEW PASS: [message]"

// Advance the clock adapter by one normal interval while retaining production
// throttling. This is nominal game time, not a wall-time performance measurement.
/proc/dew_step(obj/structure/reagent_dispensers/dew_collector/D, count = 1)
	for (var/i in 1 to count)
		D.last_collection_tick = world.time - 20
		D.process_interval(2)

/proc/dew_recipe(list/recipes)
	for (var/entry in recipes)
		if (istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			var/datum/stack_recipe/found = dew_recipe(group.recipes)
			if (found)
				return found
		else if (istype(entry, /datum/stack_recipe))
			var/datum/stack_recipe/R = entry
			if (R.result_type == /obj/structure/reagent_dispensers/dew_collector)
				return R
	return null

/world/New()
	OpenPort("none")
	sleep(1)
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x1", "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		var/area/A = get_area(site)
		A.location = AREA_OUTSIDE
		A.weather = WEATHER_NONE
		A.icon_state = ""
		season = "SPRING"
		time_of_day = "Night"
		map = new /obj/map_metadata/dew_tester
		map.ordinal_age = 0
		var/mob/living/human/dew_tester/U = new(site)
		build_research_tree()
		craftlist_lists["global"] = list()
		for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
			if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
				craftlist_lists["global"] += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
		var/material/wood/soft/planks = new
		var/faction = "dew_fixture"
		map.faction_baseline_era[faction] = 0
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		dew_assert(!dew_recipe(planks.recipes), "unresearched collector hidden")
		dew_assert(get_recipe_node_req("/obj/structure/reagent_dispensers/dew_collector") == "basic_agriculture", "agriculture research mapping")
		var/list/research_entry = map.ensure_node_entry(faction, "basic_agriculture")
		research_entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		var/datum/stack_recipe/recipe = dew_recipe(planks.recipes)
		dew_assert(recipe && recipe.req_amount == 8 && recipe.one_per_turf && recipe.on_floor, "paid collector recipe")
		recipe.time = 0
		var/obj/item/stack/material/woodplank/wood = new(site, 7, FALSE)
		wood.produce_recipe(recipe, 1, U)
		dew_assert(!(locate(/obj/structure/reagent_dispensers/dew_collector) in site), "insufficient planks rejected")
		wood.amount = 9
		wood.produce_recipe(recipe, 1, U)
		var/obj/structure/reagent_dispensers/dew_collector/D = locate() in site
		dew_assert(D && wood.amount == 1 && D.reagents.total_volume == 0, "paid empty collector constructed")
		dew_assert(D.collection_rate() == 2, "clear night dew rate")
		D.last_collection_tick = world.time - 6000
		D.process_interval(600)
		dew_assert(D.reagents.total_volume == 0 && D.collection_seconds <= 2, "delayed tick cannot replay backlog")
		D.collection_seconds = 0
		dew_step(D, 29)
		dew_assert(D.reagents.total_volume == 0, "no early yield")
		dew_step(D)
		dew_assert(D.reagents.get_reagent_amount("water") == 2, "one minute dew yield")
		D.process_interval(2)
		dew_assert(D.collection_seconds == 0, "same tick no duplicate credit")
		A.location = AREA_INSIDE
		dew_assert(D.collection_rate() == 0, "indoors rejected")
		A.location = AREA_OUTSIDE
		var/obj/roof/dew_tester/R = new(site)
		dew_assert(D.collection_rate() == 0, "roof rejected")
		qdel(R)
		D.radiation = 1
		dew_assert(D.collection_rate() == 0, "radiation rejected")
		D.radiation = 0
		time_of_day = "Midday"
		dew_assert(D.collection_rate() == 0, "daylight dew rejected")
		A.weather = WEATHER_WET
		A.icon_state = "snow1"
		dew_assert(D.collection_rate() == 0, "wet snow is not rain")
		A.icon_state = "rain2"
		dew_assert(D.collection_rate() == 10, "rain collection rate")
		D.collection_seconds = 58
		dew_step(D)
		dew_assert(D.reagents.total_volume == 2 && D.collection_seconds == 2, "rate change cancels partial minute")
		dew_step(D, 29)
		dew_assert(D.reagents.get_reagent_amount("water") == 12, "one minute rain yield")
		D.reagents.clear_reagents()
		D.reagents.add_reagent("water", 199)
		dew_step(D, 30)
		dew_assert(D.reagents.total_volume == 200, "capacity bounds collection")
		dew_step(D, 60)
		dew_assert(D.reagents.total_volume == 200 && D.collection_seconds == 0, "full collector has no backlog")
		D.collection_seconds = 58
		D.attack_hand(U)
		dew_step(D, 30)
		dew_assert(!D.collecting && D.collection_seconds == 0 && D.reagents.total_volume == 200, "cover cancels collection")
		D.attack_hand(U)
		map.heat_wave = TRUE
		dew_assert(D.collection_rate() == 0, "heatwave rejected")
		map.heat_wave = FALSE
		season = "WINTER"
		dew_assert(D.collection_rate() == 0, "frozen collection rejected")
		season = "SPRING"
		var/obj/item/weapon/reagent_containers/glass/beaker/C = new(U)
		U.wait_mode = "cancel"
		dew_assert(!D.draw_water(C,U) && C.reagents.total_volume == 0 && D.reagents.total_volume == 200 && !D.drawing, "cancelled drawing conserves water")
		U.wait_mode = "overlap"
		dew_assert(D.draw_water(C,U) && C.reagents.get_reagent_amount("water") == 20 && D.reagents.total_volume == 180, "drawing conserves source and target water")
		U.wait_mode = "move"
		dew_assert(!D.draw_water(C,U) && D.reagents.total_volume == 180, "movement cancels drawing")
		U.loc = site
		U.wait_mode = "real_move"
		dew_assert(!D.draw_water(C,U) && D.reagents.total_volume == 180, "real movement cancels drawing")
		U.loc = site
		U.wait_mode = "real_complete"
		dew_assert(D.draw_water(C,U) && D.reagents.total_volume == 160 && C.reagents.total_volume == 40, "real delayed drawing conserves water")
		D.collecting = FALSE
		D.drawing = TRUE
		D.collection_seconds = 58
		dew_assert(!("drawing" in D.get_saved_vars()), "drawing lock excluded")
		for (var/key in list("collection_seconds", "collection_mode", "last_collection_tick", "retired_collector"))
			dew_assert(!(key in D.get_saved_vars()) && D.persistence_runtime_var(key), "runtime field excluded: [key]")
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("dew-state.sav")
		F["/format_version"] << 2
		var/id = map_storage.BuildVarDirectory(F, D, 1)
		F.Flush()
		F = null
		F = new("dew-state.sav")
		map_storage.clear_bookkeeping()
		var/obj/structure/reagent_dispensers/dew_collector/loaded = map_storage.Load_Entry(F, id, starting_loc = site)
		dew_assert(loaded && !loaded.collecting && loaded.reagents.get_reagent_amount("water") == 160 && !loaded.drawing && loaded.collection_seconds == 0, "real reagent contents and cover disk round trip")
		var/registrations = 0
		for (var/obj/O in processing_objects)
			if (O == loaded)
				registrations++
		dew_assert(registrations == 1, "loaded object registered exactly once")
		loaded.collecting = TRUE
		dew_step(loaded)
		dew_assert(loaded.reagents.total_volume == 160, "restore no collection replay")
		loaded.retire_collection()
		dew_step(loaded, 60)
		dew_assert(!(loaded in processing_objects) && loaded.reagents.total_volume == 160, "retired collector cannot yield")
		U.wait_mode = "dispose"
		D.drawing = FALSE
		dew_assert(!D.draw_water(C,U) && !D.loc, "disposal cancels drawing")
		// Legacy qdel nulls loc before deferred Destroy; processing must stop now.
		D.process_interval(2)
		dew_assert(!(D in processing_objects), "queued deletion unregisters before output")
		map_storage.clear_bookkeeping()
		text2file("PASS: dew collector and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "DEW exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
