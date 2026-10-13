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
/proc/check_drying_route(obj/structure/dehydrator/rack, input_type, remaining_fraction)
	var/turf/T = get_turf(rack)
	var/obj/item/weapon/reagent_containers/food/snacks/input = new input_type(T)
	var/obj/item/weapon/reagent_containers/food/snacks/default_output = new input.dried_type(T)
	var/default_nutrition = default_output.nutriments_value()
	qdel(default_output)
	for (var/datum/reagent/nutrient in input.reagents.reagent_list.Copy())
		if (istype(nutrient, /datum/reagent/nutriment))
			input.reagents.remove_reagent(nutrient.id, nutrient.volume * (1 - remaining_fraction))
	var/paid_nutrition = input.nutriments_value()
	var/original_decay = input.decay
	input.decaytimer = 1200
	var/product_type = input.dried_type
	food_check(rack.hang_on(input), "recipe input fits production rack")
	rack.set_dry_timer(input, TIME_TO_DRY - 150)
	rack.current_process_id = "route-[input_type]-[remaining_fraction]"
	rack.dry_process(rack.current_process_id)
	sleep(4)
	var/obj/item/weapon/reagent_containers/food/snacks/product
	for (var/obj/item/weapon/reagent_containers/food/snacks/candidate in rack.storage.contents)
		if (candidate.type == product_type)
			product = candidate
	food_check(product, "recipe creates expected dried product")
	food_check(!(input in rack.storage.contents), "recipe consumes one paid input")
	var/output_nutrition = product.nutriments_value()
	food_check(output_nutrition <= paid_nutrition + 0.001, "drying does not replenish consumed nutrition")
	food_check(abs(output_nutrition - min(paid_nutrition, default_nutrition)) < 0.001, "drying retains available nutrition across reagent conversion")
	food_check(abs(product.decaytimer / product.decay - 1200 / original_decay) < 0.0001, "drying does not erase accumulated age")
	world.log << "ROUTE [input_type] remaining=[remaining_fraction] paid=[paid_nutrition] output=[output_nutrition] age_fraction=[product.decaytimer / product.decay]"
	rack.before_save()
	qdel(product)
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
	var/paid_nutrition = restored.nutriments_value()
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
	food_check(product.nutriments_value() <= paid_nutrition + 0.001, "drying does not replenish consumed nutrition")
	food_check(product.decaytimer >= 1200, "drying does not erase accumulated age")
	rack.before_save()
	qdel(product)
	for (var/input_type in list(/obj/item/weapon/reagent_containers/food/snacks/fishfillet, /obj/item/weapon/reagent_containers/food/snacks/salmonfillet, /obj/item/weapon/reagent_containers/food/snacks/pink_squid, /obj/item/weapon/reagent_containers/food/snacks/rawcutlet, /obj/item/weapon/reagent_containers/food/snacks/octopus))
		for (var/remaining_fraction in list(1, 0.5, 0))
			check_drying_route(rack, input_type, remaining_fraction)
	text2file("PASS: five drying routes, paid nutrition, relative age and native restoration", "food_result.txt")
	del(world)
