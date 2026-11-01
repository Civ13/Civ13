// Actual production crafting/waits/payment with the existing inert actor adapters.
// This fixture does not establish connected-client, save or visual acceptance.
/datum/stone_mold_ci_case
	var/mob/living/human/handle_ci/joinery_ci/actor
	var/obj/item/stack/material/sandstone/stock
	var/obj/item/weapon/chisel/chisel
	var/obj/item/weapon/hammer/hammer
	var/datum/stack_recipe/recipe
	var/before_output

/datum/stone_mold_ci_case/New(title = "sandstone axehead mold", delay = 4)
	..()
	actor = new(locate(2,1,1))
	actor.civilization = "recipe_ci"
	stock = new(actor, 20, FALSE)
	actor.r_hand = stock
	chisel = new(locate(2,1,1))
	hammer = new /obj/item/weapon/hammer/tribalhammer(locate(2,1,1))
	var/list/row
	for (var/list/R in craftlist_lists["global"])
		if (R[2] == title)
			row = R
	if (!row)
		throw EXCEPTION("Missing stone mold fixture row: [title]")
	recipe = new(title, text2path(row[3]), text2num(row[4]), 1, 1, delay, text2num(row[6]), text2num(row[7]))
	before_output = joinery_ci_outputs(recipe.result_type)

/datum/stone_mold_ci_case/proc/clean()
	qdel(actor)
	qdel(chisel) // Also retire a chisel moved into another item by a control.
	for (var/obj/item/I in locate(2,1,1))
		qdel(I)

/proc/stone_mold_ci_expect(condition, label)
	if (!condition)
		recipe_ci_fail("stone molds", label)

/proc/recipe_ci_stone_molds()
	map.ordinal_age = 0
	var/datum/stone_mold_ci_case/C
	for (var/shape in list("ingot", "axehead", "sword", "knife", "spearhead", "pickaxe", "shovel", "arrowhead"))
		C = new("sandstone [shape] mold")
		C.stock.produce_recipe(C.recipe, 1, C.actor)
		stone_mold_ci_expect(C.stock.amount == 20 - C.recipe.req_amount && joinery_ci_outputs(C.recipe.result_type) == C.before_output + 1, "paid construction: [shape]")
		stone_mold_ci_expect(C.actor.joinery_xp == C.recipe.req_amount && !QDELETED(C.chisel) && !QDELETED(C.hammer), "paid XP and reused tools: [shape]")
		var/obj/item/weapon/clay/mold/M = locate(C.recipe.result_type) in locate(2,1,1)
		if (M)
			stone_mold_ci_expect(M.fired && M.stone_mold && M.capacity == 0, "usable immediately: [shape]")
			// Seed metal directly for oven/icon checks; this does not exercise pouring or casting.
			M.capacity = 1
			M.current_material = "bronze"
			M.update_icon()
			stone_mold_ci_expect(M.icon_state == "[M.base_icon]_full", "filled appearance: [shape]")
			var/obj/structure/oven/O = new(locate(2,1,1))
			M.loc = O
			O.process()
			stone_mold_ci_expect(!QDELETED(M) && M.loc == get_turf(O) && M.capacity == 1 && M.current_material == "bronze" && M.type == C.recipe.result_type, "oven preserves exact filled stone mold: [shape]")
			M.capacity = 0
			M.current_material = null
			M.update_icon()
			stone_mold_ci_expect(M.icon_state == "[M.base_icon]_empty", "empty appearance after reset: [shape]")
			M.loc = locate(2,1,1)
			qdel(O)
		C.clean()
	for (var/change in list("nested chisel", "broken hammer", "wrong material", "locked research", "research revoked", "cancelled", "tool moved", "stock moved", "stock spent", "save crossed"))
		C = new()
		var/datum/research_node/controlled_node
		var/original_tier
		if (change == "nested chisel") C.chisel.loc = C.hammer
		if (change == "broken hammer") C.hammer.health = 0
		if (change == "wrong material") C.stock.material = get_material_by_name("stone")
		if (change in list("locked research", "research revoked"))
			var/node_id = get_recipe_node_req("[C.recipe.result_type]")
			controlled_node = get_research_node(node_id)
			original_tier = joinery_ci_research_control(C.actor, node_id, change == "research revoked")
		if (change in list("research revoked", "cancelled", "tool moved", "stock moved", "stock spent", "save crossed"))
			spawn(1)
				switch (change)
					if ("cancelled") C.actor.stat = UNCONSCIOUS
					if ("tool moved")
						C.chisel.loc = C.hammer
						new /obj/item/weapon/chisel(locate(2,1,1)) // Never substitute a spare after selection.
					if ("stock moved") C.stock.loc = C.hammer
					if ("stock spent") C.stock.amount = 0
					if ("save crossed") persistence_admission_identity = new /datum
					if ("research revoked")
						var/list/entry = map.get_node_entry(C.actor.civilization, controlled_node.id)
						entry[RNODE_ENTRY_STATUS] = RNODE_AVAILABLE
		C.stock.produce_recipe(C.recipe, 1, C.actor)
		if (controlled_node)
			controlled_node.era_tier = original_tier
		stone_mold_ci_expect((change == "stock spent" || C.stock.amount == 20) && joinery_ci_outputs(C.recipe.result_type) == C.before_output, "no payment/output after rejection: [change]")
		stone_mold_ci_expect(C.actor.joinery_xp == 0, "no unpaid XP: [change]")
		C.clean()
