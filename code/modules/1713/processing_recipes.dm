// Processing-station recipes as data.
//
// A station that turns one input into a fixed product (grinding in a mortar,
// knapping a stone) lists its rows here instead of an if-chain in its own
// code. The station reads its rows with processing_recipes_for(); the
// Crafting Atlas (scripts/atlas/interactions.py) reads this file directly.
//
// Row fields, in order:
// - station: which station's code uses the row.
// - choice: the menu label, or null when the input alone decides.
// - input: the type path the station accepts.
// - output: a type path, a reagent id, or null for a station's own special case.
// - amount: how many of the output (reagent units, or stack count).
// - delay: the work time in deciseconds before dexterity.
// - fail_chance: percent chance to ruin the input, before crafting skill.
// - gated: the output needs crafting_recipe_allowed() and counts as practice.

/datum/processing_recipe
	var/station
	var/choice
	var/input
	var/output
	var/amount = 1
	var/delay = 0
	var/fail_chance = 0
	var/gated = FALSE

/datum/processing_recipe/New(_station, _choice, _input, _output, _amount = 1, _delay = 0, _fail_chance = 0, _gated = FALSE)
	..()
	station = _station
	choice = _choice
	input = _input
	output = _output
	amount = _amount
	delay = _delay
	fail_chance = _fail_chance
	gated = _gated

var/global/list/processing_recipes = null

/proc/processing_recipe_list()
	if (!processing_recipes)
		processing_recipes = list(
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/grown/wheat, "flour", 5),
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/grown/oat, "oatflour", 5),
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/grown/barley, "barleyflour", 5),
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/grown/sunflower_seeds, "sunflower_oil", 5),
			new /datum/processing_recipe("mortar", null, /obj/item/stack/farming/seeds/flax, "linseed_oil", 2),
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/grown/olives, "olive_oil", 6),
			new /datum/processing_recipe("mortar", null, /obj/item/weapon/reagent_containers/food/snacks/roasted_coffee, "coffee_grounds", 3),
			new /datum/processing_recipe("mortar", null, /obj/item/stack/material/poppy, "poppy_straw", 3),
			new /datum/processing_recipe("mortar", null, /obj/item/stack/material/coca, "coca_leaf", 3),
			new /datum/processing_recipe("mortar", null, /obj/item/stack/material/cannabis, "thc", 3),

			new /datum/processing_recipe("flint knapping", "Sharp flake", /obj/item/weapon/flint, null, 1, 40, 10),
			new /datum/processing_recipe("flint knapping", "Three arrowheads", /obj/item/weapon/flint, /obj/item/stack/arrowhead/flint, 3, 60, 25),
			new /datum/processing_recipe("flint knapping", "Flint knife", /obj/item/weapon/flint, /obj/item/weapon/material/kitchen/utensil/knife/flint, 1, 80, 35),
			new /datum/processing_recipe("flint knapping", "Spearhead", /obj/item/weapon/flint, /obj/item/weapon/flint_spearhead, 1, 80, 30),
			new /datum/processing_recipe("flint knapping", "Sickle teeth", /obj/item/weapon/flint, /obj/item/weapon/flint_sickle_teeth, 1, 70, 25),
			new /datum/processing_recipe("flint knapping", "Hand axe", /obj/item/weapon/flint, /obj/item/weapon/material/hatchet/tribal/hand_axe, 1, 100, 30, TRUE),
			new /datum/processing_recipe("flint knapping", "Hide scraper", /obj/item/weapon/flint, /obj/item/weapon/material/hide_scraper, 1, 50, 15, TRUE),

			// Five points easier than the matching flint work: obsidian has no grain.
			new /datum/processing_recipe("obsidian knapping", "Sharp flake", /obj/item/weapon/obsidian_nodule, /obj/item/weapon/obsidian_flake, 1, 40, 5),
			new /datum/processing_recipe("obsidian knapping", "Five arrowheads", /obj/item/weapon/obsidian_nodule, /obj/item/stack/arrowhead/obsidian, 5, 60, 20),
			new /datum/processing_recipe("obsidian knapping", "Knife", /obj/item/weapon/obsidian_nodule, /obj/item/weapon/material/kitchen/utensil/knife/obsidian, 1, 80, 30),
			new /datum/processing_recipe("obsidian knapping", "Spearhead", /obj/item/weapon/obsidian_nodule, /obj/item/weapon/obsidian_spearhead, 1, 80, 25),
			new /datum/processing_recipe("obsidian knapping", "Scraper", /obj/item/weapon/obsidian_nodule, /obj/item/weapon/material/hide_scraper/obsidian, 1, 50, 10, TRUE),
			new /datum/processing_recipe("obsidian knapping", "Blade core", /obj/item/weapon/obsidian_nodule, /obj/item/weapon/obsidian_core, 1, 100, 25, TRUE),
		)
	return processing_recipes

// Every row of one station, in menu order.
/proc/processing_recipes_for(station)
	. = list()
	for (var/datum/processing_recipe/R in processing_recipe_list())
		if (R.station == station)
			. += R

// The first row of this station that accepts the item, or null.
/proc/processing_recipe_for_input(station, obj/item/I)
	if (!I)
		return null
	for (var/datum/processing_recipe/R in processing_recipes_for(station))
		if (istype(I, R.input))
			return R
	return null

/proc/processing_recipe_choice(station, choice)
	for (var/datum/processing_recipe/R in processing_recipes_for(station))
		if (R.choice == choice)
			return R
	return null

// A gated row is offered only once its output's recipe is known.
/proc/processing_recipe_allowed(datum/processing_recipe/R, mob/living/human/H)
	if (!R)
		return FALSE
	return !R.gated || crafting_recipe_allowed(H, "[R.output]")

// The menu labels this builder may pick, in order.
/proc/processing_recipe_choices(station, mob/living/human/H)
	. = list()
	for (var/datum/processing_recipe/R in processing_recipes_for(station))
		if (R.choice && processing_recipe_allowed(R, H))
			. += R.choice

// Make the row's product at T, recording practice for a gated row. Null if refused.
/proc/processing_recipe_make(datum/processing_recipe/R, turf/T, mob/living/human/H)
	if (!R || !ispath(R.output) || !processing_recipe_allowed(R, H))
		return null
	if (R.gated)
		note_craft_practice(H, "[R.output]")
	var/path = R.output
	if (R.amount > 1)
		return new path(T, R.amount)
	return new path(T)
