// A textile variant of the staged component bench, not a second stack-crafting API.
/obj/item/armor_component
	icon = 'icons/obj/materials.dmi'
	w_class = ITEM_SIZE_NORMAL

/obj/item/armor_component/carrier
	name = "armor carrier"
	desc = "A sewn cloth carrier with leather fastenings. Fit aramid panels at an armor assembly workbench."
	icon_state = "sheet-cloth"

/obj/item/armor_component/aramid_panels
	name = "aramid armor panels"
	desc = "Layered woven aramid panels, ready to fit to an armor carrier."
	icon_state = "sheet-kevlar"

/obj/structure/component_workbench/armor
	name = "armor assembly workbench"
	desc = "Select a recipe, insert its listed materials or components, and assemble. Retrieve returns all stored inputs or the finished item."
	selected_tool = "Armor carrier"
	assembly_time = 100

// Requirements are exact types; material names also reject relabelled stack subtypes.
/obj/structure/component_workbench/armor/proc/armor_recipes()
	return list(
		"Armor carrier" = list("node" = "weaving", "era" = 0, "result" = /obj/item/armor_component/carrier, "inputs" = list(/obj/item/stack/material/cloth = list(4, "cloth"), /obj/item/stack/material/leather = list(2, "leather"))),
		"Aramid panels" = list("node" = "modern_armor", "era" = 7, "result" = /obj/item/armor_component/aramid_panels, "inputs" = list(/obj/item/stack/material/kevlar = list(14, "kevlar"))),
		"Standard aramid vest" = list("node" = "modern_armor", "era" = 7, "result" = /obj/item/clothing/accessory/armor/nomads/kevlarblack, "inputs" = list(/obj/item/armor_component/carrier = list(1), /obj/item/armor_component/aramid_panels = list(1))))

/obj/structure/component_workbench/armor/tool_recipes()
	return armor_recipes()

/obj/structure/component_workbench/armor/after_load()
	..()
	if (!(selected_tool in armor_recipes())) selected_tool = "Armor carrier"

/obj/structure/component_workbench/armor/can_use(mob/living/human/H)
	return !QDELETED(src) && ..() && !QDELETED(H) && anchored && !persistence_save_in_progress && !persistence_active_operation && !persistence_load_recovery_required

/obj/structure/component_workbench/armor/proc/recipe_available(mob/living/human/H, choice)
	var/list/R = armor_recipes()[choice]
	return R && map && map.ordinal_age >= R["era"] && map.is_node_done(H.civilization, R["node"])

/obj/structure/component_workbench/armor/proc/input_valid(obj/item/I, input_type, list/cost)
	if (!islist(cost) || QDELETED(I) || I.type != input_type) return FALSE
	if (istype(I, /obj/item/stack/material))
		var/obj/item/stack/material/S = I
		var/material/M = S.get_material()
		return M && M.name == cost[2] && S.amount == round(S.amount) && S.amount <= S.max_amount && S.can_use(cost[1])
	return TRUE

/obj/structure/component_workbench/armor/proc/staged_inputs(choice)
	var/list/R = armor_recipes()[choice]
	if (!R) return
	var/list/requirements = R["inputs"]
	if (contents.len != requirements.len) return
	var/list/staged = list()
	for (var/input_type in requirements)
		for (var/obj/item/I in contents)
			if (I.loc == src && input_valid(I, input_type, requirements[input_type]))
				staged += I
				break
	return staged.len == requirements.len ? staged : null

/obj/structure/component_workbench/armor/insert(obj/item/I, mob/living/human/H)
	if (busy || !can_use(H) || !recipe_available(H, selected_tool) || QDELETED(I) || I.loc != H || !H.item_is_in_hands(I)) return FALSE
	var/list/R = armor_recipes()[selected_tool]
	var/list/requirements = R["inputs"]
	if (contents.len >= requirements.len || !input_valid(I, I.type, requirements[I.type])) return FALSE
	for (var/obj/item/stored in contents)
		if (stored.type == I.type) return FALSE
	// No floor staging: stack Crossed hooks could merge away a paid input.
	return H.transfer_held_item_to(I, src) && I.loc == src

/obj/structure/component_workbench/armor/attackby(obj/item/I, mob/living/human/H)
	if (insert(I, H)) to_chat(H, "You stage [I] on [src].")
	else to_chat(H, "Hold a complete listed input for an unlocked recipe. Retrieve the current items before changing recipes.")

/obj/structure/component_workbench/armor/proc/commit_armor(mob/living/human/H, choice, list/staged, list/amounts, turf/site, datum/epoch)
	if (!busy || cancelled || assembler != H || !can_use(H) || loc != site || selected_tool != choice || epoch != persistence_admission_identity || !recipe_available(H, choice)) return
	var/list/current = staged_inputs(choice)
	if (!current || current.len != staged.len) return
	for (var/obj/item/I in staged)
		if (!(I in current) || I.loc != src || (istype(I, /obj/item/stack) && I:amount != amounts[I])) return
	var/list/R = armor_recipes()[choice]
	var/list/requirements = R["inputs"]
	// Claim completion before payment/constructors. No sleeps from validation to output.
	cancelled = TRUE
	for (var/obj/item/I in staged)
		if (istype(I, /obj/item/stack))
			var/obj/item/stack/S = I
			var/list/cost = requirements[I.type]
			S.use(cost[1]) // Exact cost, no Production-religion discount.
		else
			qdel(I)
	var/result_type = R["result"]
	return new result_type(src)

/obj/structure/component_workbench/armor/assemble(mob/living/human/H)
	if (busy || !can_use(H) || !recipe_available(H, selected_tool)) return
	var/list/staged = staged_inputs(selected_tool)
	if (!staged) return
	var/choice = selected_tool
	var/turf/site = loc
	var/datum/epoch = persistence_admission_identity
	var/list/amounts = list()
	for (var/obj/item/stack/S in staged) amounts[S] = S.amount
	busy = TRUE
	cancelled = FALSE
	assembler = H
	var/obj/item/result
	if (do_after(H, assembly_time, src)) result = commit_armor(H, choice, staged, amounts, site, epoch)
	busy = FALSE
	assembler = null
	if (result) to_chat(H, "You finish [result]. Retrieve it and any unused stock from [src].")
	return result

/obj/structure/component_workbench/armor/proc/recipe_status()
	var/list/R = armor_recipes()[selected_tool]
	var/list/requirements = R["inputs"]
	var/message = "[selected_tool] requires: "
	for (var/input_type in requirements)
		var/list/cost = requirements[input_type]
		message += "[cost[1]] [initial(input_type:name)]; "
	return "[message]Research: [R["node"]], era [R["era"]]-8. [busy ? "Working" : "Idle"]. Retrieve returns stored items and cancels work."

/obj/structure/component_workbench/armor/attack_hand(mob/living/human/H)
	if (!can_use(H)) return
	var/list/options = list("Status", "Retrieve / cancel")
	if (!busy && !contents.len) options += "Select recipe"
	if (!busy && recipe_available(H, selected_tool) && staged_inputs(selected_tool)) options += "Assemble"
	var/action = input(H, recipe_status(), name) as null|anything in options
	if (!can_use(H)) return
	switch (action)
		if ("Retrieve / cancel") retrieve(H)
		if ("Status") to_chat(H, recipe_status())
		if ("Assemble") assemble(H)
		if ("Select recipe")
			var/choice = input(H, "Armor recipe", name) as null|anything in armor_recipes()
			if (can_use(H) && !busy && !contents.len && (choice in armor_recipes())) selected_tool = choice
