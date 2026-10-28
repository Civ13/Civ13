// Explicit recipe namespace: missing configuration fails closed. Existing recipes
// retain their behavior. JSON is shared with the Atlas/Help projector.
var/global/list/furniture_joinery_specs

/proc/furniture_joinery_spec(datum/stack_recipe/R)
	if (!R || findtext(R.title, "joinery: ") != 1)
		return null
	if (!furniture_joinery_specs)
		furniture_joinery_specs = json_decode(file2text("config/crafting/furniture_joinery.json"))
	return furniture_joinery_specs ? furniture_joinery_specs[R.title] : null

/obj/item/stack/wooden_dowels
	name = "wooden dowel sets"
	singular_name = "wooden dowel set"
	desc = "Whittled wooden pegs for furniture joints. Each set supplies a small frame. Hold the required sets alongside logs; keep a chisel and hammer or mallet equipped or on the ground at your feet."
	icon = 'icons/obj/old_weapons.dmi'
	icon_state = "sharpened_stick"
	color = "#824B28"
	max_amount = 50
	w_class = ITEM_SIZE_SMALL
	flammable = TRUE
	value = 0

// Real hands/equipment only. Never search closed or nested storage.
/proc/furniture_joinery_equipped(mob/living/human/H, obj/item/I)
	return !QDELETED(H) && !QDELETED(I) && I.loc == H && H.get_inventory_slot(I) && (isnull(I.health) || I.health > 0)

/proc/furniture_joinery_available(mob/living/human/H, obj/item/I)
	return furniture_joinery_equipped(H, I) || (!QDELETED(H) && !QDELETED(I) && isturf(I.loc) && I.loc == get_turf(H))

/proc/furniture_joinery_tool(obj/item/I, role, material/stock)
	if (QDELETED(I) || I.woodwork_owner || (!isnull(I.health) && I.health <= 0))
		return FALSE
	switch (role)
		if ("shaping") return woodwork_shaping_tool(I, stock)
		if ("chisel") return istype(I, /obj/item/weapon/chisel)
		if ("hammer") return istype(I, /obj/item/weapon/hammer)
	return FALSE

/datum/furniture_joinery_action
	should_save = FALSE
	var/list/spec
	var/list/tools = list()
	var/mob/living/human/actor
	var/obj/item/stack/stock
	var/obj/item/stack/component
	var/datum/stack_recipe/recipe
	var/atom/stock_loc
	var/turf/site
	var/datum/save_epoch

/datum/furniture_joinery_action/New(obj/item/stack/S, mob/living/human/H, datum/stack_recipe/R)
	..()
	actor = H
	stock = S
	recipe = R
	spec = furniture_joinery_spec(R)
	stock_loc = S.loc
	site = get_turf(H)
	save_epoch = persistence_admission_identity
	if (!spec || !istype(H))
		return
	if (spec["component_type"])
		component = H.l_hand == S ? H.r_hand : H.l_hand
	for (var/role in spec["tools"])
		for (var/slot in (list(slot_l_hand, slot_r_hand) + slot_equipment_priority))
			var/obj/item/I = H.get_equipped_item(slot)
			if (furniture_joinery_equipped(H, I) && furniture_joinery_tool(I, role, S.get_material()))
				tools[role] = I
				break
		if (!tools[role])
			// At most 32 movable atoms at the actor's feet; no containers or range scan.
			var/visited = 0
			for (var/atom/movable/A in site)
				if (++visited > 32)
					break
				var/obj/item/I = A
				if (istype(I) && furniture_joinery_available(H, I) && furniture_joinery_tool(I, role, S.get_material()))
					tools[role] = I
					break

/datum/furniture_joinery_action/proc/valid()
	if (!spec || QDELETED(actor) || QDELETED(stock) || actor.incapacitated())
		return FALSE
	if (persistence_save_in_progress || persistence_active_operation || persistence_load_recovery_required || save_epoch != persistence_admission_identity)
		return FALSE
	if (actor.woodwork_owner || stock.woodwork_owner || stock.loc != stock_loc || !stock.crafting_stack_accessible(actor) || get_turf(actor) != site)
		return FALSE
	if (!istype(stock, text2path(spec["stock_type"])) || recipe.result_type != text2path(spec["result_type"]) || recipe.req_amount != spec["stock_cost"] || !stock.can_use(recipe.req_amount))
		return FALSE
	var/material/expected = istype(stock, /obj/item/stack/material/wood) ? /material/wood : /material/wood/soft
	var/material/actual = stock.get_material()
	if (!actual || actual.type != expected)
		return FALSE
	if (istype(stock, /obj/item/stack/material/wood) && (stock:onfire || stock:splitting_in_progress))
		return FALSE
	var/node = get_recipe_node_req("[recipe.result_type]")
	if (!map || (node && !map.is_node_done(actor.civilization, node)))
		return FALSE
	if (recipe.one_per_turf && (locate(recipe.result_type) in site))
		return FALSE
	for (var/role in spec["tools"])
		var/obj/item/I = tools[role]
		if (!furniture_joinery_available(actor, I) || !furniture_joinery_tool(I, role, stock.get_material()))
			return FALSE
	if (spec["component_type"])
		if (!furniture_joinery_equipped(actor, component) || !actor.item_is_in_hands(component) || component.type != text2path(spec["component_type"]) || component.woodwork_owner || !component.can_use(spec["component_cost"]))
			return FALSE
	return TRUE

/datum/furniture_joinery_action/proc/consume_component()
	// Caller revalidates immediately before the primary debit; no yields here.
	if (component)
		if (component.amount == spec["component_cost"])
			actor.remove_from_mob(component)
		component.use(spec["component_cost"])
	var/obj/item/weapon/material/blade = tools["shaping"]
	if (istype(blade))
		blade.health -= 0.25
		blade.check_health()
