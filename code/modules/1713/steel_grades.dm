// Steel grades and the bloomery's steely bloom (docs/steelmaking.md).
//
// Steel comes in three grades. Each is its own stack type, so every recipe
// that takes steel takes any grade, but stacks of different grades never
// merge. The grade scales the quality of anything forged from it, before
// the quench tub hardens it: blister steel (carburized, uneven) x0.9,
// steel x1.0, fine steel (crucible or folded tamahagane) x1.1.
//
// A bloomery firing under a bellows blast leaves some of its sponge iron
// steely: a smith sorts that on the anvil into blister steel.

#define STEELY_BLOOM_CHANCE 10 // percent of a blown bloomery's sponge iron that comes out steely

// Forged-quality factor of a stack of metal. 1 for anything ungraded.
/obj/item/stack/material/var/stock_grade = 1
// Armour forged from it: factor on melee armour, and on bullet and arrow armour.
/obj/item/stack/material/var/armor_blunt_grade = 1
/obj/item/stack/material/var/armor_pierce_grade = 1

/obj/item/stack/material/steel/blister
	name = "blister steel"
	stock_grade = 0.9

/obj/item/stack/material/steel/fine
	name = "fine steel"
	stock_grade = 1.1

// Grades keep their own stacks (material/New sets stacktype from the material).
/obj/item/stack/material/steel/blister/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/steel/fine/New()
	. = ..()
	stacktype = type

/obj/item/stack/material/steel/proc/grade_name()
	return null

// A graded stack is drawn as its own sheet in steelmaking.dmi.
/obj/item/stack/material/steel/proc/grade_sheet()
	return null

/obj/item/stack/material/steel/blister/grade_sheet()
	return "sheet-blister"

/obj/item/stack/material/steel/fine/grade_sheet()
	return "sheet-fine"

/obj/item/stack/material/steel/blister/update_icon()
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = grade_sheet()

/obj/item/stack/material/steel/fine/update_icon()
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = grade_sheet()

/obj/item/stack/material/steel/blister/grade_name()
	return "blister"

/obj/item/stack/material/steel/fine/grade_name()
	return "fine"

/obj/item/stack/material/steel/update_strings()
	..()
	var/grade = grade_name()
	if (!grade)
		return
	name = "[grade] [name]"
	var/more = grade_desc()
	if (more)
		desc = "[desc] [more]"

/obj/item/stack/material/steel/proc/grade_desc()
	return null

/obj/item/stack/material/steel/blister/grade_desc()
	return "Carburized iron, steel only skin-deep in places: what is forged from it comes out a little worse."

/obj/item/stack/material/steel/fine/grade_desc()
	return "Even, clean steel: what is forged from it comes out a little better."

// Grade of the stock a piece was forged from; quench_tub.dm hardens to it.
/obj/item/weapon/material/var/tmp/forged_grade = 1

// Returns the piece, so the anvil can pass it on to finish_forged_piece().
/obj/structure/anvil/proc/apply_stock_grade(obj/item/I, obj/item/stack/material/stock)
	. = I
	if (!istype(stock))
		return
	if (istype(I, /obj/item/clothing))
		grade_forged_armor(I, stock)
		return
	var/obj/item/weapon/material/W = I
	if (!istype(W) || stock.stock_grade == 1)
		return
	W.forged_grade = stock.stock_grade
	var/obj/item/weapon/material/hatchet/H = W
	if ((istype(H) && H.component_wear) || istype(W, /obj/item/weapon/material/part/axehead/hatchet))
		W.hatchet_stock_grade = stock.stock_grade
	W.crafting_quality *= stock.stock_grade
	W.update_force()

#define GRADED_ARMOR_CAP 90 // a grade never lifts an armour value past this

// Armour forged from graded stock: blows by one factor, bullets and arrows by
// another. A grade never lowers armour and never lifts it past the cap.
/proc/grade_forged_armor(obj/item/clothing/C, obj/item/stack/material/stock)
	if (!istype(C) || !istype(stock) || !C.armor)
		return FALSE
	// Family armor takes its tier from the metal (armor_families.dm).
	if (C.armor_family)
		var/tier = armor_tier_for_stock(stock)
		if (tier)
			C.armor_tier = tier
		C.armor_blow_grade = stock.armor_blunt_grade
		C.armor_arrow_grade = stock.armor_pierce_grade
	if (stock.armor_blunt_grade == 1 && stock.armor_pierce_grade == 1)
		return FALSE
	for (var/key in list("melee", "arrow", "gun"))
		var/value = C.armor[key]
		if (!isnum(value) || value <= 0)
			continue
		var/factor = key == "melee" ? stock.armor_blunt_grade : stock.armor_pierce_grade
		C.armor[key] = max(value, min(GRADED_ARMOR_CAP, round(value * factor)))
	C.desc = "[C.desc] It is forged from [stock.name]."
	return TRUE

#undef GRADED_ARMOR_CAP

//////////////////////////////////////////////////////////////////////////////
// Steely bloom

/obj/item/stack/ore/iron_sponge/steely
	name = "steely bloom"
	icon = 'icons/obj/steelmaking.dmi'
	icon_state = "steely_bloom"
	desc = "A lump of bloomery iron that soaked up carbon from the charcoal under a hard blast. Sorted on an anvil, it gives blister steel."

/obj/item/stack/ore/iron_sponge/steely/update_icon()
	icon_state = "steely_bloom"

/obj/item/stack/ore/iron_sponge/steely/New()
	. = ..()
	stacktype = type

// How many of a blown firing's sponge iron come out steely.
/proc/steely_bloom_count(sponge)
	. = 0
	for (var/i in 1 to sponge)
		if (prob(STEELY_BLOOM_CHANCE))
			.++

// Steely bloom sorts into blister steel on any anvil that works iron.
/obj/structure/anvil/proc/sort_steely_bloom(obj/item/stack/ore/iron_sponge/steely/P, mob/user)
	to_chat(user, "You begin sorting the steely bloom...")
	icon_state = "[base_icon]_anvil_use"
	in_use = TRUE
	update_icon()
	playsound(loc, 'sound/effects/clang.ogg', 100, TRUE)
	var/initial_amount = P.amount
	if (do_after(user, 15 * initial_amount, src) && !QDELETED(P) && P.amount == initial_amount)
		qdel(P)
		spawn_stack(/obj/item/stack/material/steel/blister, loc, initial_amount)
		to_chat(user, SPAN_NOTICE("You hammer out the slag and cut the steely parts into blister steel."))
	in_use = FALSE
	update_icon()

//////////////////////////////////////////////////////////////////////////////
// Bloomery fuel: charcoal, or wood at half its worth. Raw coal's sulphur
// ruins iron, so it is refused. A firing costs a base load to bring the
// furnace up to heat, plus fuel for each unit of ore.

#define BLOOMERY_FIRING_BASE 2 // fuel to bring a furnace to heat (one charcoal)
#define BLOOMERY_FUEL_PER_ORE 1 // fuel per unit of iron ore (one charcoal per two ore)

/obj/structure/furnace/proc/firing_fuel_cost()
	return firing_fuel_cost_for(iron, iron_sand)

// What a firing of this much ore and iron sand would cost.
/obj/structure/furnace/proc/firing_fuel_cost_for(ore, sand = 0)
	return BLOOMERY_FIRING_BASE + max(0, ore) * BLOOMERY_FUEL_PER_ORE + max(0, sand) * BLOOMERY_FUEL_PER_ORE / 2

/obj/structure/furnace/proc/has_firing_fuel()
	return fuel > 1 && fuel >= firing_fuel_cost() && !firing_refusal()

// Why this furnace can't fire now (besides fuel), or null.
/obj/structure/furnace/proc/firing_refusal()
	return null

// A blast furnace needs a steady blast no hand bellows can give: a water
// wheel or windmill must drive its bellows (mechanical_power.dm).
/obj/structure/furnace/blast_furnace/firing_refusal()
	if (mechanical_drive_factor(src) >= 1)
		return "A blast furnace needs a water wheel or windmill nearby to drive its bellows."
	return null

// Kilns melt metal in vessels and burn what they always did.
/obj/structure/furnace/kiln/firing_fuel_cost()
	return 2 + crucible_fuel()

/obj/structure/furnace/kiln/has_firing_fuel()
	return fuel > 1 && fuel >= firing_fuel_cost()

/obj/structure/furnace/lime_kiln/has_firing_fuel()
	return fuel > 1

// Fuel rates this furnace burns by hand and from automation.
/obj/structure/furnace/proc/fuel_rates()
	return bloomery_fuel_rates

/obj/structure/furnace/kiln/fuel_rates()
	return furnace_fuel_rates

/obj/structure/furnace/proc/fuel_refusal(obj/item/I)
	if (istype(I, /obj/item/stack/ore/coal))
		return "Raw coal's sulphur would ruin the iron. Burn charcoal, wood or coke."
	return null

/obj/structure/furnace/examine(mob/user, distance)
	. = ..()
	if (istype(src, /obj/structure/furnace/kiln) || istype(src, /obj/structure/furnace/lime_kiln))
		return
	to_chat(user, SPAN_NOTICE("It holds [round(fuel, 0.1)] fuel. Its next firing needs [firing_fuel_cost()]: one charcoal brings it to heat, and every two ore take another. A log is worth half a charcoal."))

#undef STEELY_BLOOM_CHANCE
#undef BLOOMERY_FIRING_BASE
#undef BLOOMERY_FUEL_PER_ORE
