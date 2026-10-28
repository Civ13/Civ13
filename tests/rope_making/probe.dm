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

/client/New()
	del(src)

/mob/living/human/rope_tester
	var/wait_mode = "complete"
	var/obj/item/rope_spindle/tool
	var/obj/item/stack/feed
	var/allow_recovery_pickup = FALSE

/mob/living/human/rope_tester/New()
	species = new /datum/species/human
	body_build = new /datum/body_build

/mob/living/human/rope_tester/religion_check()
	return "none"

/obj/map_metadata/rope_tester/New()
	return

/mob/living/human/rope_tester/put_in_any_hand_if_possible(obj/item/W, del_on_fail = FALSE, disable_warning = TRUE, redraw_mob = TRUE, prioritize_active_hand = FALSE)
	if (!allow_recovery_pickup || !istype(W, /obj/item/hemp_rope_bundle) || (l_hand && r_hand))
		return FALSE
	if (!W.forceMove(src) || W.loc != src)
		return FALSE
	if (!l_hand)
		l_hand = W
	else
		r_hand = W
	return TRUE

// Inventory/HUD adapter only; production admission, payment and work stay intact.
/mob/living/human/rope_tester/transfer_held_item_to(obj/item/I, atom/target)
	if (!rope_held(src, I) || I.nodrop)
		return FALSE
	if (!I.forceMove(target) || I.loc != target)
		return FALSE
	if (l_hand == I)
		l_hand = null
	if (r_hand == I)
		r_hand = null
	return TRUE

/mob/living/human/rope_tester/proc/hold(obj/item/I, left = TRUE)
	I.forceMove(src)
	if (left)
		l_hand = I
	else
		r_hand = I

/mob/living/human/rope_tester/rope_making_wait(delay, atom/target)
	if (wait_mode == "cancel")
		return FALSE
	if (wait_mode == "hold_retting")
		sleep(3)
		return FALSE
	if (wait_mode == "recover_return" || wait_mode == "recover_restart")
		var/obj/item/hemp_rope_bundle/B = target
		var/turf/water = B.loc
		rope_assert(B.recover_bundle(src) && rope_held(src, B), "in-flight bundle recovery succeeds")
		rope_assert(transfer_held_item_to(B, water), "recovered bundle returns to same water")
		if (wait_mode == "recover_restart")
			wait_mode = "hold_retting"
			spawn(0)
				B.ret(src, water)
			sleep(1)
		return TRUE
	if (wait_mode == "tool_loss")
		r_hand = null
		tool.forceMove(get_turf(src))
	if (wait_mode == "feed_loss")
		l_hand = null
		// Keep the loss probe independent of legitimate floor-stack merging.
		feed.forceMove(locate(4,4,1))
	if (wait_mode == "admission")
		// Simulate an admitted save/load which has already finished before wake.
		persistence_admission_identity = new /datum
	if (wait_mode == "remove")
		if (istype(target, /obj/structure/ropewalk))
			var/obj/structure/ropewalk/R = target
			R.release_rope_material()
		if (istype(target, /obj/structure/hemp_dressing_bench))
			var/obj/structure/hemp_dressing_bench/D = target
			D.release_rope_material()
	if (wait_mode == "move")
		forceMove(locate(8,8,1))
	if (wait_mode == "overlap")
		if (istype(target, /obj/structure/ropewalk))
			var/obj/structure/ropewalk/R = target
			rope_assert(!R.lay_rope(src), "concurrent laying refused")
		if (istype(target, /obj/structure/hemp_dressing_bench))
			var/obj/structure/hemp_dressing_bench/D = target
			rope_assert(!D.dress(src), "concurrent dressing refused")
		if (istype(target, /obj/item/hemp_rope_bundle))
			var/obj/item/hemp_rope_bundle/B = target
			rope_assert(!B.ret(src, B.loc), "concurrent retting refused")
		if (istype(target, /obj/item/stack))
			rope_assert(!tool.spin(src, feed), "concurrent spinning refused")
	return TRUE

/proc/rope_assert(condition, message)
	if (!condition)
		throw EXCEPTION(message)
	world.log << "ROPE PASS: [message]"

/proc/rope_amount(atom/site, path)
	var/total = 0
	for (var/obj/item/stack/S in site)
		if (S.type == path)
			total += S.amount
	return total

/proc/rope_recipe(list/recipes, path)
	for (var/entry in recipes)
		if (istype(entry, /datum/stack_recipe_list))
			var/datum/stack_recipe_list/group = entry
			var/datum/stack_recipe/found = rope_recipe(group.recipes, path)
			if (found)
				return found
		else if (istype(entry, /datum/stack_recipe))
			var/datum/stack_recipe/R = entry
			if (R.result_type == path)
				return R
	return null

/world/New()
	OpenPort("none")
	sleep(1)
	try
		rope_assert(port == 0 && !OpenPort(0), "closed port and refused reopen")
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		text2file(json_encode(list("byond_version" = world.byond_version, "byond_build" = world.byond_build, "dimensions" = "8x8x1", "network" = "closed", "startup" = "disabled")), "fixture.json")
		var/turf/site = locate(3,3,1)
		var/mob/living/human/rope_tester/U = new(site)
		map = new /obj/map_metadata/rope_tester
		map.ordinal_age = 0
		build_research_tree()
		craftlist_lists["global"] = list()
		for (var/line in file2list("config/crafting/material_recipes_global.txt", "\n"))
			if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
				craftlist_lists["global"] += list(splittext(replacetext(line, "RECIPE: ", ""), ","))
		var/material/wood/soft/planks = new
		var/faction = "rope_fixture"
		map.faction_baseline_era[faction] = 0
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		rope_assert(!rope_recipe(planks.recipes, /obj/structure/ropewalk) && !rope_recipe(planks.recipes, /obj/structure/hemp_dressing_bench), "unresearched processing equipment hidden")
		rope_assert(rope_recipe(planks.recipes, /obj/item/rope_spindle), "founding Basic Tools baseline admits spindle")
		for (var/node in list("basic_tools", "resource_processing"))
			var/list/research_entry = map.ensure_node_entry(faction, node)
			research_entry[RNODE_ENTRY_STATUS] = RNODE_DONE
		planks.generate_recipes_civs(list(0,0,0), "global", faction)
		var/list/costs = list(/obj/item/rope_spindle = 1, /obj/structure/hemp_dressing_bench = 8, /obj/structure/ropewalk = 12)
		for (var/path in costs)
			var/datum/stack_recipe/R = rope_recipe(planks.recipes, path)
			rope_assert(R && R.req_amount == costs[path], "paid equipment recipe [path]")
		rope_assert(get_recipe_node_req("/obj/structure/ropewalk") == "resource_processing", "ropewalk research mapping")
		rope_assert(get_recipe_node_req("/obj/item/rope_spindle") == "basic_tools", "spindle research mapping")

		var/obj/item/stack/material/hemp/raw = new(U, 5, FALSE)
		U.hold(raw)
		rope_assert(raw.tie_rope_bundle(U) && raw.amount == 3, "bundle paid with raw hemp")
		var/obj/item/hemp_rope_bundle/B = locate() in site
		rope_assert((/obj/item/hemp_rope_bundle/verb/recover_hemp_bundle in B.verbs), "normal-player recovery verb registered")
		var/turf/floor/beach/water/W = new(locate(4,3,1))
		B.forceMove(W)
		U.wait_mode = "cancel"
		rope_assert(!B.ret(U, W) && B.stage == 0 && !B.working, "cancelled retting retains bundle")
		U.allow_recovery_pickup = TRUE
		rope_assert(B.recover_bundle(U) && rope_held(U, B) && B.stage == 0, "cancelled submerged bundle can be recovered")
		rope_assert(U.transfer_held_item_to(B, W), "cancelled bundle can be returned to water")
		W.salty = TRUE
		rope_assert(!B.ret(U, W), "salt retting refused")
		rope_assert(B.recover_bundle(U) && rope_held(U, B) && B.stage == 0, "salt water does not trap paid bundle")
		rope_assert(U.transfer_held_item_to(B, W), "salt-recovered bundle retained")
		W.salty = FALSE
		W.radiation = 1
		rope_assert(!B.ret(U, W), "irradiated water refused")
		rope_assert(B.recover_bundle(U) && rope_held(U, B) && B.stage == 0, "irradiated water does not trap paid bundle")
		rope_assert(U.transfer_held_item_to(B, W), "irradiated-water bundle retained")
		W.radiation = 0
		var/old_epoch = B.retting_epoch
		var/obj/item/hand_blocker = new(U)
		U.hold(hand_blocker, FALSE)
		rope_assert(!B.recover_bundle(U) && B.loc == W && B.retting_epoch == old_epoch, "full hands refuse recovery without state loss")
		U.r_hand = null
		qdel(hand_blocker)
		U.canmove = FALSE
		rope_assert(!B.recover_bundle(U) && B.loc == W && B.retting_epoch == old_epoch, "immobile actor cannot recover bundle")
		U.canmove = TRUE
		var/obj/item/weapon/handcuffs/cuffs = new(U)
		U.handcuffed = cuffs
		rope_assert(!B.recover_bundle(U) && B.loc == W && B.retting_epoch == old_epoch, "restrained actor cannot recover bundle")
		U.handcuffed = null
		qdel(cuffs)
		persistence_save_in_progress = TRUE
		rope_assert(!B.recover_bundle(U) && B.loc == W && B.retting_epoch == old_epoch, "save admission refuses bundle recovery")
		persistence_save_in_progress = FALSE
		U.wait_mode = "recover_return"
		rope_assert(!B.ret(U, W) && B.loc == W && B.stage == 0 && !B.working, "recovery invalidates wait after same-water return")
		U.wait_mode = "recover_restart"
		rope_assert(!B.ret(U, W) && B.stage == 0 && B.working, "retired waiter preserves replacement retting lock")
		sleep(4)
		rope_assert(!B.working && B.stage == 0, "replacement retting cancellation releases its own lock")
		U.allow_recovery_pickup = FALSE
		U.wait_mode = "overlap"
		rope_assert(B.ret(U, W) && B.stage == 1 && !B.ret(U, W), "retting advances exactly once")
		var/obj/structure/hemp_dressing_bench/D = new(site)
		U.hold(B)
		D.attackby(B, U)
		rope_assert(B.loc == D, "dressing admits held retted bundle")
		U.wait_mode = "cancel"
		rope_assert(!D.dress(U) && B.stage == 1 && !D.working, "dressing cancellation retains stage")
		U.wait_mode = "remove"
		rope_assert(!D.dress(U) && B.stage == 1 && B.loc == site, "removed dressing batch cannot finish")
		U.hold(B)
		D.attackby(B, U)
		U.wait_mode = "overlap"
		rope_assert(D.dress(U) && B.stage == 2, "drying distinct from breaking")
		rope_assert(D.dress(U) && B.stage == 3, "breaking distinct from scutching")
		rope_assert(D.dress(U) && B.stage == 4, "scutching distinct from combing")
		rope_assert(D.dress(U) && rope_amount(site, /obj/item/stack/dressed_hemp) == 2, "dressing yield from paid bundle")
		rope_assert(!D.dress(U), "empty dressing cannot replay")

		U.tool = new(site)
		U.feed = new /obj/item/stack/dressed_hemp(site, 4, FALSE)
		U.hold(U.tool, FALSE)
		U.hold(U.feed)
		U.wait_mode = "cancel"
		rope_assert(!U.tool.spin(U, U.feed) && U.feed.amount == 4 && !U.tool.spinning, "spindle cancellation retains fibres")
		U.wait_mode = "tool_loss"
		rope_assert(!U.tool.spin(U, U.feed) && U.feed.amount == 4, "lost spindle cancels")
		U.hold(U.tool, FALSE)
		U.wait_mode = "feed_loss"
		rope_assert(!U.tool.spin(U, U.feed) && U.feed.amount == 4, "lost fibre cancels")
		U.hold(U.feed)
		U.wait_mode = "admission"
		rope_assert(!U.tool.spin(U, U.feed) && U.feed.amount == 4, "completed admission cancels spindle")
		persistence_save_in_progress = TRUE
		rope_assert(!U.tool.spin(U, U.feed) && !raw.tie_rope_bundle(U), "active save refuses work")
		persistence_save_in_progress = FALSE
		U.wait_mode = "overlap"
		rope_assert(U.tool.spin(U, U.feed) && U.feed.amount == 3, "spindle payment")
		rope_assert(rope_amount(site, /obj/item/stack/rope_yarn/hemp) == 1, "hemp yarn output")
		rope_assert(!U.tool.spin(U, raw), "raw hemp cannot skip dressing")
		var/obj/item/stack/crude_twine/crude = new(site, 4, FALSE)
		rope_assert(!U.tool.spin(U, crude), "crude twine cannot become yarn")
		var/obj/item/stack/flax_tow/tow = new(site, 2, FALSE)
		U.hold(tow)
		U.feed = tow
		rope_assert(U.tool.spin(U, tow) && tow.amount == 1 && rope_amount(site, /obj/item/stack/rope_yarn/flax) == 1, "flax yarn stays distinct")

		var/obj/structure/ropewalk/R = new(site)
		U.hold(crude)
		rope_assert(!R.load_yarn(U, crude) && crude.amount == 4, "crude cordage remains separate")
		var/obj/item/stack/rope_yarn/hemp/Y = new(site, 3, FALSE)
		U.hold(Y)
		rope_assert(!R.load_yarn(U, Y) && Y.amount == 3, "insufficient yarn retained")
		Y.amount = 5
		rope_assert(R.load_yarn(U, Y) && Y.amount == 1, "four matching yarn paid")
		rope_assert(!R.load_yarn(U, Y) && Y.amount == 1, "occupied ropewalk refuses more yarn")
		var/obj/item/stack/rope_yarn/flax/other_yarn = new(site, 4, FALSE)
		U.hold(other_yarn)
		rope_assert(!R.load_yarn(U, other_yarn) && other_yarn.amount == 4, "mixed yarn cannot alter paid hemp batch")
		var/obj/item/laid_rope_work/hemp/batch = locate() in R
		rope_assert(batch && batch.stage == 0, "homogeneous paid batch stored")
		var/before = rope_amount(site, /obj/item/stack/material/rope)
		U.wait_mode = "cancel"
		rope_assert(!R.lay_rope(U) && batch.stage == 0, "cancelled twisting retains stage")
		U.wait_mode = "admission"
		rope_assert(!R.lay_rope(U) && batch.stage == 0, "completed admission cancels twisting")
		U.wait_mode = "remove"
		rope_assert(!R.lay_rope(U) && batch.loc == site && batch.stage == 0, "removed rope batch cannot finish")
		U.hold(batch)
		rope_assert(R.load_yarn(U, batch), "paid batch reloads")
		U.wait_mode = "overlap"
		rope_assert(R.lay_rope(U) && batch.stage == 1 && rope_amount(site, /obj/item/stack/material/rope) == before, "twist advances without rope")
		U.wait_mode = "cancel"
		rope_assert(!R.lay_rope(U) && batch.stage == 1, "cancelled counter-laying retains twist")
		batch.stage = 9
		rope_assert(!R.lay_rope(U), "invalid imported stage refused")
		batch.stage = 1

		// Production native nested entry serialization; no production saves touched.
		R.working = TRUE
		D.working = TRUE
		U.tool.spinning = TRUE
		rope_assert(!("working" in R.get_saved_vars()) && !("working" in D.get_saved_vars()), "station lock excluded")
		rope_assert(!("spinning" in U.tool.get_saved_vars()), "spindle lock excluded")
		var/obj/item/hemp_rope_bundle/saved_hemp = new(D)
		saved_hemp.stage = 3
		saved_hemp.working = TRUE
		saved_hemp.retting_epoch = 91
		rope_assert(!("working" in saved_hemp.get_saved_vars()) && !("retting_epoch" in saved_hemp.get_saved_vars()), "bundle lock and epoch excluded")
		map_storage.clear_bookkeeping()
		map_storage.saving_z = 1
		var/savefile/F = new("rope-state.sav")
		F["/format_version"] << 2
		var/rope_id = map_storage.BuildVarDirectory(F, R, 1)
		var/dress_id = map_storage.BuildVarDirectory(F, D, 1)
		var/tool_id = map_storage.BuildVarDirectory(F, U.tool, 1)
		F.Flush()
		F = null
		F = new("rope-state.sav")
		map_storage.clear_bookkeeping()
		var/obj/structure/ropewalk/restored = map_storage.Load_Entry(F, rope_id, starting_loc = site)
		var/obj/structure/hemp_dressing_bench/restored_dress = map_storage.Load_Entry(F, dress_id, starting_loc = site)
		var/obj/item/rope_spindle/restored_tool = map_storage.Load_Entry(F, tool_id, starting_loc = site)
		var/obj/item/laid_rope_work/hemp/restored_batch = locate() in restored
		var/obj/item/hemp_rope_bundle/restored_hemp = locate() in restored_dress
		rope_assert(restored_batch && restored_batch.stage == 1 && !restored.working, "nested twisted batch disk round trip")
		rope_assert(restored_hemp && restored_hemp.stage == 3 && !restored_hemp.working && restored_hemp.retting_epoch == 0 && !restored_dress.working, "nested dressed hemp disk round trip")
		rope_assert(restored_tool && !restored_tool.spinning, "spindle disk round trip")
		U.wait_mode = "overlap"
		rope_assert(restored.lay_rope(U) && rope_amount(site, /obj/item/stack/material/rope) == before + 4, "restored counter-laying publishes paid rope")
		rope_assert(!restored.lay_rope(U) && rope_amount(site, /obj/item/stack/material/rope) == before + 4, "finished batch cannot replay")
		R.working = FALSE
		qdel(R)
		rope_assert(batch.loc == site && batch.stage == 1, "destruction releases twisted work")
		D.working = FALSE
		qdel(D)
		rope_assert(saved_hemp.loc == site && saved_hemp.stage == 3, "destruction releases dressed work")
		map_storage.clear_bookkeeping()
		text2file("PASS: rope making and native disk round trips", "result.txt")
	catch (var/exception/E)
		world.log << "ROPE exception: [E] at [E.file]:[E.line]"
		text2file("FAIL: [E.name]", "result.txt")
	shutdown()
