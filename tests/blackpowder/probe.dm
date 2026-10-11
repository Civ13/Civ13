// Production assembly, anvil options/payment, research, material catalog and persistence.
// World/actor initialization and inventory/UI effects are isolated from game startup.
/world
	hub = ""
	hub_password = ""
	maxx = 5
	maxy = 3
	maxz = 1
	turf = /turf
	area = /area

/obj/map_metadata/blackpowder_ci/New()
	return

/mob/living/human/blackpowder_ci
	var/test_incapacitated = FALSE
	var/test_full_hands = FALSE
	New()
		return
	incapacitated(incapacitation_flags = INCAPACITATION_DEFAULT)
		return test_incapacitated
	update_icons()
		return
	drop_from_inventory(obj/item/I, atom/target = null)
		if (l_hand == I) l_hand = null
		if (r_hand == I) r_hand = null
		I.loc = loc
		return TRUE
	put_in_hands(obj/item/I)
		if (test_full_hands) return FALSE
		I.loc = src
		r_hand = I
		return TRUE

var/blackpowder_checks = 0
var/blackpowder_error = FALSE
var/blackpowder_action = "complete"
var/mob/living/human/blackpowder_ci/blackpowder_second
var/obj/item/blackpowder_part/stock/blackpowder_other_stock
var/obj/item/blackpowder_part/blackpowder_other_input
var/blackpowder_concurrent_result

/world/Error(exception/E)
	blackpowder_error = TRUE
	world.log << "BLACKPOWDER RUNTIME: [E] at [E.file]:[E.line]"
	text2file("FAIL: runtime [E]", "blackpowder-result.txt")

/proc/blackpowder_gone(atom/movable/A)
	return !A || !A.loc

/proc/blackpowder_check(condition, label)
	if (!condition) throw EXCEPTION(label)
	blackpowder_checks++
	world.log << "BLACKPOWDER PASS: [label]"

/proc/blackpowder_hold(mob/living/human/blackpowder_ci/H, obj/item/I)
	H.hand = FALSE
	H.r_hand = I
	I.loc = H

/proc/blackpowder_wait_action(obj/item/blackpowder_part/target, mob/living/human/blackpowder_ci/H)
	sleep(1)
	switch(blackpowder_action)
		if ("cancel") return FALSE
		if ("drop") H.r_hand.loc = H.loc
		if ("delete input") qdel(H.r_hand)
		if ("delete target") qdel(target)
		if ("move") H.loc = locate(5,3,1)
		if ("incapacitated") H.test_incapacitated = TRUE
		if ("era") map.ordinal_age = 2
		if ("research") map.get_node_entry(H.civilization, "gunsmithing")[RNODE_ENTRY_STATUS] = RNODE_LOCKED
		if ("flint lost")
			var/obj/item/blackpowder_part/mechanism/M = H.r_hand
			M.has_flint = FALSE
		if ("concurrent target") blackpowder_concurrent_result = target.assemble(blackpowder_other_input, blackpowder_second)
		if ("concurrent input") blackpowder_concurrent_result = blackpowder_other_stock.assemble(H.r_hand, H)
	return TRUE

/obj/item/blackpowder_part/stock/pistol/blackpowder_ci/wait_for_assembly(mob/living/human/H, delay)
	return blackpowder_wait_action(src, H)
/obj/item/blackpowder_part/stock/musket/blackpowder_ci/wait_for_assembly(mob/living/human/H, delay)
	return blackpowder_wait_action(src, H)
/obj/item/blackpowder_part/mechanism/blackpowder_ci/wait_for_assembly(mob/living/human/H, delay)
	return blackpowder_wait_action(src, H)

/obj/structure/anvil/steel/blackpowder_ci/wait_for_blackpowder_forging(mob/living/human/H, delay)
	sleep(1)
	switch(blackpowder_action)
		if ("cancel") return FALSE
		if ("drop") H.r_hand.loc = H.loc
		if ("insufficient") H.r_hand.amount = 1
		if ("era") map.ordinal_age = 5
		if ("concurrent forge")
			blackpowder_concurrent_result = produce_blackpowder_part("Flintlock Mechanism", H.r_hand, H)
	return TRUE

/proc/blackpowder_restore(mob/living/human/blackpowder_ci/H)
	H.loc = locate(1,1,1)
	H.test_incapacitated = FALSE
	H.civilization = "blackpowder_ci"
	H.may_do_after = TRUE
	H.test_full_hands = FALSE
	map.ordinal_age = 3
	map.faction_baseline_era[H.civilization] = 0
	map.ensure_node_entry(H.civilization, "gunsmithing")[RNODE_ENTRY_STATUS] = RNODE_DONE
	blackpowder_action = "complete"

/proc/blackpowder_stock_recipe(material_type, output_type, mob/living/human/H)
	var/material/M = new material_type
	M.generate_recipes_civs(list(200,200,200), "global", H.civilization)
	for (var/datum/stack_recipe_list/L in M.recipes)
		for (var/datum/stack_recipe/R in L.recipes)
			if (R.result_type == output_type) return R
	return null

/proc/blackpowder_roundtrip(obj/item/I)
	var/savefile/S = new("blackpowder-roundtrip-[blackpowder_checks].sav")
	S["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(S, I, 1)
	blackpowder_check(ref > 0, "serializer accepts [I.type]")
	map_storage.clear_bookkeeping()
	var/obj/item/loaded = map_storage.Load_Entry(S, ref, starting_loc = locate(2,1,1))
	blackpowder_check(loaded && loaded.type == I.type, "load preserves [I.type]")
	return loaded

/world/New()
	world.log << "BLACKPOWDER START"
	run_blackpowder_checks()

/proc/run_blackpowder_checks()
	try
		populate_material_list()
		build_research_tree()
		map = new /obj/map_metadata/blackpowder_ci
		craftlist_lists["global"] = list()
		for (var/line in splittext(file2text("config/crafting/material_recipes_global.txt"), "\n"))
			if (findtext(line, "RECIPE: ") && !findtext(line, "//"))
				var/list/R = splittext(replacetext(line, "RECIPE: ", ""), ",")
				R[R.len] = replacetext(R[R.len], ascii2text(13), "")
				craftlist_lists["global"] += list(R)
		var/turf/T = locate(1,1,1)
		var/mob/living/human/blackpowder_ci/H = new(T)
		blackpowder_second = new(T)
		blackpowder_restore(H)
		blackpowder_restore(blackpowder_second)
		var/obj/structure/anvil/steel/blackpowder_ci/A = new(locate(2,1,1))
		var/obj/structure/anvil/iron_anvil = new(locate(2,1,1))
		var/obj/item/stack/material/iron/I = new(H)
		I.amount = 31
		blackpowder_hold(H, I)
		var/obj/item/stack/material/steel/Steel = new(T)
		Steel.amount = 3
		var/obj/item/stack/material/bronze/Bronze = new(T)
		for (var/age in list(2,3,4,5))
			map.ordinal_age = age
			blackpowder_check((A.blackpowder_part_options(I,H).len == 3) == (age == 3 || age == 4), "iron menu age [age]")
			blackpowder_check((A.blackpowder_part_options(Steel,H).len == 2) == (age == 3 || age == 4), "steel menu age [age]")
			blackpowder_check(!!blackpowder_stock_recipe(/material/wood/soft, /obj/item/blackpowder_part/stock/pistol,H) == (age == 3 || age == 4), "wood menu age [age]")
		map.ordinal_age = 3
		blackpowder_check(iron_anvil.blackpowder_part_options(Steel,H).len == 1 && A.blackpowder_part_options(Bronze,H).len == 1, "material and anvil restrictions")
		map.get_node_entry(H.civilization,"gunsmithing")[RNODE_ENTRY_STATUS] = RNODE_LOCKED
		blackpowder_check(A.blackpowder_part_options(I,H).len == 1 && !blackpowder_stock_recipe(/material/wood/soft,/obj/item/blackpowder_part/stock/pistol,H), "research cannot be bypassed with legacy thresholds")
		blackpowder_restore(H)
		blackpowder_check(!blackpowder_stock_recipe(/material/wood,/obj/item/blackpowder_part/stock/pistol,H), "raw logs cannot substitute for planks")
		var/datum/stack_recipe/PR = blackpowder_stock_recipe(/material/wood/soft,/obj/item/blackpowder_part/stock/pistol,H)
		var/datum/stack_recipe/MR = blackpowder_stock_recipe(/material/wood/soft,/obj/item/blackpowder_part/stock/musket,H)
		blackpowder_check(PR.req_amount == 1 && MR.req_amount == 3, "stock costs")
		var/obj/item/blackpowder_part/barrel/musket/MB = A.produce_blackpowder_part("Musket Barrel", I,H)
		blackpowder_check(MB && I.amount == 1 && !A.in_use, "production musket forging pays 30 iron once")
		blackpowder_hold(H,Steel)
		var/obj/item/blackpowder_part/mechanism/FM = A.produce_blackpowder_part("Flintlock Mechanism",Steel,H)
		blackpowder_check(FM && Steel.amount == 1, "production mechanism forging pays 2 steel")
		blackpowder_check(!A.produce_blackpowder_part("Flintlock Mechanism",Steel,H) && Steel.amount == 1, "insufficient forging consumes nothing")
		for (var/action in list("cancel","drop","insufficient","era","concurrent forge"))
			blackpowder_restore(H)
			Steel = new(H)
			Steel.amount = 3
			blackpowder_hold(H,Steel)
			blackpowder_action = action
			var/obj/item/O = A.produce_blackpowder_part("Flintlock Mechanism",Steel,H)
			if (action == "concurrent forge")
				blackpowder_check(O && !blackpowder_concurrent_result && Steel.amount == 1, "shared anvil cannot forge twice")
			else
				blackpowder_check(!O && !A.in_use && Steel.amount == (action == "insufficient" ? 1 : 3), "forge interruption [action]")
			qdel(O)
			qdel(Steel)
		blackpowder_restore(H)
		for (var/gun in list("pistol","musket"))
			var/stock_type = gun == "pistol" ? /obj/item/blackpowder_part/stock/pistol/blackpowder_ci : /obj/item/blackpowder_part/stock/musket/blackpowder_ci
			var/barrel_path = gun == "pistol" ? /obj/item/blackpowder_part/barrel/pistol : /obj/item/blackpowder_part/barrel/musket
			var/obj/item/blackpowder_part/stock/S = new stock_type(T)
			var/obj/item/blackpowder_part/P = new barrel_path(H)
			blackpowder_hold(H,P)
			S.attackby(P,H)
			blackpowder_check(S.barrel_attached && blackpowder_gone(P), "attackby consumes matching [gun] barrel")
			var/obj/item/blackpowder_part/mechanism/blackpowder_ci/M = new(T)
			var/obj/item/weapon/flint/F = new(H)
			blackpowder_hold(H,F)
			blackpowder_check(!M.assemble(F,H), "raw flint rejected [gun]")
			F.sharpen()
			blackpowder_check(F.type == /obj/item/weapon/flint && F.sharpened && M.assemble(F,H) && M.has_flint && blackpowder_gone(F), "normal sharpening accepted [gun]")
			blackpowder_hold(H,M)
			H.test_full_hands = TRUE
			var/obj/item/weapon/gun/projectile/flintlock/G = S.assemble(M,H)
			blackpowder_check(G && G.type == initial(S.gun_type) && G.loc == T && blackpowder_gone(M) && blackpowder_gone(S), "[gun] correct output and floor fallback")
			blackpowder_check(!S.assemble(M,H), "no second [gun] output")
			var/obj/item/weapon/gun/projectile/flintlock/loaded_gun = blackpowder_roundtrip(G)
			blackpowder_check(loaded_gun.force == G.force && loaded_gun.accuracy == G.accuracy && loaded_gun.caliber == G.caliber, "[gun] stats survive persistence")
			qdel(G)
			qdel(loaded_gun)
			blackpowder_restore(H)
		// Exhaustive incompatible pairs: barrels and locks never act as stocks.
		var/list/part_types = list(/obj/item/blackpowder_part/stock/pistol, /obj/item/blackpowder_part/stock/musket, /obj/item/blackpowder_part/barrel/pistol, /obj/item/blackpowder_part/barrel/musket, /obj/item/blackpowder_part/mechanism)
		for (var/target_type in part_types)
			for (var/input_type in part_types)
				if ((target_type == /obj/item/blackpowder_part/stock/pistol && input_type == /obj/item/blackpowder_part/barrel/pistol) || (target_type == /obj/item/blackpowder_part/stock/musket && input_type == /obj/item/blackpowder_part/barrel/musket)) continue
				var/obj/item/blackpowder_part/target = new target_type(T)
				var/obj/item/blackpowder_part/input_part = new input_type(H)
				blackpowder_hold(H,input_part)
				blackpowder_check(!target.assemble(input_part,H) && !blackpowder_gone(input_part), "reject pair [target_type] + [input_type]")
				qdel(target)
				qdel(input_part)
		for (var/action in list("cancel","drop","delete input","delete target","move","incapacitated","era","research","concurrent target","concurrent input"))
			blackpowder_restore(H)
			var/obj/item/blackpowder_part/stock/pistol/blackpowder_ci/S = new(T)
			var/obj/item/blackpowder_part/barrel/pistol/P = new(H)
			blackpowder_hold(H,P)
			blackpowder_other_stock = new /obj/item/blackpowder_part/stock/pistol(T)
			blackpowder_other_input = new /obj/item/blackpowder_part/barrel/pistol(blackpowder_second)
			blackpowder_hold(blackpowder_second,blackpowder_other_input)
			blackpowder_action = action
			var/result = S.assemble(P,H)
			if (findtext(action,"concurrent"))
				blackpowder_check(result && !blackpowder_concurrent_result && S.barrel_attached, "shared reservation [action]")
			else
				blackpowder_check(!result && !S.assembly_busy && (blackpowder_gone(S) || !S.barrel_attached) && (action == "delete input" || !blackpowder_gone(P)), "assembly interruption [action]")
			qdel(S)
			qdel(P)
			qdel(blackpowder_other_stock)
			qdel(blackpowder_other_input)
		blackpowder_restore(H)
		// Real do_after, without a wait adapter: actor movement during the wait cancels.
		var/obj/item/blackpowder_part/stock/pistol/blackpowder_ci/final_stock = new(T)
		final_stock.barrel_attached = TRUE
		var/obj/item/blackpowder_part/mechanism/final_lock = new(H)
		final_lock.has_flint = TRUE
		blackpowder_hold(H,final_lock)
		blackpowder_action = "flint lost"
		blackpowder_check(!final_stock.assemble(final_lock,H) && !blackpowder_gone(final_stock) && !blackpowder_gone(final_lock), "post-wait missing flint rejects final assembly")
		qdel(final_stock)
		qdel(final_lock)
		blackpowder_restore(H)
		var/obj/item/blackpowder_part/stock/pistol/S = new(T)
		var/obj/item/blackpowder_part/barrel/pistol/P = new(H)
		blackpowder_hold(H,P)
		spawn(1) H.loc = locate(5,3,1)
		blackpowder_check(!S.assemble(P,H) && !S.barrel_attached && !blackpowder_gone(P) && !S.assembly_busy && H.may_do_after, "production do_after movement cancellation")
		blackpowder_restore(H)
		blackpowder_check(S.assemble(P,H) && S.barrel_attached, "production do_after success after cancellation")
		var/obj/item/blackpowder_part/stock/loaded_stock = blackpowder_roundtrip(S)
		blackpowder_check(loaded_stock.barrel_attached && loaded_stock.icon_state == S.icon_state && loaded_stock.name == S.name, "partial stock survives persistence")
		var/obj/item/blackpowder_part/mechanism/M = new(T)
		M.has_flint = TRUE
		M.assembly_busy = TRUE
		M.assembly_consumed = TRUE
		blackpowder_check(!("assembly_busy" in M.get_saved_vars()) && !("assembly_consumed" in M.get_saved_vars()), "runtime reservations excluded from serializer")
		var/obj/item/blackpowder_part/mechanism/loaded_lock = blackpowder_roundtrip(M)
		blackpowder_check(loaded_lock.has_flint && !loaded_lock.assembly_busy && !loaded_lock.assembly_consumed, "loaded flint persists and runtime reservations reset")
		M = new(T)
		loaded_lock = blackpowder_roundtrip(M)
		blackpowder_check(!loaded_lock.has_flint, "empty mechanism survives persistence")
		var/obj/item/container = new(T)
		new /obj/item/blackpowder_part/stock/musket(container)
		var/obj/item/loaded_container = blackpowder_roundtrip(container)
		blackpowder_check(locate(/obj/item/blackpowder_part/stock/musket) in loaded_container, "nested inventory stock survives persistence")
		blackpowder_check(anvil_recipes["Crude Musket"] && anvil_recipes["Flintlock Musket"] && anvil_recipes["Flintlock Musketoon"] && anvil_recipes["Flintlock Blunderbuss"] && anvil_recipes["Flintlock Pistol"], "all legacy weapon routes retained")
		blackpowder_check(!blackpowder_error, "no runtime errors")
		text2file("PASS: [blackpowder_checks] assembly, cancellation, concurrency, material/research/era catalog and production persistence assertions", "blackpowder-result.txt")
	catch(var/exception/E)
		text2file("FAIL: [E] at [E.file]:[E.line]", "blackpowder-result.txt")
	del(world)

