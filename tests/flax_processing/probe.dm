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

// Constructor, inventory UI and action duration adapters only. Production
// payment, transformation, validation, stage and serializer bodies are retained.
/mob/living/human/flax_tester
	var/wait_mode = "complete"
	var/waits = 0

/mob/living/human/flax_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build

/mob/living/human/flax_tester/religion_check()
	return "none"

/obj/map_metadata/flax_tester/New()
	return

// No forensic UI state is needed for a paid construction regression.
/obj/structure/flax_comb/add_fingerprint(mob/living/M, ignoregloves = FALSE)
	return

/mob/living/human/flax_tester/put_in_any_hand_if_possible(obj/item/W, prioritize_active_hand = FALSE)
	return FALSE

/mob/living/human/flax_tester/drop_from_inventory(obj/item/W, atom/Target = null, ignore_nodrop = FALSE)
	W.forceMove(Target ? Target : loc)
	return TRUE

/mob/living/human/flax_tester/flax_processing_wait(delay, atom/target)
	waits++
	if (wait_mode == "cancel" || (wait_mode == "partial" && waits > 1))
		return FALSE
	if (wait_mode == "replace_water")
		new /turf/floor/plating(get_turf(target))
	if (wait_mode == "salt")
		var/turf/floor/beach/water/W = get_turf(target)
		W.salty = TRUE
	if (wait_mode == "move")
		loc = locate(8,8,1)
	if (wait_mode == "overlap")
		if (istype(target, /obj/item/flax_bundle))
			var/obj/item/flax_bundle/B = target
			flax_assert(!B.soak(src, B.loc), "concurrent soaking rejected")
		if (istype(target, /obj/structure/flax_comb))
			var/obj/structure/flax_comb/C = target
			flax_assert(!C.comb(src), "concurrent combing rejected")
		if (istype(target, /obj/item/stack/flax_tow))
			var/obj/item/stack/flax_tow/T = target
			T.attack_self(src)
	if (wait_mode == "real_complete")
		return do_after(src, 2, target, progress = FALSE)
	if (wait_mode == "real_move")
		spawn(1)
			loc = locate(8,8,1)
		return do_after(src, 4, target, progress = FALSE)
	return TRUE

/proc/flax_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "FLAX PASS: [message]"

/proc/flax_amount(atom/site, path)
	var/total = 0
	for (var/obj/item/stack/S in site)
		if (istype(S, path))
			total += S.amount
	return total

/proc/flax_comb_recipe(list/recipes)
	for (var/entry in recipes)
		if (istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			var/datum/stack_recipe/found = flax_comb_recipe(group.recipes)
			if (found)
				return found
		else if (istype(entry, /datum/stack_recipe))
			var/datum/stack_recipe/R = entry
			if (R.result_type == /obj/structure/flax_comb)
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
		var/mob/living/human/flax_tester/U = new(site)
		map = new /obj/map_metadata/flax_tester
		map.ordinal_age = 0
		build_research_tree()
		craftlist_lists["global"] = list()
		for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
			if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
				craftlist_lists["global"] += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
		var/material/wood/soft/planks = new
		var/faction = "flax_fixture"
		map.faction_baseline_era[faction] = 0
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		flax_assert(!flax_comb_recipe(planks.recipes), "unresearched comb hidden")
		flax_assert(get_recipe_node_req("/obj/structure/flax_comb") == "resource_processing", "comb research mapping")
		var/list/research_entry = map.ensure_node_entry(faction, "resource_processing")
		research_entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		var/datum/stack_recipe/recipe = flax_comb_recipe(planks.recipes)
		flax_assert(recipe && recipe.req_amount == 8 && recipe.time == 150 && recipe.one_per_turf && recipe.on_floor, "paid registered comb recipe")
		// Skip only the generic crafting wait; retain production payment/build.
		recipe.time = 0
		var/obj/item/stack/material/woodplank/wood = new(site, 7, FALSE)
		wood.produce_recipe(recipe, 1, U)
		flax_assert(!(locate(/obj/structure/flax_comb) in site), "insufficient construction input rejected")
		wood.amount = 9
		wood.produce_recipe(recipe, 1, U)
		var/obj/structure/flax_comb/constructed = locate() in site
		flax_assert(constructed && wood.amount == 1, "construction consumes eight planks")
		wood.amount = 9
		wood.produce_recipe(recipe, 1, U)
		flax_assert(wood.amount == 9, "occupied construction turf rejected")
		qdel(constructed)
		qdel(wood)
		var/obj/item/stack/material/flax/raw = new(U, 3, FALSE)
		flax_assert(raw.tie_bundle(U), "bundle available without twine")
		flax_assert(raw.amount == 1, "bundle payment")
		flax_assert(!raw.tie_bundle(U), "insufficient flax rejected")
		var/obj/item/flax_bundle/B = locate() in site
		flax_assert(B && B.soak_stage == 0, "paid bundle created")
		var/turf/floor/beach/water/W = new(locate(4,3,1))
		B.loc = W
		U.wait_mode = "partial"
		flax_assert(!B.soak(U, W) && B.soak_stage == 1 && !B.soaking, "soaking interruption retains completed stage")
		flax_assert(!flax_amount(W, /obj/item/stack/rotten_flax), "partial soaking emits nothing")
		U.wait_mode = "overlap"
		flax_assert(B.soak(U, W), "soaking resumes")
		flax_assert(flax_amount(W, /obj/item/stack/rotten_flax) == 2, "soaking conservation")
		flax_assert(!B.soak(U, W) && flax_amount(W, /obj/item/stack/rotten_flax) == 2, "consumed bundle cannot replay")
		for (var/mode in list("cancel", "replace_water", "salt", "move", "real_move"))
			W = new /turf/floor/beach/water(locate(4,3,1))
			B = new(W)
			U.loc = site
			U.wait_mode = mode
			flax_assert(!B.soak(U, W) && B.soak_stage == 0 && !B.soaking, "invalid soaking rejected: [mode]")
			qdel(B)
		U.loc = site
		U.wait_mode = "real_complete"
		W = new /turf/floor/beach/water(locate(4,3,1))
		B = new(W)
		flax_assert(B.soak(U, W), "real delayed soaking completes")
		B = new(W)
		W.radiation = 1
		flax_assert(!B.soak(U, W), "irradiated water rejected")
		W.radiation = 0
		W.salty = TRUE
		flax_assert(!B.soak(U, W), "salt water rejected")
		B.loc = site
		flax_assert(!B.soak(U, W), "dry bundle rejected")
		qdel(B)

		var/obj/structure/flax_comb/C = new(site)
		var/obj/item/stack/rotten_flax/R = new(U, 12, FALSE)
		C.attackby(R, U)
		var/obj/item/flax_work/batch = locate() in C
		flax_assert(batch && batch.units == 10 && R.amount == 2, "batch cap and payment")
		C.attackby(R, U)
		flax_assert(R.amount == 2 && C.contents.len == 1, "occupied comb rejects more inputs")
		U.wait_mode = "cancel"
		flax_assert(!C.comb(U) && batch.stage == 0 && !C.combing, "cancelled combing emits nothing")
		U.wait_mode = "overlap"
		flax_assert(C.comb(U) && batch.stage == 1, "comb stage advances")
		flax_assert(flax_amount(site, /obj/item/stack/material/straw) == 10, "straw conservation")
		batch.forceMove(site)
		flax_assert(!C.finish_stage(batch), "removed batch cannot advance")
		batch.loc = U
		C.attackby(batch, U)
		flax_assert(C.comb(U) && batch.stage == 2, "tow stage resumes")
		flax_assert(C.comb(U) && !batch.loc, "lint stage retires paid batch")
		flax_assert(!C.finish_stage(batch), "completed batch cannot replay")
		flax_assert(flax_amount(site, /obj/item/stack/flax_tow) == 10 && flax_amount(site, /obj/item/stack/textile_lint) == 10, "comb products conserved")
		var/obj/item/stack/flax_tow/tow = locate() in site
		tow.loc = U
		U.wait_mode = "cancel"
		tow.attack_self(U)
		flax_assert(tow.amount == 10 && !tow.spinning, "cancelled spinning conserves input")
		U.wait_mode = "overlap"
		tow.attack_self(U)
		flax_assert(tow.amount == 8 && flax_amount(site, /obj/item/stack/material/rope) == 1, "tow spins to compatible rope")
		var/obj/item/stack/textile_lint/lint = locate() in site
		lint.loc = U
		lint.attack_self(U)
		flax_assert(lint.amount == 8 && flax_amount(site, /obj/item/stack/material/rettedfabric) == 1, "lint prepares compatible loom feed")

		// Persist a partially soaked bundle and an actual nested paid comb batch.
		B = new(site)
		B.soak_stage = 2
		B.soaking = TRUE
		flax_assert(!("soaking" in B.get_saved_vars()), "soaking lock excluded")
		R.loc = U
		C.attackby(R, U)
		batch = locate() in C
		batch.stage = 1
		C.combing = TRUE
		tow.spinning = TRUE
		flax_assert(!("combing" in C.get_saved_vars()) && !("spinning" in tow.get_saved_vars()), "remaining action locks excluded")
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("flax-state.sav")
		F["/format_version"] << 2
		var/bundle_id = map_storage.BuildVarDirectory(F, B, 1)
		var/comb_id = map_storage.BuildVarDirectory(F, C, 1)
		var/tow_id = map_storage.BuildVarDirectory(F, tow, 1)
		F.Flush()
		F = null
		F = new("flax-state.sav")
		map_storage.clear_bookkeeping()
		var/obj/item/flax_bundle/restored_bundle = map_storage.Load_Entry(F, bundle_id, starting_loc = site)
		var/obj/structure/flax_comb/restored_comb = map_storage.Load_Entry(F, comb_id, starting_loc = site)
		var/obj/item/stack/flax_tow/restored_tow = map_storage.Load_Entry(F, tow_id, starting_loc = site)
		flax_assert(restored_bundle && restored_bundle.soak_stage == 2 && !restored_bundle.soaking, "bundle disk round trip")
		var/obj/item/flax_work/restored_batch = locate() in restored_comb
		flax_assert(restored_batch && restored_batch.units == 2 && restored_batch.stage == 1 && !restored_comb.combing, "nested paid comb batch disk round trip")
		flax_assert(restored_tow && restored_tow.amount == 8 && !restored_tow.spinning, "tow disk round trip")
		var/before_straw = flax_amount(site, /obj/item/stack/material/straw)
		U.wait_mode = "complete"
		flax_assert(restored_comb.comb(U) && restored_comb.comb(U), "saved comb resumes remaining stages")
		flax_assert(flax_amount(site, /obj/item/stack/material/straw) == before_straw, "saved comb does not replay straw")
		C.combing = FALSE
		qdel(C)
		flax_assert(batch.loc == site && batch.stage == 1 && batch.units == 2, "destruction releases unfinished paid batch")
		map_storage.clear_bookkeeping()
		text2file("PASS: flax processing and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "FLAX exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
