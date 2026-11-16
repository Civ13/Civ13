// Coffee: find, roast, grind, brew.
//
// - Coffee grows wild in jungle and savanna (flora regrowth) and its seeds can
//   be foraged there. Harvesting gives green coffee cherries.
// - Green coffee is no drink. Roast it in a lit campfire, stove or oven
//   (oven.dm process()) into roasted coffee beans, which keep.
// - Grind roasted beans in a mortar and pestle (processing_recipes.dm) into
//   coffee grounds.
// - Brew grounds with water in a small pot on a lit campfire or stove, or in a
//   wooden mug with a hot stone (stone_boiling.dm). Each unit of grounds turns
//   COFFEE_BREW_WATER units of water into COFFEE_BREW_WATER + 1 units of coffee.
// - Coffee wakes you up, warms you, helps you get your breath back and lifts
//   the mood a little. It is no running stimulant.

#define COFFEE_BREW_WATER 4

/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee
	name = "roasted coffee beans"
	desc = "A handful of dark, fragrant roasted coffee beans. Grind them in a mortar and pestle, then brew the grounds in hot water."
	icon = 'icons/obj/food/food.dmi'
	icon_state = "roasted_coffee"
	nutriment_amt = 1
	nutriment_desc = list("bitter roasted beans" = 1)
	bitesize = 1
	w_class = ITEM_SIZE_TINY
	value = 4
	decay = 0
	roasted = TRUE // a second roast burns them
	raw = FALSE

/obj/item/weapon/reagent_containers/food/snacks/roasted_coffee/New()
	..()
	reagents.add_reagent("coffee", 2) // chewed beans give a weak kick

/datum/reagent/coffee_grounds
	name = "Coffee Grounds"
	id = "coffee_grounds"
	description = "Ground roasted coffee beans. Brew them in boiling water."
	taste_description = "bitter grit"
	reagent_state = SOLID
	color = "#2B1708"

// Brew any coffee grounds in this holder with its water. Returns the coffee made.
/datum/reagents/proc/brew_coffee()
	var/grounds = get_reagent_amount("coffee_grounds")
	var/water = get_reagent_amount("water")
	if (grounds <= 0 || water <= 0)
		return 0
	var/batches = min(grounds, water / COFFEE_BREW_WATER)
	if (batches <= 0)
		return 0
	remove_reagent("coffee_grounds", batches)
	remove_reagent("water", batches * COFFEE_BREW_WATER)
	var/made = batches * (COFFEE_BREW_WATER + 1)
	add_reagent("coffee", made)
	return made

// Tell the brewer when grounds were left over for want of water.
/proc/coffee_brew_notice(datum/reagents/holder, atom/where, made)
	if (!holder || !where)
		return
	if (made > 0)
		where.visible_message(SPAN_NOTICE("The water in \the [holder.my_atom] turns dark: the coffee is brewed."))
	if (holder.get_reagent_amount("coffee_grounds") > 0)
		where.visible_message(SPAN_NOTICE("Some coffee grounds are left in \the [holder.my_atom]: brew them with more water ([COFFEE_BREW_WATER] units for each unit of grounds)."))

/datum/reagent/drink/coffee/proc/coffee_perk(mob/living/human/M, removed)
	if (!istype(M) || !islist(M.stats) || !islist(M.stats["stamina"]))
		return
	var/cap = M.diet_stamina_cap()
	if (M.stats["stamina"][1] < cap)
		M.stats["stamina"][1] = min(cap, M.stats["stamina"][1] + removed * 5)
	M.adjust_mood(removed * 1, "coffee")
