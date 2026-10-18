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
		var/obj/item/stack/material/pelt/cowpelt/existing_hide = new(site, 5)
		var/mob/living/simple_animal/cattle/cow/harvest_tester/pelt_cow = new(site)
		pelt_cow.harvest_products(site, TRUE)
		harvest_assert(existing_hide.amount == 7 && harvest_count(site, /obj/item/stack/material/pelt/cowpelt) == 1, "Hide constructor merged before setting yield")
		qdel(pelt_cow)
		harvest_clear(site)
		var/obj/item/stack/material/rope/existing_rope = new(site, 10)
		var/obj/item/stack/sinew/S = new(U, 3)
		S.attack_self(U)
		harvest_assert(S.amount == 2 && existing_rope.amount == 10 && harvest_count(site, /obj/item/stack/material/rope) == 2, "Binding conversion conservation on stocked turf")
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
		for (var/path in list(/mob/living/simple_animal/hostile/sabertooth/lion, /mob/living/simple_animal/hostile/sabertooth/lion/gladiator, /mob/living/simple_animal/hostile/sabertooth))
			var/mob/living/simple_animal/A = new path(site)
			A.harvest_hide(site)
			var/obj/item/stack/material/pelt/lionpelt/pelt = locate() in site
			var/expected = path == /mob/living/simple_animal/hostile/sabertooth/lion/gladiator ? 0 : (path == /mob/living/simple_animal/hostile/sabertooth/lion ? 3 : 6)
			harvest_assert(expected ? pelt && pelt.amount == expected : !pelt, "Lion hide subtype yield: [path]")
			qdel(A)
			harvest_clear(site)
		for (var/action in list("cancel", "drop", "move_branch", "empty", "disconnect", "concurrent", "complete", "ground"))
			var/obj/item/weapon/branch/sharpened/harvest_tester/B = new(U)
			var/obj/item/weapon/flint/sharpened/H = new(U)
			var/obj/item/stack/sinew/binding = new(U, 2)
			B.test_action = action
			if (action == "ground")
				B.loc = site
			B.assemble_flint_axe(U, H)
			if (action == "complete" || action == "concurrent" || action == "ground")
				harvest_assert(!B.loc && !H.loc && !H.sharpened && binding.amount == 1 && harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint) == 1, "Axe assembly conservation/duplication: [action]")
				B.assemble_flint_axe(U, H)
				harvest_assert(binding.amount == 1 && harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint) == 1, "Consumed parts reused")
			else
				harvest_assert(!QDELETED(B) && !QDELETED(H) && !B.assembling_axe && !harvest_count(site, /obj/item/weapon/material/hatchet/tribal/flint), "Invalid assembly accepted: [action]")
			qdel(B)
			qdel(H)
			qdel(binding)
			harvest_clear(site)
		for (var/action in list("cancel", "drop", "disconnect", "concurrent", "complete"))
			var/obj/item/weapon/branch/sharpened/harvest_tester/B = new(U)
			var/obj/item/weapon/flint/sharpened/H = new(U)
			var/obj/item/stack/crude_twine/binding = new(U, 2)
			B.test_action = action
			B.assemble_flint_axe(U, H)
			var/obj/item/weapon/material/hatchet/tribal/flint/axe = locate() in site
			if (action == "complete" || action == "concurrent")
				var/obj/item/weapon/material/hatchet/tribal/flint/normal = new(site)
				harvest_assert(axe && axe.maxhealth == max(1, normal.maxhealth * 0.25) && axe.health == axe.maxhealth && binding.amount == 1, "Weak binding durability/conservation: [action]")
				qdel(normal)
			else
				harvest_assert(!axe && binding.amount == 2, "Interrupted twine consumed: [action]")
			qdel(B)
			qdel(H)
			qdel(binding)
			harvest_clear(site)
		for (var/action in list("complete", "cancel", "drop", "concurrent"))
			var/turf/floor/grass/twine_tester/G = site.ChangeTurf(/turf/floor/grass/twine_tester)
			var/obj/item/weapon/flint/sharpened/H = new(U)
			G.test_action = action
			G.gather_grass_cuttings(U, H)
			var/obj/item/stack/grass_cuttings/cuttings = locate() in site
			if (action == "complete" || action == "concurrent")
				harvest_assert(cuttings && cuttings.amount == 2 && istype(site, /turf/floor/dirt), "Grass harvest conservation: [action]")
				cuttings.loc = U
				cuttings.attack_self(U)
				var/obj/item/stack/crude_twine/cord = locate() in U
				if (!cord)
					cord = locate() in site
				harvest_assert(!cuttings.loc && cord && cord.amount == 1, "Twine conversion conservation")
				qdel(cord)
			else
				harvest_assert(!cuttings && !G.busy && istype(site, /turf/floor/grass), "Interrupted grass harvest: [action]")
			qdel(H)
			harvest_clear(site)
		// Both scenery variants enter through the actual player attackby handler.
		for (var/path in list(/obj/structure/wild/tallgrass/twine_tester, /obj/structure/wild/tallgrass2/twine_tester))
			for (var/action in list("complete", "concurrent", "cancel", "drop", "unsharpen", "move", "actor_move", "delete", "disconnect_after", "unconscious", "realwait_move", "realwait_complete"))
				var/obj/structure/wild/G = new path(site)
				var/obj/item/weapon/flint/sharpened/H = new(U)
				G.vars["test_action"] = action
				var/turf/original_floor = site
				harvest_duplicate_result = null
				var/result = G.attackby(H, U)
				var/obj/item/stack/grass_cuttings/cuttings = locate() in site
				if (action == "complete" || action == "concurrent" || action == "realwait_complete")
					harvest_assert(result && QDELETED(G) && cuttings && cuttings.amount == 2, "Tall grass yield/removal: [path] [action]")
					if (action == "concurrent")
						harvest_assert(harvest_duplicate_result == FALSE, "Competing tall grass cut accepted")
					G.gather_grass_cuttings(U, H)
					harvest_assert(cuttings.amount == 2, "Removed tall grass reused")
					cuttings.loc = U
					cuttings.attack_self(U)
					var/obj/item/stack/crude_twine/cord = locate() in U
					if (!cord)
						cord = locate() in site
					harvest_assert(!cuttings.loc && cord && cord.amount == 1, "Tall grass to existing twine conservation")
					qdel(cord)
				else
					harvest_assert(!result && !cuttings && (QDELETED(G) || !G.cutting_grass), "Interrupted tall grass cut: [path] [action]")
				harvest_assert(locate(3,3,1) == original_floor, "Tall grass cutting replaced underlying floor")
				U.loc = site
				U.stat = CONSCIOUS
				qdel(G)
				qdel(H)
				harvest_clear(site)
			var/obj/structure/wild/G = new path(site)
			var/obj/item/weapon/flint/raw = new(U)
			G.attackby(raw, U)
			harvest_assert(!QDELETED(G) && !harvest_count(site, /obj/item/stack/grass_cuttings), "Unsharpened flint harvested tall grass")
			G.cutting_grass = TRUE
			harvest_assert(G.persistence_runtime_var("cutting_grass") && !("cutting_grass" in G.get_saved_vars()), "Tall grass cutting lock exported")
			G.cutting_grass = FALSE
			K.loc = U
			harvest_assert(G.attackby(K, U) && QDELETED(G) && harvest_count(site, /obj/item/stack/grass_cuttings) == 1, "Knife did not use tall grass cutting handler")
			qdel(raw)
			harvest_clear(site)
		var/obj/structure/wild/bush/ordinary_bush = new(site)
		harvest_assert(!ordinary_bush.gather_grass_cuttings(U, K) && !harvest_count(site, /obj/item/stack/grass_cuttings), "Non-grass vegetation gained fibre yield")
		qdel(ordinary_bush)
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
	if (test_action == "move_branch")
		loc = locate(8,8,1)
	if (test_action == "empty")
		var/obj/item/stack/sinew/S = locate() in user
		S.amount = 0
	if (test_action == "disconnect")
		test_action = "disconnected"
	if (test_action == "concurrent")
		var/obj/item/weapon/flint/H = locate() in user
		assemble_flint_axe(user, H)
	return TRUE

/turf/floor/grass/twine_tester
	var/test_action = "complete"
/turf/floor/grass/twine_tester/grass_cutting_actor_connected(mob/user)
	return user != null
/turf/floor/grass/twine_tester/grass_cutting_wait(mob/user)
	var/obj/item/weapon/flint/H = locate() in user
	if (test_action == "cancel")
		return FALSE
	if (test_action == "drop")
		H.loc = get_turf(user)
	if (test_action == "concurrent")
		gather_grass_cuttings(user, H)
	return TRUE

/obj/structure/wild/tallgrass/twine_tester
	var/test_action = "complete"

/obj/structure/wild/tallgrass2/twine_tester
	var/test_action = "complete"

/obj/structure/wild/tallgrass/twine_tester/grass_cutting_actor_connected(mob/user)
	return user && test_action != "disconnect"

/obj/structure/wild/tallgrass2/twine_tester/grass_cutting_actor_connected(mob/user)
	return user && test_action != "disconnect"

/obj/structure/wild/tallgrass/twine_tester/grass_cutting_wait(mob/user)
	return tallgrass_fixture_wait(user, test_action)

/obj/structure/wild/tallgrass2/twine_tester/grass_cutting_wait(mob/user)
	return tallgrass_fixture_wait(user, test_action)

/obj/structure/wild/proc/tallgrass_fixture_wait(mob/user, action)
	var/obj/item/weapon/flint/tool = locate() in user
	if (action == "realwait_complete")
		return do_after(user, 2, src, progress = FALSE)
	if (action == "realwait_move")
		spawn(1)
			user.loc = locate(7,7,1)
		return do_after(user, 3, src, progress = FALSE)
	if (action == "cancel")
		return FALSE
	if (action == "drop")
		tool.loc = get_turf(user)
	if (action == "unsharpen")
		tool.sharp = FALSE
	if (action == "move")
		loc = locate(7,7,1)
	if (action == "actor_move")
		user.loc = locate(7,7,1)
	if (action == "delete")
		qdel(src)
	if (action == "disconnect_after")
		vars["test_action"] = "disconnect"
	if (action == "unconscious")
		user.stat = UNCONSCIOUS
	if (action == "concurrent")
		harvest_duplicate_result = attackby(tool, user)
	return TRUE
