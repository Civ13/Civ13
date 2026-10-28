// Uses real catalog generation, produce_recipe, do_after and consumption.
// Existing handle_ci supplies inert character startup/stats/HUD adapters only.
/datum/joinery_ci_case
	var/mob/living/human/handle_ci/actor
	var/obj/item/stack/stock
	var/obj/item/stack/wooden_dowels/dowels
	var/obj/item/weapon/chisel/chisel
	var/obj/item/weapon/hammer/hammer
	var/datum/stack_recipe/recipe
	var/before_output
	var/component_cost

/datum/joinery_ci_case/New(title = "joinery: hewn chair (wooden pegs)", delay = 0)
	..()
	actor = new(locate(1,1,1))
	actor.civilization = "recipe_ci"
	var/list/row
	for (var/list/R in craftlist_lists["global"])
		if (R[2] == title)
			row = R
	if (!row)
		throw EXCEPTION("Missing joinery catalog fixture")
	var/stock_path = text2path(row[1] == "/material/wood/" ? "/obj/item/stack/material/wood" : "/obj/item/stack/material/woodplank")
	stock = new stock_path(actor, 20, FALSE)
	actor.r_hand = stock
	recipe = new(title, text2path(row[3]), text2num(row[4]), 1, 1, delay, text2num(row[6]), text2num(row[7]))
	var/list/spec = furniture_joinery_spec(recipe)
	component_cost = spec["component_cost"]
	if (component_cost)
		dowels = new(actor, 10, FALSE)
		actor.l_hand = dowels
		chisel = new(actor)
		hammer = new /obj/item/weapon/hammer/tribalhammer(actor)
		actor.belt = chisel
		actor.back = hammer
	else
		var/obj/item/weapon/flint/F = new(actor)
		F.sharp = TRUE
		F.sharpened = TRUE
		actor.l_hand = F
	before_output = handle_ci_outputs(recipe.result_type)

/datum/joinery_ci_case/proc/craft()
	stock.produce_recipe(recipe, 1, actor)

/datum/joinery_ci_case/proc/unchanged()
	return stock.amount == 20 && (!dowels || dowels.amount == 10) && handle_ci_outputs(recipe.result_type) == before_output

/datum/joinery_ci_case/proc/clean()
	for (var/obj/O in locate(1,1,1))
		if (O.type == recipe.result_type)
			qdel(O)
	qdel(actor)

/proc/joinery_ci_expect(condition, label)
	if (!condition)
		recipe_ci_fail("furniture joinery", label)

/proc/recipe_ci_furniture_joinery()
	map.ordinal_age = 0
	var/datum/stack_recipe/seed = new("joinery: whittled wooden dowel set")
	furniture_joinery_spec(seed)
	// Existing fixture faction has every node done; locked controls use another.
	var/datum/joinery_ci_case/C
	for (var/title in furniture_joinery_specs)
		C = new(title)
		C.craft()
		joinery_ci_expect(C.stock.amount == 20 - C.recipe.req_amount && (!C.dowels || C.dowels.amount == 10 - C.component_cost) && handle_ci_outputs(C.recipe.result_type) == C.before_output + 1, "paid construction: [title]")
		joinery_ci_expect(!C.chisel || (!QDELETED(C.chisel) && !QDELETED(C.hammer)), "assembly tools reused: [title]")
		C.clean()
	// Test every rejection through the production action, including post-wait changes.
	for (var/change in list("missing pegs", "nested chisel", "broken hammer", "locked research", "cancelled", "tool moved", "peg spent", "source spent", "occupied tile", "save crossed"))
		C = new("joinery: hewn chair (wooden pegs)", 4)
		if (change == "missing pegs") C.actor.l_hand = null
		if (change == "nested chisel") C.chisel.loc = C.hammer
		if (change == "broken hammer") C.hammer.health = 0
		if (change == "locked research")
			C.actor.civilization = "joinery_locked_ci"
			map.faction_baseline_era[C.actor.civilization] = 0
		if (change in list("cancelled", "tool moved", "peg spent", "source spent", "occupied tile", "save crossed"))
			spawn(1)
				switch (change)
					if ("cancelled") C.actor.stat = UNCONSCIOUS
					if ("tool moved") C.actor.remove_from_mob(C.chisel)
					if ("peg spent") C.dowels.amount = 0
					if ("source spent") C.stock.amount = 0
					if ("occupied tile") new /obj/structure/bed/chair/wood(locate(1,1,1))
					if ("save crossed") persistence_admission_identity = new /datum
		C.craft()
		joinery_ci_expect((change == "source spent" || C.stock.amount == 20) && (change == "peg spent" || C.dowels.amount == 10) && handle_ci_outputs(C.recipe.result_type) == C.before_output + (change == "occupied tile" ? 1 : 0), "no debit on rejection: [change]")
		C.clean()
	// Exhausted secondary stock clears its real hand; no free replacement appears.
	C = new
	C.dowels.amount = C.component_cost
	C.craft()
	joinery_ci_expect(C.stock.amount == 16 && QDELETED(C.dowels) && !C.actor.l_hand, "last dowel set consumed and hand cleared")
	C.clean()
	// Two waits sharing one last component can create only one result.
	C = new("joinery: hewn chair (wooden pegs)", 4)
	C.dowels.amount = 1
	spawn(0) C.craft()
	spawn(0) C.craft()
	sleep(6)
	joinery_ci_expect(C.stock.amount == 16 && handle_ci_outputs(C.recipe.result_type) == C.before_output + 1, "competing waits cannot spend one peg set twice")
	C.clean()
