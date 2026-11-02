// Production produce_recipe, do_after, stack.use, equipment lookup/removal and
// handle/output constructors. Character startup, skill learning and HUD painting
// are adapters; slot fields are arranged directly, not through a client UI.
var/list/handle_ci_cases = list()
var/handle_ci_retired = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

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
/mob/living/human/handle_ci/update_icons()
	return

// Only the connection and delay are adapted; assembly and hand placement are real.
/obj/item/weapon/branch/sharpened/axe_hand_ci/axe_actor_connected(mob/user)
	return TRUE
/obj/item/weapon/branch/sharpened/axe_hand_ci/axe_assembly_wait(mob/user)
	return TRUE

/obj/item/weapon/material/handle/recipe_ci/Destroy()
	handle_ci_retired++
	return ..()

/proc/handle_ci_expect(condition, label, list/details = null)
	handle_ci_cases += list(list("case"=label,"passed"=!!condition,"details"=details))
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
	var/obj/item/weapon/material/handle/spare
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
	// The isolated runner bypasses global startup; use actual event objects for
	// real equipment exits/entries rather than replacing those lifecycle hooks.
	GLOB.all_observable_events = list()
	GLOB.moved_event = new
	GLOB.dir_set_event = new
	GLOB.destroyed_event = new
	GLOB.name_set_event = new
	GLOB.stat_set_event = new
	var/turf/T = locate(1,1,1)
	if (!isfloor(T))
		throw EXCEPTION("Handle fixture requires the initial world floor")
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
		spawn(1)
			// Introduce the alternative after the exact original was selected.
			// A datum field survives spawn's copy of the local variable frame.
			C.spare = new(C.actor)
			C.actor.shoulder = C.spare
			if (change == "handle moved") C.actor.remove_from_mob(C.handle)
			if (change == "handle deleted") qdel(C.handle)
			if (change == "stock moved") C.stock.loc = T
			if (change == "stock deleted") qdel(C.stock)
		C.craft()
		var/list/details = list("output_delta"=handle_ci_outputs(C.recipe.result_type)-C.before_output,"stock_amount"=QDELETED(C.stock) ? null : C.stock.amount,"selected_deleted"=QDELETED(C.handle),"spare_available"=!QDELETED(C.spare),"spare_equipped"=(C.actor.shoulder == C.spare))
		handle_ci_expect(details["output_delta"] == 0 && details["spare_available"] && details["spare_equipped"] && (change == "stock deleted" || C.stock.amount == C.before_stock) && (change == "handle deleted" || !QDELETED(C.handle)), "late change cancels without substituting spare: [change]", details)
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
	// The completed stone hatchet goes to the current active hand only when
	// the last input stack has actually vacated that hand.
	C = new("stone hatchet", slot_back)
	C.stock.amount = C.recipe.req_amount
	C.craft()
	var/obj/item/weapon/material/hatchet/tribal/held_hatchet = C.actor.get_active_hand()
	var/held_hatchet_count = 0
	for (var/obj/item/weapon/material/hatchet/tribal/candidate in C.actor)
		if (candidate.type == C.recipe.result_type && !QDELETED(candidate))
			held_hatchet_count++
	handle_ci_expect(istype(held_hatchet) && held_hatchet.loc == C.actor && held_hatchet_count == 1 && handle_ci_outputs(C.recipe.result_type) == C.before_output && QDELETED(C.stock) && QDELETED(C.handle), "stone hatchet reaches newly empty active hand exactly once")
	// Exercise the same production placement proc independently of recipe debit.
	var/mob/living/human/handle_ci/recipient = new(T)
	var/obj/item/weapon/material/hatchet/tribal/flint/axe = new(T)
	recipient.hand = FALSE
	var/obj/item/blocker = new(recipient)
	recipient.r_hand = blocker
	handle_ci_expect(!offer_crafted_axe_to_active_hand(recipient, axe) && axe.loc == T && recipient.r_hand == blocker, "occupied active hand leaves axe on floor")
	// Directly switch active hands to test completion-hand selection; no wait is simulated.
	recipient.hand = TRUE
	handle_ci_expect(offer_crafted_axe_to_active_hand(recipient, axe) && recipient.l_hand == axe && recipient.r_hand == blocker, "current active hand selection after direct hand switch")
	recipient.remove_from_mob(axe)
	handle_ci_expect(!recipient.get_active_hand() && axe.loc == T, "incapacity control starts with active hand empty")
	var/obj/item/weapon/material/hatchet/tribal/flint/second_axe = new(T)
	recipient.stat = UNCONSCIOUS
	handle_ci_expect(!offer_crafted_axe_to_active_hand(recipient, second_axe) && second_axe.loc == T, "incapacitated actor leaves result on floor")
	recipient.stat = CONSCIOUS
	recipient.stunned = 1
	handle_ci_expect(!recipient.get_active_hand() && !offer_crafted_axe_to_active_hand(recipient, second_axe) && second_axe.loc == T, "conscious stunned actor leaves result on floor")
	var/mob/living/human/handle_ci/flint_actor = new(T)
	var/obj/item/weapon/branch/sharpened/axe_hand_ci/stick = new(T)
	var/obj/item/weapon/flint/sharpened/head = new(flint_actor)
	var/obj/item/stack/sinew/binding = new(T, 2, FALSE)
	flint_actor.hand = FALSE
	flint_actor.r_hand = head
	var/flint_ground_before = handle_ci_outputs(/obj/item/weapon/material/hatchet/tribal/flint)
	stick.assemble_flint_axe(flint_actor, head)
	var/flint_held_count = 0
	for (var/obj/item/weapon/material/hatchet/tribal/flint/candidate in flint_actor)
		if (!QDELETED(candidate))
			flint_held_count++
	handle_ci_expect(istype(flint_actor.r_hand, /obj/item/weapon/material/hatchet/tribal/flint) && flint_actor.r_hand.loc == flint_actor && flint_held_count == 1 && handle_ci_outputs(/obj/item/weapon/material/hatchet/tribal/flint) == flint_ground_before && QDELETED(head) && QDELETED(stick) && binding.amount == 1, "flint assembly consumes parts and fills vacated active hand exactly once")
	text2file(json_encode(handle_ci_cases), "handle-checks.json")
