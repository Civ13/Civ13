// Recipe equivalence only: never change wool's item type, material or stacktype.
// Raw wool, cotton, rags, leather and relabelled material stacks are not cloth.
/proc/is_cloth_sheet(obj/item/I)
	if (!istype(I, /obj/item/stack/material) || QDELETED(I)) return FALSE
	var/obj/item/stack/material/S = I
	var/material/M = S.get_material()
	return M && ((istype(S, /obj/item/stack/material/cloth) && M.type == /material/cloth) || (istype(S, /obj/item/stack/material/woolcloth) && M.type == /material/woolcloth))

/proc/stack_matches_recipe_material(obj/item/stack/S, required_type)
	if (required_type == /obj/item/stack/material/cloth) return is_cloth_sheet(S)
	return istype(S, required_type)

// Retained payment for textile recipes and paintings' extra cloth. This datum
// lives only on the crafting call's stack, never on a saved item or project.
/datum/cloth_recipe_payment
	should_save = FALSE
	var/mob/living/human/actor
	var/obj/item/stack/stock
	var/atom/stock_loc
	var/turf/site
	var/datum/save_epoch
	var/datum/stack_recipe/recipe
	var/primary_cloth
	var/primary_cost
	var/secondary_type = /obj/item/stack/material/cloth
	var/secondary_cost
	var/list/secondary = list()

/datum/cloth_recipe_payment/New(obj/item/stack/S, mob/living/human/H, datum/stack_recipe/R, quantity, extra_cloth = 0)
	..()
	actor = H
	stock = S
	stock_loc = S.loc
	site = get_turf(H)
	save_epoch = persistence_admission_identity
	recipe = R
	primary_cloth = is_cloth_sheet(S)
	primary_cost = quantity * R.req_amount
	secondary_cost = quantity * extra_cloth
	if (!istype(H) || quantity <= 0 || quantity != round(quantity))
		primary_cost = 0
		return
	select_secondary(/obj/item/stack/material/cloth, secondary_cost)

/datum/cloth_recipe_payment/proc/select_secondary(required_type, required_amount)
	secondary_type = required_type
	secondary_cost = required_amount
	secondary = list()
	var/left = secondary_cost
	// Explicit hands only; mixed finished cloth is allowed for cloth shares.
	// Retain exact objects and shares, never search again after waits.
	for (var/obj/item/stack/C in list(actor.l_hand, actor.r_hand))
		if (C == stock || !stack_matches_recipe_material(C, secondary_type) || C.loc != actor || C.amount <= 0 || left <= 0) continue
		var/take = min(left, C.amount)
		secondary[C] = take
		left -= take
	return left == 0

/datum/cloth_recipe_payment/proc/valid()
	if (QDELETED(actor) || QDELETED(stock) || actor.incapacitated() || primary_cost <= 0) return FALSE
	if (persistence_admission_changed(save_epoch)) return FALSE
	if (stock.loc != stock_loc || !stock.crafting_stack_accessible(actor) || get_turf(actor) != site || !stock.can_use(primary_cost)) return FALSE
	if (primary_cloth && !is_cloth_sheet(stock)) return FALSE
	if (recipe.one_per_turf && (locate(recipe.result_type) in site)) return FALSE
	var/node = get_recipe_node_req("[recipe.result_type]")
	if (node && !crafting_node_allowed(actor, node)) return FALSE
	var/paid = 0
	for (var/obj/item/stack/C in secondary)
		if (!stack_matches_recipe_material(C, secondary_type) || C.loc != actor || !actor.item_is_in_hands(C) || !C.can_use(secondary[C])) return FALSE
		paid += secondary[C]
	return paid == secondary_cost

/datum/cloth_recipe_payment/proc/consume_secondary()
	// Caller validates every share immediately before the primary use(). There
	// is no wait between that debit, these exact (undiscounted) debits and output.
	// use() empties the stack before inventory retirement, avoiding floor merges.
	for (var/obj/item/stack/C in secondary)
		C.use(secondary[C])
