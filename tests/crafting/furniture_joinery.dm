// Uses real catalog generation, produce_recipe, do_after and consumption.
// Existing handle_ci supplies inert character startup/stats/HUD adapters only.
/world
	maxx = 2

/proc/joinery_ci_outputs(result_path)
	var/count = 0
	for (var/obj/O in locate(2,1,1))
		if (O.type == result_path)
			count++
	return count
/mob/living/human/handle_ci/joinery_ci
	var/joinery_xp = 0

/mob/living/human/handle_ci/joinery_ci/adaptStat(statname, multiplier = 1)
	if (statname == "crafting")
		joinery_xp += multiplier

/datum/joinery_ci_case
	var/mob/living/human/handle_ci/joinery_ci/actor
	var/obj/item/stack/stock
	var/obj/item/stack/wooden_dowels/dowels
	var/obj/item/weapon/chisel/chisel
	var/obj/item/weapon/hammer/hammer
	var/datum/stack_recipe/recipe
	var/before_output
	var/component_cost

/datum/joinery_ci_case/New(title = "joinery: hewn chair (wooden pegs)", delay = 0)
	..()
	actor = new(locate(2,1,1))
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
		// Legal bare-character setup: paid tools on the floor, no fake belt/back slots.
		chisel = new(locate(2,1,1))
		hammer = new /obj/item/weapon/hammer/tribalhammer(locate(2,1,1))
	else
		var/obj/item/weapon/flint/F = new(actor)
		F.sharp = TRUE
		F.sharpened = TRUE
		actor.l_hand = F
	before_output = joinery_ci_outputs(recipe.result_type)

/datum/joinery_ci_case/proc/craft()
	stock.produce_recipe(recipe, 1, actor)

/datum/joinery_ci_case/proc/unchanged()
	return stock.amount == 20 && (!dowels || dowels.amount == 10) && joinery_ci_outputs(recipe.result_type) == before_output

/datum/joinery_ci_case/proc/clean()
	for (var/obj/O in locate(2,1,1))
		if (O.type == recipe.result_type)
			qdel(O)
	qdel(actor)
	// The separate fixture tile belongs only to these cases. Retire dropped
	// inputs/tools too so the bounded ground scan is not testing old clutter.
	for (var/obj/item/I in locate(2,1,1))
		qdel(I)

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
		C = new(title, 4)
		C.craft()
		joinery_ci_expect(C.stock.amount == 20 - C.recipe.req_amount && (!C.dowels || C.dowels.amount == 10 - C.component_cost) && joinery_ci_outputs(C.recipe.result_type) == C.before_output + 1, "paid construction: [title]")
		joinery_ci_expect(C.actor.joinery_xp == C.recipe.req_amount, "paid construction XP: [title]")
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
					if ("tool moved") C.chisel.loc = C.hammer
					if ("peg spent") C.dowels.amount = 0
					if ("source spent") C.stock.amount = 0
					if ("occupied tile") new /obj/structure/bed/chair/wood(locate(2,1,1))
					if ("save crossed") persistence_admission_identity = new /datum
		C.craft()
		joinery_ci_expect((change == "source spent" || C.stock.amount == 20) && (change == "peg spent" || C.dowels.amount == 10) && joinery_ci_outputs(C.recipe.result_type) == C.before_output + (change == "occupied tile" ? 1 : 0), "no debit on rejection: [change]")
		joinery_ci_expect(C.actor.joinery_xp == 0, "no unpaid XP on rejection: [change]")
		C.clean()
	// Preset stack subtypes keep their ordinary material contract.
	for (var/title in list("joinery: hewn chair (wooden pegs)", "joinery: whittled wooden dowel set"))
		C = new(title)
		qdel(C.stock)
		var/stock_path = C.component_cost ? /obj/item/stack/material/wood/twentyfive : /obj/item/stack/material/woodplank/twentyfive
		C.stock = new stock_path(C.actor, 20, FALSE)
		C.actor.r_hand = C.stock
		var/before_amount = C.stock.amount
		C.craft()
		joinery_ci_expect(C.stock.amount == before_amount - C.recipe.req_amount && joinery_ci_outputs(C.recipe.result_type) == C.before_output + 1, "preset stack subtype: [title]")
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
	joinery_ci_expect(C.stock.amount == 16 && joinery_ci_outputs(C.recipe.result_type) == C.before_output + 1, "competing waits cannot spend one peg set twice")
	C.clean()
	// Existing stool constructor chooses wood, and disassembly returns only one
	// log, never metal or paid pegs. Native execution remains a separate check.
	C = new("joinery: pegged wooden stool")
	C.craft()
	var/obj/item/weapon/stool/wood/stool = locate() in locate(2,1,1)
	joinery_ci_expect(stool && stool.material && stool.material.name == "wood", "stool has actual wood material")
	if (stool)
		stool.dismantle()
	var/logs = 0
	var/metal = 0
	for (var/obj/item/stack/material/S in locate(2,1,1))
		if (istype(S, /obj/item/stack/material/wood)) logs += S.amount
		if (istype(S, /obj/item/stack/material/iron) || istype(S, /obj/item/stack/material/steel)) metal += S.amount
	joinery_ci_expect(logs == 1 && metal == 0, "stool refund is one paid wood log without metal")
	C.clean()
