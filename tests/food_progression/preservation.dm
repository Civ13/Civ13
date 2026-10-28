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
/proc/check_salted_meat(obj/structure/dehydrator/rack, mob/living/human/user)
	var/turf/T = get_turf(rack)
	var/obj/item/weapon/reagent_containers/food/condiment/saltshaker/shaker = new(T)
	shaker.reagents.remove_reagent("sodiumchloride", 19)
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/input = new(T)
	input.decaytimer = 1200
	input.reagents.remove_reagent("protein", 1)
	shaker.afterattack(input, user, TRUE)
	food_check(input.salted_meat && input.decay == 18000 && input.decaytimer == 2400, "salting consumes salt and preserves relative age")
	food_check(shaker.reagents.get_reagent_amount("sodiumchloride") == 0, "last unit of salt consumed")
	shaker.afterattack(input, user, TRUE)
	food_check(input.decay == 18000 && input.decaytimer == 2400, "repeat salting cannot renew food")
	var/savefile/F = new("salted-meat.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/input_ref = map_storage.BuildVarDirectory(F, input, 1)
	var/shaker_ref = map_storage.BuildVarDirectory(F, shaker, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/restored = map_storage.Load_Entry(F, input_ref, starting_loc = T)
	var/obj/item/weapon/reagent_containers/food/condiment/saltshaker/restored_shaker = map_storage.Load_Entry(F, shaker_ref, starting_loc = T)
	food_check(restored.salted_meat && restored.decay == 18000 && restored.decaytimer == 2400, "save restores salt and accumulated age")
	food_check(restored.reagents.get_reagent_amount("protein") == 0 && restored_shaker.reagents.get_reagent_amount("sodiumchloride") == 0, "save preserves depleted food and salt")
	qdel(input)
	food_check(rack.hang_on(restored), "rack accepts salted cutlet")
	rack.set_dry_timer(restored, TIME_TO_DRY - 150)
	rack.current_process_id = "salted-meat"
	rack.dry_process("salted-meat")
	sleep(4)
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/product
	for (var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/candidate in rack.storage.contents)
		product = candidate
	food_check(product && product.salted_meat, "drying retains paid salt state")
	var/offset = findtext(product.name, "DECAY_") + 6
	var/limit = text2num(copytext(product.name, offset, offset + 8))
	food_check(limit == 600000 && abs(product.decaytimer / limit - 2400 / 18000) < 0.0001, "salted dried meat lasts four times longer and retains age")
	rack.before_save()
	var/savefile/dried_save = new("salted-dried-meat.sav")
	dried_save["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/dried_ref = map_storage.BuildVarDirectory(dried_save, product, 1)
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/restored_dried = map_storage.Load_Entry(dried_save, dried_ref, starting_loc = T)
	food_check(restored_dried.salted_meat && restored_dried.decay == 600000 && abs(restored_dried.decaytimer - 80000) < 0.01, "dried save retains salt, lifetime and age")
	food_check(restored_dried.nutriments_value() == 0, "dried save does not restore depleted nutrition")
	qdel(restored_dried)
	qdel(product)
	var/obj/item/weapon/reagent_containers/food/snacks/rawcutlet/spoiled = new(T)
	spoiled.rotten = TRUE
	var/obj/item/weapon/reagent_containers/food/condiment/saltshaker/full_shaker = new(T)
	full_shaker.afterattack(spoiled, user, TRUE)
	food_check(!spoiled.salted_meat && full_shaker.reagents.get_reagent_amount("sodiumchloride") == 20, "spoiled meat cannot be revived or consume salt")
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/direct = new(T)
	direct.decaytimer = 30000
	full_shaker.afterattack(direct, user, TRUE)
	food_check(direct.salted_meat && direct.decay == 600000 && direct.decaytimer == 120000 && full_shaker.reagents.get_reagent_amount("sodiumchloride") == 19, "direct dried salting costs one unit and retains age")
	full_shaker.afterattack(direct, user, TRUE)
	food_check(direct.decay == 600000 && direct.decaytimer == 120000 && full_shaker.reagents.get_reagent_amount("sodiumchloride") == 19, "repeat with available salt neither consumes nor renews")
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/empty_attempt = new(T)
	restored_shaker.afterattack(empty_attempt, user, TRUE)
	food_check(!empty_attempt.salted_meat && empty_attempt.decay == 150000, "depleted shaker cannot preserve")
	qdel(direct)
	qdel(empty_attempt)
	qdel(spoiled)
	qdel(full_shaker)
	qdel(shaker)
	qdel(restored_shaker)
/proc/check_drying_route(obj/structure/dehydrator/rack, input_type, remaining_fraction)
	var/turf/T = get_turf(rack)
	var/obj/item/weapon/reagent_containers/food/snacks/input = new input_type(T)
	var/obj/item/weapon/reagent_containers/food/snacks/default_output = new input.dried_type(T)
	var/default_nutrition = default_output.nutriments_value()
	var/default_decay = default_output.decay
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
	// The rack suspends decay by setting decay to zero and encoding its limit in the name.
	var/decay_offset = findtext(product.name, "DECAY_") + 6
	var/encoded_decay = text2num(copytext(product.name, decay_offset, decay_offset + 8))
	food_check(encoded_decay == default_decay && default_decay > 0, "recipe retains dried lifetime while on rack")
	food_check(abs(product.decaytimer / default_decay - 1200 / original_decay) < 0.0001, "drying does not erase accumulated age")
	world.log << "ROUTE [input_type] remaining=[remaining_fraction] paid=[paid_nutrition] output=[output_nutrition] age_fraction=[product.decaytimer / default_decay]"
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
	var/mob/living/human/food_fixture/user = new(T)
	check_salted_meat(rack, user)
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
