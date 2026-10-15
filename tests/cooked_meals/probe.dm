/world
	hub = ""
	hub_password = ""
	maxx = 8
	maxy = 8
	maxz = 2
	turf = /turf/floor/plating
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/mob/living/human/meal_tester
	var/wait_mode = "complete"
	var/obj/structure/oven/fire

/mob/living/human/meal_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build
	ingested = new /datum/reagents(100, src)
	reagents = new /datum/reagents(100, src)

/mob/living/human/meal_tester/religion_check()
	return "none"

/mob/living/human/meal_tester/meal_cooking_wait(obj/structure/pot/P)
	if (wait_mode == "real_complete")
		return do_after(src, 1, P, progress = FALSE)
	if (wait_mode == "real_move")
		spawn(1)
			loc = locate(8,8,1)
		return do_after(src, 2, P, progress = FALSE)
	if (wait_mode == "cancel")
		return FALSE
	if (wait_mode == "heat")
		fire.on = FALSE
	if (wait_mode == "overlap")
		meal_assert(!P.cook_meal(src), "overlapping action rejected")
	if (wait_mode == "move")
		loc = locate(8,8,1)
	if (wait_mode == "remove")
		var/obj/item/I = locate() in P
		I.loc = get_turf(P)
	return TRUE

// Inventory adapters avoid UI/organ startup, retaining held-bowl validation.
/mob/living/human/meal_tester/remove_from_mob(obj/O)
	if (l_hand == O)
		l_hand = null
	if (r_hand == O)
		r_hand = null
	O.loc = loc
	return TRUE

/mob/living/human/meal_tester/equip_to_slot(obj/item/W, slot, redraw_mob = TRUE)
	W.loc = src
	if (slot == slot_l_hand)
		l_hand = W
	else
		r_hand = W
	return TRUE

/obj/map_metadata/meal_tester/New()
	return

/proc/meal_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "MEAL PASS: [message]"

/proc/meal_ingredient(obj/structure/pot/P, path, amount = 4)
	var/obj/item/weapon/reagent_containers/food/snacks/F = new path(P)
	F.reagents.clear_reagents()
	F.reagents.add_reagent("nutriment", amount)
	return F

/proc/meal_pot(turf/site, quality = 1)
	var/obj/structure/pot/P = new(site)
	P.state = "boiling"
	P.fullness = 100
	meal_ingredient(P, /obj/item/weapon/reagent_containers/food/snacks/grown/potato)
	meal_ingredient(P, /obj/item/weapon/reagent_containers/food/snacks/grown/carrot)
	if (quality >= 2)
		meal_ingredient(P, /obj/item/weapon/reagent_containers/food/snacks/grown/beans)
	if (quality >= 3)
		meal_ingredient(P, /obj/item/weapon/reagent_containers/food/snacks/grown/tomato)
		P.reagents.add_reagent("sodiumchloride", 0.5)
	return P

/proc/meal_load(datum/D, turf/site, filename)
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new(filename)
	F["/format_version"] << 2
	var/id = map_storage.BuildVarDirectory(F,D,1)
	F.Flush()
	F = null
	F = new(filename)
	map_storage.clear_bookkeeping()
	return map_storage.Load_Entry(F,id,starting_loc = site)

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
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x2", "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		map = new /obj/map_metadata/meal_tester
		var/mob/living/human/meal_tester/U = new(site)
		var/obj/structure/oven/fireplace/fire = new(locate(4,3,1))
		U.fire = fire
		var/obj/structure/pot/P = meal_pot(site,3)
		meal_assert(!P.cook_meal(U) && P.contents.len == 4, "unlit fire cannot cook")
		fire.on = TRUE
		U.loc = locate(3,3,2)
		meal_assert(!P.cook_meal(U), "different z level rejected")
		U.loc = site
		var/obj/structure/pot/fresh = new(site)
		fresh.fullness = 100
		fresh.state = "water"
		new /obj/item/weapon/reagent_containers/food/snacks/grown/potato(fresh)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/carrot(fresh)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/beans(fresh)
		new /obj/item/weapon/reagent_containers/food/snacks/grown/tomato(fresh)
		fresh.reagents.add_reagent("sodiumchloride", 0.5)
		meal_assert(fresh.meal_recipe() == 3, "unaltered produce constructors qualify")
		U.wait_mode = "real_move"
		meal_assert(!fresh.cook_meal(U) && fresh.contents.len == 4, "real action cancels movement")
		U.loc = site
		U.wait_mode = "real_complete"
		meal_assert(fresh.cook_meal(U) && fresh.meal_portions == 3, "real action completes with paid produce")
		U.wait_mode = "complete"
		for (var/q in 1 to 3)
			var/obj/structure/pot/recipe = meal_pot(site,q)
			meal_assert(recipe.meal_recipe() == q, "realistic recipe tier [q]")
		var/obj/item/weapon/reagent_containers/food/snacks/F = locate() in P
		F.rotten = TRUE
		meal_assert(!P.meal_recipe(), "rotten ingredient rejected")
		F.rotten = FALSE
		F.reagents.clear_reagents()
		F.reagents.add_reagent("nutriment", 0.1)
		meal_assert(!P.meal_recipe(), "trace ingredient cannot qualify")
		F.reagents.add_reagent("nutriment", 3.9)
		for (var/mode in list("cancel", "heat", "move"))
			U.wait_mode = mode
			meal_assert(!P.cook_meal(U) && P.contents.len == 4 && !P.meal_cooking && !P.meal_portions, "interruption preserves ingredients: [mode]")
			U.loc = site
			fire.on = TRUE
		U.wait_mode = "overlap"
		meal_assert(P.cook_meal(U), "cooking succeeds after paid wait")
		meal_assert(P.reagents.get_reagent_amount("nutriment") == 16 && P.contents.len == 0, "paid nutrients conserved")
		meal_assert(P.meal_portions == 3 && P.meal_quality == 3 && !P.meal_has_meat, "vegetarian seasoned batch")
		P.meal_cooking = TRUE
		meal_assert(!("meal_cooking" in P.get_saved_vars()), "cooking lock excluded")
		P.meal_cooking = FALSE
		var/obj/structure/pot/loaded = meal_load(P,site,"pot.sav")
		meal_assert(loaded.meal_portions == 3 && loaded.meal_quality == 3 && !loaded.meal_cooking && loaded.reagents.get_reagent_amount("nutriment") == 16, "batch native disk round trip")
		var/total = 0
		var/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/M
		for (var/i in 1 to 3)
			var/obj/item/kitchen/wood_bowl/B = new(U)
			meal_assert(!loaded.serve_meal(B,U), "unheld bowl rejected")
			U.l_hand = B
			meal_assert(loaded.serve_meal(B,U), "held bowl served once")
			M = U.l_hand
			meal_assert(abs(M.reagents.get_reagent_amount("nutriment") - 16/3) < 0.001, "equal paid portions")
			total += M.reagents.get_reagent_amount("nutriment")
			U.l_hand = null
		meal_assert(abs(total - 16) < 0.001 && !loaded.meal_portions && loaded.reagents.total_volume < 0.001, "all portions conserve whole batch")
		meal_assert(!loaded.serve_meal(new /obj/item/kitchen/wood_bowl(U),U), "empty batch cannot replay")
		var/obj/item/weapon/reagent_containers/food/snacks/prepared_meal/restored = meal_load(M,site,"meal.sav")
		meal_assert(restored.meal_quality == 3 && !restored.non_vegetarian && abs(restored.reagents.get_reagent_amount("nutriment") - 16/3) < 0.001, "food metadata and contents native disk round trip")
		U.mood = 50
		restored.take_food_bite(U, 0.1)
		meal_assert(U.mood == 50 && U.meal_food_credit > 0 && U.meal_food_credit < 1, "tiny bite has no reward")
		restored.take_food_bite(U, 5)
		meal_assert(U.mood == 65, "substantial actual ingestion earns seasoned reward")
		U.mood = 50
		U.meal_food_credit = 0
		U.ingested.add_reagent("nutriment",100)
		restored.take_food_bite(U,1)
		meal_assert(U.mood == 50 && U.meal_food_credit == 0, "failed ingestion cannot earn credit")
		U.mood = 60
		U.credit_prepared_meal(3,4)
		meal_assert(U.mood == 65, "reward has a floor not additive stacking")
		for (var/i in 1 to 20)
			U.credit_prepared_meal(3,4)
		meal_assert(U.mood == 65, "repeated food cannot exceed tier floor")
		U.mood = 90
		U.credit_prepared_meal(1,4)
		meal_assert(U.mood == 90, "meal preserves higher mood")
		U.mood = 50
		U.meal_food_credit = 0
		U.credit_prepared_meal(3,3.9)
		U.credit_prepared_meal(1,0.1)
		meal_assert(U.mood == 50 && U.meal_food_credit < 1, "tier switching cannot upgrade old crumbs")
		meal_assert(U.meal_food_credit >= 0 && U.meal_food_credit <= 4 && ("meal_food_credit" in U.get_saved_vars()), "bounded durable meal progress")
		text2file("PASS: cooking and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "MEAL exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
