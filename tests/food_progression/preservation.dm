/obj/map_metadata/food_fixture/New()
	return
/mob/living/human/food_fixture/New()
	return
/mob/living/human/food_fixture/adaptStat(stat, amount)
	return
/proc/food_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1) // Stop this caller while world shutdown completes.
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Food fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	OpenPort("none")
	food_check(!world.port, "preservation fixture closes listener")
	if (config)
		config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	var/turf/T = locate(2,2,1)
	var/obj/structure/dehydrator/rack = new(T)
	sleep(35) // Allow production constructor/refill startup to finish.
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/input = new(T)
	input.reagents.remove_reagent("nutriment", 3)
	input.reagents.remove_reagent("protein", 0.5)
	input.decaytimer = 1200
	var/nutrition_before = input.reagents.get_reagent_amount("nutriment")
	var/protein_before = input.reagents.get_reagent_amount("protein")
	food_check(rack.hang_on(input), "production rack accepts paid partial food")
	food_check(input.loc == rack.storage, "production storage owns drying input")
	rack.set_dry_timer(input, 150)
	rack.before_save()
	food_check(input.loc == T && !rack.storage.contents.len, "production before_save drops input out of runtime storage")
	food_check(rack.slots[1][1] == null, "production before_save clears runtime slot")
	var/savefile/F = new("preservation.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, input)
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/restored = map_storage.Load_Entry(F, ref, starting_loc = T)
	food_check(restored && restored != input, "native disk entry creates restored input")
	food_check(restored.decaytimer == 1200, "native disk entry retains accumulated food age")
	food_check(restored.reagents.get_reagent_amount("nutriment") == nutrition_before && restored.reagents.get_reagent_amount("protein") == protein_before, "native disk entry retains partial nutrition")
	food_check(rack.get_dry_timer(restored) == 150, "native disk entry retains encoded drying progress")
	qdel(input) // Only the restored paid input proceeds.
	rack.refill()
	food_check(restored.loc == rack.storage, "production refill recognizes restored drying input")
	rack.set_dry_timer(restored, TIME_TO_DRY - 150)
	rack.current_process_id = "preservation-probe"
	rack.dry_process("preservation-probe")
	sleep(4)
	var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/product
	for (var/obj/item/weapon/reagent_containers/food/snacks/octopus/dried/candidate in rack.storage.contents)
		product = candidate
	food_check(product, "production drying creates actual dried output")
	food_check(!(restored in rack.storage.contents), "production drying retires original input")
	food_check(product.reagents.get_reagent_amount("nutriment") <= nutrition_before && product.reagents.get_reagent_amount("protein") <= protein_before, "drying does not replenish consumed nutrition")
	food_check(product.decaytimer >= 1200, "drying does not erase accumulated age")
	text2file("PASS: partial food drying, before_save cleanup and native restoration", "food_result.txt")
	del(world)