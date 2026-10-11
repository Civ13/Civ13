/world
	maxx = 8
	maxy = 8
	maxz = 1
	turf = /turf/floor/plating

// No human startup, network, inventory UI or skill side effects in this adapter.
/mob/living/harvest_tester/New()
	return

/obj/map_metadata/harvest_fixture/New()
	map = src

/mob/living/simple_animal/cattle/cow/harvest_tester
	var/test_action = "complete"

var/global/harvest_duplicate_result = null

/mob/living/simple_animal/cattle/cow/harvest_tester/New()
	return

/mob/living/simple_animal/cattle/cow/harvest_tester/crush()
	return

/mob/living/simple_animal/cattle/cow/harvest_tester/harvest_valid(mob/user, obj/item/tool, turf/site, require_client = TRUE)
	return ..(user, tool, site, test_action == "disconnect")

/mob/living/simple_animal/cattle/cow/harvest_tester/harvest_wait(mob/user, delay)
	if (test_action == "realwait_move")
		spawn(1)
			user.loc = locate(7,7,1)
		return do_after(user, 3, src, progress = FALSE)
	if (test_action == "realwait_complete")
		return do_after(user, 2, src, progress = FALSE)
	if (test_action == "cancel")
		return FALSE
	if (test_action == "disconnect_after")
		test_action = "disconnect"
	if (test_action == "move")
		loc = locate(7,7,1)
	if (test_action == "revive")
		stat = CONSCIOUS
	if (test_action == "drop")
		var/obj/item/tool = locate(/obj/item) in user
		tool.loc = get_turf(user)
	if (test_action == "delete")
		qdel(src)
	if (test_action == "concurrent")
		var/obj/item/tool = locate(/obj/item) in user
		harvest_duplicate_result = harvest_animal(user, tool)
	return TRUE

/proc/harvest_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/proc/harvest_count(turf/site, path)
	var/count = 0
	for (var/obj/O in site)
		if (istype(O, path) && !QDELETED(O))
			count++
	return count

/proc/harvest_clear(turf/site)
	for (var/obj/O in site)
		qdel(O)

/world/New()
	// Exercise object cleanup after the first world tick.
	sleep(1)
	try
		new /obj/map_metadata/harvest_fixture
		text2file(json_encode(list("commit" = world.params["tested_commit"], "byond_version" = world.byond_version, "byond_build" = world.byond_build, "maxx" = world.maxx, "maxy" = world.maxy)), "metadata.json")
		var/turf/site = locate(3,3,1)
		var/mob/living/harvest_tester/U = new(site)
		var/obj/item/weapon/material/kitchen/utensil/knife/K = new(U)
		for (var/action in list("cancel", "move", "revive", "drop", "delete", "disconnect", "disconnect_after", "realwait_move", "realwait_complete", "concurrent", "complete"))
			var/mob/living/simple_animal/cattle/cow/harvest_tester/C = new(site)
			C.stat = DEAD
			C.test_action = action
			K.loc = U
			var/result = C.harvest_animal(U, K, TRUE)
			if (action == "complete" || action == "concurrent" || action == "realwait_complete")
				harvest_assert(QDELETED(C), "Completed corpse not deleted")
				harvest_assert(harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/meat/offal) == 6, "Cow organs missing or duplicated")
				harvest_assert(harvest_count(site, /obj/item/stack/sinew) == 1, "Sinew stack missing or duplicated")
				harvest_assert(harvest_count(site, /obj/item/stack/material/pelt/cowpelt) == 1, "Cow hide missing")
				harvest_assert(harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/cow/stomach) == 1, "Cow processing stomach lost")
				if (action == "concurrent")
					harvest_assert(harvest_duplicate_result == FALSE, "Concurrent harvest accepted")
			else
				harvest_assert(!result && !harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks) && !harvest_count(site, /obj/item/stack), "Invalid/cancelled harvest emitted products: [action]")
				if (action != "delete")
					harvest_assert(!C.harvested && !C.harvesting, "Cancelled claim retained: [action]")
			qdel(C)
			U.loc = site
			K.loc = U
			harvest_clear(site)
			K.loc = U
		for (var/size_category in list(MOB_MINISCULE, MOB_TINY, MOB_SMALL, MOB_MEDIUM, MOB_LARGE, MOB_HUGE))
			var/mob/living/simple_animal/cattle/cow/harvest_tester/C = new(site)
			C.mob_size = size_category
			C.harvest_products(site, FALSE)
			var/yield_count = C.butcher_yield()
			var/slabs = 0
			for (var/obj/item/weapon/reagent_containers/food/snacks/meat/M in site)
				if (!istype(M, /obj/item/weapon/reagent_containers/food/snacks/meat/offal))
					slabs++
			var/obj/item/stack/material/bone/bone = locate() in site
			var/obj/item/stack/material/leather/hide = locate() in site
			var/obj/item/stack/sinew/tendons = locate() in site
			harvest_assert(slabs == yield_count && bone.amount == max(1, yield_count-2) && hide.amount == max(1, yield_count-2), "Size portions/stacks incorrect")
			harvest_assert(yield_count >= 3 ? tendons && tendons.amount == min(4, max(1, yield_count-2)) : !tendons, "Sinew quantity incorrect")
			qdel(C)
			harvest_clear(site)
		var/list/species = list(/mob/living/simple_animal/pig_gilt, /mob/living/simple_animal/chicken, /mob/living/simple_animal/crab, /mob/living/simple_animal/frog/poisonous, /mob/living/simple_animal/hostile/human/zombie, /mob/living/simple_animal/deer, /mob/living/simple_animal/hostile/wolf/white, /mob/living/simple_animal/hostile/gorilla/gigantopithecus)
		for (var/path in species)
			var/mob/living/simple_animal/A = new path(site)
			A.radiation = 8
			A.harvest_products(site, TRUE)
			harvest_assert(harvest_count(site, /obj/item) <= 24, "Unbounded output: [path]")
			if (istype(A, /mob/living/simple_animal/pig_gilt))
				harvest_assert(harvest_count(site, /obj/item/weapon/pigleg) == 1 && harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/pig/stomach) == 1, "Pig routes lost")
			if (istype(A, /mob/living/simple_animal/chicken))
				harvest_assert(harvest_count(site, /obj/item/weapon/chicken_carcass) == 1 && harvest_count(site, /obj/item/stack/sinew) == 0, "Chicken anatomy incorrect")
			if (istype(A, /mob/living/simple_animal/crab) || istype(A, /mob/living/simple_animal/frog/poisonous) || istype(A, /mob/living/simple_animal/hostile/human/zombie))
				harvest_assert(!harvest_count(site, /obj/item/stack/sinew) && !harvest_count(site, /obj/item/weapon/reagent_containers/food/snacks/meat/offal), "False mammal anatomy")
			if (istype(A, /mob/living/simple_animal/hostile/wolf/white))
				harvest_assert(harvest_count(site, /obj/item/stack/material/pelt/wolfpelt/white) == 1, "White wolf pelt unreachable")
			for (var/obj/item/weapon/reagent_containers/food/snacks/F in site)
				harvest_assert(F.reagents && F.reagents.total_volume > 0, "Empty food")
				if (istype(F, /obj/item/weapon/reagent_containers/food/snacks/meat/offal))
					harvest_assert(F.rots && F.raw && F.decay > 0 && F.radiation == 4 && F.reagents.get_reagent_amount("protein") == 2, "Offal decay/nutrition/radiation contract")
			qdel(A)
			harvest_clear(site)
		var/obj/item/stack/sinew/S = new(U, 3)
		S.attack_self(U)
		harvest_assert(S.amount == 2 && harvest_count(site, /obj/item/stack/material/rope) == 1, "Binding conversion conservation")
		var/mob/living/simple_animal/cattle/cow/harvest_tester/saved = new(site)
		saved.harvesting = TRUE
		saved.harvested = TRUE
		var/list/keys = saved.get_saved_vars()
		harvest_assert(!("harvesting" in keys) && ("harvested" in keys), "Save persisted lock or lost claim")
		saved.stat = DEAD
		saved.harvesting = FALSE
		harvest_assert(!saved.harvest_animal(U, K), "Already-claimed corpse accepted")
		saved.harvesting = TRUE
		var/savefile/F = new("harvest-state.sav")
		F["/format_version"] << 2
		map_storage.saving_z = 1
		var/saved_id = map_storage.BuildVarDirectory(F, saved)
		var/sinew_id = map_storage.BuildVarDirectory(F, S)
		harvest_assert(saved_id && sinew_id, "Saved types excluded")
		var/mob/living/simple_animal/cattle/cow/harvest_tester/restored = map_storage.Load_Entry(F, saved_id, starting_loc = site)
		var/obj/item/stack/sinew/restored_sinew = map_storage.Load_Entry(F, sinew_id, starting_loc = site)
		harvest_assert(restored.harvested && !restored.harvesting && restored_sinew.amount == 2, "Production object round trip failed")
		var/obj/item/weapon/branch/sharpened/saved_branch = new(site)
		saved_branch.assembling_axe = TRUE
		var/branch_id = map_storage.BuildVarDirectory(F, saved_branch)
		var/obj/item/weapon/branch/restored_branch = map_storage.Load_Entry(F, branch_id, starting_loc = site)
		harvest_assert(restored_branch.sharpened && !restored_branch.assembling_axe, "Assembly lock persisted")
		map_storage.clear_bookkeeping()
		qdel(S)
		harvest_clear(site)
		for (var/action in list("cancel", "drop", "empty", "disconnect", "concurrent", "complete"))
			var/obj/item/weapon/branch/sharpened/harvest_tester/B = new(U)
			var/obj/item/weapon/flint/sharpened/H = new(U)
			var/obj/item/stack/sinew/binding = new(U, 2)
			B.test_action = action
			B.assemble_flint_axe(U, H)
			if (action == "complete" || action == "concurrent")
				harvest_assert(!B.loc && !H.loc && !H.sharpened && binding.amount == 1 && harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint) == 1, "Axe assembly conservation/duplication: [action]")
				B.assemble_flint_axe(U, H)
				harvest_assert(binding.amount == 1 && harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint) == 1, "Consumed parts reused")
			else
				harvest_assert(!QDELETED(B) && !QDELETED(H) && !B.assembling_axe && !harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint), "Invalid assembly accepted: [action]")
			qdel(B)
			qdel(H)
			qdel(binding)
			harvest_clear(site)
		var/obj/structure/oven/oven = new(site)
		var/obj/item/weapon/reagent_containers/food/snacks/meat/offal/heart/heart = new(oven)
		oven.process()
		harvest_assert(heart.loc == site && heart.roasted && !heart.raw && heart.reagents.get_reagent_amount("protein") == 6 && heart.icon_state == "heart-off", "Production offal cooking failed")
		heart.rot()
		harvest_assert(heart.rotten && heart.icon_state == "heart-x" && heart.reagents.get_reagent_amount("food_poisoning") == 1, "Production offal rot failed")
		harvest_clear(site)
		text2file("PASS: bounded production products, species anatomy, cancellation and post-wait validity, concurrent/repeated claims, cord and axe conservation, decay/nutrition/radiation and production save/load", "result.txt")
	catch (var/exception/error)
		text2file("FAIL: [error]", "result.txt")
	del(world)

/world/Error(exception/E)
	text2file("[E]\n[E.file]:[E.line]\n[E.desc]", "errors.txt")
	return ..()

/obj/item/weapon/branch/sharpened/harvest_tester
	var/test_action = "complete"

/obj/item/weapon/branch/sharpened/harvest_tester/axe_actor_connected(mob/user)
	return user && test_action != "disconnected"

/obj/item/weapon/branch/sharpened/harvest_tester/axe_assembly_wait(mob/user)
	if (test_action == "cancel")
		return FALSE
	if (test_action == "drop")
		var/obj/item/weapon/flint/H = locate() in user
		H.loc = get_turf(user)
	if (test_action == "empty")
		var/obj/item/stack/sinew/S = locate() in user
		S.amount = 0
	if (test_action == "disconnect")
		test_action = "disconnected"
	if (test_action == "concurrent")
		var/obj/item/weapon/flint/H = locate() in user
		assemble_flint_axe(user, H)
	return TRUE
