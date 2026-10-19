// Production produce_recipe, do_after, stack.use, equipment lookup/removal and
// handle/output constructors. Character startup, skill learning and HUD painting
// are adapters; slot fields are arranged directly, not through a client UI.
var/list/handle_ci_cases = list()
var/handle_ci_retired = 0

/mob/living/human/handle_ci/New()
	return
/mob/living/human/handle_ci/religion_check()
	return "none"
/mob/living/human/handle_ci/getStatCoeff(statname)
	return 1
/mob/living/human/handle_ci/adaptStat(statname, multiplier = 1)
	return
/mob/living/human/handle_ci/update_inv_back(update_icons = 1)
	return
/mob/living/human/handle_ci/update_inv_shoulder(update_icons = 1)
	return
/mob/living/human/handle_ci/update_inv_belt(update_icons = 1)
	return
/mob/living/human/handle_ci/update_inv_l_hand(update_icons = 1)
	return
/mob/living/human/handle_ci/update_inv_r_hand(update_icons = 1)
	return
/mob/living/human/handle_ci/update_action_buttons()
	return

/obj/item/weapon/material/handle/recipe_ci/Destroy()
	handle_ci_retired++
	return ..()

/proc/handle_ci_expect(condition, label)
	handle_ci_cases += list(list("case"=label,"passed"=!!condition))
	if (!condition)
		recipe_ci_fail("handle crafting", label)
	return condition

/proc/handle_ci_outputs(result_path)
	var/count = 0
	for (var/obj/O in locate(1,1,1))
		if (O.type == result_path)
			count++
	return count

/datum/handle_ci_case
	var/mob/living/human/handle_ci/actor
	var/obj/item/stack/stock
	var/obj/item/weapon/material/handle/recipe_ci/handle
	var/datum/stack_recipe/recipe
	var/slot
	var/before_stock
	var/before_output
	var/before_retired

/datum/handle_ci_case/New(title = "bone pickaxe", equipment_slot = slot_back, delay = 0)
	var/list/catalog_row
	for (var/list/row in craftlist_lists["global"])
		if (row[2] == title)
			catalog_row = row
			break
	if (!catalog_row)
		throw EXCEPTION("Missing handle fixture catalog row: [title]")
	var/input_path = text2path("/obj/item/stack[copytext(catalog_row[1], 1, length(catalog_row[1]))]")
	var/result_path = text2path(catalog_row[3])
	if (!ispath(input_path, /obj/item/stack/material) || !ispath(result_path, /obj/item))
		throw EXCEPTION("Missing handle fixture input/output type: [title]")
	actor = new(locate(1,1,1))
	stock = new input_path(actor, 30, FALSE)
	actor.r_hand = stock
	handle = new(actor)
	handle.name = "selected custom handle"
	handle.crafting_quality = 2
	slot = equipment_slot
	switch (slot)
		if (slot_back) actor.back = handle
		if (slot_shoulder) actor.shoulder = handle
		if (slot_belt) actor.belt = handle
		if (slot_l_hand) actor.l_hand = handle
		if (slot_r_hand)
			actor.l_hand = stock
			actor.r_hand = handle
			actor.hand = TRUE
	var/supplied = catalog_row[13] == "null" ? null : catalog_row[13]
	// Real catalog costs/types/materials/floor gate, bounded timing only.
	recipe = new(title, result_path, text2num(catalog_row[4]), 1, 1, delay, FALSE, TRUE, supplied)
	before_stock = stock.amount
	before_output = handle_ci_outputs(result_path)
	before_retired = handle_ci_retired

/datum/handle_ci_case/proc/craft()
	stock.produce_recipe(recipe, 1, actor)

/datum/handle_ci_case/proc/succeeded()
	return stock.amount == before_stock - recipe.req_amount && handle_ci_outputs(recipe.result_type) == before_output + 1 && handle_ci_retired == before_retired + 1 && !actor.get_equipped_item(slot) && QDELETED(handle)

/datum/handle_ci_case/proc/unchanged()
	return stock.amount == before_stock && handle_ci_outputs(recipe.result_type) == before_output && handle_ci_retired == before_retired && !QDELETED(handle) && handle.loc == actor && actor.get_equipped_item(slot) == handle && handle.name == "selected custom handle" && handle.crafting_quality == 2

/proc/recipe_ci_handles()
	var/turf/T = locate(1,1,1)
	if (!isfloor(T))
		T = new /turf/floor/plating(T)
	var/datum/handle_ci_case/C = new
	C.craft()
	// The hands-only mutation stops here with exactly this named failure.
	if (!handle_ci_expect(C.succeeded(), "equipped back handle is accepted exactly once"))
		text2file(json_encode(handle_ci_cases), "handle-checks.json")
		return
	for (var/slot in list(slot_l_hand, slot_r_hand, slot_shoulder, slot_belt))
		C = new("bone pickaxe", slot)
		C.craft()
		handle_ci_expect(C.succeeded(), "hand/shoulder/belt slot cleanup [slot]")
	C = new
	var/obj/item/other = new(C.actor)
	C.actor.l_hand = other
	C.craft()
	handle_ci_expect(C.succeeded() && C.actor.l_hand == other && C.actor.r_hand == C.stock, "full hands preserve existing items and produce one tool on floor")
	C = new("bone pickaxe", slot_l_hand)
	var/obj/item/weapon/material/handle/spare = new(C.actor)
	C.actor.back = spare
	C.craft()
	handle_ci_expect(C.succeeded() && !QDELETED(spare) && C.actor.back == spare, "hand preferred over spare equipped handle")
	C = new
	C.stock.amount = 1
	C.before_stock = 1
	C.craft()
	handle_ci_expect(C.unchanged(), "insufficient materials preserve selected handle")
	for (var/restriction in list("canremove", "nodrop", "ground", "foreign", "loose", "nested", "nested twice"))
		C = new
		if (restriction == "canremove") C.handle.canremove = FALSE
		if (restriction == "nodrop") C.handle.nodrop = TRUE
		if (restriction == "ground") C.handle.loc = T
		if (restriction == "foreign")
			var/mob/living/human/handle_ci/foreign = new(T)
			C.handle.loc = foreign
			foreign.back = C.handle
		if (restriction == "loose") C.actor.back = null
		if (restriction == "nested" || restriction == "nested twice")
			var/obj/item/weapon/storage/container = new(C.actor)
			C.actor.back = container
			C.handle.loc = container
			if (restriction == "nested twice")
				var/obj/item/weapon/storage/inner = new(container)
				C.handle.loc = inner
		C.craft()
		handle_ci_expect(C.stock.amount == C.before_stock && handle_ci_outputs(C.recipe.result_type) == C.before_output && handle_ci_retired == C.before_retired, "reject inaccessible ingredient: [restriction]")
	// Actual waits exercise cancellation and late ingredient revalidation.
	C = new("bone pickaxe", slot_back, 4)
	spawn(1)
		C.actor.stat = UNCONSCIOUS
	C.craft()
	handle_ci_expect(C.unchanged(), "cancelled action preserves original handle and quality")
	C = new("bone pickaxe", slot_back, 4)
	spawn(1)
		C.stock.amount = 1
	C.craft()
	handle_ci_expect(C.stock.amount == 1 && handle_ci_outputs(C.recipe.result_type) == C.before_output && handle_ci_retired == C.before_retired && C.actor.back == C.handle, "failed material debit does not consume handle")
	for (var/change in list("handle moved", "handle deleted", "stock moved", "stock deleted"))
		C = new("bone pickaxe", slot_back, 4)
		spare = new(C.actor)
		C.actor.shoulder = spare
		spawn(1)
			if (change == "handle moved") C.actor.remove_from_mob(C.handle)
			if (change == "handle deleted") qdel(C.handle)
			if (change == "stock moved") C.stock.loc = T
			if (change == "stock deleted") qdel(C.stock)
		C.craft()
		handle_ci_expect(handle_ci_outputs(C.recipe.result_type) == C.before_output && !QDELETED(spare) && C.actor.shoulder == spare && (change == "stock deleted" || C.stock.amount == C.before_stock) && (change == "handle deleted" || !QDELETED(C.handle)), "late change cancels without substituting spare: [change]")
	C = new("bone pickaxe", slot_back, 4)
	var/obj/item/stack/material/bone/second_stock = new(T, 30, FALSE)
	spawn(0)
		C.craft()
	spawn(0)
		second_stock.produce_recipe(C.recipe, 1, C.actor)
	sleep(6)
	handle_ci_expect(C.succeeded() && second_stock.amount == 30, "concurrent crafts debit only one stack and one handle")
	C = new
	C.stock.loc = T
	C.craft()
	handle_ci_expect(C.succeeded(), "nearby ground source stack remains eligible for direct callers")
	// Every active global row in the unchanged shared title predicate.
	for (var/title in list("bone hatchet", "battle axe", "bone shovel", "stone pickaxe", "stone hatchet", "bamboo spear", "trench shovel", "sandstone hatchet", "pickaxe"))
		C = new(title, slot_shoulder)
		C.craft()
		handle_ci_expect(C.succeeded(), "catalog handle family: [title]")
	text2file(json_encode(handle_ci_cases), "handle-checks.json")
